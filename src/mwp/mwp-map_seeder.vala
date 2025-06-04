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
    private enum TILE_ITER_RES {
        DONE=-1,
        FETCH=0,
        SKIP=1
    }

    public struct TileList {
        int z;
        int sx;
        int ex;
        int sy;
        int ey;
    }

    public struct TileStats {
        uint nt;
        uint skip;
        uint dlok;
        uint dlerr;
    }

	public class Seeder {
		private double maxlat;
		private double minlat;
		private double minlon;
		private double maxlon;
		private int minzoom;
		private int maxzoom;
		private int in;
		private int ix;
		private int iy;
		private DateTime dtime;
		private bool done;
		private File file;
		private TileList[] tl;
		private string cachedir;
		private string uri;
		private Soup.Session session;
		private TileStats stats;

		public signal void show_stats (TileStats ts);
		public signal void tile_done ();

		public Seeder() {		}

		public void set_range(double _minlat, double _minlon, double _maxlat, double _maxlon) {
			minlat = _minlat;
			minlon = _minlon;
			maxlat = _maxlat;
			maxlon = _maxlon;
		}

		public void set_zooms(int _minzoom, int _maxzoom) {
			minzoom = _minzoom;
			maxzoom = _maxzoom;
		}

		public void set_misc(string id) {
			var s = Environment.get_user_cache_dir();
			var cnames = MapIdCache.cache.lookup(id);
			cachedir = Path.build_filename(s,"shumate",cnames.cache);
			uri = cnames.uri;
		}

		public TileStats build_table() {
			var inc = 0;
			stats.nt = 0;
			stats.dlok = 0;
			stats.dlerr = 0;
			tl={};

			for(var z = maxzoom; z >= minzoom; z--) {
				var m = TileList();
				m.z = z;
				ll2tile(maxlat, minlon, z, out m.sx, out m.sy);
				ll2tile(minlat, maxlon, z, out m.ex, out m.ey);
				if(inc != 0) {
					m.sx -= inc;
					m.sy -= inc;
					m.ex += inc;
					m.ey += inc;
				}
				inc++;
				stats.nt += (1 + m.ex - m.sx) * (1  + m.ey - m.sy);
				tl += m;
			}
			in = 0;
			ix = tl[0].sx;
			iy = tl[0].sy;
			done = false;
			return stats;
		}

		/*
		  public void dump_tl() {
		  foreach(var m in tl) {
		  MWPLog.message("%d %d %d %d %d\n", m.z, m.sx, m.sy, m.ex, m.ey);
		  }
		  }
		*/
		public void ll2tile(double lat, double lon, int zoom, out int x, out int y) {
			x = (int)Math.floor((lon + 180.0) / 360.0 * (1 << zoom));
			y = (int)Math.floor(((1.0 - Math.log(Math.tan(lat*Math.PI/180.0)+1.0/Math.cos(lat*Math.PI/180.0))/Math.PI) / 2.0 * (1 << zoom)));
			return;
		}

		public void tile2ll(int x, int y, int zoom, out double lat, out double lon) {
			double n = Math.PI - ((2.0 * Math.PI * y) / Math.pow(2.0, zoom));
			lon = (x / Math.pow(2.0, zoom) * 360.0) - 180.0;
			lat = 180.0 / Math.PI * Math.atan(Math.sinh(n));
		}

		private TILE_ITER_RES get_next_tile(out string? s) {
			TILE_ITER_RES r = TILE_ITER_RES.FETCH;
			s = null;
			if(done)
				r = TILE_ITER_RES.DONE;
			else {
				var fn = Path.build_filename(cachedir,
											 tl[in].z.to_string(),ix.to_string(),
											 "%d.png".printf(iy));

				file = File.new_for_path(fn);

				if(iy == tl[in].sy) {
					File f = file.get_parent();
					if(f.query_exists() == false) {
						try {
							f.make_directory_with_parents();
						} catch {};
					}
				}

				if (file.query_exists() == true) {
					try {
						var fi = file.query_info("*", FileQueryInfoFlags.NONE);
						var dt = fi.get_modification_date_time ();
						if(dt.difference(dtime) > 0) {
							r = TILE_ITER_RES.SKIP;
							stats.skip++;
						}
					} catch {};
				}

				if(r ==  TILE_ITER_RES.FETCH)
					s = uri_builder();

				if(iy ==  tl[in].ey) { // end of row
					if (ix == tl[in].ex) {
						in += 1;
						if(in == tl.length) {
							in = 0;
							ix = tl[0].sx;
							iy = tl[0].sy;
							done=true;
						} else {
							ix = tl[in].sx;
							iy = tl[in].sy;
						}
					} else {
						ix++;
						iy = tl[in].sy;
					}
				} else {
					iy++;
				}
			}
			return r;
		}

		private string uri_builder() {
			var s = uri;
			s = s.replace("{z}", "%d".printf(tl[in].z));
			s = s.replace("{x}", "%d".printf(ix));
			s = s.replace("{y}", "%d".printf(iy));
			return s;
		}

		public void start_seeding() {
			session = new Soup.Session();
			session.user_agent = "Mission-Planner/1.0";
			done = false;
			show_stats(stats);
			fetch_tile();
		}

		public void fetch_tile() {
			TILE_ITER_RES r = TILE_ITER_RES.SKIP;
			string tile_uri = null;

			do {
				r = get_next_tile(out tile_uri);
			} while (r == TILE_ITER_RES.SKIP);

			if(r == TILE_ITER_RES.FETCH) {
				var msg = new Soup.Message ("GET", tile_uri);
				//            msg.get_request_headers().append("X-Requested-With", "Anticipation");
				session.send_and_read_async.begin(msg, 0, null, (obj,res) => {
						try {
							var byt = session.send_and_read_async.end(res);
							stats.dlok++;
							file.replace_contents(byt.get_data(), null,
												  false,
												  FileCreateFlags.REPLACE_DESTINATION,null);
						} catch (Error e) {
							MWPLog.message("Tile %s %s, failure status %u\n", tile_uri, e.message, msg.status_code);
							stats.dlerr++;
						}
						show_stats(stats);
						fetch_tile();
					});
			}
			if(r == TILE_ITER_RES.DONE) {
				tile_done();
			}
		}
		public void set_delta(uint days) {
			var t =  new  DateTime.now_local ();
			dtime = t.add_days(-(int)days);
		}

		public void stop() {
			done = true;
			show_stats(stats);
		}
	}
}
