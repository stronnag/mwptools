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

namespace GPSStats {
	[GtkTemplate (ui = "/org/stronnag/mwp/gps_stats_dialog.ui")]
	public class Window : Adw.Window {
		[GtkChild]
		private unowned Gtk.Label gps_stats_last_dt;
		[GtkChild]
		private unowned Gtk.Label gps_stats_errors;
		[GtkChild]
		private unowned Gtk.Label gps_stats_timeouts;
		[GtkChild]
		private unowned Gtk.Label gps_stats_packets;
		[GtkChild]
		private unowned Gtk.Label gps_stats_hdop;
		[GtkChild]
		private unowned Gtk.Label gps_stats_eph;
		[GtkChild]
		private unowned Gtk.Label gps_stats_epv;

		private uint tid = 0;

		public Window() {
			Timeout.add(1000, () => {
					double hz = 1000.0/Mwp.gpsstats.last_message_dt;
					gps_stats_last_dt.label = "%.1f".printf(hz);
					gps_stats_errors.label = "%u".printf(Mwp.gpsstats.errors);
					gps_stats_packets.label = "%u".printf(Mwp.gpsstats.packet_count);
					gps_stats_timeouts.label = "%u".printf(Mwp.gpsstats.timeouts);
					double hdop, eph, epv;
					hdop = Mwp.gpsstats.hdop * 0.01;
					eph = Mwp.gpsstats.eph * 0.01;
					epv = Mwp.gpsstats.epv * 0.01;
					gps_stats_hdop.label = "%.2f".printf(hdop);
					gps_stats_eph.label = "%.2f".printf(eph);
					gps_stats_epv.label = "%.2f".printf(epv);
					return true;
				});

			close_request.connect(() => {
					if(tid != 0) {
						Source.remove(tid);
					}
					return false;
				});
		}
	}
}