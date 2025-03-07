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

namespace JsonIO {
    public Mission? [] read_json_file(string fn) {
        try {
            string s;
            if(FileUtils.get_contents(fn, out s))
                return from_json(s);
        } catch {}
        return {};
    }

	private Mission? parse_segment(Json.Object obj) {
		var ms = new Mission();
		foreach (var name in obj.get_members ()) {
			switch (name) {
			case "mission":
				MissionItem []mi = {};
				foreach (var rsnode in obj.get_array_member ("mission").get_elements()) {
					var rsitem = rsnode.get_object ();
					var m = new MissionItem();
					m.no = (int) rsitem.get_int_member("no");
					m.action =  Msp.lookup_name(rsitem.get_string_member("action"));
					m.lat = rsitem.get_double_member("lat");
					m.lon = rsitem.get_double_member("lon");
					m.alt = (int) rsitem.get_int_member("alt");
					if(m.alt > ms.maxalt)
						ms.maxalt = m.alt;
					m.param1 = (int) rsitem.get_int_member("p1");
					m.param2 = (int) rsitem.get_int_member("p2");
					m.param3 = (int) rsitem.get_int_member("p3");
					if(rsitem.has_member("flag"))
						m.flag = (uint8) rsitem.get_int_member("flag");

					if(m.flag == 0x48) {
						if(m.lat == 0.0)
							m.lat = ms.homey;
						if(m.lon == 0.0)
							m.lon = ms.homex;
					}

					if(m.action != Msp.Action.RTH && m.action != Msp.Action.JUMP &&
					   m.action != Msp.Action.SET_HEAD) {
						if (m.lat > ms.maxy)
							ms.maxy = m.lat;
						if (m.lon > ms.maxx)
							ms.maxx = m.lon;
						if (m.lat <  ms.miny)
							ms.miny = m.lat;
						if (m.lon <  ms.minx)
							ms.minx = m.lon;
					}
					mi += m;
				}
				ms.points = mi;
				ms.update_meta(false);
				break;
			case "meta":
				var msobj = obj.get_object_member("meta");
				parse_meta(msobj, ref ms);
				break;
			case "fwapproach":
				var fwobj = obj.get_object_member("fwapproach");
				parse_fwa(fwobj);
				break;
			}
		}
		return ms;
	}


    public Mission? [] from_json(string s) {
		Mission[] msx = {};
		try {
			var parser = new Json.Parser ();
			parser.load_from_data (s);

			Json.Node root = parser.get_root ();
			Json.Object obj = null;
			if(root!= null && !root.is_null())
				obj = root.get_object ();
			if(obj != null) {
				Json.Node? node;
				node = obj.get_member("missions");
				if (node != null) {
					foreach (var mmnode in  obj.get_array_member ("missions").get_elements()) {
						var mmitem = mmnode.get_object ();
						var ms =  parse_segment(mmitem);
						msx += ms;
					}
				} else {
					var ms =  parse_segment(obj);
					msx += ms;
				}
			}
		} catch {}
		return msx;
    }

    private static void parse_fwa(Json.Object o) {
		FWApproach.approach l={};
		int idx=0;
        foreach (var name in o.get_members()) {
            switch (name) {
                case "appalt":
					l.appalt = o.get_int_member("appalt")/100.0;
					break;
                case "aref":
					l.aref = o.get_boolean_member("aref");
					break;
                case "dirn1":
					l.dirn1 = (int16)o.get_int_member("dirn1");
					if (l.dirn1 < 0) {
						l.ex1 = true;
						l.dirn1 = -l.dirn1;
					}
					break;
                case "dirn2":
					l.dirn2 = (int16)o.get_int_member("dirn2");
					if (l.dirn2 < 0) {
						l.ex2 = true;
						l.dirn2 = -l.dirn2;
					}
					break;
                case "dref":
					l.dref = o.get_string_member("dref") == "right";
					break;
                case "index":
					break;
                case "landalt":
					l.landalt = o.get_int_member("landalt")/100.0;
					break;
                case "no":
					idx = (int)o.get_int_member("no");
					break;
			}
		}
		if(idx > 7) {
			FWApproach.set(idx, l);
		}
	}

    private static void parse_meta(Json.Object o, ref Mission ms) {
        foreach (var name in o.get_members()) {
            switch (name) {
                case "zoom":
                    ms.zoom = (int)o.get_int_member("zoom");
                    break;
                case "cx":
                    ms.cx = o.get_double_member("cx");
                    break;
                case "cy":
                    ms.cy = o.get_double_member("cy");
                    break;
                case "home-x":
                    ms.homex = o.get_double_member("home-x");
                    break;
                case "home-y":
                    ms.homey = o.get_double_member("home-y");
                    break;
                case "details":
                    var dobj = o.get_object_member("details");
                    if (dobj != null) {
                        parse_details(dobj, ref ms);
                    }
					break;
            }
        }
    }

