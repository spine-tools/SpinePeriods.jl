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


function postprocess_results!(m::Model, db_url, window__static_slice)
    @fetch selected, weight = m.ext[:variables]

    objects = []
    object_parameters = []
    object_parameter_values = []

    push!(object_parameters, ("temporal_block", "weight"))

    db_uri = URI(db_url)
    db_path = db_uri.path[2:length(db_uri.path)]
    new_db_path_root = string(db_path[1:findlast(isequal('.'), db_path) - 1], "_rps")
    path_ext = ".sqlite"
    if isfile(string(new_db_path_root, path_ext))
        i = 1
        while isfile(string(new_db_path_root, "_", i, path_ext))
            i = i + 1
        end
        new_db_path = string(new_db_path_root, "_", i, path_ext)
    else
        new_db_path = string(new_db_path_root, path_ext)
    end

    cp(db_path, new_db_path)
    new_db_url=string("sqlite:///", new_db_path)

    @info "new database copied to $(new_db_path)"

    db_map=db_api.DiffDatabaseMapping(new_db_url; upgrade=true)

    for w in window()
        if JuMP.value(selected[w]) == 1
            tb_name = string("rp_", w)

            t_start = date_time_to_db(split(string(first(window__static_slice[w]).name), " ~> ")[1])
            t_end = date_time_to_db(split(string(last(window__static_slice[w]).name), " ~> ")[2])

            res = resolution(temporal_block=first(temporal_block()))
            wt = JuMP.value(weight[w])
            push!(objects, ("temporal_block", tb_name))
            push!(object_parameter_values, ("temporal_block", tb_name, "block_start", t_start))
            push!(object_parameter_values, ("temporal_block", tb_name, "block_end", t_end))
            push!(object_parameter_values, ("temporal_block", tb_name, "resolution", string(res)))
            push!(object_parameter_values, ("temporal_block", tb_name, "weight", wt))
            @info "selected window: $(w) with start $(t_start["data"]) and weight $(wt)"
        end
    end

    added, err_log = db_api.import_data(
        db_map,
        objects=objects,
        object_parameters=object_parameters,
        object_parameter_values=object_parameter_values
    )
    @info "added $(added) items"
    for err in err_log
        @info "import error: " err.msg
    end

    comment="added temporal blocks from timeslice tool"
    db_map.commit_session(comment)

end

function postprocess_ordering_results!(m::Model, db_url, window__static_slice)
    chron = Dict(
        (w1,w2) => value(m.ext[:variables][:chronology][w1,w2])
        for w1 in SpinePeriods.window(), w2 in SpinePeriods.window()
    )
    nonZero = findall(x -> x == 1, chron)
    chronMap = Dict(w[1] => w[2] for w in nonZero)
    jsonDict = Dict(
        "type" => "map",
        "index_type" => "date_time",
        "data" => []
    )
    for w1 in window()
        w2 = chronMap[w1]
        for (ss1,ss2) in zip(
                window__static_slice[w1],
                window__static_slice[w2],
            )
            ss1_start = string(rstrip(split(split(string(ss1.name), ">")[1], "~")[1]))
            ss1_end = string(lstrip(split(string(ss1.name), ">")[2]))
            ss2_start = string(rstrip(split(split(string(ss2.name), ">")[1], "~")[1]))
            ss2_end = string(rstrip(split(split(string(ss2.name), ">")[1], "~")[1]))

            push!(
                jsonDict["data"],
                [ss1_start, Dict(
                    "type" => "map",
                    "index_type" => "date_time",
                    "data" => [
                        [ss1_end, Dict(
                            "type" => "map",
                            "index_type" => "str",
                            "data" => hcat(
                                [
                                    "start",
                                    ss2_start
                                ],
                                [
                                    "end",
                                    ss2_end
                                ]
                            )
                        )]
                    ]
                )]
            )
        end
    end
    open("timeslice_map.json","w") do f
        JSON.print(f, jsonDict)
    end
end

function date_time_to_db(datetime_string)
    val=Dict()
    val["type"] = "date_time"
    val["data"] = datetime_string
    val
end
