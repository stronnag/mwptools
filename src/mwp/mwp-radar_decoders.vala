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

namespace Radar {
	public const uint32 ADSB_DISTNDEF = (uint32)0xffffffff;

	public void decode_sbs(string[] p) {
		var rdebug = ((Mwp.debug_flags & Mwp.DEBUG_FLAGS.RADAR) != Mwp.DEBUG_FLAGS.NONE);
		bool posrep = (p[1] == "2" || p[1] == "3");
		bool isvalid = false;
		string s4 = "0x%s".printf(p[4]);
		uint v = (uint)uint64.parse(s4);
		var name = p[10].strip();

		var ri = radar_cache.lookup(v);
		if (ri == null) {
			ri = new RadarPlot();
			ri.source = RadarSource.SBS;
			ri.srange = ADSB_DISTNDEF;
		}

		if (name.length > 0) {
			ri.name = name;
		}

		if (ri.name == null || ri.name.length == 0) {
			ri.name = "[%s]".printf(p[4]);
		}

		if(posrep) {
			double lat = double.parse(p[14]);
			double lng = double.parse(p[15]);
			uint16 hdg = (uint16)int.parse(p[13]);
			int spd = int.parse(p[12]);
			isvalid = (p[14].length > 0  && p[15].length > 0);
			var currdt = make_sbs_time(p[6], p[7]);
			if ( isvalid && hdg == 0 && spd == 0 && ri.posvalid && ri.dt != null) {
				if (ri.speed == 0.0) {
					double c,d;
					Geo.csedist(ri.latitude, ri.longitude, lat, lng, out d, out c);
					hdg = (uint16)c;
					ri.heading = hdg;
					var tdiff = currdt.difference(ri.dt);
					if (tdiff > 0) {
						ri.speed = d*1852.0 / (tdiff / 1e6) ;
					}
				}
			} else {
				ri.speed = spd * (1852.0/3600.0);
				ri.heading = hdg;
			}
			if(isvalid) {
				if (lat != 0 && lng != 0) {
					ri.latitude = lat;
					ri.longitude = lng;
					ri.posvalid = true;
					if (ri.dt != null) {
						var td = currdt.difference(ri.dt);
						td /= 1000000;
						if (td < 255)
							ri.lq = (uint8)(td&0xff);
					}
					ri.dt = currdt;
				}
			}
			ri.altitude = int.parse(p[11])*0.3048;
			//			ri.lasttick = nticks;
		} else if (p[1] == "4") {
			uint16 hdg = (uint16)int.parse(p[13]);
			int spd = int.parse(p[12]);
			if(spd != 0) {
				ri.speed = spd * (1852.0/3600.0);
			}
			if (hdg != 0) {
				ri.heading = hdg;
			}
			isvalid = ri.posvalid;
		}
		ri.etype = 0;
		if(ri.posvalid) {
			Radar.upsert(v, ri);
			Radar.update(v, rdebug);
			Radar.update_marker(v);
			if (rdebug) {
				MWPLog.message("SBS p[1]=%s id=%x calls=%s lat=%f lon=%f alt=%.0f hdg=%u speed=%.1f last=%u\n", p[1], v, ri.name, ri.latitude, ri.longitude, ri.altitude, ri.heading, ri.speed, ri.lasttick);
			}
		}
	}

#if PROTOC
	public void decode_pba(uint8[] buf) {
		ReadSB.Pbuf[] acs={};
		var rdebug = ((Mwp.debug_flags & Mwp.DEBUG_FLAGS.RADAR) != Mwp.DEBUG_FLAGS.NONE);
		var now = new DateTime.now_local();
		var nac = ReadSB.decode_ac_pb(buf, out acs);
		for(int k = 0; k < nac; k++) {
			var a = acs[k];
			var ri = Radar.radar_cache.lookup(a.addr);
			if (ri == null) {
				ri = new RadarPlot();
				ri.source = Radar.RadarSource.SBS;
				ri.srange = ADSB_DISTNDEF;
			}
			ri.posvalid = true;
			ri.latitude = a.lat;
			ri.longitude = a.lon;
			uint8 et = (a.catx&0xf) | (a.catx>>4)/0xa;
			if (et != ri.etype) {
				ri.alert |= Radar.RadarAlert.SET;
			}
			ri.etype = et;
			string aname = (string)a.name;

			if (aname == null || aname[0] == 0 || aname[0] == ' ') {
				ri.name = "[%X]".printf(a.addr);
			} else {
				ri.name = aname;
			}
			ri.heading = (uint16)a.hdg;
			ri.altitude = 0.3048*((double)a.alt);
			ri.speed = ((double)a.speed) * 1852.0 / 3600;
			// ri.dt = new DateTime.from_unix_local ((int64)(a.seen_tm/1000));
			//	MWPLog.message("ADSB: %x %u %u\n", a.addr, a.seen_tm, a.seen_pos);
			//if (ri.dt ==  null) { // can't happen ... unless it's cygwin, when it does
			TimeSpan ts = (int64)(a.seen_pos*-1e6);
			ri.dt = now.add(ts);
			//}
			ri.lq = (a.seen_pos < 256) ? (uint8)a.seen_pos : 255;
			//			ri.lasttick = nticks;
			ri.srange = a.srange;
			if (rdebug) {
				string ssm;
				if(ri.srange == Radar.ADSB_DISTNDEF) {
					ssm = "undef";
				} else {
					ssm = "%um".printf(ri.srange);
				}
				MWPLog.message("PBA %X %s %f %f a:%.0f h:%u s:=%.0f %s %s (%u)\n",
							   a.addr, ri.name, ri.latitude, ri.longitude, ri.altitude,
							   ri.heading, ri.speed, ri.dt.format("%T"),
							   ssm, ri.lq);
			}
			Radar.upsert(a.addr, ri);
			Radar.update(a.addr, rdebug);
			Radar.update_marker(a.addr);
		}
	}
#endif

