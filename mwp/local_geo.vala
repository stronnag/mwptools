
private struct LLPos
{
    double lat;
    double lon;
}

private struct GridPos
{
    double x;
    double y;
}

private struct GridSet
{
    double xmin;
    double xmax;
    double ymin;
    double ymax;
    double xrange;
    double yrange;
    GridPos [] points;
}

public class FlatEarth : GLib.Object
{
    private static double sfact;
    private static LLPos origin;
    private const double DELTA_LON_EQUATOR = 1.113195;  // MagicEarthNumber from APM

    private static void set_origin(LLPos o)
    {
        origin.lat = o.lat;
        origin.lon = o.lon;
        sfact = Math.cos(((Math.fabs(origin.lat) )* 0.0174532925));
        if (sfact > 1.0)
            sfact = 1.0;
        if (sfact < 0.01)
            sfact = 0.01;
    }

    private static GridPos geo_to_flatearth (LLPos ici)
    {
        GridPos p = {0};
        p.y = (ici.lat - origin.lat) * DELTA_LON_EQUATOR;
        p.x = (ici.lon - origin.lon) * (DELTA_LON_EQUATOR * sfact);
        return p;
    }

        /* Because it plots .... */
    private static Gdk.Pixbuf? conspire (GridSet g, int width, int height)
    {
        double scale;
        int xaxis,yaxis;
        if (g.xrange > g.yrange)
        {
            scale = 256.0 / g.xrange;
            xaxis = 256;
            yaxis = (int)(g.yrange*scale + 0.5);
        }
        else
        {
            scale = 256.0 / g.yrange;
            yaxis = 256;
            xaxis = (int)(g.xrange*scale + 0.5);
        }
        var cst = new Cairo.ImageSurface (Cairo.Format.ARGB32, xaxis, yaxis);
        var cr = new Cairo.Context (cst);
        cr.set_line_cap(Cairo.LineCap.ROUND);
        cr.set_line_width(8);
        cr.set_source_rgb (0.81, 0, 0);
        var xp = scale*(g.points[0].x - g.xmin);
        var yp = scale*(g.ymax - g.points[0].y);
        cr.move_to(xp, yp);
        foreach (var p in g.points)
        {
            xp = scale*(p.x - g.xmin);
            yp = scale*(g.ymax - p.y);
            cr.line_to(xp, yp);
        }
        cr.stroke();
        var pixb = Gdk.pixbuf_get_from_surface (cst, 0, 0, xaxis, yaxis);
        return pixb;
    }

    public static Gdk.Pixbuf getpixbuf(string fn, int width, int height)
    {
        Gdk.Pixbuf spixb = null;
        var ms = new Mission ();
        if (ms.read_xml_file (fn) == true)
        {
            LLPos wpos = {0};
            GridPos gp = {0};
            GridPos [] gpa = {};
            GridSet gps = {};
            MissionItem []wps = ms.get_ways();

            gps.xmin = gps.ymin = 999;
            gps.xmax = gps.ymax = -999;

            LLPos origin= {wps[0].lat, wps[0].lon};
            set_origin (origin);

            foreach (var wp in wps)
            {
                if(wp.action != MSP.Action.WAYPOINT &&
                   wp.action != MSP.Action.POSHOLD_UNLIM &&
                   wp.action != MSP.Action.POSHOLD_TIME)
                    continue;
                wpos.lat = wp.lat;
                wpos.lon = wp.lon;
                gp = geo_to_flatearth(wpos);
                gp.x *= 1000000;
                gp.y *= 1000000;
                gpa += gp;
                if(gp.x < gps.xmin)
                    gps.xmin = gp.x;
                if(gp.x > gps.xmax)
                    gps.xmax = gp.x;
                if(gp.y < gps.ymin)
                    gps.ymin = gp.y;
                if(gp.y > gps.ymax)
                    gps.ymax = gp.y;
            }
            gps.points = gpa;
            gps.xrange = gps.xmax - gps.xmin;
            gps.yrange = gps.ymax - gps.ymin;
            spixb = conspire(gps, width, height);
        }
        return spixb;
    }
}
