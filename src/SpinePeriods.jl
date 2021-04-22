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

using SpineOpt, SpineInterface, JuMP, Dates, URIParser, JSON

include("preprocess_data_structure.jl")
include("representative_periods_model.jl")
include("postprocess_results.jl")
include("run_spine_periods_selection.jl")
include("run_spine_periods_ordering.jl")
include("run_spine_periods.jl")

export run_spine_periods

end  # module
