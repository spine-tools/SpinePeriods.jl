"""
    run_spine_periods_ordering(url_in, optimizer)

Solves an optimisation problem which selects representative periods.
"""
function run_spine_periods_ordering(
        url_in::String,
        url_out::String;
        with_optimizer=optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0, "ratioGap" => 0.01),
    )
    @info "Processing SpinePeriods temporal structure..."
    m = Model(with_optimizer)
    m.ext[:instance] = model()[1]
    SpineOpt.generate_temporal_structure!(m)
    
    @info "Preprocessing data structure..."
    window__static_slice = preprocess_data_structure(m)
    
    @info "Initializing model..."
    m.ext[:variables] = Dict{Symbol,Dict}()
    m.ext[:variables_lb] = Dict{Symbol,Any}()
    m.ext[:variables_ub] = Dict{Symbol,Any}()
    m.ext[:values] = Dict{Symbol,Dict}()
    m.ext[:constraints] = Dict{Symbol,Dict}()

    create_ordering_variables!(m)
    add_constraint_enforce_period_mapping!(m)
    # line 390, seems fine
    add_constraint_enforce_chronology_less_than_selected!(m)
    # line 398, seems fine
    add_constraint_selected_periods!(m)
    # line 418, should be fine
    add_constraint_link_weight_and_chronology!(m)
    # line 431, seems fine
    add_constraint_total_weight!(m)
    # line 449, should be fine
    # add_constraint_single_weight!(m) # Not included in my formulation
    set_ordering_objective!(m)

    optimize!(m)
    if termination_status(m) in (MOI.OPTIMAL, MOI.TIME_LIMIT)
        @info "Model solved. Termination status: $(termination_status(m))."
        order = postprocess_ordering_results!(m, url_in, url_out, window__static_slice)
    else
        @info "Unable to find solution (reason: $(termination_status(m)))."
    end

    return m, url_in, window__static_slice, order
end
