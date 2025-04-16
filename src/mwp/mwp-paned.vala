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

namespace Panel {
	[Flags]
	public enum View {
		VISIBLE,
		DIRN,
		FVIEW,
		AHI,
		RSSI,
		VOLTS,
		VARIO,
		WIND,
	}

	View status;

	private struct WidgetMap {
		string aname;
		string wname;
	}
	private WidgetMap []wmap;

	Direction.View dirnv;
	FlightBox.View fboxv;
	AHI.View ahiv;
	RSSI.View rssiv;
	Voltage.View powerv;
	Vario.View vario;
	WindEstimate.View wind;

	public class Box: Gtk.Frame {
		private Gtk.Paned v;    // master paned
		private Gtk.Paned v0;    // Vertical split paned
		private Gtk.Paned v1;    // Vertical split paned
		private Gtk.Paned v0h0;
		private Gtk.Paned v0h1;
		private Gtk.Paned v0h0h0;
		private Gtk.Paned v1h0;
		private Gtk.Paned v1h1;

		Gtk.Widget popwidget;
		private Gtk.Paned []upanes;
		private GLib.SimpleActionGroup dg;
        private Gtk.PopoverMenu pop;

		public Box() {
			v = new Gtk.Paned(Gtk.Orientation.VERTICAL);
			// first panel
			v0 = new Gtk.Paned(Gtk.Orientation.VERTICAL);
			v0h0 = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
			v0h1 = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
			v0.start_child = v0h0;
			v0.end_child = v0h1;
			v0.resize_start_child = true;
			v0.resize_end_child = true;
			v0h0h0 = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
			v0h0.start_child = v0h0h0;
			v0h0.resize_start_child = true;
			v0h0.resize_end_child = true;
			v0h0.position = 220;

			// client slots
			// v0h0h0.start_client
			// v0h0h0.end_client
			// v0h0.end_client
			//
			// v0h1.start_clint
			// v0h1.end_client
			v1 = new Gtk.Paned(Gtk.Orientation.VERTICAL);
			v1h0 = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
			v1h1 = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);

			v1.start_child = v1h0;
			v1.end_child = v1h1;
			v1.resize_start_child = true;
			v1.resize_end_child = true;

			// client slots
			// v1h0.start_client
			// v1h0.end_client
			//
			// v1h1.start_clint
			// v1h1.end_client
			v.start_child = v0;
			v.end_child = v1;
			v.resize_start_child = true;
			v.resize_end_child = true;
			build_mm();
			upanes = {v0h0h0, v0h0, v0h1, v1h0, v1h1};
			wmap = {
				{"ahi", "AHIView"},
				{"dirn", "DirectionView"},
				{"flight", "FlightBoxView"},
				{"rssi", "RSSIView"},
				{"vario", "VarioView"},
				{"volts",  "VoltageView"},
				{"wind", "WindEstimateView"},
			};
			this.set_child(v);
			init();
			Mwp.window.close_request.connect(() => {
					save_geometry();
					return false;
				});

		}

		private void set_pane(string id, int pos) {
			switch (id) {
			case "v":
				v.position = pos;
				break;
			case "v0":
				v0.position = pos;
				break;
			case "v1":
				v1.position = pos;
				break;
			case "v0h0":
				v0h0.position = pos;
				break;
			case "v0h1":
				v0h1.position = pos;
				break;
			case "v0h0h0":
				v0h0h0.position = pos;
				break;
			case "v1h0":
				v1h0.position = pos;
				break;
			case "v1h1":
				v1h1.position = pos;
				break;
			default:
				break;
			}
		}

