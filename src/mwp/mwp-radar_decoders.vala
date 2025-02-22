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
					ri.state = Radar.set_initial_state(ri.lq);
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
		var nac = ReadSB.decode_ac_pb(buf, out acs);
		for(int k = 0; k < nac; k++) {
			var a = acs[k];
			var ri = Radar.radar_cache.lookup(a.addr);
			if (ri == null) {
				ri = new RadarPlot();
				ri.source = Radar.RadarSource.SBS;
				ri.srange = ADSB_DISTNDEF;
			}
			var xdt = new DateTime.from_unix_local ((int64)(a.seen_tm/1000));
			var msec = (int)a.seen_tm%1000;
			xdt = xdt.add(TimeSpan.MILLISECOND*msec);
			if(ri.source != Radar.RadarSource.SBS && ri.dt != null) {
				// MWPLog.message("MULTI %x %s this=%s/%.12s db=%s/%.12s\n", a.addr, ri.name.strip(), Radar.RadarSource.SBS.source_id(), xdt.format("%T.%f"), ((Radar.RadarSource)ri.source).source_id(), ri.dt.format("%T.%f"));
				if(xdt.compare(ri.dt) == -1) {
					// MWPLog.message(" *** SKIP this\n");
					continue;
				}
			}
			ri.source = Radar.RadarSource.SBS;

			ri.dt = xdt;
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
			// seen_pos is **millseconds**
			var lts = a.seen_pos/1000;
			ri.lq = (lts < 256) ? (uint8)lts : 255;
			ri.state = Radar.set_initial_state(ri.lq);

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

	public void decode_jsa(string js, bool adsbx = false) {
		var parser = new Json.Parser();
		var rdebug = ((Mwp.debug_flags & Mwp.DEBUG_FLAGS.RADAR) != Mwp.DEBUG_FLAGS.NONE);
		try {
			parser.load_from_data (js);
			Json.Array acarry;
			DateTime now;
			var root = parser.get_root().get_object();
			if(root.has_member("aircraft")) {
				acarry = root.get_array_member ("aircraft");
			} else if(root.has_member("ac")) {
				acarry = root.get_array_member ("ac");
			} else {
				return;
			}

			if(root.has_member("now")) {
				var epoch_sec = root.get_double_member ("now");
				if (epoch_sec > 9999999999) { // in **millisecs**
					epoch_sec /= 1000;
				}
				var idt = (int64)epoch_sec;
				int64 msec = (int64)(1000*(epoch_sec - idt));
				var xdt = new DateTime.from_unix_local (idt);
				now = xdt.add(TimeSpan.MILLISECOND*msec);
			} else {
				now = new DateTime.now_local();
			}

			foreach (var acnode in acarry.get_elements ()) {
				var obj = acnode.get_object ();
				var hex  = obj.get_string_member ("hex");
				var icao = (uint)  MwpLibC.strtoul(hex, null, 16);  //uint64.parse(hex,16);
				if(obj.has_member("lat")) {
					var tsource = (adsbx) ? Radar.RadarSource.ADSBX : Radar.RadarSource.SBS;
					var ri = radar_cache.lookup(icao);
					if (ri == null) {
						ri = new RadarPlot();
						ri.source = tsource;
						ri.srange = Radar.ADSB_DISTNDEF;
					}
					double seen=0.0;
					bool is_seen = false;
					if(obj.has_member("seen_pos")) {
						seen = (uint)obj.get_double_member ("seen_pos");
						is_seen = true;
					} else if(obj.has_member("seen")) {
						seen = (uint)obj.get_double_member ("seen");
						is_seen = true;
					}
					if(is_seen) {
						int64 lts = (int64)(seen*1000.0);
						TimeSpan ts = -1*TimeSpan.MILLISECOND*lts;
						var xdt = now.add(ts);
						if(tsource != ri.source && ri.dt != null) {
							// MWPLog.message("MULTI %x %s this=%s/%.12s db=%s/%.12s\n", icao, ri.name.strip(), tsource.source_id(), xdt.format("%T.%f"), ((Radar.RadarSource)ri.source).source_id(), ri.dt.format("%T.%f"));
							if(xdt.compare(ri.dt) == -1) {
								// MWPLog.message(" *** SKIP this\n");
								continue;
							}
						}
						ri.dt = xdt;
						ri.lq = (seen < 256) ? (uint8)seen : 255;
					} else {
						ri.dt = now;
						ri.lq = 255;
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
						/*
						if(s[0] > 'A') {
							MWPLog.message("CAT %x %s %s\n", icao, ri.name, s);
						}
						*/
					}
					if(obj.has_member("flight")) {
						var s = obj.get_string_member("flight");
						if(s == "00000000") {
							if(obj.has_member("r")) {
								s = obj.get_string_member("r");
							}
						}
						ri.name = s;
					} else if(ri.name == null || ri.name.length == 0) {
						ri.name = "[%u]".printf(icao);
					}
					sb.append_printf(" name: %s", ri.name);
					if(obj.has_member("mag_heading")) {
						ri.heading = (uint16)obj.get_double_member("mag_heading");
						sb.append_printf(" hdr: %u", ri.heading);
					} else 	if(obj.has_member("track")) {
						ri.heading = (uint16)obj.get_double_member("track");
						sb.append_printf(" hdr: %u", ri.heading);
					} else 	if(obj.has_member("calc_track")) {
						ri.heading = (uint16)obj.get_double_member("calc_track");
						sb.append_printf(" hdr: %u", ri.heading);
					}

					if(obj.has_member("alt_geom")) {
						ri.altitude = 0.3048*(double)obj.get_int_member ("alt_geom");
						sb.append_printf(" alt: %.0f", ri.altitude);
					} else if(obj.has_member("alt_baro")) {
						ri.altitude = 0.3048*(double)obj.get_int_member ("alt_baro");
						sb.append_printf(" alt: %.0f", ri.altitude);
					}

					if(obj.has_member("gs")) {
						ri.speed = obj.get_double_member ("gs") * 1852.0 / 3600;
						sb.append_printf(" spd: %.0f", ri.speed);
					}

					if(obj.has_member("dst")) {
						ri.srange = (uint)(obj.get_double_member ("dst") * 1852.0);
						sb.append_printf(" range: %.0f", ri.range);
					}

					//if(obj.has_member("dir")) {
					//	ri.bearing = (uint16)obj.get_double_member ("dir");
					//	sb.append_printf(" brg: %u", ri.bearing);
					//} else {
					ri.bearing = 0xffff;
						//}
					ri.source = tsource;

					ri.state = Radar.set_initial_state(ri.lq);
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