// valac --thread --pkg libsoup-2.4 --pkg json-glib-1.0 json-sample.vala#

public class BingElevations : Object {
    private const string MAP="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-";
    public struct Point {
        double y;
        double x;
    }

    public signal void elevations(int[]e);

    private static int [] parse_bing_elev(string s) {
        int []elevs= {};
        if(s.length > 0)
            try {
            var parser = new Json.Parser ();
            parser.load_from_data (s);
            var root = parser.get_root ().get_object ();
            foreach (var rsnode in root.get_array_member ("resourceSets").get_elements ())
            {
                var rsitem = rsnode.get_object ();
                foreach (var rxnode in
                         rsitem.get_array_member ("resources").get_elements ())
                {
                    var rxitem = rxnode.get_object ();
                    var elist = rxitem.get_array_member ("elevations");
                    elist.foreach_element ((a,i,n) => {
                            elevs += (int)n.get_int();
                        });
                }
            }
        } catch (Error e) {
            stderr.printf ("JSON parse: %s\n", e.message);
        }
        return elevs;
    }

    private static string pca (Point []points) {
        StringBuilder sb = new StringBuilder();
        int64 longitude = 0;
        int64 latitude = 0;
        foreach(var p in points) {
            int64 newLatitude =(int64)Math.round(p.y * 100000);
            int64 newLongitude = (int64)Math.round(p.x * 100000);

            int64 dy = newLatitude - latitude;
            int64 dx = newLongitude - longitude;
            latitude = newLatitude;
            longitude = newLongitude;
            dy = (dy << 1) ^ (dy >> 31);
            dx = (dx << 1) ^ (dx >> 31);
            var index = ((dy + dx) * (dy + dx + 1) / 2) + dy;
            while (index > 0) {
                var rem = index & 31;
                index = (index - rem) / 32;
                if (index > 0) rem += 32;
                char c = (char)MAP.data[rem];
                sb.append_c(c);
            }
        }
        return sb.str;
    }

    public static async int[] get_elevations(Point []pts) {
        int []elevs={};
        try {
            StringBuilder sb = new StringBuilder("https://dev.virtualearth.net/REST/V1/Elevation/List/?key=");
            sb.append((string)Base64.decode(BingMap.KENC));
            var pstr = "points=%s".printf(pca(pts));
            var session = new Soup.Session ();
            var msg = new Soup.Message ("POST", sb.str);
            msg.request_headers.append("Accept", "*/*");
            msg.request_headers.append ("Content-Type", "text/plain; charset=utf-8");
            msg.request_headers.append ("Content-Length", pstr.length.to_string());
            msg.set_request("text/plain", Soup.MemoryUse.TEMPORARY, pstr.data);
            var resp = yield session.send_async(msg);
            if (msg.status_code == Soup.Status.OK) {
                var data = new uint8[4096+8*pts.length];
                yield resp.read_all_async(data, GLib.Priority.DEFAULT, null, null);
                elevs = parse_bing_elev((string)data);
            }
        } catch (Error e) {stderr.printf("Get elevs : %s\n", e.message);}
        return elevs;
    }
}

#if TEST
// valac -D TEST --pkg libsoup-2.4 --pkg json-glib-1.0 -X -lm -o /tmp/melevtest   mwp_elevations.vala
namespace BingMap {
    public string KENC;
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


void fetch_points(BingElevations.Point []pts) {
    MWPLog.message("Click!\n");
    BingElevations.get_elevations.begin(pts, (obj, res) => {
            var elevs = BingElevations.get_elevations.end(res);
            if(elevs.length > 0) {
                MWPLog.message("[ ");
                foreach (var e in elevs) {
                    stdout.printf("%d ", e);
                }
                stdout.printf("]\n");
            }
        });
}

public static int main(string?[] args) {
    BingMap.KENC=args[1];

    BingElevations.Point []pts = {
        {54.1246100260987, -4.73209477294404},
        {54.1256398671789, -4.7353658418433},
        {54.1291110223104, -4.72942960645014},
        {54.132058087145,  -4.7311004648509},
        {54.1334003050251,  -4.72237688387395},
        {54.1372829217935,  -4.7197312726712},
        {54.144827752892,  -4.7121212485672},
        {54.1463031566675,  -4.70491621395922},
        {54.1497562527683,  -4.69493652621168},
        {54.1523636286874,  -4.67233330708041},
        {54.1482023304552,  -4.66885475914751},
        {54.1432440918571,  -4.67819920864713},
        {54.1340616705804,  -4.7031784723913},
        {54.1259340632735,  -4.71353626140626}
    };

    Gtk.init (ref args);
    var win = new Gtk.Window ();
    win.set_title ("Async Functions Test");
    win.set_default_size (800,100);
    win.set_border_width (2);
    win.destroy.connect (Gtk.main_quit);
    var spin = new Gtk.Spinner();
    var button = new Gtk.Button.with_label("Elevs");
    button.clicked.connect(() => {
            fetch_points(pts);
        });

    var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL,2);

    vbox.pack_start (spin, true, true, 0);
    vbox.pack_start (button, false, false, 0);
    win.add(vbox);
    spin.start();
    win.show_all();
    Gtk.main ();
    return 0;
}
