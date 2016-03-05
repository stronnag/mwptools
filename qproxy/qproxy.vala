/************************************************************************
 *
 * qproxy is a champlain proxy for a number of semi-obfuscated sources
 *
 * If a definiton appears in sources.json, a proxy will be started
 * where the definiton includes a 'spawn' line.
 * As a ** backward compatible special case ** , a proxy will also be started if the
 * URI contains host localhost and path quadkey-proxy
 *
 * e.g. for a mythical provider "Vio", with the following entry in sources.json:
 *
 *   {
 *       "id": "Vio",
 *       "name": "Vio Proxy",
 *       "license": "(c) VIO ",
 *       "license_uri": "http://maps.vio.com/",
 *       "min_zoom": 0,
 *       "max_zoom": 19,
 *       "tile_size": 256,
 *       "projection": "MERCATOR",
 *       "uri_format": "http://localhost:21305/vio/#Z#/#X#/#Y#.png",
 *       "spawn" : "qproxy http://#C#.maptile.maps.svc.vio.com/maptiler/v2/maptile/newest/satellite.day/#Z#/#X#/#Y#/256/png8 21305",
 *       "warning" : "The only user changeable part of the uri is the port number (21305) which must be consistent"
 *  }
 *
 * Note: This will build on Ubuntu LTS, with its ancient Soup version
 * It will not build on modern operating systems
 *
 ************************************************************************/

public class QProxy : GLib.Object
{
    private string [] p_uri;
    private const string UrlServerLetters = "bcde";

    public QProxy(string _uri)
    {
        p_uri = _uri.split("#");
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
        stderr.printf("request %s\n", path);
        var xpath = rewrite_path(path);
        stderr.printf("fetch %s\n", xpath);
        var session = new Soup.Session ();
        var message = new Soup.Message ("GET", xpath);

            /* send a sync request */
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

    private void proxy(int port)
    {
        var server = new Soup.Server (Soup.SERVER_PORT, port);
        server.add_handler (null, default_handler);
        server.run ();
    }

    public static int main (string []args)
    {
        if (args.length > 2)
        {
            var port = int.parse(args[2]);
            var q = new QProxy(args[1]);
            q.proxy(port);
        }
        else
        {
            stderr.puts("qproxy uri port\n");
        }
        return 0;
    }
}
