function run_SpinePeriods_master(db_url_in::String, db_url_out::String) ###add other optional solver choices
@info "reading database"
using_spinedb(db_url_in; upgrade=true)
if representative_period_method(representative_period=first(representative_period())) == :representative_periods
    run_spineperiods(
        db_url_in, db_url_out,
        with_optimizer=optimizer_with_attributes(
            Cbc.Optimizer, "logLevel" => 1, "ratioGap" => 0.01,
            "seconds" => 60
        )
    )
elseif representative_period_method(representative_period=first(representative_period())) == :representative_periods_ordering
    run_spineperiods_ordering(
        db_url_in, db_url_out,
        with_optimizer=optimizer_with_attributes(
            Cbc.Optimizer, "logLevel" => 1, "ratioGap" => 0.01,
            "seconds" => 60
        )
    )
end
end
