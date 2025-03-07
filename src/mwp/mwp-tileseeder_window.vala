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

namespace TileUtils {
	[GtkTemplate (ui = "/org/stronnag/mwp/seeder.ui")]
	public class Dialog : Adw.Window {
		[GtkChild]
		private unowned Gtk.SpinButton tile_minzoom;
		[GtkChild]
		private unowned Gtk.SpinButton tile_maxzoom;
		[GtkChild]
		private unowned Gtk.SpinButton tile_age;
		[GtkChild]
		private unowned Gtk.Label tile_stats;
		[GtkChild]
		private unowned Gtk.Button tile_start;
		[GtkChild]
		private unowned Gtk.Button tile_stop;

		private int age  {get; set; default = 30;}
		private TileUtils.Seeder ts;

		public Dialog() {
			set_transient_for(Mwp.window);
			ts = new TileUtils.Seeder();

			close_request.connect(() => {
					reset();
					return false;
			});

			tile_minzoom.adjustment.value_changed.connect (() =>  {
					int minv = (int)tile_minzoom.value;
					int maxv = (int)tile_maxzoom.value;
					if (minv > maxv) {
						tile_minzoom.value = maxv;
					} else {
						ts.set_zooms(minv,maxv);
						var nt = ts.build_table();
						set_label(nt);
					}
				});
			tile_maxzoom.adjustment.value_changed.connect (() => {
					int minv = (int)tile_minzoom.value;
					int maxv = (int)tile_maxzoom.value;
					if (maxv < minv ) {
						tile_maxzoom.value = minv;
					} else {
						ts.set_zooms(minv,maxv);
						var nt = ts.build_table( );
						set_label(nt);
					}
            });

			tile_start.clicked.connect(() => {
					tile_start.sensitive = false;
					int days = (int)tile_age.value;
					ts.set_delta(days);
					tile_stop.set_label("Stop");
					ts.start_seeding();
				});

			tile_stop.clicked.connect(() => {
					reset();
					close();
				});
		}

		private void reset() {
			if (ts != null) {
				ts.stop();
				ts = null;
			}
		}

		private void set_label(TileUtils.TileStats s) {
			var lbl = "Tiles: %u / Skip: %u / DL: %u / Err: %u".printf(s.nt, s.skip, s.dlok, s.dlerr);
			tile_stats.label = lbl;
		}

		public void run_seeder() {
			var source = Gis.map.viewport.get_reference_map_source ();
			var minz = (int)source.get_min_zoom_level();
			var maxz = (int)source.get_max_zoom_level();

			var b = MapUtils.get_bounding_box();

			var zval = (int)Gis.map.viewport.zoom_level;
			tile_stop.set_label("Close");
			tile_start.sensitive = true;
			tile_maxzoom.adjustment.lower = minz;
			tile_maxzoom.adjustment.upper = maxz;
			tile_maxzoom.adjustment.value = zval;

			tile_minzoom.adjustment.lower = minz;
			tile_minzoom.adjustment.upper = maxz;
			tile_minzoom.adjustment.value = zval-4;
			tile_age.adjustment.value = age;
			ts.show_stats.connect((stats) => {
					set_label(stats);
				});
			ts.tile_done.connect(() => {
					tile_start.sensitive = true;
					tile_stop.set_label("Close");
					get_dem_list(b);
				});
			// MWPLog.message(":DBG: BBOX %f %f %f %f\n",b.minlat, b.minlon, b.maxlat,b.maxlon);
			ts.set_range(b.minlat, b.minlon, b.maxlat,b.maxlon);
			ts.set_misc(source.id);
			ts.set_zooms(zval-4, zval);
			var nt = ts.build_table();
			set_label(nt);
			present();
		}
	}

	void get_dem_list(MapUtils.BoundingBox b) {
		for(var lat = b.minlat; lat <  b.maxlat; lat += 1.0) {
			for(var lon = b.minlon; lon <  b.maxlon; lon += 1.0) {
				var hh  = new HgtHandle(lat, lon);
				var fn = HgtHandle.getbase(lat, lon, null, null);
				if (hh.fd == -1) {
					MWPLog.message("Seeder: Add DEM download %s\n", fn);
					DemManager.asyncdl.add_queue(fn);
				} else {
					MWPLog.message("Seeder: Skip DEM %s\n", fn);
				}
				hh = null;
			}
		}
	}
}
