
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
public class Geo {
    private static double d2r(double d) {
        return d*(Math.PI/180.0);
    }

    private static double r2d(double r) {
        return r/(Math.PI/180.0);
    }

    private static double nm2r(double nm) {
        return (Math.PI/(180.0*60.0))*nm;
    }

    private static double r2nm(double r) {
        return ((180*60)/Math.PI)*r;
    }

    public static void csedist(double lat1, double lon1, double lat2, double lon2, out double d, out double cse) {
        lat1 = d2r(lat1);
        lon1 = d2r(lon1);
        lat2 = d2r(lat2);
        lon2 = d2r(lon2);
        var p1 = Math.sin((lat1-lat2)/2.0);
        var p2 = Math.cos(lat1)*Math.cos(lat2);
        var p3 = Math.sin((lon2-lon1)/2.0);
        d = 2.0*Math.asin(Math.sqrt( (p1*p1) + p2*(p3*p3)));
        d = r2nm(d);
        cse =  (Math.atan2(Math.sin(lon2-lon1)*Math.cos(lat2),
                           Math.cos(lat1)*Math.sin(lat2)-Math.sin(lat1)*Math.cos(lat2)*Math.cos(lon2-lon1))) % (2.0*Math.PI);
        cse = r2d(cse);
        if(cse < 0.0)
            cse += 360;
    }

    public static void posit (double lat1, double lon1, double cse, double dist,
							  out double lat, out double lon, bool rhumb = false) {

        double tc = d2r(cse);
        double rlat1= d2r(lat1);
        double rdist = nm2r(dist);
        double dphi,q,dlon;

        if (rhumb == true) {
                // Use Rhumb lines
            dphi = 0.0;
            lat= rlat1+rdist*Math.cos(tc);
            double tmp = Math.tan(lat/2.0+Math.PI/4.0)/Math.tan(rlat1/2.0+Math.PI/4.0);
            if(tmp <= 0)
                tmp = 0.000000001;

            dphi=Math.log(tmp);
            if (dphi == 0.0 || Math.fabs(lat-rlat1) < 1.0e-6)
                q=Math.cos(rlat1);
            else
                q= (lat-rlat1)/dphi;
            dlon = rdist*Math.sin(tc)/q;
            lon = ((d2r(lon1)+dlon+Math.PI) % (2*Math.PI)) - Math.PI;
        } else {
            lat = Math.asin(Math.sin(rlat1)*Math.cos(rdist)+Math.cos(rlat1)* Math.sin(rdist)*Math.cos(tc));
            dlon = Math.atan2(Math.sin(tc)*Math.sin(rdist)*Math.cos(rlat1),
                              Math.cos(rdist)-Math.sin(rlat1)*Math.sin(lat));
            lon = ((Math.PI + d2r(lon1) + dlon) % (2 * Math.PI)) - Math.PI;
        }
        lat=r2d(lat);
        lon = r2d(lon);
    }
}
