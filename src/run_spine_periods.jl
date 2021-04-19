"""
    run_spine_periods_ordering(url_in, url_out; with_optimizer)

Solves an optimisation problem which selects (and orders) representative periods.

Specifying which optimisation method can be done from, and can be either:
* `representative_periods` - selects representative_periods.
* `representative_periods_ordering` - selects and orders representative periods.
"""
function run_spine_periods(url_in::String, url_out::String; 
        with_optimizer=optimizer_with_attributes(
            Cbc.Optimizer, "logLevel" => 1, "ratioGap" => 0.01,
            "seconds" => 60*10
        )
    )
    @info "Reading database..."
    using_spinedb(url_in; upgrade=true)

    if representative_period_method(representative_period=first(representative_period())) == :representative_periods
        return run_spine_periods_selection(
            url_in, url_out,
            with_optimizer=with_optimizer
        )
    elseif representative_period_method(representative_period=first(representative_period())) == :representative_periods_ordering
        return run_spine_periods_ordering(
            url_in, url_out,
            with_optimizer=with_optimizer
        )
    else
        error("Please specify an optimisation method in the Spine database.")
    end
end


