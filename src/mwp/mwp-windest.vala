/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * (c) Jonathan Hudson <jh+mwptools@daria.co.uk>
 */

namespace WindEstimate {
	public void update(TrackData t) {
		double w_x = (double)t.wind.w_x;
		double w_y = (double)t.wind.w_y;
		var w_dirn = Math.atan2(w_y, w_x) * (180.0 / Math.PI);
		if (w_dirn < 0) {
			w_dirn += 360;
		}
		var w_ms = Math.sqrt(w_x*w_x + w_y*w_y) / 100.0;
		var w_angle = (w_dirn + 180) % 360;
		var w_diff = t.gps.cog - w_angle;
		if (w_diff < 0) {
			w_diff += 360;
		}
		var vas = t.gps.gspeed - w_ms * Math.cos(w_diff*Math.PI/180.0);
		if((Mwp.DEBUG_FLAGS.ADHOC in Mwp.debug_flags)) {
			MWPLog.message(":DBG: Vas %.1f (%.1fm/s %.0f)\n", vas, w_ms, w_dirn);
		}
	}
}
