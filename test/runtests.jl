using SpinePeriods, SpineInterface, Cbc, JuMP, SpineOpt, Test

include(joinpath(@__DIR__, "representative_days_finder.jl"))
include(joinpath(@__DIR__, "representative_days_orderer.jl"))

rm(joinpath(@__DIR__, "Belgium_2017_finder_rps.sqlite"), force=true)
rm(joinpath(@__DIR__, "Belgium_2017_orderer_rps.sqlite"), force=true)