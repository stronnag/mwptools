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

// Handle Secondary Devices

namespace TelemTracker {
	TelemTracker.Window ttrk;

	enum Column {
		NAME,
		ALIAS,
		STATUS,
		PMASK,
		ID,
		NO_COLS
	}

	public enum Status {
		UNDEF = 0,
		PRESENT = 1,
		USED  = 2,
	}

	[Flags]
	private enum Fields {
		LAT,
		LON,
		SAT,
		ALT,
		FIX,
		SPD,
		CSE,
		STS,
		ALL
	}

	public void init() {
		ttrk = new TelemTracker.Window();
	}

	public class Window {
		private const double RAD2DEG = 57.29578;

		public signal void changed();
		public signal void pending(bool val);

		public struct SecDev {
			MWSerial dev;
			string name;
			string devalias;
			string alias;
			Status status;
			bool userdef;
			uint8 ready;
			MWSerial.PMask pmask;
		}

		internal SecDev[] secdevs;

		private  string? find_conf_file(string fn) {
			var uc =  Environment.get_user_config_dir();
			var cfile = GLib.Path.build_filename(uc,"mwp",fn);
			var n = Posix.access(cfile, Posix.R_OK);
			if (n == 0)
				return cfile;
			else
				return null;
		}

		public Window() {
			secdevs = {};
			string fn;
			if((fn = find_conf_file("secdevs")) != null) {
				var file = File.new_for_path(fn);
				try {
					var dis = new DataInputStream(file.read());
					string line;
					while ((line = dis.read_line (null)) != null) {
						if(line.strip().length > 0 &&
						   !line.has_prefix("#") &&
						   !line.has_prefix(";")) {
							add(line);
						}
					}
				} catch (Error e) {
					error ("%s", e.message);
				}
			}
		}

		public void save_data() {
			var uc =  Environment.get_user_config_dir();
			var cfile = GLib.Path.build_filename(uc,"mwp","secdevs");
			var fp = FileStream.open (cfile, "w");
			if (fp != null) {
				fp.write("# name, hint, alias\n".data);
				foreach (var sd in secdevs) {
					if (sd.userdef && sd.name != "" && sd.status != TelemTracker.Status.UNDEF) {
						fp.write("%s,%s,%s\n".printf(sd.name, MWSerial.pmask_to_name(sd.pmask), sd.alias).data);
					}
				}
			}
		}

		public void show_dialog() {
			Status []xstat={};
			foreach (var s in secdevs) {
				xstat += s.status;
			}
			var s = new SecDevDialog();
			s.close_request.connect(() => {
					save_data();
					return false;
				});
			s.run();
		}

		public bool is_used(string sname) {
			var parts = sname.split(" ", 2);
			foreach (var s in secdevs) {
				if (s.name == parts[0] && s.status == Status.USED) {
					return true;
				}
			}
			return false;
		}


		public void add(string? sname) {
			bool found = false;
			string devname = "";
			string devalias = "";
			string[] parts={};
			MWSerial.PMask pmask = MWSerial.PMask.AUTO;
			if (sname != null) {
				parts = sname.split(",", 3);
				var sparts = parts[0].split(" ",2);
				if (sparts.length > 0) {
					devname = sparts[0];
					if (sparts.length > 1) {
						devalias = sparts[1];
						if (parts.length > 1 ) {
							if (parts[1].strip().length > 0) {
								pmask = MWSerial.name_to_pmask(parts[1]);
							}
						}
					}
				}

				for(int n = 0; n < secdevs.length; n++) {
					if (secdevs[n].name == devname || secdevs[n].name == devalias) {
						secdevs[n].status = Status.PRESENT;
						found = true;
						break;
					}
				}
			}

			if(!found) {
				var s = SecDev();
				s.userdef = (parts.length > 1);
				s.status = Status.PRESENT;
				s.name = devname;
				if (parts.length == 3) {
					s.alias = parts[2];
				} else {
					if (s.name.length > 0) {
						string suffix;
						if (sname.has_prefix("/dev/")) {
							suffix = s.name[5:s.name.length];
						} else {
							suffix = s.name;
						}
						if (devalias == null) {
							s.alias = "TTRK-%s".printf(suffix);
						} else {
							s.alias = devalias;
						}
					}
				}
				s.dev = null;
				s.pmask = pmask;
				secdevs += s;
				changed();
			}
		}

		public void remove(string sname) {
			disable(sname);
			changed();
		}

		public void enable(string sname) {
			var parts = sname.split(" ", 2);
			for(int n = 0; n < secdevs.length; n++) {
				if (secdevs[n].name == parts[0]) {
					secdevs[n].status = Status.PRESENT;
					break;
				}
			}
			changed();
		}

