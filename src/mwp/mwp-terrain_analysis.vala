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

namespace TA {
	[GtkTemplate (ui = "/org/stronnag/mwp/tadialog.ui")]
	public class Dialog : Adw.Window {
		[GtkChild]
		private unowned Gtk.Button pe_ok;
		[GtkChild]
		private unowned Gtk.Button pe_close;
		[GtkChild]
		unowned Gtk.Label  pe_home_text;
		[GtkChild]
		unowned Gtk.Entry pe_clearance;
		[GtkChild]
		unowned Gtk.CheckButton pe_replace;
		[GtkChild]
		unowned Gtk.CheckButton pe_land;
		[GtkChild]
		unowned Gtk.Entry pe_rthalt;
		[GtkChild]
		unowned Gtk.DropDown pe_altmode;
		[GtkChild]
		unowned Gtk.Entry pe_climb;
		[GtkChild]
		unowned Gtk.Entry pe_dive;

		private int margin_alt = 30;
		private int rth_alt = 50;

		private double maxclimb = 15.0;
		private double maxdive = -12.0;

		private ScrollView? altview;
		private Pid pid;


		public Dialog() {
			altview = null;
			close_request.connect (() => {
					cleanup();
					return true;
				});

			pe_ok.clicked.connect(() => {
					run_elevation_tool();
					hide();
				});

			pe_close.clicked.connect(() => {
					cleanup();
				});

			pe_rthalt.text = rth_alt.to_string();
			pe_climb.text = "%.1f".printf(maxclimb);
			pe_dive.text = "%.1f".printf(maxdive);

		}

		public void cleanup() {
			Utils.terminate_plots();
			if(altview != null) {
				altview.close();
			}
			hide();
		}

		public void run() {
			HomePoint.hp.drag_motion.connect((la, lo) => {
					pe_home_text.label = PosFormat.pos(la, lo, Mwp.conf.dms,false);
				});

			var hlat = HomePoint.hp.latitude;
			var hlon = HomePoint.hp.longitude;
			pe_home_text.label = PosFormat.pos(hlat, hlon, Mwp.conf.dms,false);
						pe_clearance.text = margin_alt.to_string();

			transient_for = Mwp.window;
			present();
		}



