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
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public const int SPEED_CONV = 100;
public struct mstat {
	int next;
	int cse;
	double dist;
}

public class MissionItem : Object {
	public int no {get; construct set;}
    public Msp.Action action {get; construct set;}
    public double lat {get; construct set;}
    public double lon {get; construct set;}
    public int alt {get; construct set;}
	public int param1 {get; construct set;}
    public int param2 {get; construct set;}
    public int param3 {get; construct set;}
    public uint8 flag {get; construct set;}

	// mwp field(s)
	public mstat []stats;
	public uint8 _mflag;

	public MissionItem() {}

	public MissionItem.full(int no, Msp.Action action, double lat, double lon, int alt, int p1, int p2, int p3,uint8 flag){
		this.no = no;
		this.action = action;
		this.lat = lat;
		this.lon = lon;
		this.alt = alt;
		this.param1 = p1;
		this.param2 = p2;
		this.param3 = p3;
		this.flag = flag;
	}

	public bool is_geo() {
		return (action != Msp.Action.RTH && action != Msp.Action.JUMP && action != Msp.Action.SET_HEAD);
	}

	public string format_lat() {
    if (is_geo()) {
      return PosFormat.lat(lat, Mwp.conf.dms);
    } else {
      return "";
    }
  }

  public string format_lon() {
    if (is_geo()) {
      return PosFormat.lon(lon,Mwp.conf.dms);
    } else {
      return "";
    }
  }

  public string format_alt() {
    if(is_geo()) {
      return "%d".printf(alt);
    }
    return "";
  }

  public string format_p1() {
	  switch(action) {
	  case Msp.Action.RTH:
		  return (param1 == 1) ? "Land" : "";
	  case Msp.Action.WAYPOINT, Msp.Action.LAND:
		  return ("%.2f".printf((double)param1/100.0));

	  case Msp.Action.POSHOLD_TIME, Msp.Action.JUMP, Msp.Action.SET_HEAD:
		  return "%d".printf(param1);
	  default:
		  return "";
	  }
  }

  public string format_p2() {
	  switch(action) {
	  case Msp.Action.POSHOLD_TIME:
		  return ("%.2f".printf((double)param2/100.0));
	  case Msp.Action.JUMP, Msp.Action.LAND:
		  return "%d".printf(param2);
	  default:
		  return "";
	  }
  }

  public string format_p3() {
	  if(is_geo()) {
		  uint8 p3[6]={'R','_','_','_','_',0};
		  if((param3 & 1) == 1) {
			  p3[0]='A';
		  }
		  if((param3 & 2) == 2) {
			  p3[1]='1';
		  }
		  if((param3 & 4) == 4) {
			  p3[2]='2';
		  }
		  if((param3 & 8) == 8) {
			  p3[3]='3';
		  }
		  if((param3 & 16) == 16) {
			  p3[4]='4';
		  }
		  return (string)p3;
	  }
	  return "";
  }

  public string format_flag() {
	  switch(flag) {
	  case 'H':
		  return "FBH";
	  case 0xa5:
		  return "EoM";
	  default:
		  return "";
	  }
  }
}

public class Mission : GLib.Object {
    public MissionItem [] points;
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

	public signal void changed();

    public Mission() {
        points = {};
        version = null;
        npoints=0;
        maxy=-90;
        maxx=-180;
        miny=90;
        minx=180;
        maxalt = -2147483648;
        cx = cy = 0;
        zoom = 0;
        dist = -1;
        et = -1;
        lt = -1;
        nspeed = -1;
    }

	public Mission.clone(Mission m) {
		MissionItem []npts = {};
		foreach (var mi in m.points) {
			var mix = new MissionItem.full(mi.no, mi.action, mi.lat, mi.lon, mi.alt,
									   mi.param1, mi.param2, mi.param3, mi.flag);
			npts += mix;
		}
		npoints = m.npoints;
		points = npts;
	}

    public MissionItem []get_ways() {
        return points;
    }

    public MissionItem? get_waypoint(uint n) {
        if(n < points.length)
            return points[n];
        else
            return null;
    }

	public void check_wp_sanity(ref MissionItem m) {
		if((m.action == Msp.Action.WAYPOINT || m.action == Msp.Action.POSHOLD_TIME
			|| m.action == Msp.Action.LAND) && m.lat == 0.0 && m.lon == 0.0) {
			m.flag = 0x48;
		}
		if(m.flag == 0x48) {
			if(m.lat == 0.0)
				m.lat = this.homey;
			if(m.lon == 0.0)
				m.lon = this.homex;
		}
		if(m.is_geo()) {
			if (m.lat > this.maxy)
				this.maxy = m.lat;
			if (m.lon > this.maxx)
				this.maxx = m.lon;
			if (m.lat <  this.miny)
				this.miny = m.lat;
			if (m.lon <  this.minx)
				this.minx = m.lon;
		}
	}

	public void set_waypoint(MissionItem m, uint n) {
        if(n < points.length)
            points[n] = m;
    }

    public void set_ways(MissionItem []m) {
        points = m;
    }

	public int get_index(int id) {
		for(var j = 0; j < points.length; j++) {
			if(points[j].no == id) {
				return j;
			}
		}
		return -1;
	}

    public bool is_valid(int maxwp) {
        if(points.length > maxwp)
            return false;

        for(var i = 0; i < points.length; i++) {
            var target = points[i].param1 - 1;
            if(points[i].action == Msp.Action.JUMP) {
                if((i == 0) || ((target > (i-2)) && (target < (i+2)) ) || (target >= points.length) || (points[i].param2 < -1))
                    return false;
                if(!(points[target].action == Msp.Action.WAYPOINT || points[target].action == Msp.Action.POSHOLD_TIME || points[target].action == Msp.Action.LAND))
                    return false;
            }
        }
        return true;
    }

