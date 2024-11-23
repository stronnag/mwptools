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

namespace MapIdCache {
	public struct Item {
		string cache;
		string uri;
	}

	public HashTable<string, MapIdCache.Item?> cache;
	public string normalise(string s) {
		uint8[] chars = s.data;
		for(var j = 0; j < chars.length; j++) {
			if(((char)chars[j]).ispunct()) {
				chars[j] = '_';
			}
		}
		string name = (string)chars;
		return name;
	}
	public void init() {
		MapIdCache.cache = new HashTable<string, MapIdCache.Item?>(str_hash,str_equal);
	}
}


namespace MapUtils {
	public struct BoundingBox {
		public double minlat;
		public double minlon;
		public double maxlat;
		public double maxlon;

		public double get_centre_latitude() {
			return (maxlat+minlat)/2.0;
		}
		public double get_centre_longitude() {
			return (maxlon+minlon)/2.0;
		}

		public bool covers(double qlat, double qlon) {
			return (qlat > minlat && qlon > minlon && qlat < maxlat && qlon < maxlon);
		}

		public void get_map_size(out double width, out double height) {
			double dist,cse;
			double apos;
			apos = get_centre_latitude();
			Geo.csedist(apos, minlon, apos, maxlon, out dist, out cse);
			width = dist * 1852.0;

			apos = get_centre_longitude();
			Geo.csedist(maxlat, apos, minlat, apos, out dist, out cse);
			height = dist * 1852.0;
		}
	}

	public void centre_on(double lat, double lon) {
		Gis.map.center_on(lat, lon);
		Gis.map.go_to(lat, lon);
	}

	internal const double WCIRC = 40075016.686; // Earth circumference
	public int evince_zoom(BoundingBox b) {
		var h = Gis.map.get_height();
		var w = Gis.map.get_width();
		var alat = b.get_centre_latitude();
		var alon = b.get_centre_longitude();
		double c, dlat, dlon;
		Geo.csedist(alat, b.minlon, alat, b.maxlon, out dlon, out c);
		Geo.csedist(b.minlat, alon, b.maxlat, alon, out dlat, out c);
		dlon *= 1852;
		dlat *= 1852;
		uint rz = 0;
		for(var z = Gis.map.viewport.min_zoom_level; z <= Gis.map.viewport.max_zoom_level; z++) {
			var spix = WCIRC*Math.cos(alat*Math.PI/180.0)/(256* Math.pow(2.0, z));
			var hpix = dlon/spix;
			var vpix = dlat/spix;
			if (hpix > w || vpix > h) {
				rz = z;
				break;
			}
		}
		return (int)rz-1;
	}

	public void get_centre_location(out double clat, out double clon) {
		var h = Gis.map.get_height();
		var w = Gis.map.get_width();
		var dh = (double)h*0.5;
		var dw = (double)w*0.5;
		Gis.map.viewport.widget_coords_to_location (Gis.map, dw, dh, out clat, out clon);
	}

	public double get_centre_latitude() {
		double clat;
		double clon;
		get_centre_location(out clat, out clon);
		return clat;
	}

	public double get_centre_longitude() {
		double clat;
		double clon;
		get_centre_location(out clat, out clon);
		return clat;
	}

	public BoundingBox get_bounding_box() {
		//out double ullat, out double ullon, out double lrlat, out double lrlon) {
		BoundingBox b={};

		var dh = (double)Gis.map.get_height();
		var dw = (double)Gis.map.get_width();
		Gis.map.viewport.widget_coords_to_location (Gis.map, 0.0, 0.0, out b.maxlat, out b.minlon);
		Gis.map.viewport.widget_coords_to_location (Gis.map, dw, dh, out b.minlat, out b.maxlon);
		return b;
	}

	public void try_centre_on(double xlat, double xlon) {
		var bbox = MapUtils.get_bounding_box();
		if (!bbox.covers(xlat, xlon)) {
            var mlat = bbox.get_centre_latitude();
            var mlon = bbox.get_centre_longitude();
            double alat, alon;
			double width_m, height_m;
			bbox.get_map_size(out width_m, out height_m);

			double msize = Math.fmin(width_m, height_m);
            double dist,_cse;
            Geo.csedist(xlat, xlon, mlat, mlon, out dist, out _cse);

            if(dist * 1852.0 > msize) {
                alat = xlat;
                alon = xlon;
            } else {
                alat = (mlat + xlat)/2.0;
                alon = (mlon + xlon)/2.0;
            }
            map_centre_on(alat,alon);
		}
	}

	public void map_centre_on(double lat, double lon) {
		Gis.map.center_on(lat, lon);
	}
}
