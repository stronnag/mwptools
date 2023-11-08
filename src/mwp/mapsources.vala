
/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 3
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */
using Gtk;
using Clutter;
using Champlain;
using GtkChamplain;

public struct MapSource {
    string id;
    string name;
    int min_zoom;
    int max_zoom;
    int tile_size;
    Champlain.MapProjection projection;
    string licence;
    string licence_uri;
    string uri_format;
    Champlain.MapSourceDesc desc;
}

public class MwpMapSource : Champlain.MapSourceDesc {
    public MwpMapSource (string id,
						 string name,
						 string license,
						 string license_uri,
						 int minzoom,
						 int maxzoom,
						 int tile_size,
						 Champlain.MapProjection projection,
						 string uri_format) {
        Object(id: id, name: name, license: license, license_uri: license_uri,
               min_zoom_level: minzoom, max_zoom_level: maxzoom,
               tile_size: tile_size,
               uri_format: uri_format,
               projection: projection,
               constructor: (void *)my_construct);
    }

    static Champlain.MapSource my_construct (Champlain.MapSourceDesc d) {
        var source =  new Champlain.NetworkTileSource.full(
            d.get_id(),
            d.get_name(),
            d.get_license(),
            d.get_license_uri(),
            d.get_min_zoom_level(),
            d.get_max_zoom_level(),
            d.get_tile_size(),
            d.get_projection(),
            d.get_uri_format(),
            new Champlain.ImageRenderer());
        return source;
    }
}

public class SoupProxy : Soup.Server {
    public bool offline = false;
    private Soup.Session session;
    private string? basename = null;
    private string? extname = null;

    public SoupProxy(bool _offline) {
		offline = _offline;
		this.add_handler (null, default_handler);
		session = new Soup.Session ();
		session.timeout = 5;
	}

