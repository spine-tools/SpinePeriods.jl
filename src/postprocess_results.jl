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
    @unpack selected, weight, chronology = m.ext[:spineopt].variables
    objects = []
    relationships = []
    object_parameters = []
    object_parameter_values = []
    object_groups = []
    represented_tblocks = _represented_temporal_blocks()
    selected_windows = [w for w in window() if isapprox(JuMP.value(selected[w]), 1)]
    chron_map = Dict(w1 => w2 for w1 in window(), w2 in window() if isapprox(value(chronology[w1, w2]), 1))
    windows = is_selection_model() ? selected_windows : unique(values(chron_map))
    res = minimum(resolution(temporal_block=tb) for tb in represented_tblocks)
    add_representative_period_group!(objects, object_groups, windows)
    add_representative_period_temporal_blocks!(
        objects, object_parameters, object_parameter_values, window__static_slice, windows, weight, res
    )
    remove_parameter_values!(object_parameter_values, represented_tblocks)
    add_representative_period_relationships!(relationships, windows, represented_tblocks)
    if is_ordering_model()
        add_representative_period_mapping!(
            m, objects, object_parameters, object_parameter_values, window__static_slice, chron_map, represented_tblocks
        )
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
        t_start = date_time_to_db(split(string(first(window__static_slice[w]).name), "~>")[1])
        t_end = date_time_to_db(split(string(last(window__static_slice[w]).name), "~>")[2])
        wt = JuMP.value(weight[w])
        push!(objects, ("temporal_block", tb_name))
        push!(object_parameter_values, ("temporal_block", tb_name, "block_start", t_start))
        push!(object_parameter_values, ("temporal_block", tb_name, "block_end", t_end))
        push!(object_parameter_values, ("temporal_block", tb_name, "resolution", unparse_db_value(res)))
        push!(object_parameter_values, ("temporal_block", tb_name, "weight", wt))
        @info "selected window: $(w) with start $(t_start["data"]) and weight $(wt)"
    end
end

function add_representative_period_group!(objects, object_groups, windows)
    push!(objects, ("temporal_block", "all_representative_periods"))
    for w in windows
        tb_name = string("rp_", w)
        push!(object_groups, ("temporal_block", "all_representative_periods", tb_name))
    end
end

function remove_parameter_values!(object_parameter_values, tblocks)
    model_name = first(model()).name
    push!(object_parameter_values, ("model", model_name, "roll_forward", nothing))
    append!(object_parameter_values, [("temporal_block", tb.name, "block_end", nothing) for tb in tblocks])
end

function add_representative_period_relationships!(relationships, windows, tblocks)
    default_tblocks = model__default_temporal_block(model=first(model()))
    add_to_default = any(tb in default_tblocks for tb in tblocks)
    model_name = first(model()).name
    for w in windows
        tb_name = string("rp_", w)
        push!(relationships, ("model__temporal_block", (model_name, tb_name)))
        add_to_default && push!(relationships, ("model__default_temporal_block", (model_name, tb_name)))
        append!(
            relationships,
            [("node__temporal_block", (n.name, tb_name)) for n in node__temporal_block(temporal_block=tblocks)]
        )
        append!(
            relationships,
            [("units_on__temporal_block", (u.name, tb_name)) for u in units_on__temporal_block(temporal_block=tblocks)]
        )
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
end

date_time_to_db(datetime_string) = Dict("type" => "date_time", "data" => datetime_string)

map_to_db(map_array) = Dict("type" => "map", "index_type" => "date_time", "data" => map_array)

function julia_resolution_to_db_resolution_string(resolution::TimePeriod)
    # to be extended, probably there is already a function like this
    conversion_dict = Dict(Dates.Hour => "h", Dates.Minute => "m")
    string(resolution.value, conversion_dict[typeof(resolution)])
end

function create_copy_db(url_in, url_out)
    input_data = run_request(url_in, "export_data")
    import_data(url_out, input_data, "Copy input db")
    @info "new database copied to $url_out"
end