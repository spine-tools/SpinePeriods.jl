

"""
    run_spine_periods_clustering(url_in, out_file)

    Solves an clustering problem which selects representative periods.
    Output: written in the database or JSON file.

"""
function run_spine_periods_clustering(
    url_in::String,
    out_file::String;
    with_optimizer=optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false),
    alternative=""
)

    rp = first(representative_period())

    @info "Initializing model..."
    m = Model(with_optimizer)
    m.ext[:spineopt] = SpineOptExt(first(model()), with_optimizer)
    @info "Generating SpinePeriods temporal structure..."
    generate_temporal_structure!(m)
    @info "Preprocessing data structure..."
    window__static_slice = preprocess_data_structure(m)
    
    obs_matrix = make_obs_matrix()
    println(size(obs_matrix))

    # import the Python module for clustering
    scriptdir = @__DIR__
    pushfirst!(PyVector(pyimport("sys")."path"), scriptdir)
    clustering = pyimport("cluster")
    
    # call clustering function, correct zero-based indices
    cl_result = Dict()
    cl_result[:chronology], cl_result[:win_selected] = 
        clustering.kmedoids_clustering(obs_matrix, representative_periods(representative_period=rp))
    cl_result[:chronology] = cl_result[:win_selected][cl_result[:chronology] ]
    @info "Clustering done."

    postprocess_results!(m, url_in, out_file, window__static_slice; 
        clustering_result=cl_result, alternative=alternative)
end

"""
    function make_obs_matrix()

    Prepare the observation matrix X for clustering analysis from
    resource availability data. 

    Return:

    `obs_matrix`: the observation matrix X for clustering analysis
    where rows correspond to observations.
    
"""
function make_obs_matrix()

    obs_matrix = nothing
    window_len = length(resource__window__static_slice(resource=first(resource()), window=first(window())))

    for r in resource()
        a = zeros(length(window()), window_len)
        for w1 in window()
            wn = window_number(w1)
            wss = resource__window__static_slice(resource=r, window=w1)
            wss = sort(wss, by = ss -> slice_ends(ss)[1])
            for i_wss in 1:length(wss)
                a[wn, i_wss] = resource_availability_window_static_slice(resource=r, window=w1, ss=wss[i_wss])
            end
        end
        a = a / norm(a)
        if isnothing(obs_matrix)
            obs_matrix = a
        else
            obs_matrix = hcat(obs_matrix, a)
        end
    end
       
    return obs_matrix
end
