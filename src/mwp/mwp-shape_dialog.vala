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

namespace Shape {

    public struct Point {
        public double lat;
        public double lon;
        public double bearing;
        public int no;
    }

[GtkTemplate (ui = "/org/stronnag/mwp/shapedialog.ui")]
	public class Dialog : Adw.Window {
		[GtkChild]
		private unowned Gtk.SpinButton nopoints;
		[GtkChild]
		private unowned Gtk.SpinButton rrange;
		[GtkChild]
		private unowned Gtk.SpinButton offangle;
		[GtkChild]
		private unowned Gtk.DropDown direction;
		[GtkChild]
		private unowned Gtk.Button shapeapply;
		[GtkChild]
		private unowned Gtk.Button shapecancel;

		private double clat;
		private double clon;

		public signal void get_values(Shape.Point[] pts);

		public Dialog () {
			transient_for = Mwp.window;
			/*
			close_request.connect (() => {
					return true;
				});
			*/
			shapeapply.clicked.connect(() => {
					var npts = (int)nopoints.value;
					var radius = rrange.value;
					var start = offangle.value;
					var dirn = direction.selected;
					radius = InputParser.get_scaled_real(radius.to_string());
					if(radius > 0) {
						var p = mkshape(clat, clon, radius, npts, start, dirn);
						get_values(p);
					}
					//this.hide();
					close();
				});

			shapecancel.clicked.connect(() => {
					//this.hide();
					close();
				});
		}

		public void get_points(double _clat, double _clon) {
			clat = _clat;
			clon = _clon;
			this.present();
		}
	}
	public Shape.Point[] mkshape(double clat, double clon,double radius,
								 int npts=6, double start = 0, uint dirn=0) {
        double ang = start;
        double dint  = ((dirn == 0) ? 1.0 : -1.0) *(360.0/npts);
        Shape.Point[] points= new Shape.Point[npts+1];
        radius /= 1852.0;
        for(int i =0; i <= npts; i++) {
            double lat,lon;
            Geo.posit(clat,clon,ang,radius,out lat, out lon);
            var p = Shape.Point() {no = i, lat=lat, lon=lon, bearing = ang};
            points[i] = p;
            ang = (ang + dint) % 360.0;
            if (ang < 0.0)
                ang += 360;
        }
        return points;
    }
}
