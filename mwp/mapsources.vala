
/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
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
    string proj;
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
            /* the 0.12 vapi appears not to support projection
             * as a property
             */
        Object(id: id, name: name, license: license, license_uri: license_uri,
               min_zoom_level: minzoom, max_zoom_level: maxzoom,
               tile_size: tile_size,
               uri_format: uri_format,
               data: (void *)projection,
               constructor: (void*)my_construct);
    }

    static Champlain.MapSource my_construct (Champlain.MapSourceDesc d)
    {
        var renderer = new Champlain.ImageRenderer();
        Champlain.MapProjection proj =  (Champlain.MapProjection)d.get_data();
        var source =  new Champlain.NetworkTileSource.full(
            d.get_id(),
            d.get_name(),
            d.get_license(),
            d.get_license_uri(),
            d.get_min_zoom_level(),
            d.get_max_zoom_level(),
            d.get_tile_size(),
            proj,
            d.get_uri_format(),
            renderer);
        return source;
    }
}

public class SoupProxy : Soup.Server
{
    private string basefmt;
    public SoupProxy(int p, string uri)
    {
        basefmt = uri;
        this.add_handler (null, default_handler);
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
        return basefmt.printf(q);
    }

    private void default_handler (Soup.Server server,
                                  Soup.Message msg, string path,
                                  GLib.HashTable? query,
                                  Soup.ClientContext client)
    {
        var xpath = rewrite_path(path);
        var session = new Soup.Session ();
        var message = new Soup.Message ("GET", xpath);

            /* send a sync request */
        session.send_message (message);

        if(message.status_code == 200)
        {
            msg.set_response ("image/png", Soup.MemoryUse.COPY,
                              message.response_body.data);
        }
        msg.set_status(message.status_code);
    }
}

public class JsonMapDef : Object
{
    private static Regex rx = null;
    public static int port = 0;

    private static void check_proxy(string s)
    {
        MatchInfo mi = null;
        if(rx == null)
        {
            rx = new Regex("localhost:(?<port>\\d+)\\/quadkey-proxy\\/");
        }
        if((port == 0) && rx.match(s,0,out mi))
        {
            var p = mi.fetch_named("port");
            if(p != null)
            {
                port = int.parse(p);
            }
        }
    }

    public static MapSource[] read_json_sources(string fn)
    {
        MapSource[] sources = {};

        try {
            var parser = new Json.Parser ();
            parser.load_from_file (fn);
            var root_object = parser.get_root ().get_object ();
            foreach (var node in
                     root_object.get_array_member ("sources").get_elements ())
            {
                var s = MapSource();
                var item = node.get_object ();
                s.name = item.get_string_member ("name");
                s.id = item.get_string_member ("id");
                s.min_zoom = (int)item.get_int_member ("min_zoom");
                s.max_zoom = (int) item.get_int_member ("max_zoom");
                s.tile_size = (int)item.get_int_member("tile_size");
                s.proj = item.get_string_member("projection");
                s.uri_format = item.get_string_member("uri_format");
                s.licence = item.get_string_member("license");
                s.licence_uri = item.get_string_member("license_uri");
                check_proxy(s.uri_format);
                sources += s;
            }
        }
        catch (Error e) {
            MWPLog.message ("I guess something is not working...\n");
        }
        return sources;
    }

    public static void run_proxy(int pt, string uri)
    {
        stderr.puts("Starting proxy thread\n");
        new Thread<int>("proxy",() => {
                var sp = new SoupProxy(pt,uri);
                stderr.puts("Running proxy thread\n");
                sp.listen_all(pt, 0);
                return 43;
            });
    }
}
