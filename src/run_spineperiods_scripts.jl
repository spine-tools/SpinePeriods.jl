#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
#
# This file is part of SpineOpt.
#
# SpineOpt is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# SpineOpt is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################

using SpinePeriods

db_url_in = ARGS[1]
db_url_out = ARGS[2]
@info "reading database"
SpinePeriods.using_spinedb(db_url_in; upgrade=true)
if representative_period_method(representative_period=first(representative_period())) == :representative_periods
    SpinePeriods.run_spineperiods(
        db_url_in, db_url_out,
        with_optimizer=optimizer_with_attributes(
            Cbc.Optimizer, "logLevel" => 1, "ratioGap" => 0.01,
            "seconds" => 60
        )
    )
elseif representative_period_method(representative_period=first(representative_period())) == :representative_periods_ordering
    SpinePeriods.run_spineperiods_ordering(
        db_url_in, db_url_out,
        with_optimizer=optimizer_with_attributes(
            Cbc.Optimizer, "logLevel" => 1, "ratioGap" => 0.01,
            "seconds" => 60
        )
    )
end
