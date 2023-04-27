"""
    run_spine_periods_ordering(url_in, optimizer)

Solves an optimisation problem which selects representative periods.
"""
function run_spine_periods_ordering(
    url_in::String,
    out_file::String;
    with_optimizer=optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false, "mip_rel_gap" => 0.01),
    alternative=""
)
    @info "Initializing model..."
    m = Model(with_optimizer)
    m.ext[:spineopt] = SpineOptExt(first(model()))
    @info "Generating SpinePeriods temporal structure..."
    generate_temporal_structure!(m)
    @info "Preprocessing data structure..."
    window__static_slice = preprocess_data_structure(m)
    create_ordering_variables!(m)
    add_constraint_enforce_period_mapping!(m)
    add_constraint_enforce_chronology_less_than_selected!(m)
    add_constraint_selected_periods!(m)
    add_constraint_link_weight_and_chronology!(m)
    add_constraint_total_weight!(m)
    # add_constraint_single_weight!(m) # Not included in my formulation
    set_ordering_objective!(m)
    optimize!(m)
    if termination_status(m) in (MOI.OPTIMAL, MOI.TIME_LIMIT)
        @info "Model solved. Termination status: $(termination_status(m))."
        postprocess_results!(m, url_in, out_file, window__static_slice; alternative=alternative)
    else
        @info "Unable to find solution (reason: $(termination_status(m)))."
    end
    m, url_in, window__static_slice
end
