# Remove output database if necessary
rm(joinpath(@__DIR__, "Belgium_2017_finder_rps.sqlite"), force=true)

# Specify database to use
sqlite_file = joinpath(@__DIR__, "Belgium_2017_finder")

# Run
m = SpinePeriods.run_spine_periods_selection(
    "sqlite:///$(sqlite_file).sqlite",
    "sqlite:///$(sqlite_file)_rps.sqlite",
    with_optimizer=optimizer_with_attributes(
        Cbc.Optimizer, "logLevel" => 1, "ratioGap" => 0.01,
        "seconds" => 60
    )
)

# Assert that the weights add up to 365
weight = Dict(w => value(m.ext[:variables][:weight][w]) for w in SpinePeriods.window())
@test sum(last.(collect(weight))) == length(SpinePeriods.window())
