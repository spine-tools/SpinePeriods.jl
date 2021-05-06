function is_selection_model()
    return representative_period_method(representative_period=first(representative_period())) == :representative_periods
end

function is_ordering_model()
    return representative_period_method(representative_period=first(representative_period())) == :representative_periods_ordering
end

function is_db_url(str::String)
    return (isnothing(match(r".sqlite", str)) == false)
end

function is_json_file(str::String)
    return (isnothing(match(r".json", str)) == false)
end

function check_out_file(str::String)
    if is_db_url(str) == false && is_json_file(str) == false
        error("Output file $(str) extension must be .sqlite or .json.")
    end
end