		private void run_elevation_tool() {
			var outfn = Utils.mstempname();
			string replname = null;
			string[] spawn_args = {"mwp-plot-elevations"};
			var ms = MissionManager.current();
			MissionManager.validate_elevations(ms);
			// FIXME : check when old windows kill was done.

			spawn_args += "-localdem=%s".printf(DemManager.demdir);
			spawn_args += "--no-mission-alts";
			spawn_args += "--home=%.8f,%.8f".printf(HomePoint.hp.latitude, HomePoint.hp.longitude);

			margin_alt = int.parse(pe_clearance.text);
			if (margin_alt != 0) {
				spawn_args += "--margin=%d".printf(margin_alt);
			}
			rth_alt = int.parse(pe_rthalt.text);
			if (rth_alt != 0) {
				spawn_args += "--rth-alt=%d".printf(rth_alt);
			}

			if (pe_replace.active) {
				replname = Utils.mstempname();
				spawn_args += "--output=%s".printf(replname);
			}

			if (pe_land.active) {
				spawn_args += "--upland";
			}
			var altid = (int)pe_altmode.get_selected();
			if (altid != 0) {
				spawn_args += "--force-alt=%d".printf(altid-1);
			}

			XmlIO.to_xml_file(outfn, {ms});
			spawn_args += outfn;
			MWPLog.message("%s\n", string.joinv(" ",spawn_args));
			string []cdlines = {};
			try {
				int p_stderr;
				int p_stdout;
				Process.spawn_async_with_pipes (null,
												spawn_args,
												null,
												SpawnFlags.SEARCH_PATH |
												SpawnFlags.DO_NOT_REAP_CHILD,
												null,
												out pid,
												null,
												out p_stdout,
												out p_stderr);

				IOChannel outp = new IOChannel.unix_new (p_stdout);
				IOChannel error = new IOChannel.unix_new (p_stderr);
				string line = null;
				string lastline = null;
				size_t len = 0;

				error.add_watch (IOCondition.IN|IOCondition.HUP, (source, condition) => {
						try {
							if (condition == IOCondition.HUP)
								return false;
							IOStatus eos = source.read_line (out line, out len, null);
							if(eos == IOStatus.EOF)
								return false;

							if(line == null || len == 0)
								return true;
							lastline = line;
							return true;
						} catch (IOChannelError e) {
							MWPLog.message("IOChannelError: %s\n", e.message);
							return false;
						} catch (ConvertError e) {
							MWPLog.message ("ConvertError: %s\n", e.message);
							return false;
						}
					});

				outp.add_watch (IOCondition.IN|IOCondition.HUP, (source, condition) => {
						try {
							if (condition == IOCondition.HUP)
								return false;
							IOStatus eos = source.read_line (out line, out len, null);
							if(eos == IOStatus.EOF)
								return false;

							if(line == null || len == 0)
								return true;
							cdlines += line;
							return true;
						} catch (IOChannelError e) {
							MWPLog.message("IOChannelError: %s\n", e.message);
							return false;
						} catch (ConvertError e) {
							MWPLog.message ("ConvertError: %s\n", e.message);
							return false;
						}
					});


				ChildWatch.add (pid, (pid, status) => {
						try { error.shutdown(false); } catch {}
						Process.close_pid (pid);
						if(status == 0) {
							if (replname != null) {
								MissionManager.open_mission_file(replname);
							}
						} else {
							var errstr="Plot Error: %s".printf(lastline);
							MWPLog.message(":DBG: %s\n", errstr);
						}
						FileUtils.unlink(outfn);
						if(replname != null)
							FileUtils.unlink(replname);

						if (cdlines.length > 0) {
							// FIXME Dstr ...
							maxclimb = double.parse(pe_climb.text);
							maxdive = double.parse(pe_dive.text);
							if (altview != null) {
								altview.close();
								altview = null;
							}
							altview = new ScrollView("MWP Altitude Analysis");
							altview.close_request.connect(() => {
									altview = null;
									return false;
								});
							altview.generate_climb_dive(cdlines, maxclimb, maxdive);
						}
                });
			} catch (SpawnError e) {
				MWPLog.message ("Spawn Error: %s\n", e.message);
			}
		}
	}
}

public class  ScrollView : Adw.Window {
	private Gtk.Label label;
	public ScrollView (string _title = "Text View") {
		title = _title;

		var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		var header_bar = new Adw.HeaderBar();
		box.append(header_bar);

		var win = new Gtk.ScrolledWindow();

		label = new Gtk.Label (null);
        label.set_use_markup(true);


		win.has_frame = true;
		win.min_content_height = 400;
		win.min_content_width = 320;
		win.propagate_natural_height = true;
		win.propagate_natural_width = true;

		var button = new Gtk.Button.with_label ("OK");
		button.clicked.connect (() => {
				close();
			});

		win.set_child (label);
		box.append(win);
		box.append(button);
		set_content(box);
	}

	public void generate_climb_dive(string[]lines, double maxclimb, double maxdive) {
		var sb = new StringBuilder();
		sb.append("<tt>");
		foreach (var l in lines) {
			var hilite = false;
			var lparts = l.split("\t");
            if (lparts.length == 3) {
                double angle=double.parse(lparts[1]);
                if((angle > 0.0 && maxclimb > 0.0 && angle > maxclimb) ||
                   (angle < 0.0 && maxdive < 0.0 && angle < maxdive))
                    hilite = true;
            }
            if(hilite)
                sb.append("<span foreground='red'>");
            sb.append(l);
            if(hilite)
                sb.append("</span>");
		}
		sb.append("</tt>");
		label.set_markup(sb.str);
		present();
		label.selectable = true;
	}
}
