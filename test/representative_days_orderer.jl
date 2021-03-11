using SpinePeriods
using SpineInterface
using Cbc
using JuMP
using SpineOpt

# Remove output database if necessary
rm(joinpath(@__DIR__, "Belgium_2017_finder_rps.sqlite"), force=true)

# Specify database to use
sqlite_file = joinpath(@__DIR__, "Belgium_2017_finder.sqlite")

# Run
m, url_in, window__static_slice, order = SpinePeriods.run_spineperiods_ordering(
    "sqlite:///$(sqlite_file)",
    "sqlite:///$(sqlite_file)_rep",
    with_optimizer=optimizer_with_attributes(
        Cbc.Optimizer, "logLevel" => 1, "ratioGap" => 0.01,
        "seconds" => 60
    )
)

# Assert right number of days selected according to chronology
chron = Dict((w1,w2) => value(m.ext[:variables][:chronology][w1,w2]) for w1 in SpinePeriods.window(), w2 in SpinePeriods.window())
vecChron = collect(chron)
idx = findall(x -> last(x) > 0, collect(chron))
vecChron[idx]
rp = first(SpineInterface.representative_period())
@assert length(unique(last.(first.(vecChron[idx])))) ≈ SpineInterface.representative_periods(representative_period=rp)

# Assert that the weights add up to 365
weight = Dict(w => value(m.ext[:variables][:weight][w]) for w in SpinePeriods.window())
@assert sum(last.(collect(weight))) == length(SpinePeriods.window())
