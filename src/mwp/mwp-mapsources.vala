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

using Gtk;

public struct  MwpMapDesc {
	 public string id;
	 public string name;
	 public string license;
	 public string license_uri;
	 public uint min_zoom_level;
	 public uint max_zoom_level;
	 public uint tile_size;
	 public Shumate.MapProjection projection;
	 public string url_template;
}

public class SoupProxy : Soup.Server {
    public bool offline = false;
    private Soup.Session session;
    private string? basename = null;
    private string? extname = null;
    private const string UASTR = "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:%d1.0) Gecko/%d%d%d Firefox/%d.0.%d";
	private string cdir;

    private string make_ua() {
        int yr = new DateTime.now_local ().get_year();
        var r = new Rand();
        string ua = UASTR.printf(
            r.int_range(3,14),
            r.int_range(yr-4,yr),
            r.int_range(11,12),
            r.int_range(10,30),
            r.int_range(3,14),
            r.int_range(1,10));
        return ua;
    }

	public void set_cdir(string c) {
		cdir = c;
	}

	public SoupProxy(bool _offline) {
		offline = _offline;
		this.add_handler (null, default_handler);
		session = new Soup.Session ();
		//MWPLog.message("Soup Timeout %u\n", session.timeout);
		//session.timeout = 5;
	}

	public void set_uri(string uri) {
		var parts = uri.split("{Q}");
        if(parts.length == 2) {
            basename = parts[0];
            extname = parts[1];
        } else {
            MWPLog.message("Invalid quadkeys URI (%s)\n", uri);
        }
    }

	~SoupProxy() {}

    private string quadkey(int iz, int ix, int iy) {
        StringBuilder sb = new StringBuilder ();
        for (var i = iz - 1; i >= 0; i--) {
            char digit = '0';
            if ((ix & (1 << i)) != 0)
                digit += 1;
            if ((iy & (1 << i)) != 0)
                digit += 2;
            sb.append_unichar(digit);
        }
        return sb.str;
    }

	private int getservernum(int ix, int iy, int pmax) {
        return (ix + (2 * iy)) % pmax;
    }

    private string rewrite_path(string p) {
        var parts = p.split("/");
        var np = parts.length-3;
        var fn = parts[np+2].split(".");
        var iz = int.parse(parts[np]);
        var ix = int.parse(parts[np+1]);
        var iy = int.parse(fn[0]);
        var q = quadkey(iz, ix, iy);
		var svr = getservernum(ix, iy, 4);
		var bn = basename.printf(svr);
		StringBuilder sb = new StringBuilder(bn);
        sb.append(q);
        sb.append(extname);
        return sb.str;
    }

    private void default_handler (Soup.Server server, Soup.ServerMessage msg, string path,
								  GLib.HashTable? query) {
		if(offline || basename == null) {
            msg.set_status(404, null);
            return;
        }
        var method = msg.get_method();
        if (method == "HEAD") {
            bool ok = false;
            Posix.Stat st;
            var parts = path.split("/");
            var np = parts.length;
            var fnstr = GLib.Path.build_filename(
                Environment.get_home_dir(),
                ".cache/shumate",
				cdir,
                parts[np-3],
                parts[np-2],
                parts[np-1]);

            if(Posix.stat(fnstr, out st) == 0) {
                ok = true;
                var dt = new DateTime.from_unix_utc(st.st_mtime);
                var dstr = dt.format("%a, %d %b %Y %H:%M:%S %Z");
                msg.get_response_headers().append("Content-Type","image/jpeg");
                msg.get_response_headers().append("Accept-Ranges", "bytes");
                msg.get_response_headers().append("Last-Modified", dstr);
                msg.get_response_headers().append("Content-Length", st.st_size.to_string());
                msg.set_status(200, null);
            }
            if(!ok) {
                msg.set_status(404,null);
            }
        } else if (method == "GET") {
			var xpath = rewrite_path(path);
			var message = new Soup.Message ("GET", xpath);
			message.get_request_headers().append("User-Agent",make_ua());
			try {
				var b = session.send_and_read (message);
				msg.set_response ("image/jpeg", Soup.MemoryUse.COPY, b.get_data());
			} catch {}
			if (message.status_code != 200) {
				MWPLog.message("unexpected HTTP code %s\n", message.status_code.to_string());
			}
			msg.set_status(message.status_code, null);
		} else {
			msg.set_status(404, null);
		}
        msg.get_response_headers().append("Server", "qk-proxy/1.0");
    }
}

public class BingMap : Object {
	private string buri;
	private MwpMapDesc ms;

	public BingMap() {
		get_static_data();
	}

	public string get_buri() {
		return buri;
	}

	public MwpMapDesc get_ms() {
		return ms;
	}

	public void get_static_data() {
		ms.id= "Bing";
		ms.name = "Bing Maps";
		ms.min_zoom_level =  0;
		ms.max_zoom_level = 19;
		ms.tile_size = 256;
		ms.projection = Shumate.MapProjection.MERCATOR;
		ms.license = "(c) Microsoft Corporation and partners";
		ms.license_uri = "http://www.bing.com/maps/";
		//buri = "http://ecn.t3.tiles.virtualearth.net/tiles/a#Q#.jpeg?g=13902";
		buri = "http://ecn.t%d.tiles.virtualearth.net/tiles/a{Q}.jpeg?g=13902&mkt=en";
	}
}

namespace MapManager {
    public string id = null;
    private int[] proxypids;
	private SoupProxy sp;