	public void decode_jsa(string js, string aname = "aircraft") {
		var parser = new Json.Parser();
		var now = new DateTime.now_local();
		var rdebug = ((Mwp.debug_flags & Mwp.DEBUG_FLAGS.RADAR) != Mwp.DEBUG_FLAGS.NONE);
		try {
			parser.load_from_data (js);
			var root = parser.get_root().get_object();
			var acarry = root.get_array_member (aname);
			foreach (var acnode in acarry.get_elements ()) {
				var obj = acnode.get_object ();
				var hex  = obj.get_string_member ("hex");
				var icao = (uint)  MwpLibC.strtoul(hex, null, 16);  //uint64.parse(hex,16);
				if(obj.has_member("lat")) {
					var ri = radar_cache.lookup(icao);
					if (ri == null) {
						ri = new RadarPlot();
						if(aname == "aircraft") {
							ri.source = Radar.RadarSource.SBS;
						} else {
							ri.source = Radar.RadarSource.ADSBX;
						}
						ri.srange = Radar.ADSB_DISTNDEF;
					}
					var sb = new StringBuilder("JSON\n");
					sb.append_printf("I:%X", icao);
					ri.posvalid = true;
					ri.latitude = obj.get_double_member("lat");
					if(obj.has_member("lon")) {
						ri.longitude = obj.get_double_member("lon");
					}
					sb.append_printf(" pos: %.6f %.6f", ri.latitude,  ri.longitude);
					if(obj.has_member("category")) {
						var s = obj.get_string_member("category");
						var et = CatMap.from_category(s);
						if (et != ri.etype) {
							ri.alert |= Radar.RadarAlert.SET;
						}
						ri.etype = et;
						sb.append_printf(" typ: %s,%u", s, ri.etype);
					}
					if(obj.has_member("flight")) {
						var s = obj.get_string_member("flight");
						ri.name = s;
					} else if(ri.name == null || ri.name.length == 0) {
						ri.name = "[%u]".printf(icao);
					}
					sb.append_printf(" name: %s", ri.name);
					if(obj.has_member("mag_heading")) {
						ri.heading = (uint16)obj.get_double_member("mag_heading");
						sb.append_printf(" hdr: %u", ri.heading);
					}
					if(obj.has_member("alt_baro")) {
						ri.altitude = 0.3048*(double)obj.get_int_member ("alt_baro");
						sb.append_printf(" alt: %.0f", ri.altitude);
					}
					if(obj.has_member("gs")) {
						ri.speed = obj.get_double_member ("gs") * 1852.0 / 3600;
						sb.append_printf(" spd: %.0f", ri.speed);
					}

					if(obj.has_member("dst")) {
						ri.range = obj.get_double_member ("dst") * 1852.0;
						sb.append_printf(" range: %.0f", ri.range);
					}

					if(obj.has_member("dir")) {
						ri.bearing = (uint16)obj.get_double_member ("dir");
						sb.append_printf(" brg: %u", ri.bearing);
					} else {
						ri.bearing = 0xffff;
					}

					if(obj.has_member("seen")) {
						var seen = (uint)obj.get_double_member ("seen");
						TimeSpan ts = (int64)(seen*-1e6);
						ri.dt = now.add(ts);
						ri.lq = (seen < 256) ? (uint8)seen : 255;
						sb.append_printf(" seen: %.1f", seen);
					} else {
						ri.dt = now;
						ri.lq = 255;
					}
					sb.append_printf(" ts: %s, lq: %u\n", ri.dt.format("%T"), ri.lq);
					//					ri.lasttick = nticks;
					Radar.upsert(icao, ri);
					Radar.update(icao, rdebug);
					Radar.update_marker(icao);
					if (rdebug) {
						MWPLog.message(sb.str);
					}
				}
			}
		} catch (Error e) {
			print("parser: %s\n%s\n", e.message, js);
		}
	}

	private DateTime make_sbs_time(string d, string t) {
		var p = d.split("/");
		var ts = "%s-%s-%sT%s+00".printf(p[0], p[1], p[2], t);
		return new DateTime.from_iso8601(ts, null);
	}
}