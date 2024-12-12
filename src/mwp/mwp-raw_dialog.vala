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

namespace Raw {
	int delay;

	private File? rawfile;
	Raw.Window raw;

	public void replay_raw(string? s) {
		raw = new Raw.Window();
		raw.complete.connect(() => {
				Mwp.run_replay(rawfile.get_path(), true, Mwp.Player.RAW, Raw.delay);
			});
		raw.run(s);
	}

	[GtkTemplate (ui = "/org/stronnag/mwp/raw_dialog.ui")]
	public class Window : Adw.Window {
		[GtkChild]
		private unowned Gtk.Button log_btn;
		[GtkChild]
		private unowned Gtk.Label log_name;
		[GtkChild]
		private unowned Gtk.Entry rawdelay;
		[GtkChild]
		private unowned Gtk.Button cancel;
		[GtkChild]
		private unowned Gtk.Button apply;

		public signal void complete();

		public Window() {
			transient_for = Mwp.window;
			apply.sensitive = false;
			Raw.delay = 0;

			apply.clicked.connect( (id) => {
					Raw.delay = int.parse(this.rawdelay.text);
					complete();
					close();
				});
			cancel.clicked.connect(() => {
					close();
				});

			log_btn.clicked.connect(() => {
					IChooser.Filter []ifm = {
						{"Raw", {"raw","log","bin"}},
					};
					var fc = IChooser.chooser(Mwp.conf.logpath, ifm);
					fc.title = "Open mwp Raw File";
					fc.modal = true;
					fc.open.begin (Mwp.window, null, (o,r) => {
							try {
								var file = fc.open.end(r);
								rawfile = file;
								log_name.label = file.get_basename();
								apply.sensitive = true;
							} catch (Error e) {
								MWPLog.message("Failed to open Raw file: %s\n", e.message);
							}
						});
				});
		}

		public void run(string? s=null) {
			if(s != null) {
				rawfile = File.new_for_path(s);
				log_name.label = rawfile.get_basename();
			}
			present();
		}
	}
}
