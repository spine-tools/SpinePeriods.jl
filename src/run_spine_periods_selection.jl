"""
    run_spine_periods_selection(url_in, out_file, optimizer)

Solves an optimisation problem which selects and orders representative periods.

Definitely works when choosing days in a year, but deviations from that
(e.g. choosing days from multiple years or hours from a year) will likely fail due to the problem size.
"""
function run_spine_periods_selection(
    url_in::String,
    out_file::String;
    with_optimizer=optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false, "mip_rel_gap" => 0.01),
    alternative=""
)
    @info "Initializing model..."
    m = Model(with_optimizer)
    m.ext[:spineopt] = SpineOptExt(first(model()), with_optimizer)
    @info "Generating SpinePeriods temporal structure..."
    generate_temporal_structure!(m)
    @info "Preprocessing data structure..."
    window__static_slice = preprocess_data_structure(m)
    create_variables!(m)
    set_objective!(m)
    add_constraint_error1!(m)
    add_constraint_error2!(m)
    add_constraint_selected_periods!(m)
    add_constraint_single_weight!(m)
    add_constraint_total_weight!(m)
    optimize!(m)
    if termination_status(m) in (MOI.OPTIMAL, MOI.TIME_LIMIT)
        @info "Model solved. Termination status: $(termination_status(m))."
        postprocess_results!(m, url_in, out_file, window__static_slice; alternative=alternative)
    else
        @info "Unable to find solution (reason: $(termination_status(m)))."
    end
    m
end
