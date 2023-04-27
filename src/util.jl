function is_selection_model()
    representative_period_method(representative_period=first(representative_period())) == :representative_periods
end

function is_ordering_model()
    representative_period_method(representative_period=first(representative_period())) == :representative_periods_ordering
end

function is_db_url(db_url::String)
    db_url = run_request(db_url, "get_db_url")
    (isnothing(match(r".sqlite", db_url)) == false)
end

function is_json_file(filepath::String)
    (isnothing(match(r".json", filepath)) == false)
end

function check_out_file(str::String)
    if !is_db_url(str) && !is_json_file(str)
        error("Output file $(str) extension must be .sqlite or .json.")
    end
end