		public void disable(string sname) {
			var parts = sname.split(" ", 2);
			for(int n = 0; n < secdevs.length; n++) {
				if (secdevs[n].name == parts[0]) {
					secdevs[n].status = Status.UNDEF;
					break;
				}
			}
			changed();
		}

		public void start_reader(int n) {
			if (secdevs[n].dev == null) {
				secdevs[n].dev = new MWSerial();
				secdevs[n].dev.td = new TrackData(0xff);
				secdevs[n].ready = 0;

				secdevs[n].dev.td.gps.notify["lat"].connect((s,p) => {
						uint rk = (uint)(n+256);
						var ri = get_ri(rk);
						ri.latitude = ((GPSData)s).lat;
						Radar.upsert(rk, ri);
						secdevs[n].ready |= Fields.LAT;
				});

				secdevs[n].dev.td.gps.notify["lon"].connect((s,p) => {
					uint rk = (uint)(n+256);
					var ri = get_ri(rk);
					ri.longitude = ((GPSData)s).lon;
					Radar.upsert(rk, ri);
					secdevs[n].ready |= Fields.LON;
				});

				secdevs[n].dev.td.gps.notify["gspeed"].connect((s,p) => {
					uint rk = (uint)(n+256);
					var ri = get_ri(rk);
					ri.speed = ((GPSData)s).gspeed;
					Radar.upsert(rk, ri);
				});

				secdevs[n].dev.td.gps.notify["cog"].connect((s,p) => {
					uint rk = (uint)(n+256);
					var ri = get_ri(rk);
					ri.heading = (uint16)((GPSData)s).cog;
					Radar.upsert(rk, ri);
				});

				secdevs[n].dev.td.alt.notify["alt"].connect((s,p) => {
					uint rk = (uint)(n+256);
					var ri = get_ri(rk);
					ri.altitude = ((AltData)s).alt;
					Radar.upsert(rk, ri);
				});

				secdevs[n].dev.td.rssi.notify["rssi"].connect((s,p) => {
					uint rk = (uint)(n+256);
					var ri = get_ri(rk);
					ri.lq = (uint8)(((RSSIData)s).rssi)*100/1023;
					Radar.upsert(rk, ri);
				});


				secdevs[n].dev.td.state.notify["state"].connect((s,p) => {
					uint rk = (uint)(n+256);
					var ri = get_ri(rk);
					var sts = ((StateData)s).state;
					ri.state = (sts == 0) ? Radar.RadarView.Status.UNDEF : Radar.RadarView.Status.ARMED;
					Radar.upsert(rk, ri);
				});


				secdevs[n].dev.td.gps.notify["nsats"].connect((s,p) => {
						uint rk = (uint)(n+256);
						var ri = get_ri(rk);
						var nsats = ((GPSData)s).nsats;
						ri.posvalid = (nsats > 5);
						secdevs[n].ready |= Fields.SAT;
						ri.lasttick = Mwp.nticks;
						ri.dt = new DateTime.now_local();
						Radar.upsert(rk, ri);
						update_ri(ri, rk);
					});
			}

			secdevs[n].dev.serial_event.connect((s,cmd,raw,len,xflags,errs) => {
					if(cmd >= Msp.Cmds.LTM_BASE && cmd < Msp.Cmds.MAV_BASE) {
						Mwp.handle_ltm(s, cmd, raw, len);
					} else if (cmd >= Msp.Cmds.MAV_BASE && cmd < Msp.Cmds.MAV_BASE+256) {
						Mwp.handle_mavlink(s, cmd, raw, len);
					}
				});

			secdevs[n].dev.crsf_event.connect((raw) => {
					CRSF.ProcessCRSF(secdevs[n].dev, raw);
				});

			secdevs[n].dev.flysky_event.connect((raw) => {
					// Flysky.ProcessFlysky(secdevs[n].dev, raw);
				});

			secdevs[n].dev.sport_event.connect((id,val) => {
					Frsky.process_sport_message (secdevs[n].dev, (SportDev.FrID)id, val);
				});

			secdevs[n].dev.serial_lost.connect(() => {
					stop_reader(n);
				});

			if(! secdevs[n].dev.available) {
				pending(true);
				secdevs[n].dev.open_async.begin(secdevs[n].name, 0,  (obj,res) => {
						var ok = secdevs[n].dev.open_async.end(res);
						pending(false);
						if (ok) {
							secdevs[n].dev.setup_reader();
							MWPLog.message("start secondary reader %s\n", secdevs[n].name);
							if(Mwp.rawlog)
								secdevs[n].dev.raw_logging(true);
							secdevs[n].dev.set_pmask(secdevs[n].pmask);
							secdevs[n].dev.set_auto_mpm(secdevs[n].pmask == MWSerial.PMask.AUTO);
						} else {
							string fstr = null;
							secdevs[n].dev.get_error_message(out fstr);
							MWPLog.message("Secondary reader %s\n", fstr);
							secdevs[n].status = TelemTracker.Status.PRESENT;
							changed();
						}
					});
			}
		}

