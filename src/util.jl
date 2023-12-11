function is_selection_model()
    rp = first(representative_period())
    representative_period_method(representative_period=rp) == :representative_periods
end

function is_ordering_model()
    rp = first(representative_period())
    representative_period_method(representative_period=rp) == :representative_periods_ordering
end

function is_db_url(db_url::String)
    try
        path=run_request(db_url, "get_db_url")        
        !isnothing(match(r".sqlite", path))
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

