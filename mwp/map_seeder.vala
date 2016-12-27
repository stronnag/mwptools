//using Soup;

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

public class TileUtil : Object
{

    private enum TILE_ITER_RES {
        DONE=-1,
        FETCH=0,
        SKIP=1
    }

    public struct TileList
    {
        int z;
        int sx;
        int ex;
        int sy;
        int ey;
    }

    public struct TileStats
    {
        uint nt;
        uint skip;
        uint dlok;
        uint dlerr;
    }

    private double maxlat;
    private double minlat;
    private double minlon;
    private double maxlon;
    private int minzoom;
    private int maxzoom;
    private string uri;
    private int in;
    private int ix;
    private int iy;
    private long delta;
    private bool done;
    private File file;
    private TileList[] tl;
    private string cachedir;
    private Soup.Session session;
    private TileStats stats;

    public TileUtil()
    {
    }

    public signal void show_stats (TileStats ts);
    public signal void tile_done ();

    public void set_range(double _minlat, double _minlon, double _maxlat, double _maxlon)
    {
        minlat = _minlat;
        minlon = _minlon;
        maxlat = _maxlat;
        maxlon = _maxlon;
    }

    public void set_zooms(int _minzoom, int _maxzoom)
    {
        minzoom = _minzoom;
        maxzoom = _maxzoom;
    }

    public void set_misc(string name, string _uri)
    {
        uri = _uri;
        var s = Environment.get_user_cache_dir();
        cachedir = Path.build_filename(s,"champlain",name);
    }

    public TileStats build_table()
    {
        var inc = 0;
        stats.nt = 0;
        stats.dlok = 0;
        stats.dlerr = 0;

        tl={};

        for(var z = maxzoom; z >= minzoom; z--)
        {
            var m = TileList();
            m.z = z;
            ll2tile(maxlat, minlon, z, out m.sx, out m.sy);
            ll2tile(minlat, maxlon, z, out m.ex, out m.ey);
            if(inc != 0)
            {
                m.sx -= inc;
                m.sy -= inc;
                m.ex += inc;
                m.ey += inc;
            }
            inc++;
            stats.nt += (1 + m.ex - m.sx) * (1  + m.ey - m.sy);
            tl += m;
        }
        in = 0;
        ix = tl[0].sx;
        iy = tl[0].sy;
        done = false;
        return stats;
    }

/*
    public void dump_tl()
    {
        foreach(var m in tl)
        {
            MWPLog.message("%d %d %d %d %d\n", m.z, m.sx, m.sy, m.ex, m.ey);
        }
    }
*/
    public void ll2tile(double lat, double lon, int zoom, out int x, out int y)
    {
        x = (int)Math.floor((lon + 180.0) / 360.0 * (1 << zoom));
        y = (int)Math.floor(((1.0 - Math.log(Math.tan(lat*Math.PI/180.0)+1.0/Math.cos(lat*Math.PI/180.0))/Math.PI) / 2.0 * (1 << zoom)));
        return;
    }

    public void tile2ll(int x, int y, int zoom, out double lat, out double lon)
    {
        double n = Math.PI - ((2.0 * Math.PI * y) / Math.pow(2.0, zoom));
        lon = (x / Math.pow(2.0, zoom) * 360.0) - 180.0;
        lat = 180.0 / Math.PI * Math.atan(Math.sinh(n));
    }

    private TILE_ITER_RES get_next_tile(out string? s )
    {
        TILE_ITER_RES r = TILE_ITER_RES.FETCH;
        s = null;

        if(done)
            r = TILE_ITER_RES.DONE;
        else
        {
            var fn = Path.build_filename(cachedir,
                                        tl[in].z.to_string(),ix.to_string(),
                                         "%d.png".printf(iy));
            file = File.new_for_path(fn);

            if(iy == tl[in].sy)
            {
                File f = file.get_parent();
                if(f.query_exists() == false)
                {
                    try {
                        f.make_directory_with_parents();
                    } catch {};
                }
            }

            if(delta > 0)
            {
                if (file.query_exists() == true)
                {
                    try {
                        var fi = file.query_info("*", FileQueryInfoFlags.NONE);
                        var tv = fi.get_modification_time ();
                        if(tv.tv_sec > delta)
                        {
                            r = TILE_ITER_RES.SKIP;
                            stats.skip++;
                        }
                    } catch {};
                }
            }

            if(r ==  TILE_ITER_RES.FETCH)
                s = uri_builder();

            if(iy ==  tl[in].ey) // end of row
            {
                if (ix == tl[in].ex)
                {
                    in += 1;
                    if(in == tl.length)
                    {
                        in = 0;
                        ix = tl[0].sx;
                        iy = tl[0].sy;
                        done=true;
                    }
                    else
                    {
                        ix = tl[in].sx;
                        iy = tl[in].sy;
                    }
                }
                else
                {
                    ix++;
                    iy = tl[in].sy;
                }
            }
            else
            {
                iy++;
            }
        }
        return r;
    }

