"""
    run_spine_periods_ordering(url_in, out_file; with_optimizer)

Solves an optimisation problem which selects (and orders) representative periods.

Specifying which optimisation method can be done from, and can be either:
* `representative_periods` - selects representative_periods.
* `representative_periods_ordering` - selects and orders representative periods.
"""
function run_spine_periods(
    url_in::String,
    out_file::String; 
    with_optimizer=optimizer_with_attributes(
        HiGHS.Optimizer, "output_flag" => true, "mip_rel_gap" => 0.01, "time_limit" => 60.0
    ),
    alternative=""
)
    check_out_file(out_file)
    @info "Reading database..."
    using_spinedb(url_in, SpineOpt; upgrade=true)
    if is_selection_model()
        run_spine_periods_selection(url_in, out_file, with_optimizer=with_optimizer, alternative=alternative)
    elseif is_ordering_model()
        run_spine_periods_ordering(url_in, out_file, with_optimizer=with_optimizer, alternative=alternative)
    elseif is_clustered_ordering_model()
        run_spine_periods_clustering(url_in, out_file, alternative=alternative)
    else
        error("Please specify an optimisation method in the Spine database.")
    end
end


