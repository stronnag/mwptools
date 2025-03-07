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

namespace TAClean {
	public void clean_tmps(string []tempdirs) {
		foreach(var t in tempdirs) {
			Utils.rmrf(t);
		}
	}

	public string get_tmp(int pid) {
		return Path.build_filename(Environment.get_tmp_dir(), ".mplot_%d".printf(pid));
	}
}

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

		internal string[] tempdirs;

		public Dialog() {
			altview = null;
			close_request.connect (() => {
					cleanup();
					return true;
				});

			pe_ok.clicked.connect(() => {
					tempdirs={};
					run_elevation_tool();
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
			visible=false;
			TAClean.clean_tmps(tempdirs);
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
			pe_ok.sensitive=false;
			var outfn = Utils.mstempname();
			string replname = null;
			string[] spawn_args = {"mwp-plot-elevations", "-no-gnuplot", "-no-mission-alts"};
			var ms = MissionManager.current();
			MissionManager.validate_elevations(ms);
			spawn_args += "-localdem=%s".printf(DemManager.demdir);
			spawn_args += "-home=%.8f,%.8f".printf(HomePoint.hp.latitude, HomePoint.hp.longitude);

			margin_alt = int.parse(pe_clearance.text);
			if (margin_alt != 0) {
				spawn_args += "-margin=%d".printf(margin_alt);
			}
			rth_alt = int.parse(pe_rthalt.text);
			if (rth_alt != 0) {
				spawn_args += "-rth-alt=%d".printf(rth_alt);
			}

			if (pe_replace.active) {
				replname = Utils.mstempname();
				spawn_args += "-output=%s".printf(replname);
			}

			if (pe_land.active) {
				spawn_args += "-upland";
			}
			var altid = (int)pe_altmode.get_selected();
			if (altid != 0) {
				spawn_args += "-force-alt=%d".printf(altid-1);
			}

			XmlIO.to_xml_file(outfn, {ms});
			spawn_args += outfn;
			MWPLog.message("%s\n", string.joinv(" ",spawn_args));

			string []cdlines={};
			string []errlines={};
			var subp = new ProcessLauncher();
			var res = subp.run_argv(spawn_args, ProcessLaunch.STDOUT|ProcessLaunch.STDERR);
			if(res) {
				var stdc = subp.get_stdout_iochan();
				var errc = subp.get_stderr_iochan();
				stdc.add_watch(IOCondition.IN|IOCondition.HUP|IOCondition.NVAL|IOCondition.ERR, (g,c) => {
						var err = ((c & (IOCondition.HUP|IOCondition.ERR|IOCondition.NVAL)) != 0);
						if(!err){
							string line;
							try {
								g.read_line (out line, null, null);
								if (line == null) {
									return false;
								}
							} catch {
								return false;
							}
							cdlines += line.chomp();
							} else {
								return false;
							}
							return true;
					});
				errc.add_watch(IOCondition.IN|IOCondition.HUP|IOCondition.NVAL|IOCondition.ERR, (g,c) => {
						var err = ((c & (IOCondition.HUP|IOCondition.ERR|IOCondition.NVAL)) != 0);
						if(!err){
							string line;
							try {
								g.read_line (out line, null, null);
								if (line == null) {
									return false;
								}
							} catch {
								return false;
							}
							errlines += line.chomp();
						} else {
							return false;
						}
						return true;
					});
				subp.complete.connect(() => {
						pe_ok.sensitive=true;
						try {stdc.shutdown(false);} catch {}
						try {errc.shutdown(false);} catch {}
						int sts = 0;
						var ok = subp.get_status(out sts);
						if(ok) {
							Idle.add(() => {
									var pid = subp.get_pid();
									var gdir = TAClean.get_tmp(pid);
									var fn = Path.build_filename(gdir, "mwpmission.plt");
									var file = File.new_for_path(fn);
									if (file.query_exists ()) {
										var gsubp = new ProcessLauncher();
										var gres = gsubp.run_argv({"gnuplot", "-p", fn}, 0);
										if(gres) {
											gsubp.complete.connect(() => {});
										}
									}
									return false;
								});
							if (replname != null) {
								MissionManager.open_mission_file(replname);
							}
							FileUtils.unlink(outfn);
							if(replname != null) {
								FileUtils.unlink(replname);
							}
							if (cdlines.length > 0) {
								maxclimb = DStr.strtod(pe_climb.text, null);
								maxdive = DStr.strtod(pe_dive.text, null);
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
						} else {
							MWPLog.message("gnuplot status %d (%x)\n", (int)sts, (int)sts);
						}
						if(errlines.length > 0) {
							StringBuilder sb = new StringBuilder("gnuplot reports: ");
							foreach (var l in errlines) {
								sb.append_c('\t');
								sb.append(l);
								sb.append_c('\n');
							}
							MWPLog.message(sb.str);
						}
					});
				var pid = subp.get_pid();
				var gdir = TAClean.get_tmp(pid);
				tempdirs += gdir;
			} else {
				MWPLog.message("Failed to launch 'mwp-plot-elevations'\n");
				pe_ok.sensitive=true;
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
		header_bar.decoration_layout = "icon:close";
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
			sb.append_c('\n');
		}
		sb.append("</tt>");
		label.set_markup(sb.str);
		present();
		label.selectable = true;
	}
}
