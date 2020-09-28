using SpinePeriods
using SpineInterface
using Cbc
using JuMP

# Remove output database if necessary
rm(joinpath(@__DIR__, "Belgium_2017_finder_rps.sqlite"), force=true)

# Specify database to use
sqlite_file = joinpath(@__DIR__, "Belgium_2017_finder.sqlite")

# Run
m = SpinePeriods.run_spineperiods_ordering(
    "sqlite:///$(sqlite_file)",
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

# realIdx =  collect(SpineInterface.indices(SpinePeriods.resource_availability_window_static_slice))
# resource, window, ss = first(realIdx)
#
# r=first(SpinePeriods.resource())
# w=first(SpinePeriods.window())
# sstest = first(SpinePeriods.resource__window__static_slice(resource=r, window=w))
#
# @show r === resource
# @show w === window
# @show sstest === ss
#
# for (ss1,ss2) in zip(
#     SpinePeriods.resource__window__static_slice(resource=r, window=w),
#     SpinePeriods.resource__window__static_slice(resource=r, window=w),
# )
#     @show ss1
#     @show ss2
# end
