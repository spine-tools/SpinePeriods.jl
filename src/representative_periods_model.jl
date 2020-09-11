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
    var = m.ext[:variables][:d_error] = Dict{Tuple, JuMP.VariableRef}()
    for (r, b) in resource__block()
            var[r, b] = @variable(m,
                base_name="d_error[$(r), $(b)]",
                lower_bound=0
            )
    end

    var = m.ext[:variables][:selected] = Dict{Object, JuMP.VariableRef}()
    for w in window()
            var[w] = @variable(m,
                    base_name="selected[$w]",
                    binary=true
            )
    end

    var = m.ext[:variables][:weight] = Dict{Object, JuMP.VariableRef}()
    for w in window()
            var[w] = @variable(m,
                base_name="weight[$w]",
                lower_bound=0
            )
    end
end

"""
Create the variables for the integer program which orders representative periods
"""
function create_ordering_variables!(m)

    var = m.ext[:variables][:selected] = Dict{Object, JuMP.VariableRef}()
    for w in window()
            var[w] = @variable(m,
                    base_name="selected[$w]",
                    binary=true
            )
    end

    var = m.ext[:variables][:weight] = Dict{Object, JuMP.VariableRef}()
    for w in window()
            var[w] = @variable(m,
                base_name="weight[$w]",
                lower_bound=0
            )
    end

    var = m.ext[:variables][:chronology] = Dict{Tuple, JuMP.VariableRef}()
    for w1 in window()
        for w2 in window()
            var[w1, w2] = @variable(m,
                base_name="chronology[$(w1), $(w2)]",
                binary=true
            )
        end
    end

end

"""
    set_objective!(m::Model)

Minimize the total error between target and representative distributions.
"""
function set_objective!(m::Model)
    @fetch d_error = m.ext[:variables]
    @objective(
        m,
        Min,
        + sum(
            + representative_period_weight(resource=r) *
                sum(
                    + d_error[r, b]
                    for b in block()
                )
            for r in resource()
        )
    )
end

"""
    set_ordering_objective!(m::Model)

Minimize the total error between target and representative time series.
"""
function set_ordering_objective!(m::Model)
    representative_period_weight(resource=r)
    # TODO:
    # I would like to write an objective function something along the lines of this:
    @objective(
        m,
        Min,
        + sum(
            + representative_period_weight(resource=r) *
                chronology[w1,w2] *
                    sum(
                        abs(ts_vals[r,w1,t] - ts_vals[r,w2,t])
                        for t in time_slice(window=w1)
                        # or w2, should be the same!
                    )
            for w1 in window(), w2 in window(), r in resource()
        )
    )
end

"""
    add_constraint_error1!(m::Model)

In conjunction with add_constraint_error2, defines the error between
the representative distributions and the target distributions.
"""
function add_constraint_error1!(m::Model)
    @fetch weight, d_error = m.ext[:variables]
    cons = m.ext[:constraints][:error1] = Dict()
    rp = first(representative_period())
    for (r, b) in resource__block()
        cons[r, b] = @constraint(
            m,
            d_error[r, b]
            >=
            + resource_distribution(resource=r, block=b)
            - sum(
                + (  + weight[w]
                     / length(window())
                  ) * resource_distribution_window(resource=r, block=b, window=w)
                  for w in window()
            )
        )
    end
end

"""
    add_constraint_error2!(m::Model)

In conjunction with add_constraint_error1, defines the error between
the representative distributions and the target distributions.
"""
function add_constraint_error2!(m::Model)
    @fetch d_error, weight = m.ext[:variables]
    cons = m.ext[:constraints][:error2] = Dict()
    rp = first(representative_period())
    for (r, b) in resource__block()
        cons[r, b] = @constraint(
            m,
            d_error[r, b]
            >=
            - resource_distribution(resource=r, block=b)
            + sum(
                + ( + weight[w]
                    / length(window())
                ) * resource_distribution_window(resource=r, block=b, window=w)
                for w in window()
            )
        )
    end
end

function add_constraint_selected_periods!(m::Model)
    @fetch selected = m.ext[:variables]
    cons = m.ext[:constraints][:selected_periods] = Dict()
    rp = first(representative_period())
    cons = @constraint(
        m,
        +   sum(
                + selected[w]
                for w in window()
            )
        <=
        + representative_periods(representative_period=rp)
    )
end

function add_constraint_enforce_period_mapping!(m::Model)
    @fetch chronology = m.ext[:variables]
    cons = m.ext[:constraints][:enforce_mapping] = Dict()
    for w1 in window()
        cons[w1] = @constraint(
            m,
            sum(
                chronology[w1,w2] for w2 in window()
            )
            ==
            1
        )
    end
end

function add_constraint_enforce_chronology_less_than_selected!(m::Model)
    @fetch selected, chronology = m.ext[:variables]
    cons = m.ext[:constraints][:chronology_less_than_selected] = Dict()
    for w1 in window(), w2 in window()
        cons[w1,w2] = @constraint(
            m,
            chronology[w1,w2]
            <=
            + selected[w2]
        )
    end
end

function add_constraint_single_weight!(m::Model)
    @fetch weight, selected = m.ext[:variables]
    cons = m.ext[:constraints][:single_weight] = Dict()
    rp = first(representative_period())
    for w in window()
        cons[w] = @constraint(
            m,
            + weight[w]
            <=
            + selected[w] * representative_periods(representative_period=rp) * length(block())
        )
    end
end

function add_constraint_link_weight_and_chronology!(m::Model)
    @fetch weight, chronology = m.ext[:variables]
    cons = m.ext[:constraints][:link_weight_and_chronology] = Dict()
    for w2 in window()
        cons[w2] = @constraint(
            m,
            weight[w2]
            ==
            sum(chronology[w1,w2] for w2 in window())
        )
    end
end

function add_constraint_total_weight!(m::Model)
    @fetch weight = m.ext[:variables]
    cons = m.ext[:constraints][:selected_periods]
    rp = first(representative_period())
    cons = @constraint(
        m,
        +   sum(
                + weight[w]
                for w in window()
            )
        ==
        + representative_periods(representative_period=rp) * length(block())
    )
end