	public void killall() {
        foreach(var p in proxypids)
            Posix.kill(p, 15);
    }

	private string? fixup_template_uri(string a) {
		var parts = a.split("#");
		if (parts.length > 0) {
			StringBuilder sb = new StringBuilder();
			for(var j = 0; j < parts.length; j++) {
				if ((j & 1) == 0) {
					sb.append(parts[j]);
				} else {
					sb.append_c('{');
					var lp = parts[j].down();
					sb.append(lp);
					sb.append_c('}');
				}
			}
			return sb.str;
		}
		return null;
	}

	public MwpMapDesc[] read_json_sources(string? fn, bool offline=false) {
		MwpMapDesc[] sources = {};
		proxypids = {};

		if(Gis.mapbox_key != null) {
			var mb = MwpMapDesc();
			mb.id = "mbox";
			mb.name = "MapBox";
			mb.min_zoom_level = 0;
			mb.max_zoom_level = 19;
			mb.projection = Shumate.MapProjection.MERCATOR;
			mb.tile_size = 256;
			mb.license_uri = "https://mapbox.com/";
			mb.url_template = "https://api.mapbox.com/v4/mapbox.satellite/{z}/{x}/{y}.png?access_token=%s".printf(Gis.mapbox_key);
			mb.license = "(c) Mapbox & partners";
			sources += mb;
		}

		var bg = new BingMap();
        var ms = bg.get_ms();
		MWPLog.message("Starting Bing proxy %s\n", (offline) ? "(offline)" : "");
		uint port = 0;
        sp = new SoupProxy(offline);
        try {
            sp.listen_local(31897, 0);
            var u  = sp.get_uris();
            port = u.nth_data(0).get_port ();
        } catch { port = 0; }
		if (port != 0) {
			ms.url_template = "http://localhost:%u/%s/{z}/{x}/{y}.png".printf(port,ms.id);
			var cdir = "http___localhost_%u_%s__z___x___y__png".printf(port, ms.id);
			sp.set_cdir(cdir);
		}

		sources += ms;
		sp.set_uri(bg.get_buri());

		if(fn != null) {
            try {
                var parser = new Json.Parser ();
                parser.load_from_file (fn);
                var root_object = parser.get_root ().get_object ();
                foreach (var node in
                     root_object.get_array_member ("sources").get_elements ()) {
                    var s = MwpMapDesc();
                    var item = node.get_object ();
                    s.id = item.get_string_member ("id");
                    s.license_uri = item.get_string_member("license_uri");
                    if(item.has_member("uri_format")) {
						var ut = item.get_string_member("uri_format");
						var tut = fixup_template_uri(ut);
						s.url_template = (tut == null) ? ut : tut;
					}
					bool skip = (s.id == "BingProxy" ||
                             s.url_template ==
                             "http://localhost:21303/quadkey-proxy/#Z#/#X#/#Y#.png" ||
                             s.license_uri == "http://www.bing.com/maps/");
					if(!skip) {
						s.name = item.get_string_member ("name");
						s.license = item.get_string_member("license");
						s.min_zoom_level = (int)item.get_int_member ("min_zoom");
						s.max_zoom_level = (int) item.get_int_member ("max_zoom");
						s.tile_size = (int)item.get_int_member("tile_size");
						s.projection = Shumate.MapProjection.MERCATOR;
						if(item.has_member("spawn")) {
							var spawncmd = item.get_string_member("spawn");
							var iport = spawn_proxy(spawncmd);
							if(iport > 0)
								s.url_template = "http://localhost:%u/%s/{z}/{x}/{y}.png".printf(iport,s.id);
							if(iport != -1)
								sources += s;
						}
						else {
							sources += s;
						}
					}
                }
            }
            catch (Error e) {
                MWPLog.message ("mapsources : %s\n", e.message);
            }
        }

		/*
		  MapIdCache.init();
		foreach (var s in sources) {
			var cname = MapIdCache.normalise(s.url_template);
			MapIdCache.cache.insert(s.id, {cname, s.url_template});
		}
		*/
		return sources;
    }

    private int spawn_proxy(string cmd) {
        string[]? argvp = null;
        int iport = 0;

        try {
            int pid;
            int p_out;
            Shell.parse_argv (cmd, out argvp);
            Process.spawn_async_with_pipes ("/",
                                            argvp,
                                            null,
                                            SpawnFlags.SEARCH_PATH|SpawnFlags.STDERR_TO_DEV_NULL,
                                            null,
                                            out pid,
                                            null,
                                            out p_out,
                                            null);
            proxypids += pid;
            IOChannel ioc = new IOChannel.unix_new (p_out);
            string line = null;
            size_t len = 0;
            IOStatus eos = ioc.read_line (out line, out len, null);
            if(eos != IOStatus.EOF && len != 0) {
				var parts = line.split("\t");
				if (parts.length > 1) {
					iport = int.parse(parts[1]);
				}
				if(parts[0] == "Port:") {
					MWPLog.message("External proxy \"%s\" listening on :%d\n", cmd, iport);
				} else {
					StringBuilder sb = new StringBuilder("note: ");
					sb.append(cmd);
					if (parts.length == 3) {
						sb.append_c(' ');
						sb.append(parts[2]); // has LP
					} else {
						sb.append(" unknown error\n"); // has LP
					}
					MWPLog.message(sb.str);
				}
			}
        } catch {
            MWPLog.message("Failed to start external proxy %s\n", cmd);
            iport = -1;
        }
        return iport;
    }
	public void setBingState(bool offline) {
		sp.offline = offline;
	}
}