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

namespace Measurer {
	public bool active;

	public class Measure : Adw.Window {
		private Gtk.Label label;
		private Shumate.PathLayer pl;
		private Shumate.MarkerLayer ml;
		private double tdist;
		private double clat;
		private double clon;

		public void clean_up() {
			ml.remove_all();
			pl.remove_all();
		}

		public Measure() {
			title="Measure";
			var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
			vbox.append(new Adw.HeaderBar());
			label = new Gtk.Label("00000.0m");
			vbox.append(label);

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
			hbox.append(rbutton);
			var cbutton = new Gtk.Button.with_label("Close");
			cbutton.clicked.connect(() => {
					clean_up();
					Measurer.active = false;
					close();
				});
			hbox.append(cbutton);
			vbox.append(hbox);
			set_content(vbox);
			close_request.connect (() => {
					Measurer.active = false;
					clean_up();
					return false;
				});
			set_transient_for(Mwp.window);
			tdist = 0.0;

			pl = new Shumate.PathLayer(Gis.map.viewport);
			pl.set_stroke_width (5);
			var c = Gdk.RGBA();
			c.parse("rgba(0xe7, 0x1d, 0xdd, 0.75)");
			pl.set_stroke_color(c);

			ml = new Shumate.MarkerLayer(Gis.map.viewport);

			Gis.map.insert_layer_above (ml, Gis.hm_layer); // above home layer
			Gis.map.insert_layer_above (pl, ml); // above home layer

			Measurer.active = true;
		}

		public void run() {
			tdist = 0.0;
			label.label = format_distance();
			/*
			  double lat;
			double lon;
			MapUtils.get_centre_location(out lat, out lon);
			*/
			add_point(Mwp.current_lat, Mwp.current_lon);
			present();
		}

		public void add_point(double lat, double lon) {
			var l = new MWPPoint.with_colour("#00000040");
			l.set_size_request(24,24);
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
			string ds;
			string du;
			Units.scaled_distance(md, out ds, out du);
			return "%s%s".printf(ds, du);
		}

		public void calc_distance() {
			tdist = 0.0;
			double llat = 0;
			double llon = 0;
			double lat = 0;
			double lon = 0;
			bool calc = false;
			pl.get_nodes().foreach((n) => {
					lon = ((Shumate.Point)n).longitude;
					lat = ((Shumate.Point)n).latitude;
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
}
