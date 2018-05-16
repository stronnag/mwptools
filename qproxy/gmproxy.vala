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

/************************************************************************
 *
 * gmproxy is a champlain proxy for a well known proprietary map service
 *
 * If a definiton appears in sources.json, a proxy will be started
 * where the definiton includes a 'spawn' line.
 * e.g. for a mythical provider "Zoogle", with the following entry in sources.json:
 *
 *   {
 *       "id": "gm",
 *       "name": "GM Proxy",
 *       "license": "(c) Zoogle ",
 *       "license_uri": "http://maps.zoogle.com/",
 *       "min_zoom": 0,
 *       "max_zoom": 21,
 *       "tile_size": 256,
 *       "projection": "MERCATOR",
 *       "uri_format": "http://localhost:21305/gm/#Z#/#X#/#Y#.png",
 *       "spawn" : "gmproxy 21305",
 *       "warning" : "The only user changeable part of the uri is the port number (21305) which must be consistent"
 *  }
 *
 *
 ************************************************************************/

public class GMProxy : Soup.Server
{
    private string gvers = null;
    private const string SECGOOGLEWORD="Galileo";
    private const string GVERSTR="\"*https://khms\\D?\\d.google.com/kh\\?v=(\\d*)";
    private const string GURL = "http://maps.google.com/maps/api/js?v=3.2&sensor=false";
    private const string GMURI = "http://%s%d.google.com/%s/v=%s&hl=%s&x=%d%s&y=%d&z=%d&s=%s";
    private const string UASTR = "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:%d1.0) Gecko/%d%d%d Firefox/%d.0.%d";

    public GMProxy()
    {
        this.add_handler (null, default_handler);
        gvers = get_google_api();
    }

    private string? get_google_api()
    {
        var session = new Soup.Session ();
        var message = new Soup.Message ("GET", GURL);
        message.request_headers.append("User-Agent",make_ua());
        session.send_message (message);
        string s=null;
        if ( message.status_code == 200)
            s = (string) message.response_body.flatten().data;
        return get_google_version(s);
    }

    private int get_server_num(int ix, int iy, int pmax)
    {
        return (ix + (2 * iy)) % pmax;
    }

    void get_sec_google_words(int x, int y, out string sec1, out string sec2)
    {
        sec1 = ""; // after &x=...
        sec2 = ""; // after &zoom=...
        int seclen = ((x * 3) + y) % 8;
        sec2 = SECGOOGLEWORD.substring(0,seclen);
        if(y >= 10000 && y < 100000)
            sec1 = "&s=";
    }
    string? get_google_version(string? ss)
    {
        string str = null;
        MatchInfo mi;
        try {
            Regex regx = new Regex(GVERSTR, RegexCompileFlags.CASELESS);
            if (regx.match(ss, 0, out mi))
                str = mi.fetch(1);
        } catch {};
        return str;
    }

    private string ? make_guri(string vers, int x, int y, int z)
    {
        const string server = "khm";
        const string request = "kh";
        string sec1, sec2;
        get_sec_google_words(x, y, out sec1,  out sec2);
        string u = GMURI.printf(
            server, get_server_num(x,y,4), request, vers,
            "en", x, sec1, y, z, sec2);
        return u;
    }

    private string rewrite_path(string p)
    {
        var parts = p.split("/");
        var np = parts.length-3;
        var fn = parts[np+2].split(".");
        var iz = int.parse(parts[np]);
        var ix = int.parse(parts[np+1]);
        var iy = int.parse(fn[0]);
        string uri = make_guri(gvers,ix,iy,iz);
        return uri;
    }

    private string make_ua()
    {
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

    private void default_handler (Soup.Server server, Soup.Message msg, string path,
                          GLib.HashTable? query, Soup.ClientContext client)
    {
        if(gvers == null)
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
                parts[np-4],
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
            var session = new Soup.Session ();
            var message = new Soup.Message ("GET", xpath);
            message.request_headers.append("Referrer", "https://maps.google.com/");
            message.request_headers.append("User-Agent",make_ua());
            message.request_headers.append("Accept","*/*");

            session.send_message (message);
            if(message.status_code == 200)
            {
                msg.set_response ("image/jpeg", Soup.MemoryUse.COPY,
                                  message.response_body.data);
            }
            msg.set_status(message.status_code);
        }
        else
        {
            msg.set_status(404);
        }
    }

    public static int main (string []args)
    {
        int oport = 8088;
        var loop = new MainLoop();
        if (args.length > 1)
        {
            oport = int.parse(args[1]);
            var o = new GMProxy();
            try {
                o.listen_all(oport, 0);
                loop.run();
            } catch (Error e) {
                stdout.printf ("Error: %s\n", e.message);
            }
        }
        else
        {
            stderr.puts("gmproxy port\n");
        }
        return 0;
    }
}
