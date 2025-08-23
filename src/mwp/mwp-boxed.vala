
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

	Gtk.Widget popwidget;

	public class Box: Gtk.Frame {
		Gtk.Grid grid;
		bool is_vertical;

		private GLib.SimpleActionGroup dg;

		public Box(bool _iv) {
			grid = new Gtk.Grid();
			is_vertical = _iv;
			if (_iv) {
				grid.vexpand = true;
			} else {
				grid.hexpand = true;
			}
			//          ma,e     x  y   w    h   span
			load_widget("ahi",   0, 0, 160, 160, 2);
			load_widget("rssi",  1, 0, 50,  50, 1);
			load_widget("vario", 1, 1, 50,  50, 1);
			if (is_vertical) {
				load_widget("wind",  2, 0, -1,   -1, 1);
				load_widget("dirn",  2, 1, -1,   -1, 1);
			}
			load_widget("flight", 3, 0, -1,   -1, 2);
			load_widget("volts", 4, 0, -1,   -1, 2);
			this.set_child(grid);
			init();
		}

		public void init() {
			Panel.status = Panel.View.VISIBLE;
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

		public void load_widget(string name, int col, int row, int sw=-1, int sh=-1, int span=1) {
			Gtk.Widget? w = null;
			switch (name) {
			case "ahi":
				ahiv = new AHI.View();
				w = ahiv;
				w.vexpand = false;
				w.halign = Gtk.Align.FILL;
				w.valign = Gtk.Align.FILL;
				Panel.status |= Panel.View.AHI;
				break;
			case "rssi":
				rssiv = new RSSI.View();
				w = rssiv;
				w.vexpand = false;
				if (!is_vertical) {
					w.hexpand = false;
				} else {
					w.halign = Gtk.Align.FILL;
				}
				Panel.status |= Panel.View.RSSI;
				break;
			case "dirn":
				dirnv = new Direction.View();
				w = dirnv;
				w.vexpand = false;
				w.halign = Gtk.Align.FILL;
				w.valign = Gtk.Align.FILL;
				Panel.status |= Panel.View.DIRN;
				break;
			case "flight":
				fboxv = new FlightBox.View();
				w = fboxv;
				w.halign = Gtk.Align.FILL;
				w.valign = Gtk.Align.FILL;
				Panel.status |= Panel.View.FVIEW;
				break;
			case "volts":
				powerv = new Voltage.View();
				w = powerv;
				w.vexpand = true;
				Panel.status |= Panel.View.VOLTS;
				break;
			case "vario":
				vario = new Vario.View();
				vario.update(0);
				w = vario;
				w.vexpand = false;
				w.halign = Gtk.Align.FILL;
				w.valign = Gtk.Align.FILL;
				Panel.status |= Panel.View.VARIO;
				break;
			case "wind":
				wind= new WindEstimate.View();
				wind.update(0);
				w = wind;
				w.vexpand = false;
				w.halign = Gtk.Align.FILL;
				w.valign = Gtk.Align.FILL;
				Panel.status |= Panel.View.WIND;
				break;
			}
			if(w != null) {
				int sr = 1;
				int sc = 1;
				print("load widget %s %s\n", name, is_vertical.to_string());
				if(is_vertical) {
					var t = col;
					col = row;
					row = t;
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
				print("vexpand %s\n", name);
				var f = new Gtk.Frame(null);
				f.child=w;
				grid.attach(f, col, row, sr, sc);
			}
		}
	}
}