		private bool insert(Gtk.Widget w, int row, int col) {
			bool ok = true;
			switch(row) {
			case 0:
				v0.resize_start_child = true;
				switch (col) {
				case 0:
					v0h0h0.start_child = w;
					v0h0h0.resize_start_child = true;
					v0h0.resize_start_child = true;
					v0h0.resize_end_child = true;
					break;
				case 1:
					v0h0h0.end_child = w;
					v0h0h0.resize_end_child = true;
					v0h0.resize_start_child = true;
					v0h0.resize_end_child = true;
					break;
				case 2:
					v0h0.end_child = w;
					v0h0.resize_end_child = true;
					v0h0.resize_start_child = true;
					break;
				default:
					print("**** Invalid row 0 column %d\n", col);
					ok = false;
					break;
				}
				break;
			case 1:
				v0.resize_end_child = true;
				switch (col) {
				case 0:
					v0h1.start_child = w;
					v0h1.resize_start_child = true;
					break;
				case 1:
					v0h1.end_child = w;
					v0h1.resize_end_child = true;
					break;
				default:
					print("**** Invalid row 1 column %d\n", col);
					break;
				}
				break;
			case 2:
				v1.resize_start_child = true;
				switch (col) {
				case 0:
					v1h0.start_child = w;
					v1h0.resize_start_child = true;
					break;
				case 1:
					v1h0.end_child = w;
					v1h0.resize_end_child = true;
					break;
				default:
					print("**** Invalid row 2 column %d\n", col);
					break;
				}
				break;
			case 3:
				v1.resize_end_child = true;
				switch (col) {
				case 0:
					v1h1.start_child = w;
					v1h1.resize_start_child = true;
					break;
				case 1:
					v1h1.end_child = w;
					v1h1.resize_end_child = true;
					break;
				default:
					print("**** Invalid row 3 column %d\n", col);
					break;
				}
				break;
			default:
				print("**** Invalid row %d\n", row);
				break;
			}
			if(ok) {
				w.hexpand = true;
				w.vexpand = true;
				w.halign = Gtk.Align.FILL;
			}
			return ok;
		}

		public void update(Panel.View s, int stuff=0) {
			switch (s) {
			case Panel.View.AHI:
				if (ahiv != null) {
					ahiv.update(stuff);
				}
				break;
			case Panel.View.RSSI:
				if (rssiv != null) {
					rssiv.update(stuff);
				}
				break;
			case Panel.View.DIRN:
				if (dirnv != null) {
					dirnv.update(stuff);
				}
				break;
			case Panel.View.FVIEW:
				if(fboxv != null) {
					fboxv.update(stuff);
				}
				break;
			case Panel.View.VOLTS:
				if (powerv != null) {
					powerv.update(stuff);
				}
				break;
			case Panel.View.VARIO:
				if(vario != null) {
					vario.update(stuff);
				}
				break;
			case Panel.View.WIND:
				if(wind != null) {
					wind.update(stuff);
				}
				break;
			default:
				break;
			}
		}

		private void load_widget(string name, int row, int col, int sz=-1) {
			Gtk.Widget? w = null;
			switch (name) {
			case "ahi":
				ahiv = new AHI.View();
				w = ahiv;
				Panel.status |= Panel.View.AHI;
				break;
			case "rssi":
				rssiv = new RSSI.View();
				w = rssiv;
				Panel.status |= Panel.View.RSSI;
				break;
			case "dirn":
				dirnv = new Direction.View();
				w = dirnv;
				Panel.status |= Panel.View.DIRN;
				break;
			case "flight":
				fboxv = new FlightBox.View();
				w = fboxv;
				Panel.status |= Panel.View.FVIEW;
				break;
			case "volts":
				powerv = new Voltage.View();
				w = powerv;
				Panel.status |= Panel.View.VOLTS;
				break;
			case "vario":
				vario = new Vario.View();
				vario.update(0);
				w = vario;
				Panel.status |= Panel.View.VARIO;
				break;
			case "wind":
				wind= new WindEstimate.View();
				wind.update(0);
				w = wind;
				Panel.status |= Panel.View.WIND;
				break;
			}
			if(w != null) {
				add_event_controller(w, true);
				this.insert(w, row, col);
				if(sz != -1) {
					w.height_request = sz;
					w.width_request = sz;
				}
			}
		}

		private  void save_geometry() {
			var uc =  Environment.get_user_config_dir();
			var fn = GLib.Path.build_filename(uc,"mwp",".paned");
			FileStream fs = FileStream.open (fn, "w");
			fs.printf("v %u\n", v.position);
			fs.printf("v0 %u\n", v0.position);
			fs.printf("v0h0 %u\n", v0h0.position);
			fs.printf("v0h0h0 %u\n", v0h0h0.position);
			fs.printf("v0h0 %u\n", v0h0.position);
			fs.printf("v0h1 %u\n", v0h1.position);
			fs.printf("v1 %u\n", v1.position);
 			fs.printf("v1h0 %u\n", v1h0.position);
			fs.printf("v1h1 %u\n", v1h1.position);
		}