    public string dump(bool td = false) {
		StringBuilder sb = new StringBuilder("Mission:\n");
		if(version != null)
            sb.append_printf("\tVersion: %s\n",version);
		foreach (var m in points) {
			sb.append_printf ("\t%d %s %f %f %u p1=%d p2=%d p3=%d flg=%0x\n",
						   m.no,
						   Msp.get_wpname(m.action),
						   m.lat, m.lon, m.alt,
						   m.param1, m.param2, m.param3, m.flag);
		}
		sb.append_printf("\tlon (x)  min,max %f %f\n", minx, maxx);
		sb.append_printf("\tlat (y) min,max %f %f\n", miny, maxy);
		sb.append_printf("\tcy cx %f %f %d\n", cy, cx, (int)zoom);
		if(dist != -1) {
			sb.append_printf("\tdistance %.1f m\n", dist);
		}
		if(td) {
			sb.append_printf("\tflight time %d s\n", et);
			if(lt != -1)
				sb.append_printf("\tloiter time %d s\n", lt);
			if(nspeed == 0 && dist > 0 && et > 0)
				nspeed = dist / (et - 3*points.length);
			sb.append_printf("\tspeed %.1f m/s\n", nspeed);
			if(maxalt != 0x80000000) {
				sb.append_printf("\tmax altitude %d\n", maxalt);
			}
		}

		sb.append_printf("\thp %f %f %d\n", HomePoint.lat(), HomePoint.lon(), (int)HomePoint.is_valid());
		sb.append_printf("\tvalidity %d,%d\n", (int)is_valid(120), (int)MissionManager.is_dirty);
		return sb.str;
	}

	public void update_meta(bool use_hp=true) {
		npoints = points.length;
        maxy=-90;
        maxx=-180;
        miny=90;
        minx=180;
        maxalt = -2147483648;
		if (npoints > 0) {
			points[npoints-1].flag = 0xa5;
			for(var i = 0; i < npoints; i++) {
				check_wp_sanity(ref points[i]);
				if (points[i].alt > maxalt) {
					maxalt = points[i].alt;
				}
			}
			cy = (maxy + miny) / 2.0;
			cx = (maxx + minx) / 2.0;
			double d;
			int lt;
			if (calculate_distance(out d, out lt) == true) {
				this.dist = d;
			}
			if (zoom == 0) {
				zoom = (uint)Gis.map.viewport.zoom_level;
			}
			if(use_hp && HomePoint.is_valid()) {
				HomePoint.get_location(out homey, out homex);
			}
		}
	}

    public bool is_equal(Mission m) {
        var nwp = points.length;
        var ways = m.get_ways();

        if(nwp != ways.length)
            return false;

        for(var i = 0; i < nwp; i++) {
            if(points[i].no != ways[i].no ||
               points[i].action != ways[i].action ||
               points[i].lat != ways[i].lat ||
               points[i].lon != ways[i].lon ||
               points[i].alt != ways[i].alt ||
               points[i].param1 != ways[i].param1 ||
               points[i].param2 != ways[i].param2 ||
               points[i].param3 != ways[i].param3)
                return false;
        }
        return true;
    }

	public bool calculate_distance(out double d, out int lt) {
        var n = 0;
        var rpt = 0;
        double lx = 0.0,ly=0.0;
        bool ready = false;
        double dx,cse;
        d = 0.0;
        lt = 0;

        var nsize = points.length;
		if(nsize == 0)
            return false;
		do {
            var typ = points[n].action;
            if(typ == Msp.Action.JUMP && points[n].param2 == -1) {
                d = 0.0;
                lt = 0;
                return false;
            }

            if (typ == Msp.Action.SET_POI) {
                n += 1;
                continue;
            }

            if (typ == Msp.Action.RTH) {
                break;
            }

            var cy = points[n].lat;
            var cx = points[n].lon;
            if (ready == true) {
                if(typ == Msp.Action.JUMP) {
                    var r = points[n].param2;
                    rpt += 1;
                    if (rpt > r)
                        n += 1;
                    else
                        n = points[n].param1 - 1;
                    continue;
                }
                Geo.csedist(ly,lx,cy,cx, out dx, out cse);
                d += dx;
//                print("At WP #%d, delta = %6.1f dist = %6.1f\n", n+1, dx*1852.0, d*1852.0);
                if (typ == Msp.Action.POSHOLD_TIME) {
                    lt += points[n].param1;
                }
                if (typ == Msp.Action.POSHOLD_UNLIM || typ == Msp.Action.LAND) {
                    break;
                }  else {
                    n += 1;
                }
            } else {
				ready = true;
//				print("At WP #1, delta =    0.0 dist =    0.0 (%d)\n", n);
				n += 1;
            }
            lx = cx;
            ly = cy;
        } while (n < nsize);
        d *= 1852.0;
        return true;
    }

	public void calc_mission_distance() {
        if (points.length > 1) {
			for(var k=0; k < points.length; k++) {
				points[k].stats = {};
			}
			var mp = new MissionPreviewer();
            mp.is_mr = true;
            mp.check_mission(this, true);
			var n = -1;
			mstat []_stats={};
			mp.tree.@foreach ((k, v) => {
					if(v.p1 != n) {
						if (n != -1) {
							points[n].stats = _stats;
						}
						_stats = {};
						n = v.p1;
					}
					mstat mst = {v.p2, (int)v.cse, v.legd};
					_stats += mst;
					return false;
				});
			if (n != -1) {
				points[n].stats = _stats;
			}
		}
	}
}
