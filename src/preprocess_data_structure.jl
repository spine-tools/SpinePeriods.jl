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

function preprocess_data_structure(m)
    run_checks_pre()
    generate_blocks()
    generate_resources()
    window__static_slice = generate_distributions(m)
    run_checks_post()
    return window__static_slice
end

"""
    generate_blocks()

The representative periods model decomposes a distribution into a number of operating point blocks
as specified by representative_blocks(representative_period=rp). Here we create a new object class
called block and create an object for each block.
"""
function generate_blocks()
    rp=first(representative_period())
    # Create block objects named B1, B2... BN etc.
    block_objects = ObjectLike[]
    for b in 1:representative_blocks(representative_period=rp)
        push!(block_objects, Object(Symbol(string("B", Int(b)))))
    end
    #add_objects!(block, block_objects)
    block = ObjectClass(:block, block_objects)

    @eval begin
        block = $block
    end
end


"""
    generate_resources()

The representative period model selects a number of days that best represent the distribution of various time series
For now, that's either a `demand` time series or a `unit_availability_factor` time series or a `unit_capacity` time series
In the model we generalise these into a `resource`. We define this as a new object_class and copy into it
and `nodes` or `units` that have a `node__representative_period` or `unit__representative_period` relationship respectively.
"""
function generate_resources()
    resource = ObjectClass(:resource, [])
    for (u, rp) in unit__representative_period()
        r = Object(Symbol(u.name))
        add_object!(resource, r)
        # copy the timeseries data to a new unified resource object
        # Normalise by the maximum value
        resource.parameter_values[r] = Dict()
        resource.parameter_values[r][:resource_availability] = unit.parameter_values[u][:unit_availability_factor]
        # each resource time series can have a weight defined by representative_period_weight(unit=u, representative_period=rp). It should have a default of 1, but we check just in case
        if haskey(unit__representative_period.parameter_values[(u, rp)], :representative_period_weight)
            resource.parameter_values[r][:representative_period_weight] = unit__representative_period.parameter_values[(u, rp)][:representative_period_weight]
        else
            resource.parameter_values[r][:representative_period_weight] = SpineInterface.ScalarParameterValue(1.0)
        end
    end
    for (n, rp) in node__representative_period()
        r = Object(Symbol(n.name))
        add_object!(resource, r)
        # copy the timeseries data to a new unified resource object
        resource.parameter_values[r] = Dict()
        resource.parameter_values[r][:resource_availability] = node.parameter_values[n][:demand]
        # each resource time series can have a weight defined by representative_period_weight(node=n, representative_period=rp). It should have a default of 1, but we check just in case
        if haskey(node__representative_period.parameter_values[(n, rp)], :representative_period_weight)
            resource.parameter_values[r][:representative_period_weight] = node__representative_period.parameter_values[(n, rp)][:representative_period_weight]
        else
            resource.parameter_values[r][:representative_period_weight] = SpineInterface.ScalarParameterValue(1.0)
        end
    end
    for (u, n, rp) in unit__node__representative_period()
        r = Object(Symbol(string(u.name, "_", n.name)))
        add_object!(resource, r)
        # copy the timeseries data to a new unified resource object
        resource.parameter_values[r] = Dict()
        resource.parameter_values[r][:resource_availability] = unit__node.parameter_values[(u, n)][:unit_capacity]
        # each resource time series can have a weight defined by representative_period_weight(node=n, representative_period=rp). It should have a default of 1, but we check just in case
        if haskey(unit__node__representative_period.parameter_values[(u, n, rp)], :representative_period_weight)
            resource.parameter_values[r][:representative_period_weight] = unit__node__representative_period.parameter_values[(u, n, rp)][:representative_period_weight]
        else
            resource.parameter_values[r][:representative_period_weight] = SpineInterface.ScalarParameterValue(1.0)
        end
    end

    # add the resource_availability parameter to the resource object class
    push!(representative_period_weight.classes, resource)
    resource_availability = Parameter(:resource_availability, [resource])

    @eval begin
        resource = $resource
        resource_availability = $resource_availability
    end
end