    private static void parse_details(Json.Object o, ref Mission ms) {
        foreach (var name in o.get_members()) {
			var oo = o.get_object_member(name);
			switch (name) {
			case "distance":
                    ms.dist = oo.get_double_member("value");
                    break;
                case "nav-speed":
                    ms.nspeed = oo.get_double_member("value");
                    break;
                case "fly-time":
                    ms.et = (int)oo.get_int_member("value");
                    break;
                case "loiter-time":
                    ms.lt = (int)oo.get_int_member("value");
                    break;
            }
        }
    }

	private void encode_mission(Json.Builder builder, Mission ms, int mxno) {
		bool has_land = false;
        builder.set_member_name ("meta");
        builder.begin_object ();
        builder.set_member_name ("save-date");
        time_t currtime;
        time_t(out currtime);
		var dt = new DateTime.from_unix_local(currtime);
        builder.add_string_value(dt.format("%FT%T%z"));
        builder.set_member_name ("cx");
        builder.add_double_value (ms.cx);
        builder.set_member_name ("cy");
        builder.add_double_value (ms.cy);
		builder.set_member_name ("home-x");
		builder.add_double_value (ms.homex);
		builder.set_member_name ("home-y");
		builder.add_double_value (ms.homey);
		builder.set_member_name ("details");
        builder.begin_object ();
        builder.set_member_name ("distance");
        builder.add_double_value (ms.dist);
        builder.end_object (); // details
        builder.set_member_name ("generator");
        builder.add_string_value ("mwp");
        builder.end_object (); // meta
        builder.set_member_name ("mission");
        builder.begin_array ();
		var wpno = 1;
		foreach (var m in ms.get_ways()) {
			builder.begin_object (); //mi
			builder.set_member_name ("no");
			builder.add_int_value (wpno++);
			builder.set_member_name ("action");
			builder.add_string_value(Msp.get_wpname(m.action));
			if (m.action ==  Msp.Action.LAND) {
				has_land = true;
			}
			builder.set_member_name ("lat");
			builder.add_double_value( m.lat);
			builder.set_member_name ("lon");
			builder.add_double_value( m.lon);
			builder.set_member_name ("alt");
			builder.add_int_value( m.alt);
			builder.set_member_name ("p1");
			builder.add_int_value( m.param1);
			builder.set_member_name ("p2");
			builder.add_int_value( m.param2);
			builder.set_member_name ("p3");
			builder.add_int_value( m.param3);
			builder.set_member_name ("flag");
			builder.add_int_value( m.flag);
			builder.end_object (); // mi
		}
		builder.end_array ();

		var lid = mxno+8;
		if(has_land && FWApproach.is_active(lid)) {
			var l = FWApproach.get(lid);
			builder.set_member_name ("fwapproach");
			builder.begin_object ();
			builder.set_member_name ("no");
			builder.add_int_value(lid);
			builder.set_member_name ("index");
			builder.add_int_value(mxno);
			builder.set_member_name ("appalt");
			builder.add_int_value((int)(l.appalt*100));
			builder.set_member_name ("landalt");
			builder.add_int_value((int)(l.landalt*100));
			builder.set_member_name ("dirn1");
			var d = (!l.ex1) ? l.dirn1 : -l.dirn1;
			builder.add_int_value(d);
			builder.set_member_name ("dirn2");
			d = (!l.ex2) ? l.dirn2 : -l.dirn2;
			builder.add_int_value(d);
			builder.set_member_name ("dref");
			var s = (l.dref) ? "right" : "left";
			builder.add_string_value(s);
			builder.set_member_name ("aref");
			builder.add_boolean_value(l.aref);
			builder.end_object (); // fwapproach
		}
	}

    public string? to_json(Mission []msx, bool indent=true) {
		var builder = new Json.Builder ();
		builder.begin_object ();
		if (msx.length == 1) {
			encode_mission(builder, msx[0], 0);
		} else {
			builder.set_member_name ("missions");
			builder.begin_array ();
			var j = 0;
			foreach (var ms in msx) {
				builder.begin_object ();
				encode_mission(builder, ms, j);
				builder.end_object ();
				j++;
			}
			builder.end_array ();
		}
		builder.end_object (); // root
        var generator = new Json.Generator ();
        if(indent) {
            generator.indent = 1;
            generator.indent_char = ' ';
        }
        generator.set_pretty(indent);
        var root = builder.get_root ();
        generator.set_root (root);
        return generator.to_data (null);
    }

    public static void to_json_file(string fn, Mission [] msx) {
        var s = to_json(msx, false);
        try {
            FileUtils.set_contents(fn,s);
        } catch (Error e) {
            stderr.puts(e.message);
            stderr.putc('\n');
        }
    }
}

#if JSON_TEST_MAIN
int main (string[] args) {

    if (args.length < 2) {
        stderr.printf ("Argument required!\n");
        return 1;
    }

    Mission []msx;
    msx = JsonIO.read_json_file (args[1]);
	foreach (var ms in msx) {
        ms.dump(120);
        double d;
        int lt;
        var res = ms.calculate_distance(out d, out lt);
        if (res == true) {
            var et = (int)(d / 3.0);
            print("calc dist %.1f %ds (%ds)\n",d,et,lt);
        } else
            print("Indeterminate\n");
    }
	if (args.length == 3)
		JsonIO.to_json_file(args[2], msx);
	return 0;
}
#endif
