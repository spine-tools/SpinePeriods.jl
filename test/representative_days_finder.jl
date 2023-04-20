# Remove output database if necessary
rm(joinpath(@__DIR__, "Belgium_2017_finder_rps.sqlite"), force=true)

# Specify database to use
sqlite_file = joinpath(@__DIR__, "Belgium_2017_finder")

# Run
m = run_spine_periods(
    "sqlite:///$(sqlite_file).sqlite",
    "$(sqlite_file)_rps.json",
    with_optimizer=optimizer_with_attributes(
        HiGHS.Optimizer, "output_flag" => true, "mip_rel_gap" => 0.01,
        "time_limit" => 10
    )
)

# Assert that the weights add up to 365
weight = Dict(w => value(m.ext[:variables][:weight][w]) for w in SpinePeriods.window())
@test isapprox(sum(last.(collect(weight))), length(SpinePeriods.window()), rtol=10^-9)
