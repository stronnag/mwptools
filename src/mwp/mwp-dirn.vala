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

namespace Direction {
	[GtkTemplate (ui = "/org/stronnag/mwp/dirn.ui")]
	public class View : Gtk.Box {
		[GtkChild]
		private unowned Gtk.Label heading;
		[GtkChild]
		private unowned Gtk.Label cog;

		public View() {
			Mwp.msp.td.gps.notify["cog"].connect((s,p) => {
					set_cog(((GPSData)s).cog);
            });
			Mwp.msp.td.atti.notify["yaw"].connect((s,p) => {
					set_heading(((AttiData)s).yaw);
            });

		}
		private void set_cog (double _cog) {
			cog.label = "<span size='200%%' font='monospace'>%03.0f°</span>".printf(_cog);
		}

		private void set_heading (int yaw) {
			heading.label = "<span size='200%%' font='monospace'>%03d°</span>".printf(yaw);
		}
	}
}