		private string? from_widget(string wname) {
			foreach(var w in wmap) {
				if(wname == w.wname)
					return w.aname;
			}
			return null;
		}

		private string? check_widget(Gtk.Widget ws, int r, int c) {
			if(ws.name != "GtkLabel") {
				string aname;
				aname = from_widget(ws.name);
				if(aname != null) {
					StringBuilder sb = new StringBuilder();
					sb.append_printf("%s, %d, %d", aname, r, c);
					if (aname == "ahi") {
						//var w = ahiv.get_width();
						//var h = ahiv.get_height();
						sb.append_printf(", %d", /*int.min(w,h)*/ 100);
					}
					sb.append_c('\n');
					return sb.str;
				}
			}
			return null;
		}

		public void write_panel_conf() {
			var cfile = find_panel_conf();
			var fp = FileStream.open (cfile, "w");
			string s;
			if (fp != null) {
				fp.write("# mwp panel.conf\n".data);
				s = check_widget(v0h0h0.start_child, 0, 0);
				if (s != null) {
					fp.write(s.data);
				}
				s = check_widget(v0h0h0.end_child, 0, 1);
				if (s != null) {
					fp.write(s.data);
				}
				s = check_widget(v0h0.end_child, 0, 2);
				if (s != null) {
					fp.write(s.data);
				}

				s = check_widget(v0h1.start_child, 1, 0);
				if (s != null) {
					fp.write(s.data);
				}
				s =check_widget(v0h1.end_child, 1, 1);
				if (s != null) {
					fp.write(s.data);
				}

				s = check_widget(v1h0.start_child, 2, 0);
				if (s != null) {
					fp.write(s.data);
				}
				s = check_widget(v1h0.end_child, 2, 1);
				if (s != null) {
					fp.write(s.data);
				}

				s = check_widget(v1h1.start_child, 3, 0);
				if (s != null) {
					fp.write(s.data);
				}
				s = check_widget(v1h1.end_child, 3, 1);
				if (s != null) {
					fp.write(s.data);
				}
			}
		}

	   private bool read_panel_config() {
			bool ok = false;
			var fn = MWPUtils.find_conf_file("panel.conf");
			if (fn != null) {
				var fs = FileStream.open (fn, "r");
				if (fs != null) {
					ok = true;
					string s;
					while((s = fs.read_line()) != null) {
						if (s.has_prefix("#")) {
							continue;
						}
						var parts = s.split(",");
						if (parts.length > 2) {
							var row = int.parse(parts[1]);
							var col = int.parse(parts[2]);
							int sz = -1;
							if (parts.length > 3) {
								sz = int.parse(parts[3]);
							}
							load_widget(parts[0], row, col, sz);
						}
					}
				}
			}
			if(!ok) {
				MWPLog.message("Panel: using default widgets\n");
				load_widget("ahi",0,1,100);
				load_widget("rssi", 1, 0);
				load_widget("dirn", 1, 1);
				load_widget("flight", 2, 0);
				load_widget("volts", 3, 0);
				var cfile = find_panel_conf();
				var fp = FileStream.open (cfile, "w");
				if (fp != null) {
					fp.write("# default widgets\nahi,0,1,100\nrssi, 1, 0\ndirn, 1, 1\nflight, 2, 0\nvolts, 3, 0\n".data);
				}
			}
			return ok;
		}

	   private string find_panel_conf() {
		   var uc =  Environment.get_user_config_dir();
		   return GLib.Path.build_filename(uc,"mwp","panel.conf");
	   }

