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

using Gtk;

namespace Msprc {
	[GtkTemplate (ui = "/org/stronnag/mwp/msprc_dialog.ui")]
	public class Window : Adw.Window {
		[GtkChild]
		internal unowned Gtk.Button log_btn;
		[GtkChild]
		internal unowned Gtk.Label log_name;
		[GtkChild]
		internal unowned Gtk.SpinButton cycle_ms;
		[GtkChild]
		internal unowned Gtk.CheckButton enable;
		[GtkChild]
		internal unowned Gtk.CheckButton duplex;
		[GtkChild]
		internal unowned Gtk.Button apply;

		private string dirname;
		private string filename;
		private string settings_name;

		public Window() {
			cycle_ms.value = (double)Mwp.conf.msprc_cycletime;
			dirname="";
			filename="";
			settings_name = Mwp.conf.msprc_settings;
			if (settings_name.length > 0) {
				dirname = Path.get_dirname(settings_name);
				filename = Path.get_basename(settings_name);
			}
			if(dirname.length == 0) {
				var uc = Environment.get_user_config_dir();
				dirname = GLib.Path.build_filename(uc, "mwp");
			}
			if(filename.length > 0) {
				log_name.label = filename;
			}
			enable.active = Mwp.conf.msprc_enabled;
			duplex.active = Mwp.conf.msprc_full_duplex;

			apply.clicked.connect(() => {
					if(Mwp.conf.msprc_settings != settings_name) {
						Mwp.conf.msprc_settings = settings_name;
					}
					if(Mwp.conf.msprc_cycletime != (uint)cycle_ms.get_value_as_int()) {
						Mwp.conf.msprc_cycletime = (uint)cycle_ms.get_value_as_int();
					}
					if(Mwp.conf.msprc_enabled != enable.active) {
						Mwp.conf.msprc_enabled = enable.active;
					}

					if(Mwp.conf.msprc_full_duplex != duplex.active) {
						Mwp.conf.msprc_full_duplex = duplex.active;
					}
				});

			log_btn.clicked.connect(() => {
					IChooser.Filter []ifm = {{"Text", {"txt"}},};
					var fc = IChooser.chooser(dirname, ifm);
					fc.modal = true;
					fc.open.begin (this, null, (o,r) => {
							try {
								var file = fc.open.end(r);
								log_name.label = file.get_basename();
								settings_name = file.get_path();
							} catch (Error e) {
								MWPLog.message("Failed to open BBL file: %s\n", e.message);
							}
						});
				});
		}
	}
}