"""
Generate the distribution for each time series as defined by:
- Number of operating point segments (blocks)
"""
function generate_distributions(m::Model)

    rp=first(representative_period())
    n_periods = representative_periods(representative_period=rp)

    window = ObjectClass(:window, [])
    static_slice = ObjectClass(:static_slice, [])

    @eval begin
        window = $window
        static_slice = $static_slice
    end

    ts_vals_window = Dict()

    res_dist_window = Dict()
    res_dist_horizon = Dict()
    bin_interval = Dict()
    ts_vals = Dict()
    ts_max = Dict()
    ts_min = Dict()
    window__static_slice = Dict()
    ss_ts = Dict()

    for r in resource()
        res_dist_horizon[r] = zeros(size(block(),1))
        ts_max[r] = resource_availability(resource=r, t=first(time_slice(m)))
        ts_min[r] = ts_max[r]
    end

    i_win = 1
    while true
        w = Object(Symbol(string("W", Int(i_win))))

        add_object!(window, w)

        window__static_slice[w] = []

        for t in time_slice(m)
            ss_name = Symbol(string(t))
            add_object!(static_slice, Object(ss_name))
            ss = static_slice(ss_name)
            push!(window__static_slice[w], ss)
            ss_ts[t] = ss
        end

        for r in resource()
            res_dist_window[r, w] = zeros(length(block()))
            for t in time_slice(m)
                ts_vals[r, ss_ts[t]] = resource_availability(resource=r, t=t)
                (ts_vals[r, ss_ts[t]] == nothing) && (ts_vals[r, ss_ts[t]] = 0)
                (ts_vals[r, ss_ts[t]] > ts_max[r]) && (ts_max[r] = ts_vals[r, ss_ts[t]])
                (ts_vals[r, ss_ts[t]] < ts_min[r]) && (ts_min[r] = ts_vals[r, ss_ts[t]])

                # Also seperate values by resource, window and time slice
                ts_vals_window[r, w, ss_ts[t]] = ts_vals[r, ss_ts[t]]
            end
        end
        roll_temporal_structure!(m) || break
        i_win += 1
    end
    window_time_interval = 100 / length(window__static_slice[first(window())])
    horizon_time_interval = window_time_interval / length(window())
    for r in resource()
        bin_interval = (ts_max[r] - ts_min[r]) / length(block())
        for w in window()
            for ss in window__static_slice[w]
                lowestb = floor(Int, (ts_max[r] - ts_vals[r, ss]) / bin_interval)
                (lowestb == 0) && (lowestb = 1)
                for b in lowestb:length(block())
                    res_dist_window[r, w][b] += window_time_interval
                    res_dist_horizon[r][b] += horizon_time_interval
                end
            end
        end
    end

    # r = first(resource())
    # w = first(window())
    # t = first(window__static_slice[w])
    # @show ts_vals_window[r,w,t]

    # Create relationship classes
    # Create resource window static slice relationship class
    # Allows indexing resource values by window and time slice
    res_wdw_parameter_values = Dict(
        (r, w, ss) => Dict(
            :resource_availability_window_static_slice =>
            SpineInterface.ScalarParameterValue(ts_vals_window[r,w,ss])
        )
        for r in resource() for w in window() for ss in window__static_slice[w]
    )


    resource__window__static_slice = RelationshipClass(
        :resource_availabilty__window__static_slice,
        [:resource, :window, :ss],
        [
            (resource=r, window=w, ss=ss)
            for r in resource() for w in window() for ss in window__static_slice[w]
        ],
        res_wdw_parameter_values
    )

    # Define resource__block relationship class
    res_blk_parameter_values = Dict(
        (r, b) => Dict(:resource_distribution => SpineInterface.ScalarParameterValue(res_dist_horizon[r][parse(Int,string(b.name)[2:end])]))
        for r in resource() for b in block()
    )

    resource__block = RelationshipClass(
        :resource__block,
        [:resource, :block],
        [(resource=r, block=b) for r in resource() for b in block()],
        res_blk_parameter_values
    )

    # Define resource_distribution_window
    res_blk_wdw_parameter_values = Dict(
        (r, b, w) => Dict(:resource_distribution_window => SpineInterface.ScalarParameterValue(res_dist_window[r, w][parse(Int,string(b.name)[2:end])]))
        for r in resource() for b in block() for w in window()
    )

    resource__block__window = RelationshipClass(
        :resource__block__window,
        [:resource, :block, :window],
        [(resource=r, block=b, window=r) for r in resource() for b in block() for w in window()],
        res_blk_wdw_parameter_values
    )

    resource_distribution = Parameter(:resource_distribution, [resource__block])
    resource_distribution_window = Parameter(:resource_distribution_window, [resource__block__window])
    resource_availability_window_static_slice = Parameter(
        :resource_availability_window_static_slice,
        [resource__window__static_slice]
    )

    @eval begin
        resource__block = $resource__block
        resource__block__window = $resource__block__window
        resource_distribution = $resource_distribution
        resource_distribution_window = $resource_distribution_window
        resource__window__static_slice =
            $resource__window__static_slice
        resource_availability_window_static_slice =
            $resource_availability_window_static_slice
        window__static_slice = $window__static_slice # ???
    end
end

function run_checks_pre()
    model_instance = first(model())
    err_msg = "Please define `roll_forward` parameter for `$(model_instance)`. This determines the length of a representative period."
    @assert isnothing(roll_forward(model=model_instance)) == false eval(err_msg)
end

function run_checks_post()
    err_msg = "No resources defined so cannot select representative days. Please define relationships for `representative_periods` to fix this."
    @assert length(resource()) > 0 eval(err_msg)

    err_msg = "Only one representative period possible, which you probably don't want. This is likely due to the `roll_forward` parameter, as this defines the length of a representative period."
    @assert length(window()) > 1 eval(err_msg)
end