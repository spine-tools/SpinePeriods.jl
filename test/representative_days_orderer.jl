# Remove output database if necessary
rm(joinpath(@__DIR__, "Belgium_2017_orderer_rps.sqlite"), force=true)

# Specify database to use
sqlite_file = joinpath(@__DIR__, "Belgium_2017_orderer")

# Run
m, url_in, window__static_slice = run_spine_periods(
    "sqlite:///$(sqlite_file).sqlite",
    "sqlite:///$(sqlite_file)_rps.sqlite",
    with_optimizer=optimizer_with_attributes(
        HiGHS.Optimizer, "output_flag" => true, "mip_rel_gap" => 0.01,
        "time_limit" => 60
    )
)

# Assert right number of days selected according to chronology
chron = Dict(
    (w1,w2) => value(m.ext[:variables][:chronology][w1,w2]) 
    for w1 in SpinePeriods.window(), w2 in SpinePeriods.window()
    )
vecChron = collect(chron)
idx = findall(x -> last(x) > 0, collect(chron))
vecChron[idx]
rp = first(SpinePeriods.representative_period())
@test length(unique(last.(first.(vecChron[idx])))) ≈ SpinePeriods.representative_periods(representative_period=rp)

# Assert that the weights add up to 365
weight = Dict(w => value(m.ext[:variables][:weight][w]) for w in SpinePeriods.window())
@test sum(last.(collect(weight))) == length(SpinePeriods.window())
