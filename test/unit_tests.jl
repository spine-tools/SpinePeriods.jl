# TODO

# Check that `check_out_file` errors appropriately.
@test_throws ErrorException SpinePeriods.check_out_file("out.wrong")
@test isnothing(SpinePeriods.check_out_file("out.json"))
@test isnothing(SpinePeriods.check_out_file("out.sqlite"))

# See if run_checks_pre and run_checks_post give desire result.