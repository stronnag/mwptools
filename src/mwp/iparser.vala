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
            lat = DStr.strtod(mi.fetch(1),null) +
            (DStr.strtod(mi.fetch(2),null) +
             DStr.strtod(mi.fetch(3),null)/60.0)/60.0;
            if(mi.fetch(4) == "S")
                lat = -lat;
        }
        else
        {
            lat = DStr.strtod(latstr,null);
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
            lon = DStr.strtod(mi.fetch(1),null) + (
                DStr.strtod(mi.fetch(2),null) +
                DStr.strtod(mi.fetch(3),null)/60.0)/60.0;
            if(mi.fetch(4) == "W")
                lon = -lon;
        }
        else
        {
            lon = DStr.strtod(lonstr,null);
        }
        return lon;
    }

    public static double get_scaled_real(string v, string s = "d")
    {
        double d=0;
        d = DStr.strtod(v,null);
        uint cvt;

        if(s == "d")
        {
            cvt = MWP.conf.p_distance;
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
            cvt = MWP.conf.p_speed;
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