	public void set_uri(string uri) {
		var parts = uri.split("#");
        if(parts.length == 3 && parts[1] == "Q") {
            basename = parts[0];
            extname = parts[2];
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

    private string rewrite_path(string p) {
        var parts = p.split("/");
        var np = parts.length-3;
        var fn = parts[np+2].split(".");
        var iz = int.parse(parts[np]);
        var ix = int.parse(parts[np+1]);
        var iy = int.parse(fn[0]);
        var q = quadkey(iz, ix, iy);
        StringBuilder sb = new StringBuilder(basename);
        sb.append(q);
        sb.append(extname);
        return sb.str;
    }

#if COLDSOUP
    private void default_handler (Soup.Server server, Soup.Message msg, string path,
								  GLib.HashTable? query, Soup.ClientContext client) {
#else
    private void default_handler (Soup.Server server, Soup.ServerMessage msg, string path,
								  GLib.HashTable? query) {
#endif
		if(offline || basename == null) {
#if COLDSOUP
            msg.set_status(404);
#else
            msg.set_status(404, null);
#endif
            return;
        }

#if COLDSOUP
        var method = msg.method;
#else
        var method = msg.get_method();
#endif

        if (method == "HEAD") {
            bool ok = false;
            Posix.Stat st;
            var parts = path.split("/");
            var np = parts.length;
            var fnstr = GLib.Path.build_filename(
                Environment.get_home_dir(),
                ".cache/champlain",
                JsonMapDef.id,
                parts[np-3],
                parts[np-2],
                parts[np-1]);

            if(Posix.stat(fnstr, out st) == 0) {
                ok = true;
                var dt = new DateTime.from_unix_utc(st.st_mtime);
                var dstr = dt.format("%a, %d %b %Y %H:%M:%S %Z");
#if COLDSOUP
                msg.response_headers.append("Content-Type","image/png");
                msg.response_headers.append("Accept-Ranges", "bytes");
                msg.response_headers.append("Last-Modified", dstr);
                msg.response_headers.append("Content-Length",
                                            st.st_size.to_string());
                msg.set_status(200);
#else
                msg.get_response_headers().append("Content-Type","image/png");
                msg.get_response_headers().append("Accept-Ranges", "bytes");
                msg.get_response_headers().append("Last-Modified", dstr);
                msg.get_response_headers().append("Content-Length", st.st_size.to_string());
                msg.set_status(200, null);
#endif
            }
            if(!ok) {
#if COLDSOUP
                msg.set_status(404);
#else
                msg.set_status(404,null);
#endif
            }
        } else
            if (method == "GET") {
            var xpath = rewrite_path(path);
            var message = new Soup.Message ("GET", xpath);
#if COLDSOUP
            session.send_message (message);
            if(message.status_code == 200) {
                msg.set_response ("image/png", Soup.MemoryUse.COPY,
                                  message.response_body.data);
            }
            msg.set_status(message.status_code);
#else
            try {
                var b = session.send_and_read (message);
                msg.set_response ("image/png", Soup.MemoryUse.COPY, b.get_data());
            } catch {}

            msg.set_status(message.status_code, null);
#endif
        } else {
#if COLDSOUP
            msg.set_status(404);
#else
            msg.set_status(404, null);
#endif
        }

#if COLDSOUP
        msg.response_headers.append("Server", "qk-proxy/1.0");
#else
        msg.get_response_headers().append("Server", "qk-proxy/1.0");
#endif
    }
}

public class BingMap : Object {
	public const string BURI="https://dev.virtualearth.net/REST/V1/Imagery/Metadata/Aerial/0,0?zl=1&include=ImageryProviders&key=";
    public const string KENC="QWwxYnFHYU5vZGVOQTcxYmxlSldmakZ2VzdmQXBqSk9vaE1TWjJfSjBIcGd0NE1HZExJWURiZ3BnQ1piWjF4QQ==";
	private string buri;
	private MapSource ms;
	private string savefile;

	public signal void complete(bool b);

	public BingMap() {
		savefile = GLib.Path.build_filename(Environment.get_user_config_dir(),"mwp",".blast");
		get_cached_data();
	}

	public string get_buri() {
		return buri;
	}

	public MapSource get_ms() {
		return ms;
	}

	private string validate_key() {
		var bk0 = Environment.get_variable("MWP_BING_KEY");
		var bk1 = (string)Base64.decode(BingMap.KENC);
		if (bk0 != null) {
			return bk0;
		} else {
			return bk1;
		}
	}

	public async void get_source() {
        StringBuilder sb = new StringBuilder(BingMap.BURI);
		var bk = validate_key();
		sb.append(bk);
        var session = new Soup.Session ();
        var message = new Soup.Message ("GET", sb.str);
#if COLDSOUP
		try {
			var resp = yield session.send_async (message);
			var data = new uint8[8192];
			yield resp.read_all_async(data, GLib.Priority.DEFAULT, null, null);
			var s = (string)data;
			parse_bing_json(s);
			complete(true);
		} catch (Error e) {
			complete(false);
		}
#else
		session.send_and_read_async.begin(message, 0, null, (obj,res) => {
				try {
                    var b = session.send_and_read_async.end(res);
					parse_bing_json((string)b.get_data());
					complete(true);
                } catch (Error e) {
					complete(false);
				}
			});
#endif
    }

	public void save_cached_data() {
		var fp = FileStream.open (savefile, "w");
		if(fp != null) {
			fp.printf("%s\n", buri);
			fp.printf("%d\n", ms.min_zoom);
			fp.printf("%d\n", ms.max_zoom);
			fp.printf("%d\n", ms.tile_size);
			fp.printf("%s\n", ms.licence);
		}
	}

	public void get_cached_data() {
		ms.id= "BingProxy";
		ms.name = "Bing Proxy";
		ms.min_zoom =  0;
		ms.max_zoom = 19;
		ms.tile_size = 256;
		ms.projection = MapProjection.MERCATOR;
		ms.uri_format = "";
		ms.licence = "(c) Microsoft Corporation and friends";
		ms.licence_uri = "http://www.bing.com/maps/";
		buri="http://ecn.t3.tiles.virtualearth.net/tiles/a#Q#.jpeg?g=13902";
		var fp = FileStream.open (savefile, "r");
		if(fp != null) {
			var n = 0;
			string? line;
			while ((line = fp.read_line()) != null) {
				switch(n) {
				case 0:
					buri = line;
					break;
				case 1:
					ms.min_zoom = int.parse(line);
					break;
				case 2:
					ms.max_zoom = int.parse(line);
					break;
				case 3:
					ms.tile_size = int.parse(line);
					break;
				case 4:
					ms.licence = line;
					break;
				default:
					break;
				}
				n += 1;
			}
		}
	}
	private void parse_bing_json(string s) {
		if(s.length > 0) {
			StringBuilder sb = new StringBuilder();
			try {
				var parser = new Json.Parser ();
				parser.load_from_data (s);
				int gmin = 999;
				int gmax = -1;
				double xmin,ymin;
				double xmax,ymax;
				int zmin = 999;
				int zmax = -1;
				int imgh =0, imgw = 0;

				var root_object = parser.get_root ().get_object ();
				foreach (var rsnode in
						 root_object.get_array_member ("resourceSets").get_elements ()) {
					var rsitem = rsnode.get_object ();
					foreach (var rxnode in
							 rsitem.get_array_member ("resources").get_elements ()) {
						var rxitem = rxnode.get_object ();
						buri = rxitem.get_string_member ("imageUrl");
						imgh = (int)rxitem.get_int_member("imageHeight");
						imgw = (int)rxitem.get_int_member("imageWidth");

						foreach (var pvnode in
								 rxitem.get_array_member ("imageryProviders").get_elements ()) {
							xmin = ymin = 999.0;
							xmax = ymax = -999;
							var pvitem = pvnode.get_object();
							foreach (var cvnode in
									 pvitem.get_array_member ("coverageAreas").get_elements ()) {
								var cvitem = cvnode.get_object();
								var _zmin = (int)cvitem.get_int_member("zoomMin");
								var _zmax = (int)cvitem.get_int_member("zoomMax");
								if(_zmin < zmin)
									zmin = _zmin;
								if(_zmax > zmax)
									zmax = _zmax;
								var bbarry = cvitem.get_array_member("bbox");
								var d = bbarry.get_double_element(0);
								if(d < ymin)
									ymin = d;
								d = bbarry.get_double_element(1);
								if(d < xmin)
									xmin = d;
								d = bbarry.get_double_element(2);
								if(d > ymax)
									ymax = d;
								d = bbarry.get_double_element(3);
								if(d > xmax)
									xmax = d;
							}
							if (zmin < gmin)
								gmin = zmin;
							if (zmax >  gmax)
								gmax = zmax;

							if(xmax-xmin > 359 && ymax-ymin > 179) {
								var pattr = pvitem.get_string_member("attribution");
								sb.append(pattr);
								sb.append(", ");
							}
						}
					}
				}
				sb.truncate(sb.len-2);
				ms.licence =  sb.str;
				ms.min_zoom = gmin-1;
				ms.max_zoom = gmax-1;
                     // notwithstanding what is advertised, this is the working max here, alas
				if(ms.max_zoom > 19)
					ms.max_zoom = 19;
				ms.tile_size = imgw;
			} catch (Error e) {
				MWPLog.message("bing parser %s\n", e.message);
			}
			if(buri.length > 0) {
				var parts = buri.split("/");
				sb.assign(parts[4].substring(0,1));
				sb.append("#Q#");
				sb.append(parts[4].substring(2,-1));
				parts[4] = sb.str;
				buri = string.joinv("/",parts);
				save_cached_data();
			}
		}
	}
}

public class JsonMapDef : Object {
    public static string id = null;
    private static int[] proxypids = {};
	private static SoupProxy sp;

	public static void killall() {
        foreach(var p in proxypids)
            Posix.kill(p, MwpSignals.Signal.TERM);
    }

	public static MapSource[] read_json_sources(string? fn, bool offline=false) {
        MapSource[] sources = {};

		var bg = new BingMap();

        var ms = bg.get_ms();
		MWPLog.message("Starting Bing proxy %s\n", (offline) ? "(offline)" : "");
		uint port = 0;
        sp = new SoupProxy(offline);
        try {
            sp.listen_local(0, 0);
            var u  = sp.get_uris();
            port = u.nth_data(0).get_port ();
        } catch { port = 0; }
		if (port != 0) {
			ms.uri_format="http://localhost:%u/quadkey-proxy/#Z#/#X#/#Y#.png".printf(port);
		}
		sources += ms;

		bg.complete.connect((ok) => {
				if(ok) {
					sp.set_uri(bg.get_buri());
				}
			});

		if(offline) {
			sp.set_uri(bg.get_buri());
		} else {
			bg.get_source.begin();
		}

        if(fn != null) {
            try {
                var parser = new Json.Parser ();
                parser.load_from_file (fn);
                var root_object = parser.get_root ().get_object ();
                foreach (var node in
                     root_object.get_array_member ("sources").get_elements ()) {
                    var s = MapSource();
                    var item = node.get_object ();
                    s.id = item.get_string_member ("id");
                    s.licence_uri = item.get_string_member("license_uri");
                    if(item.has_member("uri_format"))
                        s.uri_format = item.get_string_member("uri_format");

                bool skip = (s.id == "BingProxy" ||
                             s.uri_format ==
                             "http://localhost:21303/quadkey-proxy/#Z#/#X#/#Y#.png" ||
                             s.licence_uri == "http://www.bing.com/maps/");
                if(!skip) {
                    s.name = item.get_string_member ("name");
                    s.licence = item.get_string_member("license");
                    s.min_zoom = (int)item.get_int_member ("min_zoom");
                    s.max_zoom = (int) item.get_int_member ("max_zoom");
                    s.tile_size = (int)item.get_int_member("tile_size");
                    s.projection = Champlain.MapProjection.MERCATOR;
                    if(item.has_member("spawn")) {
                        var spawncmd = item.get_string_member("spawn");
                        var iport = spawn_proxy(spawncmd);
                        if(iport > 0)
                            s.uri_format="http://localhost:%u/p/#Z#/#X#/#Y#.png".printf(iport);
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
        return sources;
    }

    private static int spawn_proxy(string cmd) {
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
            if(eos != IOStatus.EOF && len != 0)
                line.scanf("Port: %d", &iport);
            MWPLog.message("External proxy \"%s\" listening on :%d\n", cmd, iport);
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

#if MTEST
namespace MwpSignals {
    public enum Signal {
        TERM =15
    }
}

namespace MWPLog {
    void message(string format, ...) {
        var args = va_list();
        var now = new DateTime.now_local ();
        StringBuilder sb = new StringBuilder();
        sb.append(now.format("%T.%f"));
        sb.append_c(' ');
        sb.append_vprintf(format, args);
        stderr.puts(sb.str);
    }
}

public static int main(string?[] args) {
    var ml = new MainLoop();
    MapSource [] msources = {};
	string msfn = "/home/jrh/.config/mwp/sources.json";
	Idle.add(() => {
			MWPLog.message("Starting map sources\n");
			msources = JsonMapDef.read_json_sources(msfn, true);
			MWPLog.message("Done map sources\n");
            return false;
        });
	ml.run();
	return 0;
}
#endif
