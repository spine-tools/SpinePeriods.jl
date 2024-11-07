function is_selection_model()
    rp = first(representative_period())
    representative_period_method(representative_period=rp) == :representative_periods
end

function is_ordering_model()
    rp = first(representative_period())
    representative_period_method(representative_period=rp) == :representative_periods_ordering
end

function is_clustered_ordering_model()
    rp = first(representative_period())
    representative_period_method(representative_period=rp) == :representative_periods_clustering
end

function is_db_url(db_url::String)
    try
        actual_db_url = run_request(db_url, "get_db_url")        
        !isnothing(match(r".sqlite", actual_db_url))
    catch
        false
    end
end

function is_json_file(filepath::String)
    !isnothing(match(r".json", filepath))
end

function check_out_file(str::String)
    if !is_json_file(str) && !is_db_url(str)
        error("Output file $(str) extension must be .sqlite or .json.")
    end
end

function template()
    JSON.parsefile(joinpath(@__DIR__, "representative_periods_template.json"))
end

function slice_ends(slice::Object)
    sl_start = split(string(slice.name), "~")[1]
    sl_end = split(string(slice.name), "~>")[2]
    return sl_start, sl_end
end

function window_number(w::Object)
    return parse(Int, string(w)[2:end])
end
