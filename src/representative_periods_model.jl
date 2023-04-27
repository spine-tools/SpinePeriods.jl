#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
#
# This file is part of SpinePeriods.
#
# SpinePeriods is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# SpinePeriods is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################

"""
Create the variables for the model
"""
function create_variables!(m)
    m.ext[:spineopt].variables[:d_error] = Dict{Tuple,JuMP.VariableRef}(
        (r, b) => @variable(m, base_name="d_error[$(r), $(b)]", lower_bound=0) for (r, b) in resource__block()
    )
    m.ext[:spineopt].variables[:selected] = Dict{Object, JuMP.VariableRef}(
        w => @variable(m, base_name="selected[$w]", binary=true) for w in window()
    )
    m.ext[:spineopt].variables[:weight] = Dict{Object,JuMP.VariableRef}(
        w => @variable(m, base_name="weight[$w]", lower_bound=0) for w in window()
    )
end

"""
Create the variables for the integer program which orders representative periods
"""
function create_ordering_variables!(m)
    m.ext[:spineopt].variables[:selected] = Dict{Object,JuMP.VariableRef}(
        w => @variable(m, base_name="selected[$w]", binary=true) for w in window()
    )
    m.ext[:spineopt].variables[:weight] = Dict{Object,JuMP.VariableRef}(
        w => @variable(m, base_name="weight[$w]", lower_bound=0) for w in window()
    )
    m.ext[:spineopt].variables[:chronology] = Dict{Tuple,JuMP.VariableRef}(
        (w1, w2) => @variable(m, base_name="chronology[$(w1), $(w2)]", binary=true)
        for w1 in window()
        for w2 in window()
    )
end

"""
    set_objective!(m::Model)

Minimize the total error between target and representative distributions.
"""
function set_objective!(m::Model)
    @unpack d_error = m.ext[:spineopt].variables
    @objective(
        m, Min, sum(representative_period_weight(resource=r) * sum(d_error[r, b] for b in block()) for r in resource())
    )
end

"""
    set_ordering_objective!(m::Model)

Minimize the total error between target and representative time series.
"""
function set_ordering_objective!(m::Model)
    ts_vals = resource_availability_window_static_slice
    @unpack chronology = m.ext[:spineopt].variables
    @objective(
        m,
        Min,
        + sum(
            + representative_period_weight(resource=r)
            * chronology[w1, w2]
            * sum(
                abs(ts_vals(resource=r, window=w1, ss=ss1) - ts_vals(resource=r, window=w2, ss=ss2))
                for (ss1, ss2) in zip(
                    resource__window__static_slice(resource=r, window=w1),
                    resource__window__static_slice(resource=r, window=w2),
                )
            )
            for r in resource(), w1 in window(), w2 in window()
        )
    )
end

"""
    add_constraint_error1!(m::Model)

In conjunction with add_constraint_error2, defines the error between
the representative distributions and the target distributions.
"""
function add_constraint_error1!(m::Model)
    @unpack weight, d_error = m.ext[:spineopt].variables
    rp = first(representative_period())
    m.ext[:spineopt].constraints[:error1] = Dict(
        (r, b) => @constraint(
            m,
            d_error[r, b]
            >=
            + resource_distribution(resource=r, block=b)
            - sum(
                (weight[w] / length(window())) * resource_distribution_window(resource=r, block=b, window=w)
                for w in window()
            )
        )
        for (r, b) in resource__block()
    )
end

"""
    add_constraint_error2!(m::Model)

In conjunction with add_constraint_error1, defines the error between
the representative distributions and the target distributions.
"""
function add_constraint_error2!(m::Model)
    @unpack d_error, weight = m.ext[:spineopt].variables
    rp = first(representative_period())
    m.ext[:spineopt].constraints[:error2] = Dict(
        (r, b) => @constraint(
            m,
            d_error[r, b]
            >=
            - resource_distribution(resource=r, block=b)
            + sum(
                (weight[w] / length(window())) * resource_distribution_window(resource=r, block=b, window=w)
                for w in window()
            )
        )
        for (r, b) in resource__block()
    )
end

"""
    add_constraint_selected_periods!(m::Model)
"""
function add_constraint_selected_periods!(m::Model)
    @unpack selected = m.ext[:spineopt].variables
    rp = first(representative_period())
    m.ext[:spineopt].constraints[:selected_periods] = Dict(
        m.ext[:spineopt].instance => @constraint(
            m, sum(selected[w] for w in window()) <= representative_periods(representative_period=rp)
        )
    )
end

"""
    enforce_period_mapping!(m::Model)
"""
function add_constraint_enforce_period_mapping!(m::Model)
    @unpack chronology = m.ext[:spineopt].variables
    m.ext[:spineopt].constraints[:enforce_mapping] = Dict(
        w1 => @constraint(m, sum(chronology[w1, w2] for w2 in window()) == 1) for w1 in window()
    )
end

"""
    add_constraint_enforce_chronology_less_than_selected!(m::Model)
"""
function add_constraint_enforce_chronology_less_than_selected!(m::Model)
    @unpack selected, chronology = m.ext[:spineopt].variables
    m.ext[:spineopt].constraints[:chronology_less_than_selected] = Dict(
        (w1, w2) => @constraint(m, chronology[w1, w2] <= selected[w2]) for w1 in window(), w2 in window()
    )
end

"""
    add_constraint_single_weight!(m::Model)
"""
function add_constraint_single_weight!(m::Model)
    @unpack weight, selected = m.ext[:spineopt].variables
    rp = first(representative_period())
    m.ext[:spineopt].constraints[:single_weight] = Dict(
        w => @constraint(
            m, weight[w] <= selected[w] * representative_periods(representative_period=rp) * length(block())
        )
        for w in window()
    )
end

"""
    add_constraint_link_weight_and_chronology!(m::Model)
"""
function add_constraint_link_weight_and_chronology!(m::Model)
    @unpack weight, chronology = m.ext[:spineopt].variables
    m.ext[:spineopt].constraints[:link_weight_and_chronology] = Dict(
        w2 => @constraint(m, weight[w2] == sum(chronology[w1, w2] for w1 in window())) for w2 in window()
    )
end

"""
    add_constraint_total_weight!(m::Model)
"""
function add_constraint_total_weight!(m::Model)
    @unpack weight = m.ext[:spineopt].variables
    m.ext[:spineopt].constraints[:selected_periods] = Dict(
        m.ext[:spineopt].instance => @constraint(m, sum(weight[w] for w in window()) == length(window()))
    )
end
