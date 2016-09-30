
class InputParser : GLib.Object
{
    private static Regex latrx = null;
    private static Regex lonrx = null;
    private const string LATSTR = "^(\\d{1,2})[ :\\-]?(\\d{2})[ :\\-]?([0-9\\.]{2,5})([NS])";
    private const string LONSTR = "^(\\d{1,3})[ :\\-]?(\\d{2})[ :\\-]?([0-9\\.]{2,5})([EW])";

    public static double get_latitude(string latstr)
    {
        MatchInfo mi;
        double lat = 0.0;
        if(latrx == null)
        {
            try {
                latrx = new Regex(LATSTR, RegexCompileFlags.CASELESS);
            } catch {};
        }

        if (latrx.match(latstr, 0, out mi))
        {
            lat = get_locale_double(mi.fetch(1))+(get_locale_double(mi.fetch(2)) +
                                                  get_locale_double(mi.fetch(3))/60.0)/60.0;
            if(mi.fetch(4) == "S")
                lat = -lat;
        }
        else
        {
            lat = get_locale_double(latstr);
        }
        return lat;
    }

    public static double get_longitude(string lonstr)
    {
        MatchInfo mi;
        double lon = 0.0;
        if(lonrx == null)
        {
            try {
                lonrx = new Regex(LONSTR, RegexCompileFlags.CASELESS);
            } catch {};
        }

        if (lonrx.match(lonstr, 0, out mi))
        {
            lon = get_locale_double(mi.fetch(1))+(get_locale_double(mi.fetch(2)) +
                                             get_locale_double(mi.fetch(3))/60.0)/60.0;
            if(mi.fetch(4) == "W")
                lon = -lon;
        }
        else
        {
            lon = get_locale_double(lonstr);
        }
        return lon;
    }

    public static double get_scaled_real(string v, string s = "d")
    {
        double d=0;
        d = get_locale_double(v);
        uint cvt;

        if(s == "d")
        {
            cvt = MWPlanner.conf.p_distance;
            if(cvt != 0 && d != 0.0)
            {
                switch(cvt)
                {
                    case 1:
                        d /= 3.2808399;
                        break;
                    case 2:
                        d /= 1.0936133;
                    break;
                    case 3:
                        d /= 0.0049709695;
                        break;
                }
            }
        }
        else
        {
            cvt = MWPlanner.conf.p_speed;
            if(cvt != 0 && d != 0.0)
            {
                switch(cvt)
                {
                    case 1:
                        d /= 3.6;
                        break;
                    case 2:
                        d /= 2.2369363;;
                        break;
                    case 3:
                        d /=1.9438445;
                        break;
                    case 4:
                        d /= 6012.8848;
                        break;
                }
            }
        }
        return d;
    }

    public static long get_scaled_int(string v,  string s = "d")
    {
        var d = get_scaled_real(v, s);
        return Math.lround(d);
    }

}
