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
			fs.printf("v0h0h0 %u\n", v0h0h0.position);											 			fs.printf("v0h0 %u\n", v0h0.position);
			fs.printf("v0h1 %u\n", v0h1.position);
			fs.printf("v1 %u\n", v1.position);
 			fs.printf("v1h0 %u\n", v1h0.position);
			fs.printf("v1h1 %u\n", v1h1.position);
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
			}
			return ok;
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
		// minimally populate unused cells so we can drag them
		private void  validate() {
			Gtk.Paned []panes = {v0h0h0, v0h0, v0h1, v1h0, v1h1};
			for(var j = 0; j < panes.length; j++) {
				if (panes[j].start_child == null) {
					var lbl = new Gtk.Label("");
					panes[j].start_child=lbl;
					panes[j].resize_start_child=true;
				}
				if (panes[j].end_child == null) {
					var lbl = new Gtk.Label("");
					panes[j].end_child=lbl;
					panes[j].resize_end_child=true;
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
