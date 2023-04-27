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
    add_representative_period_group!(objects, object_groups, selected)
    add_representative_period_temporal_blocks!(
        objects, object_parameters, object_parameter_values, window__static_slice, selected, weight
    )
    add_model_representative_period_relationships!(relationships, selected)
    remove_roll_forward!(object_parameter_values)
    is_ordering_model() && add_representative_period_mapping!(
        m, objects, object_parameters, object_parameter_values, window__static_slice
    )
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
    msg = "Saved representative periods."
    if is_db_url(out_file)
        create_copy_db(db_url, out_file)
        import_data(out_file, d, msg)
    elseif is_json_file(out_file)
        open(out_file, "w") do f
            JSON.print(f, d, 4)
        end
    end
    @info eval(msg)
end

function add_representative_period_group!(objects, object_groups, selected)
    push!(objects, ("temporal_block", "all_representative_periods"))
    for w in window()
        JuMP.value(selected[w]) != 1 && continue
        tb_name = string("rp_", w)
        push!(object_groups, ("temporal_block", "all_representative_periods", tb_name))
    end
end

function add_model_representative_period_relationships!(relationships, selected)
    model_name = first(model()).name
    for w in window()
        JuMP.value(selected[w]) != 1 && continue
        tb_name = string("rp_", w)
        push!(relationships, ("model__temporal_block", (model_name, tb_name)))
    end
end

function remove_roll_forward!(object_parameter_values)
    model_name = first(model()).name
    push!(object_parameter_values, ("model", model_name, "roll_forward", nothing))
end

function add_representative_period_temporal_blocks!(
    objects, object_parameters, object_parameter_values, window__static_slice, selected, weight
)
    for w in window()
        if JuMP.value(selected[w]) == 1
            tb_name = string("rp_", w)
            t_start = date_time_to_db(split(string(first(window__static_slice[w]).name), "~>")[1])
            t_end = date_time_to_db(split(string(last(window__static_slice[w]).name), "~>")[2])
            res = resolution(temporal_block=first(temporal_block()))
            db_res = duration_to_db(julia_resolution_to_db_resolution_string(res)) # this needs to be more generic
            res = resolution(temporal_block=first(temporal_block()))
            wt = JuMP.value(weight[w])
            push!(objects, ("temporal_block", tb_name))
            push!(object_parameter_values, ("temporal_block", tb_name, "block_start", t_start))
            push!(object_parameter_values, ("temporal_block", tb_name, "block_end", t_end))
            push!(object_parameter_values, ("temporal_block", tb_name, "resolution", db_res))
            push!(object_parameter_values, ("temporal_block", tb_name, "weight", wt))
            @info "selected window: $(w) with start $(t_start["data"]) and weight $(wt)"
        end
    end
end

function add_representative_period_mapping!(
    m, objects, object_parameters, object_parameter_values, window__static_slice
)
    chron_map = Dict(
        w1 => w2 for w1 in window(), w2 in window() if value(m.ext[:spineopt].variables[:chronology][w1, w2]) == 1
    )
    @show sort(collect(chron_map))
    periods = []
    for w in window()
        ss1 = window__static_slice[w][1]
        ss1_start = string(rstrip(split(split(string(ss1.name), ">")[1], "~")[1]))
        w2 = chron_map[w]
        ss2 = string("rp_", w2)
        push!(periods, [ss1_start, ss2])
    end
    ordering_parameter = map_to_db(periods)
    push!(object_parameters, ("temporal_block", "representative_periods_mapping"))
    push!(
        object_parameter_values, (
            "temporal_block", string(temporal_block()[1]), "representative_periods_mapping", ordering_parameter
        )
    )
end

date_time_to_db(datetime_string) = Dict("type" => "date_time", "data" => datetime_string)

duration_to_db(duration_string) = Dict("type" => "duration", "data" => duration_string)

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