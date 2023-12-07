using SpinePeriods, SpineInterface, HiGHS, JuMP, SpineOpt, Test, Dates

include("unit_tests.jl")

@testset begin
	_run_spine_periods_selection()
end
