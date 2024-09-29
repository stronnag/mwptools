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

namespace Mwpjs {
	private File? jsfile;
	private bool _speedup;
	Mwpjs.Window mjs;

	public void replay_js(string? s) {
		mjs = new Mwpjs.Window();
		mjs.complete.connect(() => {
				Mwp.run_replay(jsfile.get_path(), !Mwpjs._speedup, Mwp.Player.MWP);
			});
		mjs.run(s);
	}

	[GtkTemplate (ui = "/org/stronnag/mwp/mwpjs.ui")]
	public class Window : Adw.Window {
		[GtkChild]
		private unowned Gtk.Button log_btn;
		[GtkChild]
		private unowned Gtk.Label log_name;
		[GtkChild]
		private unowned Gtk.CheckButton speedup;
		[GtkChild]
		private unowned Gtk.Button cancel;
		[GtkChild]
		private unowned Gtk.Button apply;

		public signal void complete();

		public Window() {
			transient_for = Mwp.window;
			apply.sensitive = false;
			Mwpjs._speedup = false;

			apply.clicked.connect( (id) => {
					Mwpjs._speedup  = this.speedup.active;
					complete();
					close();
				});

			cancel.clicked.connect(() => {
					close();
				});

			log_btn.clicked.connect(() => {
					IChooser.Filter []ifm = {
						{"MwpLog", {"log"}},
					};
					var fc = IChooser.chooser(Mwp.conf.logpath, ifm);
					fc.title = "Open mwp JSON Log File";
					fc.modal = true;
					fc.open.begin (Mwp.window, null, (o,r) => {
							try {
								var file = fc.open.end(r);
								jsfile = file;
								log_name.label = jsfile.get_basename();
								apply.sensitive = true;
							} catch (Error e) {
								MWPLog.message("Failed to open JSON file: %s\n", e.message);
							}
						});
				});
		}

		public void run(string? s=null) {
			if(s != null) {
				jsfile = File.new_for_path(s);
				log_name.label = jsfile.get_basename();
			}
			present();
		}
	}

    private void check_mission(string missionlog) {
        bool done = false;
        string mfn = null;

        var dis = FileStream.open(missionlog,"r");
        if (dis != null) {
            var parser = new Json.Parser ();
            string line = null;
            while (!done && (line = dis.read_line ()) != null) {
                try {
                    parser.load_from_data (line);
                    var obj = parser.get_root ().get_object ();
                    var typ = obj.get_string_member("type");
                    switch(typ) {
                        case "init":
                            if(obj.has_member("mission"))
                                mfn =  obj.get_string_member("mission");
                            done = true;
                            break;
                        case "armed":
                            done = true;
                            break;
                    }
                } catch {
                    done = true;
                }
            }
        }
        if(mfn != null) {
            Mwp.hard_display_reset(true);
            MissionManager.open_mission_file(mfn, false);
        }
        else {
            Mwp.hard_display_reset(false);
        }
    }
}
