// valac --thread --pkg libsoup-2.4 --pkg json-glib-1.0 json-sample.vala#

public class BingElevations : Object {
    private const string MAP="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-";
    public struct Point
    {
        double y;
        double x;
    }

    private static int [] parse_bing_elev(string s)
    {
        int []elevs= {};
        if(s.length > 0)
            try
        {
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

    private static string pca (Point []points)
    {
        StringBuilder sb = new StringBuilder();
        int64 longitude = 0;
        int64 latitude = 0;
        foreach(var p in points)
        {
            int64 newLatitude =(int64)Math.round(p.y * 100000);
            int64 newLongitude = (int64)Math.round(p.x * 100000);

            int64 dy = newLatitude - latitude;
            int64 dx = newLongitude - longitude;
            latitude = newLatitude;
            longitude = newLongitude;
            dy = (dy << 1) ^ (dy >> 31);
            dx = (dx << 1) ^ (dx >> 31);
            var index = ((dy + dx) * (dy + dx + 1) / 2) + dy;
            while (index > 0)
            {
                var rem = index & 31;
                index = (index - rem) / 32;
                if (index > 0) rem += 32;
                char c = (char)MAP.data[rem];
                sb.append_c(c);
            }
        }
        return sb.str;
    }

    private static string get_json(Point []pts)
    {
        string s = null;
        StringBuilder sb = new StringBuilder("https://dev.virtualearth.net/REST/V1/Elevation/List/?key=");
        sb.append((string)Base64.decode(BingMap.KENC));
        var pstr = "points=%s".printf(pca(pts));
        var session = new Soup.Session ();
        var msg = new Soup.Message ("POST", sb.str);
        msg.request_headers.append("Accept", "*/*");
        msg.request_headers.append ("Content-Type", "text/plain; charset=utf-8");
        msg.request_headers.append ("Content-Length", pstr.length.to_string());
        msg.set_request("text/plain", Soup.MemoryUse.TEMPORARY, pstr.data);
        session.send_message (msg);
        if ( msg.status_code == 200)
        {
            s = (string) msg.response_body.flatten ().data;
        }
        return s;
    }

    public static int []get_elevations(Point []pts)
    {
        int []elevs={};
        var s  = get_json(pts);
        if (s != null) {
            elevs = parse_bing_elev(s);
        }
        return elevs;
    }
}

/****************
int main (string[]? args)
{
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

    var elevs = BingElevations.get_elevations(pts, 0);
    {
        foreach (var e in elevs)
        {
            stdout.printf("%d ", e);
        }
        stdout.printf("\n");
    }
    return 0;
}
*********************/
