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

namespace Alt {
	[GtkTemplate (ui = "/org/stronnag/mwp/altdialog.ui")]
	public class Dialog : Adw.Window {
		[GtkChild]
		private unowned Gtk.Entry deltaalt;
		[GtkChild]
		private unowned Gtk.CheckButton as_amsl;
		[GtkChild]
		private unowned Gtk.Button apply;
		[GtkChild]
		private unowned Gtk.Button cancel;

		public signal void get_value(double v, bool b);

		public Dialog() {
			apply.clicked.connect(() => {
					var alt = InputParser.get_scaled_real(deltaalt.get_text(),"d");
					get_value(alt, as_amsl.active);
					close();
				});
			cancel.clicked.connect(() => {
					close();
				});
			set_transient_for (Mwp.window);
		}

		public void get_alt() {
			present();
		}
	}
}

namespace Speed {
	[GtkTemplate (ui = "/org/stronnag/mwp/speeddialog.ui")]
	public class Dialog : Adw.Window {
		[GtkChild]
		private unowned Gtk.Entry deltaspeed;
		[GtkChild]
		private unowned Gtk.Button apply;
		[GtkChild]
		private unowned Gtk.Button cancel;

		public signal void get_value(double v);

		public Dialog() {
			apply.clicked.connect(() => {
					var alt = InputParser.get_scaled_real(deltaspeed.get_text(),"d");
					get_value(alt);
					close();
				});
			cancel.clicked.connect(() => {
					close();
				});
			set_transient_for (Mwp.window);
		}

		public void get_speed() {
			present();
		}
	}
}
