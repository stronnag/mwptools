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
			if (chars[j] == '.' ||  chars[j] == ':' || chars[j] == '{' || chars[j] == '}' || chars[j] == '/') {
				chars[j] = '_';
			}
		}
		string name = (string)chars;
		return name;
	}
	public void init() {
		MapIdCache.cache = new HashTable<string, MapIdCache.Item?>(str_hash,str_equal);
		MapIdCache.cache.insert("osm-mapnik", {
				"https___tile_openstreetmap_org__z___x___y__png",
					"https://tile.openstreetmap.org/{z}/{x}/{y}.png"});
		MapIdCache.cache.insert("osm-cyclemap", {
				"http___tile_opencyclemap_org_cycle__z___x___y__png",
					"http://tile.opencyclemap.org/cycle/{z}/{x}/{y}.png"});
		MapIdCache.cache.insert("mff-relief", {
				"http___maps_for_free_com_layer_relief_z_z__row_y___z___x___y__jpg",
					"http://maps-for-free.com/layer/relief/z{z}/row{y}/{z}_{x}-{y}.jpg"});
		MapIdCache.cache.insert("osm-transportmap", {
				"http___tile_xn__pnvkarte_m4a_de_tilegen__z___x___y__png",
					"http://tile.xn--pnvkarte-m4a.de/tilegen/{z}/{x}/{y}.png"});
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
			width = dist *= 1852.0;

			apos = get_centre_longitude();
			Geo.csedist(maxlat, apos, minlat, apos, out dist, out cse);
			height = dist *= 1852.0;
		}
	}

	public int evince_zoom(BoundingBox b) {
		// undingdouble lamin, double lomin, double lamax, double lomax
		var alat = b.get_centre_latitude();
		var vrng = b.maxlat - b.minlat;
		var hrng = (b.maxlon - b.minlon) / Math.cos(alat*Math.PI/180.0);		// well, sort of
		var drng = Math.sqrt(vrng*vrng+hrng*hrng) * 60 * 1852 * 0.7;
		// MWPLog.message("lamin %f, lomin %f, lamax %f lomax %f\n", lamin, lomin, lamax, lomax);
		// MWPLog.message("v %f, h %f, d %f\n", vrng*60*1852, hrng*60*1852, drng);
		var z = 0;
		if (drng < 120) {
			z = 20;
		} else if (drng < 240) {
			z = 19;
		} else if (drng < 480) {
			z = 18;
		} else if (drng < 960) {
			z = 17;
		} else if (drng < 1920) {
			z = 16;
		} else if (drng < 3840) {
			z = 15;
		} else if (drng < 7680) {
			z = 14;
		} else if (drng < 7680*2) {
			z = 13;
		} else {
			z = 12;
		}
		// MWPLog.message("v %f, h %f, d %f z => %d\n", vrng*60*1852, hrng*60*1852, drng, z);
		return z;
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

	public void get_cache_dir() {
		var source = Gis.map.viewport.get_reference_map_source ();
		//			var uri = Gis.get_cache_dir ();
	}
}
