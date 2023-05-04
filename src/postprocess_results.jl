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

function postprocess_results!(m::Model, db_url, out_file, window__static_slice; alternative="")
    @unpack selected, weight = m.ext[:spineopt].variables
    objects = []
    relationships = []
    object_parameters = []
    object_parameter_values = []
    object_groups = []
    selected_windows = [w for w in window() if isapprox(JuMP.value(selected[w]), 1)]
    if for_rolling(representative_period=first(representative_period()))
        setup_rolling_representative_periods!(object_parameter_values, selected_windows)
    else
        chron_map = if is_ordering_model()
            @unpack chronology = m.ext[:spineopt].variables
            Dict(w1 => w2 for w1 in window(), w2 in window() if isapprox(value(chronology[w1, w2]), 1))
        end
        windows = is_ordering_model() ? unique(values(chron_map)) : selected_windows
        represented_tblocks = _represented_temporal_blocks()
        res = minimum(resolution(temporal_block=tb) for tb in represented_tblocks)
        add_representative_period_temporal_blocks!(
            objects, object_parameters, object_parameter_values, window__static_slice, windows, weight, res
        )
        add_representative_period_group!(objects, object_groups, windows)
        fix_parameter_values!(object_parameter_values, represented_tblocks)
        add_representative_period_relationships!(relationships, windows, represented_tblocks)
        if is_ordering_model()
            add_representative_period_mapping!(
                m,
                objects,
                object_parameters,
                object_parameter_values,
                window__static_slice,
                chron_map,
                represented_tblocks
            )
        end
    end
    if !isempty(alternative)
        object_parameter_values = [(pv..., alternative) for pv in object_parameter_values]
    end
    d = Dict(
        :object_groups => object_groups,
        :objects => objects,
        :relationships => relationships,
        :object_parameters => object_parameters,
        :object_parameter_values => object_parameter_values
    )
    if !isempty(alternative)
        d[:alternatives] = [alternative]
    end
    if is_db_url(out_file)
        create_copy_db(db_url, out_file)
        import_data(out_file, d, "Save representative periods")
    elseif is_json_file(out_file)
        open(out_file, "w") do f
            JSON.print(f, d, 4)
        end
    end
    @info "representative periods saved"
end

function setup_rolling_representative_periods!(object_parameter_values, selected_windows)
    w_starts = sort!([DateTime(split(string(first(window__static_slice[w]).name), "~>")[1]) for w in selected_windows])
    rf = [w_starts[i] - w_starts[i - 1] for i in 2:length(w_starts)]
    m_start = popfirst!(w_starts)
    instance = first(model())
    push!(object_parameter_values, ("model", instance.name, "model_start", unparse_db_value(m_start)))
    push!(object_parameter_values, ("model", instance.name, "roll_forward", unparse_db_value(rf)))
    @info "set the value of model_start for $(instance.name) to $m_start"
    @info "set the value of roll_forward for $(instance.name) to $rf"
end

function _represented_temporal_blocks()
    rp = first(representative_period())
    n_tbs = (
        tb
        for n in node__representative_period(representative_period=rp)
        for tb in node__temporal_block(node=members(n))
    )
    u_tbs = (
        tb for n in unit__representative_period(representative_period=rp) for tb in units_on__temporal_block(unit=u)
    )
    un_tbs = (
        tb
        for (u, n) in unit__node__representative_period(representative_period=rp)
        for tb in Iterators.flatten((node__temporal_block(node=n), units_on__temporal_block(unit=u)))
    )
    default_tbs = model__default_temporal_block(model=first(model()))
    unique(Iterators.flatten((n_tbs, u_tbs, un_tbs, default_tbs)))
end

