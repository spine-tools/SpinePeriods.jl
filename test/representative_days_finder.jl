using SpinePeriods
using Cbc
using JuMP

# Remove output database if necessary
rm(joinpath(@__DIR__, "Belgium_2017_finder_rps.sqlite"), force=true)

# Specify database to use
sqlite_file = joinpath(@__DIR__, "Belgium_2017_finder.sqlite")

# Run
m = SpinePeriods.run_spineperiods(
    "sqlite:///$(sqlite_file)",
    with_optimizer=optimizer_with_attributes(
        Cbc.Optimizer, "logLevel" => 1, "ratioGap" => 0.01,
        "seconds" => 60
    )
)

# Check results

# Assert that the weights add up to 365
weight = Dict(w => value(m.ext[:variables][:weight][w]) for w in SpinePeriods.window())
@assert sum(last.(collect(weight))) == length(SpinePeriods.window())