		public void update_ri(Radar.RadarPlot ri, uint rk)  {
			var n = (int)rk-256;
			Radar.update(rk, false);
			if (ri.posvalid && ((secdevs[n].ready & (Fields.LAT|Fields.LON|Fields.SAT)) !=0)) {
				secdevs[n].ready &= ~(Fields.SAT);
				Radar.update_marker(rk);
			}
		}

		public void stop_reader(int n) {
			if (secdevs[n].dev.available) {
				MWPLog.message("stopping secondary reader %s\n", secdevs[n].name);
				pending(true);
				secdevs[n].dev.close_async.begin((obj,res) => {
						secdevs[n].dev.close_async.end(res);
						secdevs[n].status = TelemTracker.Status.PRESENT;
						secdevs[n].dev = null;
						pending(false);
						changed();
					});
			}
		}

		private  unowned Radar.RadarPlot? get_ri(uint rk) {
			unowned Radar.RadarPlot? ri = Radar.radar_cache.lookup(rk);
			if (ri == null) {
				uint n = rk-256;
				var r0 = Radar.RadarPlot();
				r0.name = secdevs[n].alias;
				r0.source = Radar.RadarSource.TELEM;
				r0.posvalid = false;
				Radar.radar_cache.upsert(rk, r0);
				ri = Radar.radar_cache.lookup(rk);
			}
			ri.dt = new DateTime.now_local();
			return ri;
		}
	}

	public class  SecDevDialog : Gtk.Window {
		private Gtk.TreeView tview;
		private Gtk.ListStore sd_liststore;
		private Gtk.ListStore combo_model;
		private Gtk.Grid grid;

		public SecDevDialog() {
			this.title = "Telemetry Tracker";

			var radd = new Gtk.Button.from_icon_name("list-add");
			radd.clicked.connect(() => {
					ttrk.add(null);
				});
			var rdel = new Gtk.Button.from_icon_name("list-remove");
			rdel.clicked.connect(() => {
					Gtk.TreeIter iter;
					foreach (var t in list_selected_refs()) {
						var path = t.get_path ();
						sd_liststore.get_iter (out iter, path);
						/* FIXME Stop first */
						int idx = 0;
						sd_liststore.get (iter, Column.ID, &idx);
						if (ttrk.secdevs[idx].status == TelemTracker.Status.USED) {
							ttrk.stop_reader(idx);
						}
						ttrk.secdevs[idx].status = TelemTracker.Status.UNDEF;
						sd_liststore.remove(ref iter);
					}
				});

			create_view();
			Gtk.Box bbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
			radd.set_halign(Gtk.Align.START);
			rdel.set_halign(Gtk.Align.START);
			radd.set_tooltip_text("Append a row");
			rdel.set_tooltip_text("Delete selected row(s)");
			bbox.append(radd);
			bbox.append(rdel);
			grid.attach (bbox, 0, 1, 1, 1);
			this.set_child(grid);
			ttrk.changed.connect(() => {
					redraw();
				});
			ttrk.pending.connect((v) => {
					this.sensitive = !v;
				});
		}