function add_representative_period_temporal_blocks!(
    objects, object_parameters, object_parameter_values, window__static_slice, windows, weight, res
)
    for w in windows
        tb_name = string("rp_", w)
        tb_start = split(string(first(window__static_slice[w]).name), "~>")[1]
        tb_end = split(string(last(window__static_slice[w]).name), "~>")[2]
        wt = JuMP.value(weight[w])
        push!(objects, ("temporal_block", tb_name))
        push!(object_parameter_values, ("temporal_block", tb_name, "block_start", date_time_to_db(tb_start)))
        push!(object_parameter_values, ("temporal_block", tb_name, "block_end", date_time_to_db(tb_end)))
        push!(object_parameter_values, ("temporal_block", tb_name, "resolution", unparse_db_value(res)))
        push!(object_parameter_values, ("temporal_block", tb_name, "weight", wt))
        @info "added temporal block $tb_name with start $tb_start, end $tb_end and weight $wt"
    end
end

function add_representative_period_group!(objects, object_groups, windows)
    push!(objects, ("temporal_block", "all_representative_periods"))
    for w in windows
        tb_name = string("rp_", w)
        push!(object_groups, ("temporal_block", "all_representative_periods", tb_name))
    end
    @info "added temporal block group all_representative_periods"
end

function fix_parameter_values!(object_parameter_values, tblocks)
    instance = first(model())
    last_window_start = model_start(model=instance)
    i = 1
    while true
        rf = roll_forward(model=instance, i=i, _strict=false)
        if isnothing(rf) || rf == Minute(0) || last_window_start + rf >= model_end(model=instance)
            break
        end
        last_window_start += rf
        i += 1
    end
    push!(object_parameter_values, ("model", instance.name, "roll_forward", nothing))
    @info "set the value of roll_forward for $(instance.name) to null"
    for tb in tblocks
        tb_end = block_end(temporal_block=tb)
        tb_end isa Period || continue
        tb_end += last_window_start
        push!(object_parameter_values, ("temporal_block", tb.name, "block_end", tb_end))
        @info "set the value of block_end for $(tb.name) to $tb_end"
    end
end

function add_representative_period_relationships!(relationships, windows, tblocks)
    default_tblocks = model__default_temporal_block(model=first(model()))
    add_to_default = any(tb in default_tblocks for tb in tblocks)
    model_name = first(model()).name
    for w in windows
        tb_name = string("rp_", w)
        push!(relationships, ("model__temporal_block", (model_name, tb_name)))
        @info "added model__temporal_block relationship between $model_name and $tb_name"
        if add_to_default
            push!(relationships, ("model__default_temporal_block", (model_name, tb_name)))
            @info "added model__default_temporal_block relationship between $model_name and $tb_name"
        end
        for n in node__temporal_block(temporal_block=tblocks)
            push!(relationships, ("node__temporal_block", (n.name, tb_name)))
            @info "added node__temporal_block relationship between $(n.name) and $tb_name"
        end
        for u in units_on__temporal_block(temporal_block=tblocks)
            push!(relationships, ("units_on__temporal_block", (u.name, tb_name)))
            @info "added units_on__temporal_block relationship between $(u.name) and $tb_name"
        end
    end
end

function add_representative_period_mapping!(
    m, objects, object_parameters, object_parameter_values, window__static_slice, chron_map, tblocks
)
    periods = []
    for (w1, w2) in chron_map
        ss1 = window__static_slice[w1][1]
        ss1_start = string(rstrip(split(string(ss1.name), "~>")[1]))
        ss2 = string("rp_", w2)
        push!(periods, [ss1_start, ss2])
    end
    ordering_parameter = map_to_db(periods)
    push!(object_parameters, ("temporal_block", "representative_periods_mapping"))
    append!(
        object_parameter_values,
        [("temporal_block", tb.name, "representative_periods_mapping", ordering_parameter) for tb in tblocks]
    )
    @info "added representative_periods_mapping parameter value to temporal blocks $tblocks"
end

date_time_to_db(datetime_string) = Dict("type" => "date_time", "data" => datetime_string)

map_to_db(map_array) = Dict("type" => "map", "index_type" => "date_time", "data" => map_array)

function create_copy_db(url_in, url_out)
    input_data = run_request(url_in, "export_data")
    import_data(url_out, input_data, "Copy input db")
    @info "new database copied to $url_out"
end