    private string quadkey()
    {
        StringBuilder sb = new StringBuilder ();
        for (var i = tl[in].z - 1; i >= 0; i--)
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


    private string uri_builder()
    {
        StringBuilder sb = new StringBuilder ();
        var tokens = uri.split("#");
        foreach(var t in tokens)
        {
            switch(t)
            {
                case "Q":
                    var s = quadkey();
                    sb.append(s);
                    break;
                case "X":
                    var s = "%d".printf(ix);
                    sb.append(s);
                    break;
                case "Y":
                    var s = "%d".printf(iy);
                    sb.append(s);
                    break;
                case "Z":
                    var s = "%d".printf(tl[in].z);
                    sb.append(s);
                    break;
                case "TMSY":
                    int yval = (1 << tl[in].z) - iy - 1;
                    var s = "%d".printf(yval);
                    sb.append(s);
                    break;
                default:
                    sb.append(t);
                    break;
            }
        }
        return sb.str;
    }

    public void start_seeding()
    {
        session = new Soup.Session();
        session.ssl_strict = false; // for OSM alas
        done = false;
        fetch_tile();
    }

    public void fetch_tile()
    {
        TILE_ITER_RES r = TILE_ITER_RES.SKIP;
        string tile_uri = null;

        do
        {
            r = get_next_tile(out tile_uri);
        } while (r == TILE_ITER_RES.SKIP);

        if(r == TILE_ITER_RES.FETCH)
        {
            var message = new Soup.Message ("GET", tile_uri);
            session.queue_message (message, end_session);
        }
        show_stats(stats);
        if(r == TILE_ITER_RES.DONE)
        {
            tile_done();
        }
    }

    void end_session(Soup.Session sess, Soup.Message msg)
    {
        if(msg.status_code == 200)
        {
            stats.dlok++;
            try {
                file.replace_contents(msg.response_body.data,null,
                                      false,FileCreateFlags.REPLACE_DESTINATION,null);
            } catch {
            };
        }
        else
        {
            MWPLog.message("Tile failure status %u\n", msg.status_code);
            stats.dlerr++;
        }

        fetch_tile();
    }

    public void set_delta(uint days)
    {
        var t = TimeVal();
        t.get_current_time ();
        delta = t.tv_sec - (24*3600)*days;
    }

    public void stop()
    {
        done = true;
    }
}
/*
int main (string[] args)
{
    var t  = new TileUtil();
    t.set_range(50.909728963857546, -1.5354330310947262,
               50.91093629762021, -1.533469266105385);

    if(args[1] == "ms")
    {
        t.set_zooms(15,19);
        t.set_misc("Bing", "http://h0.ortho.tiles.virtualearth.net/tiles/h#Q#.jpeg?g=131");
    }
    else
    {
        t.set_zooms(15,17);
        t.set_misc("localcache",
                   "http://ugeo/mapcache/tms/1.0.0/nsites@GoogleMapsCompatible/#Z#/#X#/#TMSY#.png");
    }
    t.set_delta(30);
    var nt = t.build_table();
    MWPLog.message("%u tiles\n", nt);
    var app = new GLib.MainLoop();

    t.show_stats.connect((ts) => {
            stdout.printf("%u / %u / %u / %u\n", ts.dlerr, ts.skip, ts.dlok, ts.nt);
        });


    t.tile_done.connect(() => { app.quit();});

    Idle.add(() => {
            t.start_seeding();
            return false;
        });


    app.run();
    return 0;
}
*/
