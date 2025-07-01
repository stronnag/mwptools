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

// Handle Secondary Devices

namespace TelemTracker {
	TelemTracker.Window ttrk;
	Gtk.StringList masksl;
	GLib.ListStore lstore;

	public enum Status {
		UNAVAIL = 0,	// used as main device
		AVAILABLE = 1,  // available for use
		ACTIVE  = 2,   // in active use
	}

	[Flags]
	public enum Fields {
		LAT,
		LON,
		SAT,
		ALT,
		RSSI,
		SPD,
		CSE,
		STS,
		ALL
	}

	public void init() {
		lstore = new GLib.ListStore(typeof(SecDev));
		masksl = new Gtk.StringList ({"Auto", "INAV", "S.Port", "CRSF", "MPM"});
		ttrk = new TelemTracker.Window();
	}

	public class SecDev : Object {
		public string name {get; construct set;}
		public string devalias {get; construct set;}
		public string alias {get; construct set;}
		public bool available {get; construct set;}
		public bool inuse {get; construct set;}
		public bool userdef {get; construct set;}
		public uint8 ready {get; construct set;}
		public uint8 pmask {get; construct set;}
		public uint id;
		public MWSerial dev;
		public SecDev() {}
	}

	public class Window {
		private const double RAD2DEG = 57.29578;
		public signal void pending(bool val);

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
			lstore.remove_all();
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
							add(line.chomp());
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
				var ni = lstore.get_n_items();
				for (var j = 0; j < ni; j++) {
					var sd = lstore.get_item(j) as SecDev;
					if (sd.name != "" ) {
						fp.write("%s,%s,%s\n".printf(sd.name, MWSerial.pmask_to_name(sd.pmask), sd.alias).data);
					}
				}
			}
		}

		public void show_dialog() {
			var sdlg = new SecDevDialog();
			sdlg.close_request.connect(() => {
					save_data();
					return false;
				});
			sdlg.present();
		}

		public void add(string? sname) {
			bool found = false;
			string devname = "";
			string devalias = "";
			string[] parts={};
			uint8 pmask = MWSerial.PMask.AUTO;
			SecDev s = null;
			uint id = 0;
			if (sname != null) {
				parts = sname.split(",", 3);
				var sparts = parts[0].split(" ",2);
				if (sparts.length > 0) {
					devname = sparts[0];
					if (sparts.length > 1) {
						devalias = sparts[1];
					}
				}
				if (parts.length > 1 ) {
					if (parts[1].strip().length > 0) {
						pmask = MWSerial.name_to_pmask(parts[1]);
					}
				}

				for(uint n = 0; n < lstore.get_n_items(); n++) {
					s = lstore.get_item(n) as SecDev;
					if (s.name == devname || s.name == devalias) {
						found = true;
						id = n;
						break;
					}
				}
			}

			if(!found) {
				id = lstore.get_n_items();
				s = new SecDev();
				s.name = devname;
				s.available = true;
				s.inuse = false;
				s.id = id;
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
				lstore.append(s);

				s.notify["inuse"].connect((_s, p) => {
						if (((SecDev)_s).inuse) {
							start_reader((SecDev)_s);
						} else if (((SecDev)_s).dev!= null && ((SecDev)_s).dev.available) {
							((SecDev)_s).dev.close_async.begin((obj,res) => {
									((SecDev)_s).dev.close_async.end(res);
								});
						}
					});

			}
			if(s != null && Mwp.msp != null) {
				if (s.name == Mwp.msp.get_devname()) {
					s.available = false;
				}
			}
		}

		public bool is_used(string sname) {
			var parts = sname.split(" ", 2);
			var ni = lstore.get_n_items();
			for(var j = 0; j < ni; j++) {
				var s = lstore.get_item(j) as SecDev;
				if (s.name == parts[0] && s.inuse) {
					return true;
				}
			}
			return false;
		}

		public void remove(string sname) {
			var parts = sname.split(" ", 2);
			var ni = lstore.get_n_items();
			for(var j = 0; j < ni; j++) {
				var s = lstore.get_item(j) as SecDev;
				if (s.name == parts[0]) {
					s.available = false;
					s.inuse = false;
					break;
				}
			}
		}

		public void enable(string sname) {
			var parts = sname.split(" ", 2);
			var ni = lstore.get_n_items();
			for(var j = 0; j < ni; j++) {
				var s = lstore.get_item(j) as SecDev;
				if (s.name == parts[0]) {
					s.available = true;
					break;
				}
			}
		}

		public void disable(string sname) {
			remove(sname);
		}

		public void update (MWSerial mws, TelemTracker.Fields what) {
			var ni = lstore.get_n_items();
			SecDev sd = null;
			for(var j = 0; j < ni; j++) {
				var s = lstore.get_item(j) as SecDev;
				if(s.dev == mws) {
					sd = s;
					break;
				}
			}
			if (sd != null) {
				uint rk = (uint)(sd.id+256);
				var ri = get_ri(rk);

				if(Fields.LAT in what) {
					ri.latitude = sd.dev.td.gps.lat;
					Radar.upsert(rk, ri);
					sd.ready |= Fields.LAT;
				}

				if(Fields.LON in what) {
					ri.longitude = sd.dev.td.gps.lon;
					Radar.upsert(rk, ri);
					sd.ready |= Fields.LON;
					ri.lasttick = Mwp.nticks;
					ri.dt = new DateTime.now_local();
					update_ri(ri, sd);
				}

				if(Fields.SPD in what) {
					ri.speed = sd.dev.td.gps.gspeed;
					Radar.upsert(rk, ri);
				}

				if(Fields.CSE in what) {
					ri.heading = (uint16)(sd.dev.td.gps.cog);
					Radar.upsert(rk, ri);
				}

				if(Fields.ALT in what) {
					ri.altitude = sd.dev.td.alt.alt;
					Radar.upsert(rk, ri);
				}

				if(Fields.SAT in what) {
					var nsats = sd.dev.td.gps.nsats;
					ri.posvalid = (nsats > 5);
					sd.ready |= Fields.SAT;
					Radar.upsert(rk, ri);
				}

				if(Fields.STS in what) {
					var sts = sd.dev.td.state.state;
					ri.state = (sts == 0) ? Radar.Status.UNDEF : Radar.Status.ARMED;
					Radar.upsert(rk, ri);
				}

				if(Fields.RSSI in what) {
					var rssi = sd.dev.td.rssi.rssi;
					ri.lq = (uint8)(rssi*100/1023);
					Radar.upsert(rk, ri);
				}
			}
		}

		public void start_reader(SecDev sd) {
			if (sd.dev == null) {
				sd.dev = new MWSerial();
				sd.ready = 0;
			}

			sd.dev.serial_event.connect(() => {
					MWSerial.INAVEvent? m;
					while((m = sd.dev.msgq.try_pop()) != null) {
						if(m.cmd >= Msp.LTM_BASE && m.cmd < Msp.MAV_BASE) {
							Mwp.handle_ltm(sd.dev, m.cmd, m.raw, m.len);
						} else if (m.cmd >= Msp.MAV_BASE && m.cmd < Msp.MAV_BASE+65535) {
							Mwp.handle_mavlink(sd.dev, m.cmd, m.raw, m.len);
						}
					}
				});

			sd.dev.crsf_event.connect(() => {
					MWSerial.INAVEvent? m;
					while((m = sd.dev.msgq.try_pop()) != null) {
						CRSF.ProcessCRSF(sd.dev, m.raw);
					}
				});

			sd.dev.flysky_event.connect(() => {
					MWSerial.INAVEvent? m;
					while((m = sd.dev.msgq.try_pop()) != null) {
						Flysky.ProcessFlysky(sd.dev, m.raw);
					}
				});

			sd.dev.sport_event.connect(() => {
					MWSerial.INAVEvent? m;
					while((m = sd.dev.msgq.try_pop()) != null) {
						Frsky.process_sport_message (sd.dev, m.raw);
					}
				});

			sd.dev.serial_lost.connect(() => {
					stop_reader(sd);
				});

			if(! sd.dev.available) {
				pending(true);
				sd.dev.open_async.begin(sd.name, 0,  (obj,res) => {
						var ok = sd.dev.open_async.end(res);
						pending(false);
						if (ok) {
							sd.dev.setup_reader();
							MWPLog.message("started secondary reader %s\n", sd.name);
							if(Mwp.rawlog)
								sd.dev.raw_logging(true);
							sd.dev.set_pmask(sd.pmask);
							sd.dev.set_auto_mpm(sd.pmask == MWSerial.PMask.AUTO);
						} else {
							string fstr = null;
							sd.dev.get_error_message(out fstr);
							MWPLog.message("Secondary reader %s\n", fstr);
							sd.inuse = false;
						}
					});
			}
		}

		public void update_ri(Radar.RadarPlot ri, SecDev s)  {
			uint rk = (uint)(s.id+256);
			Radar.update(rk, false);
			if (ri.posvalid && ((s.ready & (Fields.LAT|Fields.LON|Fields.SAT)) !=0)) {
				s.ready &= ~(Fields.LON);
				Radar.update_marker(rk);
			}
		}

		public void stop_reader(SecDev s) {
			MWPLog.message("stopped secondary reader %s\n", s.name);
			pending(true);
			s.inuse = false;
			s.available = true;
			s.dev = null;
			pending(false);
		}

		private Radar.RadarPlot? get_ri(uint rk) {
			Radar.RadarPlot? ri = Radar.radar_cache.lookup(rk);
			if (ri == null) {
				uint n = rk-256;
				var r0 = new Radar.RadarPlot();
				var s = lstore.get_item(n) as SecDev;
				r0.name = s.alias;
				r0.source = Radar.RadarSource.TELEM;
				r0.posvalid = false;
				Radar.radar_cache.upsert(rk, r0);
				ri = Radar.radar_cache.lookup(rk);
			}
			ri.dt = new DateTime.now_local();
			return ri;
		}
	}

	public class SecItemWindow : Adw.Window {
		internal Gtk.Entry dn;
		internal Gtk.Entry an;
		private Gtk.Button ok;
		public static bool apply;
		public SecItemWindow(SecDev s) {
			title = "Tracked Device";
			apply = false;
			var g = new Gtk.Grid();
			dn = new Gtk.Entry();
			dn.placeholder_text = "Device Name";
			if (s.name != null) {
				dn.text = s.name;
			}
			an = new Gtk.Entry();
			an.placeholder_text = "Device Alias";
			if (s.alias != null) {
				an.text = s.alias;
			}
			ok = new Gtk.Button.with_label("Apply");

			g.attach (new Gtk.Label("Name"), 0, 0);
			g.attach (dn, 1, 0);
			g.attach (new Gtk.Label("Alias"), 0, 1);
			g.attach (an, 1, 1);

			var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
			var tbox = new Adw.ToolbarView();
			var headerBar = new Adw.HeaderBar();
			tbox.add_top_bar(headerBar);

			box.append(g);

			var bbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL,2);
			ok.hexpand = false;
			ok.halign = Gtk.Align.END;

			bbox.halign = Gtk.Align.END;
			bbox.hexpand = true;
			bbox.append(ok);
			bbox.add_css_class("toolbar");
			tbox.add_bottom_bar(bbox);

			tbox.set_content(box);
			set_content(tbox);
			ok.clicked.connect(() => {
					apply = true;
					close();
				});
		}
	}

	public class  SecDevDialog : Adw.Window {
		Gtk.ColumnView cv;
		Gtk.MultiSelection lsel;

		public SecDevDialog() {
			transient_for = Mwp.window;
			this.title = "Telemetry Tracker";
			var radd = new Gtk.Button.from_icon_name("list-add-symbolic");
			radd.clicked.connect(() => {
					var sd = new SecDev();
					var w = new  SecItemWindow(sd);
					w.transient_for = this;
					w.close_request.connect(() => {
							if ( SecItemWindow.apply) {
								sd.name = w.dn.text;
								sd.alias = w.an.text;
								sd.pmask = 0xff;
								sd.userdef = true;
								sd.available = true;
								sd.id = lstore.get_n_items();
								lstore.append(sd);
							}
							return false;
						});
					w.present();
				});
			var rdel = new Gtk.Button.from_icon_name("list-remove-symbolic");
			rdel.clicked.connect(() => {
					var np = lsel.get_n_items();
					var bs = lsel.get_selection_in_range (0, np);
					if(!bs.is_empty()) {
						for(var i = bs.get_minimum(); i <= bs.get_maximum(); i++) {
							if (bs.contains(i)) {
								lstore.remove(i);
							}
						}
					}
				});

			var cv = create_view();

			var scrolled = new Gtk.ScrolledWindow ();
			scrolled.propagate_natural_height = true;
			scrolled.propagate_natural_width = true;
			scrolled.set_child(cv);

			Gtk.Box bbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
			radd.set_halign(Gtk.Align.END);
			rdel.set_halign(Gtk.Align.END);
			radd.set_tooltip_text("Append a row");
			rdel.set_tooltip_text("Delete selected row(s)");
			bbox.append(radd);
			bbox.append(rdel);
			bbox.halign=Gtk.Align.END;

			var headerBar = new Adw.HeaderBar();
			var tbox = new Adw.ToolbarView();
			tbox.add_top_bar(headerBar);
			bbox.add_css_class("toolbar");
			tbox.add_bottom_bar(bbox);

			tbox.set_content(scrolled);
			set_content(tbox);
			ttrk.pending.connect((v) => {
					this.sensitive = !v;
				});
		}

		private Gtk.ColumnView create_view() {
			cv = new Gtk.ColumnView(null);
			var sm = new Gtk.SortListModel(lstore, cv.sorter);
			lsel = new Gtk.MultiSelection(sm);
			cv.set_model(lsel);
			cv.show_column_separators = true;
			cv.show_row_separators = true;

			var f0 = new Gtk.SignalListItemFactory();
			var c0 = new Gtk.ColumnViewColumn("Device", f0);
			c0.expand = true;
			cv.append_column(c0);
			f0.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					label.valign = Gtk.Align.START;
                                        label.xalign = 0;
					list_item.set_child(label);
				});
			f0.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					SecDev sd = list_item.get_item() as SecDev;
					var label = list_item.get_child() as Gtk.Label;
					label.set_text(sd.name);
					sd.bind_property("name", label, "label", BindingFlags.SYNC_CREATE);
				});

			var f1 = new Gtk.SignalListItemFactory();
			var c1 = new Gtk.ColumnViewColumn("Alias", f1);
			c1.expand = true;
			cv.append_column(c1);
			f1.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var label=new Gtk.Label("");
					label.valign = Gtk.Align.START;
					label.xalign = 0;
					list_item.set_child(label);
				});
			f1.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					SecDev sd = list_item.get_item() as SecDev;
					var label = list_item.get_child() as Gtk.Label;
					label.set_text(sd.alias);
					sd.bind_property("alias", label, "label", BindingFlags.SYNC_CREATE);
				});

			var f2 = new Gtk.SignalListItemFactory();
			var c2 = new Gtk.ColumnViewColumn("Enabled", f2);
			c2.expand = true;
			cv.append_column(c2);
			f2.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var cbtn = new Gtk.CheckButton();
					cbtn.valign = Gtk.Align.START;
					cbtn.vexpand = false;
					list_item.set_child(cbtn);
				});
			f2.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					var cbtn = list_item.get_child() as Gtk.CheckButton;
					SecDev sd = list_item.get_item() as SecDev;
					sd.bind_property("inuse", cbtn, "active", BindingFlags.SYNC_CREATE|BindingFlags.BIDIRECTIONAL);
					cbtn.sensitive = sd.available;
					sd.notify["available"].connect((s,p) => {
							cbtn.sensitive = ((SecDev)s).available;
						});
				});

			var f3 = new Gtk.SignalListItemFactory();
			var c3 = new Gtk.ColumnViewColumn("Mask", f3);
			c3.expand = true;
			cv.append_column(c3);
			f3.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var dd = new Gtk.DropDown(masksl, null);
					dd.valign = Gtk.Align.START;
					dd.vexpand = false;
					dd.notify["selected"].connect(() => {
							SecDev sd = list_item.get_item() as SecDev;
							var i =  dd.get_selected();
							var c = ((Gtk.StringList)dd.model).get_string(i);
							sd.pmask = MWSerial.name_to_pmask(c);
						});
					list_item.set_child(dd);
				});
			f3.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					SecDev sd = list_item.get_item() as SecDev;
					var dd = list_item.get_child() as Gtk.DropDown;
					dd.sensitive = sd.available;
					sd.notify["available"].connect((s,p) => {
							dd.sensitive = ((SecDev)s).available;
						});
					var n = MWSerial.pmask_to_index(sd.pmask);
					dd.selected = n;
				});

			var f4 = new Gtk.SignalListItemFactory();
			var c4 = new Gtk.ColumnViewColumn("", f4);
			cv.append_column(c4);

			f4.setup.connect((f,o) => {
					Gtk.ListItem list_item = (Gtk.ListItem)o;
					var btn = new Gtk.Button.from_icon_name("document-edit-symbolic");
					btn.valign = Gtk.Align.START;
					btn.vexpand = false;
					list_item.set_child(btn);
					btn.clicked.connect(() => {
							var sd = list_item.get_item() as SecDev;
							var w = new  SecItemWindow(sd);
							w.transient_for = this;
							w.close_request.connect(() => {
									if ( SecItemWindow.apply) {
										sd.name = w.dn.text;
										sd.alias = w.an.text;
									}
									return false;
								});
							w.present();
						});
				});


			f4.bind.connect((f,o) => {
					Gtk.ListItem list_item =  (Gtk.ListItem)o;
					var sd = list_item.get_item() as SecDev;
					var w = list_item.get_child();
					w.sensitive = sd.available;
					sd.notify["available"].connect((s,p) => {
							w.sensitive = ((SecDev)s).available;
						});
				});

			var t0sorter = new Gtk.CustomSorter((a,b) => {
					return strcmp(((SecDev)a).name,((SecDev)b).name);
				});
			var t1sorter = new Gtk.CustomSorter((a,b) => {
					return strcmp(((SecDev)a).alias,((SecDev)b).alias);
				});

			c0.set_sorter(t0sorter);
			c1.set_sorter(t1sorter);
			return cv;
		}
	}
}
