using GLib;
using Clutter;
using Champlain;

public class Measure : Gtk.Window {
	public static bool active;
	private Gtk.Label label;
    private Champlain.PathLayer pl;
    private Champlain.MarkerLayer ml;
    private Clutter.Color ycol;
    private double tdist;
	private double clat;
	private double clon;
	private unowned Champlain.View view;

	public void clean_up(Champlain.View view) {
		ml.remove_all();
		pl.remove_all();
		view.button_release_event.disconnect (on_button_release);
		view.button_press_event.disconnect (on_button_press);
	}

	private bool on_button_press (Clutter.Actor a, Clutter.ButtonEvent event) {
		if (event.button == 1) {
			clat = view.get_center_latitude();
			clon = view.get_center_longitude();
			return true;
		}
		return false;
	}

	public bool on_button_release (Clutter.Actor a, Clutter.ButtonEvent event) {
		double lat, lon;
		if (event.button == 1) {
			lat = view.get_center_latitude();
			lon = view.get_center_longitude();
			var zoom = view.zoom_level;
			if((!delta_diff(clon,lon,zoom) && !delta_diff(clat,lat,zoom))) {
				lat = view.y_to_latitude (event.y);
				lon = view.x_to_longitude (event.x);
				add_point(lat, lon);
			}
			return true;
		}
		return false;
	}

	public Measure(Gtk.Window _w, Champlain.View _view) {
		title="Measure";
		view = _view;
        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
		label = new Gtk.Label("00000.0m");
		vbox.pack_start(label);

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
		var rbutton = new Gtk.Button.with_label("Reset");
		rbutton.clicked.connect(() => {
				tdist = 0.0;
				var lat = pl.get_nodes().last().data.latitude;
				var lon = pl.get_nodes().last().data.longitude;
				ml.remove_all();
				pl.remove_all();
				add_point(lat, lon);
			});
		hbox.pack_end(rbutton);
		var cbutton = new Gtk.Button.with_label("Close");
		cbutton.clicked.connect(() => {
				clean_up(view);
				active = false;
				hide();
			});
		hbox.pack_end(cbutton);
		vbox.pack_end(hbox);
		add(vbox);
		delete_event.connect (() => {
				clean_up(view);
				active = false;
				hide();
				return true;
			});
		set_transient_for(_w);
		ycol = {0xf, 0x0f, 0x0, 0xa0};
		tdist = 0.0;

		pl = new Champlain.PathLayer();
		ml = new Champlain.MarkerLayer();
		view.add_layer(pl);
		view.add_layer(ml);
	}

	public void run(int ex, int ey) {
		active = true;
		view.button_press_event.connect(on_button_press);
		view.button_release_event.connect (on_button_release);
		tdist = 0.0;
		label.label = format_distance();
		show_all();
		var lat = view.y_to_latitude (ey);
		var lon = view.x_to_longitude (ex);
		add_point(lat, lon);
	}

	public void add_point(double lat, double lon) {
        MWPLabel l;
		try {
            float w,h;
            Clutter.Actor actor = new Clutter.Actor ();
			var img = MWPMarkers.load_image_from_file("dist.svg", 20, 20);
            img.get_preferred_size(out w, out h);
			actor.set_size((int)w, (int)h);
			actor.content = img;
			l = new MWPLabel.with_image(actor);
            ((Champlain.Label)l).set_draw_background (false);
            l.set_pivot_point(0.5f, 0.5f);
        } catch {
            l = new MWPLabel();
            l.color = ycol;
        }
        l.latitude = lat;
        l.longitude = lon;
        l.set_draggable(true);
        pl.add_node(l);
        ml.add_marker(l);
		l.drag_motion.connect(() => {
				calc_distance();
			});
		calc_distance();
    }

	private string format_distance() {
		var md = tdist*1852.0;
		var u = "m";
		var fmt = "%.0f%s";
		if(md >= 10000.0) {
			md = md /1000;
			u = "km";
			fmt = "%.3f%s";
		}
		return fmt.printf(md, u);
	}

	private void calc_distance() {
		tdist = 0.0;
        double llat = 0;
        double llon = 0;
        double lat = 0;
        double lon = 0;
		bool calc = false;
        pl.get_nodes().foreach((n) => {
				lon = ((Champlain.Location)n).longitude;
				lat = ((Champlain.Location)n).latitude;
				double c;
				double d = 0;
				if(calc) {
					Geo.csedist(llat,llon,lat,lon, out d, out c);
					tdist += d;
				}
				llat = lat;
				llon = lon;
				calc = true;
			});
		label.label = format_distance();
    }
    private bool delta_diff(double f0, double f1, uint zoom) {
        var delta = 0.0000025 * Math.pow(2, (20-zoom));
		var ddist = Math.fabs(f0-f1);
		var res = (ddist > delta);
        return res;
    }
}
