
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

public struct MapSource
{
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

public class MwpMapSource : Champlain.MapSourceDesc
{
    public MwpMapSource (string id,
            string name,
            string license,
            string license_uri,
            int minzoom,
            int maxzoom,
            int tile_size,
            Champlain.MapProjection projection,
            string uri_format)
    {
        Object(id: id, name: name, license: license, license_uri: license_uri,
               min_zoom_level: minzoom, max_zoom_level: maxzoom,
               tile_size: tile_size,
               uri_format: uri_format,
               projection: projection,
               constructor: (void *)my_construct);
    }

    static Champlain.MapSource my_construct (Champlain.MapSourceDesc d)
    {
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

public class SoupProxy : Soup.Server
{
    private string basename;
    private string extname;
    public bool offline = false;
    private Soup.Session session;

    public SoupProxy(string uri)
    {
        var parts = uri.split("#");
        if(parts.length == 3 && parts[1] == "Q")
        {
            basename = parts[0];
            extname = parts[2];
            this.add_handler (null, default_handler);
            session = new Soup.Session ();
            session.timeout = 5;
            session.max_conns_per_host = 8;
        }
        else
        {
            MWPLog.message("Invalid quadkeys URI (%s)\n", uri);
            Posix.exit(255);
        }
    }

     ~SoupProxy()
     {
     }

    private string quadkey(int iz, int ix, int iy)
    {
        StringBuilder sb = new StringBuilder ();
        for (var i = iz - 1; i >= 0; i--)
        {
            char digit = '0';
            if ((ix & (1 << i)) != 0)
                digit += 1;
            if ((iy & (1 << i)) != 0)
                digit += 2;
            sb.append_unichar(digit);
        }
        return sb.str;
    }

    private string rewrite_path(string p)
    {
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

    private void default_handler (Soup.Server server,
                                  Soup.Message msg, string path,
                                  GLib.HashTable? query,
                                  Soup.ClientContext client)
    {
        if(offline)
        {
            msg.set_status(404);
            return;
        }

        if (msg.method == "HEAD")
        {
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

            if(Posix.stat(fnstr, out st) == 0)
            {
                ok = true;
                var dt = new DateTime.from_unix_utc(st.st_mtime);
                var dstr = dt.format("%a, %d %b %Y %H:%M:%S %Z");
                msg.response_headers.append("Content-Type","image/png");
                msg.response_headers.append("Accept-Ranges", "bytes");
                msg.response_headers.append("Last-Modified", dstr);
                msg.response_headers.append("Content-Length",
                                            st.st_size.to_string());
                msg.set_status(200);
            }
            if(!ok)
            {
                msg.set_status(404);
            }
        }
        else if (msg.method == "GET")
        {
            var xpath = rewrite_path(path);
            var message = new Soup.Message ("GET", xpath);

            session.send_message (message);
            if(message.status_code == 200)
            {
                msg.set_response ("image/png", Soup.MemoryUse.COPY,
                              message.response_body.data);
            }
            msg.set_status(message.status_code);
        }
        else
        {
            msg.set_status(404);
        }
        msg.response_headers.append("Server", "qk-proxy/1.0");
    }
}

public class BingMap : Object
{
    private const string BURI="https://dev.virtualearth.net/REST/V1/Imagery/Metadata/Aerial/0,0?zl=1&include=ImageryProviders&key=";
    private const string APIKEY="Al1bqGaNodeNA71bleJWfjFvW7fApjJOohMSZ2_J0Hpgt4MGdLIYDbgpgCZbZ1xA";

    public static bool get_source(out MapSource ms, out string buri)
    {
        StringBuilder sb = new StringBuilder(BURI);
        sb.append(APIKEY);
        var session = new Soup.Session ();
        var message = new Soup.Message ("GET", sb.str);
        session.send_message (message);
        string s="";;

        if ( message.status_code == 200)
            s = (string) message.response_body.flatten ().data;
        return parse_bing_json(s, out buri, out ms);
    }

    private static bool parse_bing_json(string s, out string buri, out MapSource ms)
    {
         bool res = false;
         ms = MapSource() {
             id= "BingProxy",
             name = "Bing Proxy",
             min_zoom =  0,
             max_zoom = 19,
             tile_size = 256,
             projection = MapProjection.MERCATOR,
             uri_format = "",
             licence = "(c) Microsoft Corporation and friends",
             licence_uri = "http://www.bing.com/maps/"
         };
         buri="http://ecn.t3.tiles.virtualearth.net/tiles/a#Q#.jpeg?g=6187";
         if(s.length > 0)
         {
             try
             {
                 var parser = new Json.Parser ();
                 parser.load_from_data (s);

                 int gmin = 999;
                 int gmax = -1;
                 double xmin,ymin;
                 double xmax,ymax;
                 StringBuilder sb = new StringBuilder();
                 int zmin = 999;
                 int zmax = -1;
                 int imgh =0, imgw = 0;

                 var root_object = parser.get_root ().get_object ();
                 foreach (var rsnode in
                          root_object.get_array_member ("resourceSets").get_elements ())
                 {
                     var rsitem = rsnode.get_object ();
                     foreach (var rxnode in
                              rsitem.get_array_member ("resources").get_elements ())
                     {
                         var rxitem = rxnode.get_object ();
                         buri = rxitem.get_string_member ("imageUrl");
                         imgh = (int)rxitem.get_int_member("imageHeight");
                         imgw = (int)rxitem.get_int_member("imageWidth");

                         foreach (var pvnode in
                                  rxitem.get_array_member ("imageryProviders").get_elements ())
                         {
                             xmin = ymin = 999.0;
                             xmax = ymax = -999;
                             var pvitem = pvnode.get_object();
                             foreach (var cvnode in
                                      pvitem.get_array_member ("coverageAreas").get_elements ())
                             {
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

                             if(xmax-xmin > 359 && ymax-ymin > 179)
                             {
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
                 if(ms.max_zoom > 19)
                     ms.max_zoom = 19;
                 ms.tile_size = imgw;
                 var parts = buri.split("/");
                 sb.truncate();
                 sb.append(parts[4].substring(0,1));
                 sb.append("#Q#");
                 sb.append(parts[4].substring(2,-1));
                 parts[4] = sb.str;
                 buri = string.joinv("/",parts);
                 res = true;
             } catch (Error e) {
                 MWPLog.message("bing parser %s\n", e.message);
             }
         }
         return res;
    }
}

public class JsonMapDef : Object
{
    public static string id = null;
    private static int[] proxypids = {};

    public static void killall()
    {
        foreach(var p in proxypids)
            Posix.kill(p, Posix.SIGTERM);
    }

    public static MapSource[] read_json_sources(string? fn, bool offline=false)
    {
        MapSource[] sources = {};
        MapSource s;
        string buri;
        uint port = 0;

        BingMap.get_source(out s, out buri);
        port  = run_proxy(buri, offline);
        if (port != 0)
        {
            s.uri_format="http://localhost:%u/quadkey-proxy/#Z#/#X#/#Y#.png".printf(port);
            sources += s;
            id = s.id;
        }

        if(fn != null)
        try {
            var parser = new Json.Parser ();
            parser.load_from_file (fn);
            var root_object = parser.get_root ().get_object ();
            foreach (var node in
                     root_object.get_array_member ("sources").get_elements ())
            {
                s = MapSource();
                var item = node.get_object ();
                s.id = item.get_string_member ("id");
                s.uri_format = item.get_string_member("uri_format");
                s.licence_uri = item.get_string_member("license_uri");
                bool skip = (s.id == "BingProxy" ||
                             s.uri_format ==
                             "http://localhost:21303/quadkey-proxy/#Z#/#X#/#Y#.png" ||
                             s.licence_uri == "http://www.bing.com/maps/");
                if(!skip)
                {
                    s.name = item.get_string_member ("name");
                    s.licence = item.get_string_member("license");
                    s.min_zoom = (int)item.get_int_member ("min_zoom");
                    s.max_zoom = (int) item.get_int_member ("max_zoom");
                    s.tile_size = (int)item.get_int_member("tile_size");
                    s.projection = Champlain.MapProjection.MERCATOR;
                    if(item.has_member("spawn"))
                    {
                        var spawncmd = item.get_string_member("spawn");
                        spawn_proxy(spawncmd);
                    }
                    sources += s;
                }
            }
        }
        catch (Error e) {
            MWPLog.message ("mapsources : %s\n", e.message);
        }
        return sources;
    }

    private static void spawn_proxy(string cmd)
    {
        string[]? argvp = null;
        try {
            int pid;
            Shell.parse_argv (cmd, out argvp);
            Process.spawn_async ("/",
                                 argvp,
                                 null,
                                 SpawnFlags.SEARCH_PATH |
                                 SpawnFlags.STDOUT_TO_DEV_NULL |
                                 SpawnFlags.STDERR_TO_DEV_NULL,
                                 null,
                                 out pid);
            MWPLog.message("Starting external %s process\n", argvp[0]);
            proxypids += pid;
        } catch {
            MWPLog.message("Failed to start external proxy process\n");
        }
    }

    private static uint run_proxy(string uri, bool offline)
    {
        uint port = 0;
        MWPLog.message("Starting Bing proxy %s\n", (offline) ? "(offline)" : "");
        var sp = new SoupProxy(uri);
        sp.offline = offline;
        try {
            sp.listen_all(0, 0);
            var u  = sp.get_uris();
            port = u.nth_data(0).get_port ();
        } catch { port = 0; }
        return port;
    }
}
