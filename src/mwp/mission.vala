
/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 3
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

public struct MissionItem
{
    int no;
    MSP.Action action;
    double lat;
    double lon;
    int alt;
    int param1;
    int param2;
    int param3;
    uint8 flag;
}

public class Mission : GLib.Object
{
    private MissionItem[] waypoints;
    public string? version;
    public double maxy;
    public double miny;
    public double maxx;
    public double minx;
    public double cy;
    public double cx;
    public double homey;
    public double homex;
    public uint npoints;
    public uint zoom;
    public double nspeed;
    public double dist;
    public int et;
    public int lt;
    public int maxalt;

    public Mission()
    {
        waypoints ={};
        version = null;
        npoints=0;
        maxy=-90;
        maxx=-180;
        miny=90;
        minx=180;
        cx = cy = 0;
        zoom = 0;
        maxalt = -2147483647;
        dist = -1;
        et = -1;
        lt = -1;
        nspeed = -1;
    }

    public MissionItem[] get_ways()
    {
        return waypoints;
    }

    public MissionItem? get_waypoint(uint n)
    {
        if(n < waypoints.length)
            return waypoints[n];
        else
            return null;
    }

    public void set_waypoint(MissionItem m, uint n)
    {
        if(n < waypoints.length)
            waypoints[n] = m;
    }

    public void set_ways(MissionItem[] m)
    {
        waypoints = m;
    }

    public bool is_valid()
    {
        if(waypoints.length > 60)
            return false;

            // Urg, Urg array index v. WP Nos ......
        for(var i = 0; i < waypoints.length; i++)
        {
            var target = waypoints[i].param1 - 1;
            if(waypoints[i].action == MSP.Action.JUMP)
            {
                if((i == 0) || ((target > (i-2)) && (target < (i+2)) ) || (target >= waypoints.length) || (waypoints[i].param2 < -1))
                    return false;
                if(!(waypoints[target].action == MSP.Action.WAYPOINT || waypoints[target].action == MSP.Action.POSHOLD_TIME || waypoints[target].action == MSP.Action.LAND))
                    return false;
            }
        }
        return true;
    }


    public void dump()
    {
        if(version != null)
            stdout.printf("Version: %s\n",version);
        foreach (var m in waypoints)
        {
            stdout.printf ("%d %s %f %f %u %d %d %d\n",
                           m.no,
                           MSP.get_wpname(m.action),
                           m.lat, m.lon, m.alt,
                           m.param1, m.param2, m.param3);
        }
        stdout.printf("lon (x)  min,max %f %f\n", minx, maxx);
        stdout.printf("lat (y) min,max %f %f\n", miny, maxy);
        stdout.printf("cy cx %f %f %d\n", cy, cx, (int)zoom);
        if(dist != 1)
        {
            stdout.printf("distance %.1f m\n", dist);
            stdout.printf("flight time %d s\n", et);
            if(lt != -1)
                stdout.printf("loiter time %d s\n", lt);
            if(nspeed == 0 && dist > 0 && et > 0)
                nspeed = dist / (et - 3*waypoints.length);
            stdout.printf("speed %.1f m/s\n", nspeed);

        }
        if(maxalt != 0x80000000)
            stdout.printf("max altitude %d\n", maxalt);

        stdout.printf("Mission is %svalid\n", (is_valid() == true) ? "" : "in");
    }

    public bool is_equal(Mission m)
    {
        var nwp = waypoints.length;
        var ways = m.get_ways();

        if(nwp != ways.length)
            return false;

        for(var i = 0; i < nwp; i++)
        {
/*******************
            StringBuilder sb = new StringBuilder();
            if(waypoints[i].no != ways[i].no)
                sb.append("no ");
            if(waypoints[i].action != ways[i].action)
                sb.append("act");
            if( waypoints[i].lat != ways[i].lat)
                sb.append("lat ");
            if(waypoints[i].lon != ways[i].lon)
                sb.append("lon ");
            if( waypoints[i].alt != ways[i].alt)
                sb.append("alt ");
            if(waypoints[i].param1 != ways[i].param1)
                sb.append("p1 ");
            if(waypoints[i].param2 != ways[i].param2)
                sb.append("p2 ");
            if(waypoints[i].param3 != ways[i].param3)
                sb.append("p3");
            if(sb.len > 0)
            {
                sb.prepend("WP differ : ");
                sb.append_printf(" -- WP %d\n", i+1);
                print(sb.str);
                return false;
            }
********************/
            if(waypoints[i].no != ways[i].no ||
               waypoints[i].action != ways[i].action ||
               waypoints[i].lat != ways[i].lat ||
               waypoints[i].lon != ways[i].lon ||
               waypoints[i].alt != ways[i].alt ||
               waypoints[i].param1 != ways[i].param1 ||
               waypoints[i].param2 != ways[i].param2 ||
               waypoints[i].param3 != ways[i].param3)
                return false;
        }
        return true;
    }

    public bool calculate_distance(out double d, out int lt)
    {
        var n = 0;
        var rpt = 0;
        double lx = 0.0,ly=0.0;
        bool ready = false;
        double dx,cse;
        d = 0.0;
        lt = 0;

        var nsize = waypoints.length;
        if(nsize == 0)
            return false;

        do
        {
            var typ = waypoints[n].action;

            if(typ == MSP.Action.JUMP && waypoints[n].param2 == -1)
            {
                d = 0.0;
                lt = 0;
                return false;
            }

            if (typ == MSP.Action.SET_POI)
            {
                n += 1;
                continue;
            }

            if (typ == MSP.Action.RTH)
            {
                break;
            }

            var cy = waypoints[n].lat;
            var cx = waypoints[n].lon;
            if (ready == true)
            {
                if(typ == MSP.Action.JUMP)
                {
                    var r = waypoints[n].param2;
                    rpt += 1;
                    if (rpt > r)
                        n += 1;
                    else
                        n = waypoints[n].param1 - 1;
                    continue;
                }
                Geo.csedist(ly,lx,cy,cx, out dx, out cse);
                d += dx;
                print("At WP #%d, delta = %6.1f dist = %6.1f\n", n+1, dx*1852.0, d*1852.0);

                if (typ == MSP.Action.POSHOLD_TIME)
                {
                    lt += waypoints[n].param1;
                }
                if (typ == MSP.Action.POSHOLD_UNLIM || typ == MSP.Action.LAND)
                {
                    break;
                }
                else
                {
                    n += 1;
                }
            }
            else
	    {
                ready = true;
                print("At WP #1, delta =    0.0 dist =    0.0\n");
		n += 1;
            }
            lx = cx;
            ly = cy;
        } while (n < nsize);
        d *= 1852.0;
        return true;
    }
}
