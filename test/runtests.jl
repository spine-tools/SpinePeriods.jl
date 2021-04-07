using SpinePeriods, SpineInterface, Cbc, JuMP, SpineOpt, Test

include(joinpath(@__DIR__, "representative_days_finder.jl"))
include(joinpath(@__DIR__, "representative_days_orderer.jl"))
