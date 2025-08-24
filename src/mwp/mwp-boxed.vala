
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

	[Flags]
	public enum Modes {
		V,
		H
	}

	public struct WidgetMap {
		string name;
		int row;
		int col;
		int width;
		int height;
		int span;
		Modes mode;
	}
	private WidgetMap []wmap;

/*
	public struct NameMap {
		string sname;
		string pname;
	}
	private NameMap []nmap;
	*/

	Direction.View dirnv;
	FlightBox.View fboxv;
	AHI.View ahiv;
	RSSI.View rssiv;
	Voltage.View powerv;
	Vario.View vario;
	WindEstimate.View wind;

	Gtk.Widget? []wlist;

	public class Box: Gtk.Frame {
		Gtk.Grid grid;
		bool is_vertical;

		public Box() {
			grid = new Gtk.Grid();
			this.set_child(grid);
			init();
		}

		public void init() {
			Panel.status = Panel.View.VISIBLE;
			if (!read_panel_config()) {
				wmap = {
					{"ahi", 0, 0, 200, 200, 2, Modes.H|Modes.V},
					{"rssi",1, 0, -1,  -1, 1, Modes.H|Modes.V},
					{"vario", 1, 1, -1,   -1, 1, Modes.H|Modes.V},
					{"wind", 2, 0, -1,   -1, 1, Modes.V},
					{"dirn", 2, 1, -1,  -1, 1, Modes.V},
					{"flight", 3, 0, -1,   -1, 2, Modes.H|Modes.V},
					{"volts",  4, 0, -1,   -1, 2, Modes.H|Modes.V}
				};
			}
			 /**
			 nmap = {
				 {"ahi", "AHIView"}.
				 {"rssi", "RSSIView"},
				 {"vario", "VarioView"},
				 {"wind", "WindEstimateView"},
				 {"dirn", "DirectionView"},
				 {"flight", "FlightBoxView"},
				 {"volts",  "VoltageView"},
			 }
			 **/
			write_panel_config();
		}

		public void reset() {
			Panel.status = Panel.View.VISIBLE;
			foreach(var w in wlist) {
				if (w != null) {
					if (w.parent == grid) {
						grid.remove(w);
					}
				}
			}
			wlist = {};
		}

		public void set_mode(bool _iv) {
			wlist={};
			is_vertical = _iv;
			grid.vexpand = is_vertical;
			grid.hexpand = !is_vertical;
			foreach(var w in wmap) {
				bool load = false;
				if(is_vertical) {
					load = ((w.mode & Modes.V) == Modes.V);
				} else {
					load = ((w.mode & Modes.H) == Modes.H);
				}
				if(load) {
					load_widget(w.name, w.row, w.col, w.width, w.height, w.span);
				} else {
					unload_widget(w.name);
				}
			}
		}

	public void unload_widget(string name) {
			Gtk.Widget? w = null;
			switch(name) {
			case "ahi":
				Panel.status &= ~Panel.View.AHI;
				w = ahiv;
				break;
			case "rssi":
				Panel.status &= ~Panel.View.RSSI;
				w = rssiv;
				break;
			case "dirn":
				Panel.status &= ~Panel.View.DIRN;
				w = dirnv;
				break;
			case "flight":
				w = fboxv;
				Panel.status |= Panel.View.FVIEW;
				break;
			case "volts":
				w = powerv;
				Panel.status |= Panel.View.VOLTS;
				break;
			case "vario":
				w = vario;
				Panel.status |= Panel.View.VARIO;
				break;
			case "wind":
				w = wind;
				Panel.status |= Panel.View.WIND;
				break;
			}
			if (w != null) {
				w.visible = false;
			}
		}


		public void update(Panel.View s, int stuff=0) {
			switch (s) {
			case Panel.View.AHI:
				if (ahiv != null) {
					ahiv.update(stuff);
				}
				Logger.attitude();
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
		public void load_widget(string name, int row, int col, int sw=-1, int sh=-1, int span=1) {
			Gtk.Widget? w = null;
			switch (name) {
			case "ahi":
				if (ahiv == null) {
					ahiv = new AHI.View();
				}
				w = ahiv;
				w.vexpand = false;
				w.halign = Gtk.Align.FILL;
				w.valign = Gtk.Align.FILL;
				Panel.status |= Panel.View.AHI;
				break;
			case "rssi":
				if (rssiv == null) {
					rssiv = new RSSI.View();
				}
				w = rssiv;
				w.vexpand = false;
				w.hexpand = false;
				Panel.status |= Panel.View.RSSI;
				break;
			case "dirn":
				if (dirnv == null) {
					dirnv = new Direction.View();
				}
				w = dirnv;
				w.vexpand = false;
				w.hexpand = false;
				//w.halign = Gtk.Align.FILL;
				//w.valign = Gtk.Align.FILL;
				Panel.status |= Panel.View.DIRN;
				break;
			case "flight":
				if(fboxv == null) {
					fboxv = new FlightBox.View();
				}
				w = fboxv;
				w.hexpand = false;
				//w.halign = Gtk.Align.FILL;
				//w.valign = Gtk.Align.FILL;
				Panel.status |= Panel.View.FVIEW;
				break;
			case "volts":
				if (powerv == null) {
					powerv = new Voltage.View();
				}
				w = powerv;
				w.vexpand = true;
				Panel.status |= Panel.View.VOLTS;
				break;
			case "vario":
				if (vario == null) {
					vario = new Vario.View();
				}
				w = vario;
				w.vexpand = false;
				w.hexpand = false;
				//w.halign = Gtk.Align.FILL;
				//w.valign = Gtk.Align.FILL;
				Panel.status |= Panel.View.VARIO;
				break;
			case "wind":
				if (wind == null) {
					wind = new WindEstimate.View();
				}
				w = wind;
				w.vexpand = false;
				w.hexpand = false;
				//w.halign = Gtk.Align.FILL;
				//w.valign = Gtk.Align.FILL;
				Panel.status |= Panel.View.WIND;
				break;
			}
			if(w != null) {
				int sr = 1;
				int sc = 1;
				if(!is_vertical) {
					var t = row;
					row = col;
					col = t;
					sr = span;
				} else {
					sc = span;
				}
				if(sw != -1) {
					 w.width_request = sw;
				 }
				 if(sh != -1) {
					 w.height_request = sh;
				 }
				if (w.vexpand) {
					w.valign = Gtk.Align.FILL;
				}
				w.visible = true;
				 var f = new Gtk.Frame(null);
				 f.child=w;
				grid.attach(f, col, row, sc, sr);
				wlist += f;
			}
		}

		private bool read_panel_config() {
			bool ok = false;
			var fn = MWPUtils.find_conf_file(".panel.conf");
			if (fn != null) {
				var fs = FileStream.open (fn, "r");
				if (fs != null) {
					string s;
					while((s = fs.read_line()) != null) {
						if (s.has_prefix("#")) {
							continue;
						}
						var parts = s.split(",");
						if (parts.length ==  7) {
							ok = true;
							var w = WidgetMap();
							w.name = parts[0].strip();
							w.row = int.parse(parts[1].strip());
							w.col = int.parse(parts[2].strip());
							w.width = int.parse(parts[3].strip());
							w.height = int.parse(parts[4].strip());
							w.span = int.parse(parts[5].strip());
							w.mode = (Modes)int.parse(parts[6].strip());
							wmap += w;
						}
					}
				}
			}
			return ok;
		}

		private void write_panel_config() {
			var fn = MWPUtils.find_conf_file(".panel.conf");
			var fs = FileStream.open (fn, "w");
			if (fs != null) {
				fs.puts("# mwp panel v2\n");
				fs.puts("# name, row, col, width, height, span, mode\n");
				foreach(var w in wmap) {
					fs.printf("%s,%d,%d,%d,%d,%d,%d\n", w.name, w.row, w.col, w.width, w.height, w.span, w.mode);
				}
			}
		}
	}
}
