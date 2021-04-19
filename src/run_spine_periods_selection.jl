"""
    run_spine_periods_selection(url_in, url_out, optimizer)

Solves an optimisation problem which selects and orders representative periods.

Definitely works when choosing days in a year, but deviations from that (e.g. choosing days from multiple years or hours from a year) will likely fail due to the problem size.
"""
function run_spine_periods_selection(
        url_in::String,
        url_out::String;
        with_optimizer=optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0, "ratioGap" => 0.01),
    )
    @info "Reading database..."
    using_spinedb(url_in, SpineOpt; upgrade=true)

    @info "Processing SpinePeriods temporal structure..."
    m = Model(with_optimizer)
    m.ext[:instance] = model()[1]
    SpineOpt.generate_temporal_structure!(m)
    
    @info "Preprocessing data structure..."
    window__static_slice = preprocess_data_structure(m)
    
    @info "Initializing model..."
    m = Model(with_optimizer)

    m.ext[:variables] = Dict{Symbol,Dict}()
    m.ext[:variables_lb] = Dict{Symbol,Any}()
    m.ext[:variables_ub] = Dict{Symbol,Any}()
    m.ext[:values] = Dict{Symbol,Dict}()
    m.ext[:constraints] = Dict{Symbol,Dict}()

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
        postprocess_results!(m, url_in, url_out, window__static_slice)
    else
        @info "Unable to find solution (reason: $(termination_status(m)))."
    end

    return m
end
