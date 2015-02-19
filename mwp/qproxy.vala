
public class QProxy : GLib.Object
{
    private int port = 0;
    private string uri;
    private string basename;
    private string extname;

    public QProxy(string _uri, int _port)
    {
        port = _port;
        uri = _uri;
        var parts = uri.split("#");
        if(parts.length == 3 && parts[1] == "Q")
        {
            basename = parts[0];
            extname = parts[2];
        }
        else
        {
            stderr.printf("Invalid quadkeys URI (%s)\n", uri);
            Posix.exit(255);
        }
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
        StringBuilder sb = new StringBuilder();
        sb.append(basename);
        sb.append(q);
        sb.append(extname);
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

    private void proxy()
    {
        var server = new Soup.Server (Soup.SERVER_PORT, port);
        server.add_handler (null, default_handler);
        server.run ();
    }

    public static int main (string []args)
    {
        int port = 8088;
        if (args.length > 2)
        {
            port = int.parse(args[1]);
            var q = new QProxy(args[2], port);
            q.proxy();
        }
        else
        {
            stderr.puts("qproxy port uri\n");
        }
        return 0;
    }
}
