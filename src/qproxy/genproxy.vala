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
 * genproxy is a champlain proxy for a number of semi-obfuscated sources
 *
 * If a definiton appears in sources.json, a proxy will be started
 * where the definiton includes a 'spawn' line.
 *   {
 *	   "id": "VEarth",
 *	   "name": "Virtual Earth",
 *	   "license": "(c) MS",
 *	   "license_uri": "http://localhost",
 *	   "min_zoom": 0,
 *	   "max_zoom": 19,
 *	   "tile_size": 256,
 *	   "projection": "MERCATOR",
 *	   "uri_format": "http://ecn.t3.tiles.virtualearth.net/tiles/a#Q#.jpeg?g=1",
 *	   "spawn": "genproxy http://ecn.t3.tiles.virtualearth.net/tiles/a#Q#.jpeg?g=1"
 *   }
 *
 ************************************************************************/

public class GenProxy : Soup.Server
{
    private string [] p_uri;
    private const string UrlServerLetters = "bcde";

    public GenProxy(string uri)
    {
        p_uri = uri.split("#");
        this.add_handler (null, default_handler);
    }

    private int getservernum(int ix, int iy, int pmax)
    {
        return (ix + (2 * iy)) % pmax;
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

        StringBuilder sb = new StringBuilder();

        foreach(var up in p_uri)
        {
            if(up == "N")
            {
                var num = getservernum(ix,iy,4);
                sb.append("%d".printf(num+1));
            }
            else if (up == "C")
            {
                var num = getservernum(ix,iy,4);
                var sno = UrlServerLetters.data[num];
                sb.append("%c".printf(sno));
            }
            else if (up == "X")
            {
                sb.append("%d".printf(ix));
            }
            else if (up == "Y")
            {
                sb.append("%d".printf(iy));
            }
            else if (up == "Z")
            {
                sb.append("%d".printf(iz));
            }
            else if (up == "Q")
            {
                var q = quadkey(iz, ix, iy);
                sb.append(q);
            }
            else
            {
                sb.append(up);
            }
        }
        return sb.str;
    }

    private void default_handler (Soup.Server server, Soup.Message msg, string path,
                          GLib.HashTable? query, Soup.ClientContext client)
    {
        if (msg.method == "GET")
        {
            stderr.printf("request %s\n", path);
            var xpath = rewrite_path(path);
            stderr.printf("fetch %s\n", xpath);
            var session = new Soup.Session ();
            var message = new Soup.Message ("GET", xpath);

                // send a sync request
            session.send_message (message);
            stderr.printf ("Message length: %lld %d\n",
                           message.response_body.length,
                           message.status_code);

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
    }

    public static int main (string []args)
    {
        var loop = new MainLoop();
        if (args.length > 1)
        {
            var o = new GenProxy(args[1]);
            try {
                o.listen_all(0, 0);
				var port = o.get_uris().nth_data(0).get_port ();
				print ("Port: %u\n", port);
                loop.run();
            } catch (Error e) {
                stderr.printf ("Error: %s\n", e.message);
            }
        } else {
            stderr.puts("genproxy uri\n");
        }
        return 0;
    }
}