		private void build_mm() {
			var xml = """
				<?xml version="1.0" encoding="UTF-8"?>
				<interface>
				<menu id="panel-menu">
				<section>
				<item>
				<attribute name="label">AHI</attribute>
				<attribute name="action">paned.ahi</attribute>
				</item>
				<item>
				<attribute name="label">Direction</attribute>
				<attribute name="action">paned.dirn</attribute>
				</item>
				<item>
				<attribute name="label">FlghtView</attribute>
				<attribute name="action">paned.flight</attribute>
				</item>
				<item>
				<attribute name="label">RSSI</attribute>
				<attribute name="action">paned.rssi</attribute>
				</item>
				<item>
				<attribute name="label">Vario</attribute>
				<attribute name="action">paned.vario</attribute>
				</item>
				<item>
				<attribute name="label">Voltage</attribute>
				<attribute name="action">paned.volts</attribute>
				</item>
				<item>
				<attribute name="label">WindSpeed</attribute>
				<attribute name="action">paned.wind</attribute>
				</item>
				<item>
				<attribute name="label">Remove Item</attribute>
				<attribute name="action">paned.remove</attribute>
				</item>
				</section>
				</menu>
				</interface>
				""";
				dg = new GLib.SimpleActionGroup();
			var sbuilder = new Gtk.Builder.from_string(xml, -1);
			var menu = sbuilder.get_object("panel-menu") as GLib.MenuModel;
			pop = new Gtk.PopoverMenu.from_model(menu);

			var aq = new GLib.SimpleAction("ahi",null);
			aq.activate.connect(() => {
					if(ahiv == null) {
						ahiv = new AHI.View();
						add_event_controller(ahiv, true);
						Panel.status |= Panel.View.AHI;
					}
					replace(popwidget, ahiv);
				});
			dg.add_action(aq);

			aq = new GLib.SimpleAction("dirn",null);
			aq.activate.connect(() => {
					if(dirnv == null) {
						dirnv = new Direction.View();
						add_event_controller(dirnv, true);
						Panel.status |= Panel.View.DIRN;
					}
					replace(popwidget, dirnv);
				});
			dg.add_action(aq);

			aq = new GLib.SimpleAction("flight",null);
			aq.activate.connect(() => {
					if(fboxv == null) {
						fboxv = new FlightBox.View();
						add_event_controller(fboxv, true);
						Panel.status |= Panel.View.FVIEW;
					}
					replace(popwidget, fboxv);
				});
			dg.add_action(aq);

			aq = new GLib.SimpleAction("rssi",null);
			aq.activate.connect(() => {
					if(rssiv == null) {
						rssiv = new RSSI.View();
						add_event_controller(rssiv, true);
						Panel.status |= Panel.View.RSSI;
					}
					replace(popwidget, rssiv);
				});
			dg.add_action(aq);

			aq = new GLib.SimpleAction("volts",null);
			aq.activate.connect(() => {
					if(powerv == null) {
						powerv = new Voltage.View();
						add_event_controller(powerv, true);
						Panel.status |= Panel.View.VOLTS;
					}
					replace(popwidget, powerv);
				});
			dg.add_action(aq);

			aq = new GLib.SimpleAction("wind", null);
			aq.activate.connect(() => {
					if(wind == null) {
						wind = new WindEstimate.View();
						add_event_controller(wind, true);
						Panel.status |= Panel.View.WIND;
					}
					replace(popwidget, wind);
				});
			dg.add_action(aq);

			aq = new GLib.SimpleAction("vario",null);
			aq.activate.connect(() => {
					if(vario == null) {
						vario= new Vario.View();
						Panel.status |= Panel.View.VARIO;
						add_event_controller(vario, true);
					}
					replace(popwidget, vario);
				});
			dg.add_action(aq);

			aq = new GLib.SimpleAction("remove",null);
			aq.activate.connect(() => {
					var lbl =  new Gtk.Label("");
					replace(popwidget, lbl);
					add_event_controller(lbl, false);
				});
			dg.add_action(aq);
			pop.set_parent(v);
			this.insert_action_group("paned", dg);
		}

		private void add_event_controller(Gtk.Widget w, bool act) {
			var gestc = new Gtk.GestureClick();
			w.add_controller(gestc);
			gestc.set_button(0);
			gestc.pressed.connect((n,x,y) => {
					var bn = gestc.get_current_button();
					if(bn == 3) {
						popup_menu(w,x, y, act);
					}
				});
		}

		private bool acontains(string[]arry, string name) {
			foreach(var a in arry) {
				if (a == name) {
					return true;
				}
			}
			return false;
		}