		private void create_view() {
			grid = new Gtk.Grid ();
			grid.set_vexpand (true);
			sd_liststore = new Gtk.ListStore (Column.NO_COLS,
											  typeof (string),
											  typeof (string),
											  typeof (bool),
											  typeof (string),
											  typeof(int)
											  );

			tview = new Gtk.TreeView.with_model (sd_liststore);
			tview.get_selection().set_mode(Gtk.SelectionMode.MULTIPLE);

			tview.set_hexpand(true);
			tview.set_vexpand (true);
			tview.set_fixed_height_mode (true);
			//            tview.set_model (sd_liststore);
			var cell = new Gtk.CellRendererText ();
			tview.insert_column_with_attributes (-1, "Device", cell, "text", Column.NAME);
			cell.set_property ("editable", true);
			((Gtk.CellRendererText)cell).edited.connect((path,new_text) => {
					Gtk.TreeIter iter;
					int idx=0;
					sd_liststore.get_iter(out iter, new Gtk.TreePath.from_string(path));
					sd_liststore.get (iter, Column.ID, &idx);
					ttrk.secdevs[idx].name = new_text;
					sd_liststore.set (iter, Column.NAME,new_text);
				});

			cell = new Gtk.CellRendererText ();
			tview.insert_column_with_attributes (-1, "Alias", cell, "text", Column.ALIAS);
			cell.set_property ("editable", true);
			((Gtk.CellRendererText)cell).edited.connect((path,new_text) => {
					Gtk.TreeIter iter;
					int idx=0;
					sd_liststore.get_iter(out iter, new Gtk.TreePath.from_string(path));
					sd_liststore.get (iter, Column.ID, &idx);
					ttrk.secdevs[idx].alias = new_text;
					sd_liststore.set (iter, Column.ALIAS,new_text);
					ttrk.secdevs[idx].userdef = true;
				});

			var tcell = new Gtk.CellRendererToggle();
			tview.insert_column_with_attributes (-1, "Enable",
												 tcell, "active", Column.STATUS);
			tcell.toggled.connect((p) => {
					Gtk.TreeIter iter;
					int idx = 0;
					sd_liststore.get_iter(out iter, new Gtk.TreePath.from_string(p));
					sd_liststore.get (iter, Column.ID, &idx);
					ttrk.secdevs[idx].status = (ttrk.secdevs[idx].status == TelemTracker.Status.USED) ? TelemTracker.Status.PRESENT : TelemTracker.Status.USED;
					sd_liststore.set (iter, Column.STATUS, (ttrk.secdevs[idx].status == TelemTracker.Status.USED));
					if (ttrk.secdevs[idx].status == TelemTracker.Status.USED) {
						ttrk.start_reader(idx);
					} else {
						ttrk.stop_reader(idx);
					}
					//					tt.secdevs[idx].userdef = true;
				});

			Gtk.TreeIter iter;
			combo_model = new Gtk.ListStore (2, typeof (string), typeof(MWSerial.PMask));
			combo_model.append (out iter);
			combo_model.set (iter, 0, "Auto", 1, MWSerial.PMask.AUTO);
			combo_model.append (out iter);
			combo_model.set (iter, 0, "INAV", 1, MWSerial.PMask.INAV);
			combo_model.append (out iter);
			combo_model.set (iter, 0, "SPort", 1, MWSerial.PMask.SPORT);
			combo_model.append (out iter);
			combo_model.set (iter, 0, "CRSF", 1, MWSerial.PMask.CRSF);
			combo_model.append (out iter);
			combo_model.set (iter, 0, "MPM", 1, MWSerial.PMask.MPM);

			Gtk.CellRendererCombo combo = new Gtk.CellRendererCombo ();
			combo.set_property ("editable", true);
			combo.set_property ("model", combo_model);
			combo.set_property ("text-column", 0);
			combo.set_property ("has-entry", false);
			tview.insert_column_with_attributes (-1, "Hint", combo, "text", Column.PMASK);

			combo.changed.connect((path, iter_new) => {
					int idx=0;
					Gtk.TreeIter iter_val;
					sd_liststore.get_iter (out iter_val, new Gtk.TreePath.from_string (path));
					sd_liststore.get (iter_val, Column.ID, &idx);
					Value val;
					MWSerial.PMask pmask;
					combo_model.get_value (iter_new, 0, out val);
					string hint = (string)val;
					combo_model.get_value (iter_new, 1, out val);
					pmask = (MWSerial.PMask)val;
					sd_liststore.set (iter_val, Column.PMASK, hint);
					ttrk.secdevs[idx].pmask = pmask;
					ttrk.secdevs[idx].userdef = true;
				});

			int [] widths = {30, 40, 8, 10};
			for (int j = Column.NAME; j < Column.ID; j++) {
				var scol =  tview.get_column(j);
				if(scol!=null) {
					scol.set_min_width(7*widths[j]);
					scol.resizable = true;
					scol.set_sort_column_id(j);
				}
			}

			var n =populate_view();
			var scrolled = new Gtk.ScrolledWindow ();
			scrolled.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
			scrolled.min_content_height = (2+n)*30;
			//scrolled.min_content_width = 320;
			scrolled.set_child(tview);
			scrolled.propagate_natural_height = true;
			scrolled.propagate_natural_width = true;
			grid.attach (scrolled, 0, 0, 1, 1);
		}

		private List<Gtk.TreeRowReference> list_selected_refs() {
			List<Gtk.TreeRowReference> list = new List<Gtk.TreeRowReference> ();
			Gtk.TreeModel m;
			var sel = tview.get_selection();
			var rows = sel.get_selected_rows(out m);

			foreach (var r in rows) {
				var rr = new Gtk.TreeRowReference (m, r);
				list.append(rr);
			}
			return list;
		}

		private int populate_view() {
			Gtk.TreeIter iter;
			int n = 0;
			foreach(var s in ttrk.secdevs) {
				if (s.status != 0) {
					sd_liststore.append (out iter);
					sd_liststore.set (iter,
									  Column.STATUS, (s.status == TelemTracker.Status.USED),
									  Column.NAME, s.name,
									  Column.ALIAS, s.alias,
									  Column.PMASK, MWSerial.pmask_to_name(s.pmask),
									  Column.ID,n);
				}
				n++;
			}
			return n;
		}

		public void redraw() {
			sd_liststore.clear();
			populate_view();
		}

		public void run() {
			present();
		}
	}
}