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
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Delta {
	[GtkTemplate (ui = "/org/stronnag/mwp/deltadialog.ui")]
	public class Dialog : Adw.Window {
		[GtkChild]
		private unowned Gtk.Entry latdelta;
		[GtkChild]
		private unowned Gtk.Entry londelta;
		[GtkChild]
		private unowned Gtk.Entry elevdelta;
		[GtkChild]
		private unowned Gtk.Switch movehome;
		[GtkChild]
		private unowned Gtk.Button apply;
		[GtkChild]
		private unowned Gtk.Button cancel;
		public signal void get_values(double dlat, double dlon, int ialt, bool move_home);

		public Dialog() {
			transient_for = Mwp.window;
			apply.clicked.connect(() => {
					var dlat = InputParser.get_scaled_real(latdelta.get_text());
					var dlon = InputParser.get_scaled_real(londelta.get_text());
					var ialt = (int)InputParser.get_scaled_int(elevdelta.get_text());
					var move_home = movehome.active;
					get_values(dlat, dlon, ialt, move_home);
					close();
				});

			cancel.clicked.connect(() => {
					close();
				});
		}

		public void get_deltas(bool m) {
			movehome.active = m;
			present();
		}
	}
}
