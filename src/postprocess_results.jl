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


function postprocess_results!(m::Model, db_url, out_file, window__static_slice)
    @fetch selected, weight = m.ext[:variables]

    objects = []
    object_parameters = []
    object_parameter_values = []
    object_groups = []

    add_representative_period_group!(objects, object_groups, selected)

    add_representative_period_temporal_blocks!(
        objects, object_parameters, object_parameter_values,
        window__static_slice, selected, weight
    )    
    
    is_ordering_model() && add_representative_period_mapping!(
        m, objects, object_parameters, object_parameter_values,
        window__static_slice
    )

    d = Dict(
        :object_groups => object_groups,
        :objects => objects,
        :object_parameters => object_parameters,
        :object_parameter_values => object_parameter_values
    )

    msg = "Saved representative periods."
    if is_db_url(out_file)
        create_copy_db(db_url, out_file)
        SpineOpt.import_data(
            out_file,
            d,
            msg
        )
    elseif is_json_file(out_file)
        open(out_file, "w") do f
            JSON.print(f, d, 4)
        end
    end
    @info eval(msg)
end

function postprocess_ordering_results!(m::Model, db_url, out_file, window__static_slice)
    @fetch selected, weight = m.ext[:variables]
    
    objects = []
    object_parameters = []
    object_parameter_values = []
    
    # this should be in the template: push!(object_parameters, ("temporal_block", "weight"))

    db_uri = URI(db_url)
    db_path = db_uri.path[2:length(db_uri.path)]
    url_out_uri = URI(out_file)
    url_out_path = url_out_uri.path[2:length(url_out_uri.path)]
    cp(db_path, url_out_path,force=true)
    @info "New database copied to $(url_out_path)"

    db_map = db_api.DiffDatabaseMapping(out_file; upgrade=true)
    chron = Dict(
        (w1, w2) => value(m.ext[:variables][:chronology][w1,w2])
        for w1 in SpinePeriods.window(), w2 in SpinePeriods.window()
    )
    nonZero = findall(x -> x == 1, chron)
    chronMap = Dict(w[1] => w[2] for w in nonZero)
    days = []
    object_groups = []
    push!(objects, ("temporal_block", "all_representative_periods"))
    
    for w in window()
        if JuMP.value(selected[w]) == 1
            tb_name = string("rp_", w)
            t_start = date_time_to_db(split(string(first(window__static_slice[w]).name), "~>")[1])
            t_end = date_time_to_db(split(string(last(window__static_slice[w]).name), "~>")[2])
            res = resolution(temporal_block=first(temporal_block()))
            db_res = duration_to_db(julia_resolution_to_db_resolution_string(res)) # this needs to be more generic
            wt = JuMP.value(weight[w])
            push!(objects, ("temporal_block", tb_name))
            push!(object_parameter_values, ("temporal_block", tb_name, "block_start", t_start))
            push!(object_parameter_values, ("temporal_block", tb_name, "block_end", t_end))
            push!(object_parameter_values, ("temporal_block", tb_name, "resolution", db_res))
            push!(object_parameter_values, ("temporal_block", tb_name, "weight", wt))
            @info "selected window: $(w) with start $(t_start["data"]) and weight $(wt)"
            push!(object_groups, ("temporal_block", "all_representative_periods", tb_name))
        end # if selected
        ss1 = window__static_slice[w][1]
        ss1_start = string(rstrip(split(split(string(ss1.name), ">")[1], "~")[1]))
        w2 = chronMap[w]
        ss2 = string("rp_", w2)
        push!(days,[ss1_start,ss2])
    end # for w in window

    ordering_parameter = map_to_db(days)
    push!(object_parameters, ("temporal_block", "representative_periods_mapping"))
    push!(object_parameter_values, ("temporal_block", string(temporal_block()[1]), "representative_periods_mapping", ordering_parameter))
    added, err_log = db_api.import_data(
        db_map,
        objects=objects,
        object_parameters=object_parameters,
        object_parameter_values=object_parameter_values,
        object_groups=object_groups,
    )
    @info "Added $(added) items..."
    for err in err_log
        @info "Import error: " err.msg
    end

    comment = "Added temporal blocks from timeslice tool..."
    db_map.commit_session(comment)

end

function add_representative_period_group!(
    objects, object_groups, selected
    )
    push!(objects, ("temporal_block", "all_representative_periods"))
    for w in window()
        JuMP.value(selected[w]) != 1 && continue
        tb_name = string("rp_", w)
        push!(object_groups, ("temporal_block", "all_representative_periods", tb_name))
    end
    return nothing
end

function add_representative_period_temporal_blocks!(
        objects, object_parameters, object_parameter_values,
        window__static_slice, selected, weight
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
            @info "Selected window: $(w) with start $(t_start["data"]) and weight $(wt)"
        end
    end
    return nothing
end

function add_representative_period_mapping!(
        m, objects, object_parameters, object_parameter_values,
        window__static_slice
    )
    chron = Dict(
        (w1, w2) => value(m.ext[:variables][:chronology][w1,w2])
        for w1 in SpinePeriods.window(), w2 in SpinePeriods.window()
    )
    nonZero = findall(x -> x == 1, chron)
    chronMap = Dict(w[1] => w[2] for w in nonZero)
    periods = []
    for w in window()
        ss1 = window__static_slice[w][1]
        ss1_start = string(rstrip(split(split(string(ss1.name), ">")[1], "~")[1]))
        w2 = chronMap[w]
        ss2 = string("rp_", w2)
        push!(periods, [ss1_start,ss2])
    end

    ordering_parameter = map_to_db(periods)
    push!(object_parameters, ("temporal_block", "representative_periods_mapping"))
    push!(
        object_parameter_values, (
            "temporal_block", string(temporal_block()[1]), 
            "representative_periods_mapping", ordering_parameter
        )
    )
    return nothing
end

function date_time_to_db(datetime_string)
    val = Dict()
    val["type"] = "date_time"
    val["data"] = datetime_string
    val
end

function duration_to_db(datetime_string)
    val = Dict()
    val["type"] = "duration"
    val["data"] = datetime_string
    val
end

function map_to_db(maparray)
    val = Dict()
    val["type"] = "map"
    val["index_type"] = "date_time"
    val["data"] = maparray
    val
end

function julia_resolution_to_db_resolution_string(resolution::TimePeriod)
    conversion_dict = Dict("Dates.Hour" => "h", "Dates.Minute" => "m", "Hour" => "h", "Minute" => "m") # to be extended, probably there is already a function like this
    conversion_dict[string(typeof(resolution))]
    db_resolution = string(resolution.value, conversion_dict[string(typeof(resolution))])
end

function create_copy_db(db_url, out_file)
    db_uri = URI(db_url)
    db_path = db_uri.path[2:length(db_uri.path)]
    url_out_uri = URI(out_file)
    url_out_path = url_out_uri.path[2:length(url_out_uri.path)]
    cp(db_path, url_out_path, force=true)
    @info "New database copied to $(url_out_path)"
end