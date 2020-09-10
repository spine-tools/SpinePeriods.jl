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

module SpinePeriods

using SpineOpt
using SpineInterface
using JuMP
using Dates
using URIParser

include("preprocess_data_structure.jl")
include("representative_periods_model.jl")
include("postprocess_results.jl")

function run_spineperiods(
        url_in::String;
        with_optimizer=optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0, "ratioGap" => 0.01),
    )
    @info "reading database"
    using_spinedb(url_in)
    @info "processing SpinePeriods temporal structure"
    SpineOpt.generate_temporal_structure()
    @info "preprocessing data structure"
    window__static_slice = preprocess_data_structure()
    @info "Initializing model..."
    m = Model(with_optimizer)

    m.ext[:variables] = Dict{Symbol,Dict}()
    m.ext[:variables_lb] = Dict{Symbol,Any}()
    m.ext[:variables_ub] = Dict{Symbol,Any}()
    m.ext[:values] = Dict{Symbol,Dict}()
    m.ext[:constraints] = Dict{Symbol,Dict}()

    create_variables!(m)
    set_objective!(m)
    add_constraint_error1!(m)
    add_constraint_error2!(m)
    add_constraint_selected_periods!(m)
    add_constraint_single_weight!(m)
    add_constraint_total_weight!(m)

    optimize!(m)
    if termination_status(m) in (MOI.OPTIMAL, MOI.TIME_LIMIT)
        @info "Model solved. Termination status: $(termination_status(m))"
        postprocess_results!(m, url_in, window__static_slice)
    else
        @info "Unable to find solution (reason: $(termination_status(m)))"
    end
end

end  # module
