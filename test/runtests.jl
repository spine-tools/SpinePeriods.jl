using SpinePeriods, SpineInterface, HiGHS, JuMP, SpineOpt, Test, Dates

include("unit_tests.jl")

@testset begin
	_run_spine_periods_selection()
	_run_spine_periods_ordering()
	_run_spine_periods_ordering_for_rolling()
end