		private void popup_menu(Gtk.Widget w, double x, double y, bool remitem) {
			var names = unames();
			if(remitem) {
				MwpMenu.set_menu_state(dg, "remove", true);
				foreach (var wm in wmap) {
					MwpMenu.set_menu_state(dg, wm.aname, false);
				}
			} else {
				MwpMenu.set_menu_state(dg, "remove", false);
				foreach (var wm in wmap) {
					bool state = !acontains(names, wm.wname);
					MwpMenu.set_menu_state(dg, wm.aname, state);
				}
			}
			int ix,iy;
			cpos(w, out ix, out iy);
			Gdk.Rectangle rect = { (int)x-ix, (int)y-iy, 1, 1};
			pop.set_pointing_to(rect);
			popwidget = w;
			pop.popup();
		}

		private string []unames () {
			string[] arry={};
			for(var j = 0; j < upanes.length; j++) {
				var w = upanes[j].start_child;
				arry += w.name;
				w = upanes[j].end_child;
				arry += w.name;
			}
			return arry;
		}

		private void replace (Gtk.Widget old, Gtk.Widget _new) {
			uint8 save = 0;
			int j = 0;
			for(j = 0; j < upanes.length; j++) {
				var w = upanes[j].start_child;
				if (w == old) {
					upanes[j].start_child = _new;
					save = 1;
					break;
				}
				w = upanes[j].end_child;
				if (w == old) {
					upanes[j].end_child = _new;
					save = 2;
					break;
				}
			}
			if (save != 0) {
				write_panel_conf();
				Timeout.add(20, () => {
						var ww = _new.get_width();
						if(ww > 0) {
							var pp = upanes[j].position;
							Graphene.Rect rect = {};
							upanes[j].compute_bounds(_new, out rect);
							var tw = (int)rect.get_width();
							if(save == 1) {
								if(ww > pp && ww < tw) {
									upanes[j].position = ww;
								}
							} else {
								int fw = tw-pp;
								if(ww > fw) {
									int np = tw-ww;
									if (np > 0) {
										upanes[j].position = np;
									}
								}
							}
							return false;
						}
						return true;
					});
			}
		}

		private void cpos(Gtk.Widget wx, out int xp, out int yp) {
			xp = -1;
			yp = -1;
			Graphene.Rect rect = {};
			for(var j = 0; j < upanes.length; j++) {
				var w = upanes[j].start_child;
				if (w == wx) {
					child.compute_bounds(w, out rect);
					xp = (int)rect.get_x();
					yp = (int)rect.get_y();
					break;
				}
				w = upanes[j].end_child;
				if (w == wx) {
					child.compute_bounds(w, out rect);
					xp = (int)rect.get_x();
					yp = (int)rect.get_y();
					break;
				}
			}
		}

	   private bool read_paned_config() {
			bool ok = false;
			var fn = MWPUtils.find_conf_file(".paned");
			if (fn != null) {
				FileStream fs = FileStream.open (fn, "r");
				if (fs != null) {
					ok = true;
					string s;
					while((s = fs.read_line()) != null) {
						var parts = s.split(" ");
						if (parts.length == 2) {
							var sz = int.parse(parts[1]);
							set_pane(parts[0], sz);
						}
					}
				}
			}
			if(!ok) {
				MWPLog.message("Panel: using default pane configuration\n");
				set_pane("v", 322);
				set_pane("v0", 161);
				set_pane("v0h1", 161);
				set_pane("v1", 176);
			}
			return ok;
		}

		private void  validate() {
			for(var j = 0; j < upanes.length; j++) {
				if (upanes[j].start_child == null) {
					var lbl = new Gtk.Label("");
					upanes[j].start_child=lbl;
					upanes[j].resize_start_child=true;
					add_event_controller(lbl, false);
				}
				if (upanes[j].end_child == null) {
					var lbl = new Gtk.Label("");
					upanes[j].end_child=lbl;
					upanes[j].resize_end_child=true;
					add_event_controller(lbl, false);
				}
			}
		}

		public void init() {
			Panel.status = Panel.View.VISIBLE;
			read_panel_config();
			read_paned_config();
			validate();
		}
	}
}
