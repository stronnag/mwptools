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

namespace MspRadar {

	public void handle_radar(MWSerial s, Msp.Cmds cmd, uint8[] raw, uint len,
                              uint8 xflags, bool errs) {
		double rlat, rlon;
        Mwp.nopoll = true;
		if((Mwp.debug_flags & Mwp.DEBUG_FLAGS.RADAR) != Mwp.DEBUG_FLAGS.NONE) {
			MWPLog.message("RDR-msg: %s\n", cmd.to_string());
		}

		switch(cmd) {
		case Msp.Cmds.NAME:
			var node = "MWP Fake Node";
			s.send_command(cmd, node, node.length, true);
			break;
		case Msp.Cmds.RAW_GPS:
			uint8 oraw[18]={0};
			uint8 *p = &oraw[0];

			*p++ = 2;
			*p++ = 42;

			if (GCS.get_location(out rlat, out rlon) == false) {
				if(Mwp.have_home) {
					HomePoint.get_location(out rlat, out rlon);
				} else {
					MapUtils.get_centre_location(out rlat, out rlon);
				}
			}
			p = SEDE.serialise_i32(p, (int)(rlat*1e7));
			p = SEDE.serialise_i32(p, (int)(rlon*1e7));
			p = SEDE.serialise_i16(p, 0);
			p = SEDE.serialise_u16(p, 0);
			p = SEDE.serialise_u16(p, 0);
			SEDE.serialise_u16(p, 99);
			if((Mwp.debug_flags & Mwp.DEBUG_FLAGS.RADAR) != Mwp.DEBUG_FLAGS.NONE) {
				MWPLog.message("RDR-rgps: Lat, Lon %f %f\n", rlat, rlon);
				StringBuilder sb = new StringBuilder("RDR-rgps:");
				foreach(var r in oraw)
					sb.append_printf(" %02x", r);
				sb.append_c('\n');
				MWPLog.message(sb.str);
			}
			s.send_command(cmd, oraw, 18, true);
			break;
		case Msp.Cmds.FC_VARIANT:
			uint8 []oraw;
			if (GCS.get_location(out rlat, out rlon)) {
				oraw = "INAV".data;
			} else {
				oraw = "GCS".data; //{0x47, 0x43, 0x53}; // 'GCS'
			}
			s.send_command(cmd, oraw, oraw.length, true);
			break;
		case Msp.Cmds.FC_VERSION:
			uint8 oraw[3] = {6,6,6};
			s.send_command(cmd, oraw, oraw.length,true);
			break;
		case Msp.Cmds.ANALOG:
			uint8 []oraw = {0x76, 0x4, 0x0, 0x0, 0x0, 0x0, 0x0};
			s.send_command(cmd, oraw, oraw.length,true);
			break;
		case Msp.Cmds.STATUS:
			uint8 []oraw = {0xe8, 0x3, 0x0, 0x0, 0x83, 0x0, 0x0, 0x10, 0x10, 0x0, 0x0};
			s.send_command(cmd, oraw, oraw.length,true);
			break;
		case Msp.Cmds.BOXIDS:
			uint8 []oraw = {0x0, 0x33, 0x1, 0x2, 0x23, 0x5, 0x6, 0x7, 0x20, 0x8, 0x3, 0x21, 0xc, 0x24, 0x25, 0x15, 0xd, 0x13, 0x1a, 0x26, 0x1b, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c};
			s.send_command(cmd, oraw, oraw.length,true);
			break;

		case Msp.Cmds.COMMON_SET_RADAR_POS:
			process_inav_radar_pos(raw,len);
			break;
		case Msp.Cmds.MAVLINK_MSG_ID_TRAFFIC_REPORT:
			process_mavlink_radar(raw);
			break;
		case Msp.Cmds.MAVLINK_MSG_ID_OWNSHIP:
			//                dump_mav_os_msg(raw);
			break;

		case Msp.Cmds.ADSB_VEHICLE_LIST:
			process_msp2_adsb(raw, len);
			break;

		default:
			if((Mwp.debug_flags & Mwp.DEBUG_FLAGS.RADAR) != Mwp.DEBUG_FLAGS.NONE) {
				MWPLog.message("RADAR: %s %d (%u)\n", cmd.to_string(), cmd, len);
			}
			break;
        }
    }

    void process_inav_radar_pos(uint8 []raw, uint len) {
        uint8 *rp = &raw[0];
        int32 ipos;
        uint16 ispd;
        uint8 id = *rp++; // id
		var now = new DateTime.now_local();

		var ri = Radar.radar_cache.lookup((uint)id);
		if (ri == null) {
			ri = new Radar.RadarPlot();
			ri.source  = Radar.RadarSource.INAV;
            ri.name = "⚙ inav %c".printf(65+id);
			ri.srange = Radar.ADSB_DISTNDEF;
			ri.posvalid = true;
		}

        ri.state = *rp++;
        rp = SEDE.deserialise_i32(rp, out ipos);
        ri.latitude = ((double)ipos)/1e7;
        rp = SEDE.deserialise_i32(rp, out ipos);
        ri.longitude = ((double)ipos)/1e7;
        rp = SEDE.deserialise_i32(rp, out ipos);
        ri.altitude = ipos/100.0;
		uint16 ihdr;
        rp = SEDE.deserialise_u16(rp, out ihdr);
        rp = SEDE.deserialise_u16(rp, out ispd);
		ri.heading = ihdr;
        ri.speed = ispd/100.0;
        ri.lq = *rp;
        ri.lasttick = Mwp.nticks;
		ri.posvalid = true;
		ri.dt = now;
		Radar.upsert(id, ri);
        Radar.update((uint)id, false);
        Radar.update_marker((uint)id);

        if((Mwp.debug_flags & Mwp.DEBUG_FLAGS.RADAR) != Mwp.DEBUG_FLAGS.NONE) {
            StringBuilder sb = new StringBuilder("RDR-recv:");
            MWPLog.message("RDR-recv %d: Lat, Lon %f %f\n", id, ri.latitude, ri.longitude);
            foreach(var r in raw[0:len])
                sb.append_printf(" %02x", r);
            sb.append_c('\n');
            MWPLog.message(sb.str);
        }
    }

	void process_msp2_adsb(uint8 *rp, uint mlen) {
        var sb = new StringBuilder("MSP2 ADSB:");
        uint32 v;
        int32 i;

		var maxvl = *rp++;
		var maxcs = *rp++;
		var now = new DateTime.now_local();

		var maxml = (mlen-2)/30;
		if (maxvl > maxml)
			maxvl = (uint8)maxml;

		for(var k = 0; k < maxvl; k++) {
            uint8 cs[10];
            uint8 *csp = cs;
			string callsign = "";

			for(var j = 0; j < maxcs; j++) {
				*csp++ = *rp++;
			}
			callsign = ((string)cs).strip();
			rp = SEDE.deserialise_u32(rp, out v);
			if(v != 0) {
				sb.append_printf("ICAO %X ", v);
				if(callsign.length == 0) {
					callsign = "[%X]".printf(v);
				}
				sb.append_printf("callsign <%s> ", callsign);
				var ri = Radar.radar_cache.lookup(v);
				if (ri == null) {
					ri = new Radar.RadarPlot();
					ri.source = Radar.RadarSource.MAVLINK;
					ri.srange = Radar.ADSB_DISTNDEF;
					ri.posvalid = true;
					sb.append(" * ");
				}
				ri.name = callsign;

				double lat = 0;
				double lon = 0;

				rp = SEDE.deserialise_i32(rp, out i);
				lat = i / 1e7;
				sb.append_printf("lat %.6f ", lat);

				rp = SEDE.deserialise_i32(rp, out i);
				lon = i / 1e7;
				sb.append_printf("lon %.6f ", lon);

				ri.lasttick = Mwp.nticks;

				rp = SEDE.deserialise_i32(rp, out i);
				var l = i / 1000.0;
				sb.append_printf("alt %.1f ", l);
				ri.altitude = l;

				uint16 h;
				rp = SEDE.deserialise_u16(rp, out h);
				sb.append_printf("heading %u ", h);

				ri.latitude = lat;
				ri.longitude = lon;
				if (h != 0xffff) {
					ri.heading = h;
				}
				ri.lq = *rp++;
				var et  = *rp++;
				if (et != ri.etype) {
					ri.alert |= Radar.RadarAlert.SET;
				}
				ri.etype = et;
				rp++; // ttl

				TimeSpan ts = -1000000*((int64)(ri.lq));
				ri.dt = now.add(ts);

				sb.append_printf("emitter %u tslc %u ", ri.etype, ri.lq);
				sb.append_printf("ticks %u ", ri.lasttick);
				ri.posvalid = true;

				Radar.upsert(v, ri);
				Radar.update(v, ((Mwp.debug_flags & Mwp.DEBUG_FLAGS.RADAR) != Mwp.DEBUG_FLAGS.NONE));
				Radar.update_marker(v);
				if((Mwp.debug_flags & Mwp.DEBUG_FLAGS.RADAR) != Mwp.DEBUG_FLAGS.NONE)
					MWPLog.message(sb.str);
			} else {
				// We've read 13 already ...
				rp += 17; // FIXME
			}
		}
	}

	void process_mavlink_radar(uint8 *rp) {
        var sb = new StringBuilder("MAV radar:");
        uint32 v;
        int32 i;
        uint16 valid;
		var now = new DateTime.now_local();

        SEDE.deserialise_u16(rp+22, out valid);
        SEDE.deserialise_u32(rp, out v);
        sb.append_printf("ICAO %u ", v);
        sb.append_printf("flags: %04x ", valid);
        string callsign = "";
        double lat = 0;
        double lon = 0;

        if ((valid & 0x10) == 0x10) {
            uint8 cs[10];
            uint8 *csp = cs;
            for(var j=0; j < 8; j++) {
                if (*(rp+27+j) != ' ') {
                    *csp++ = *(rp+27+j);
				}
			}
			*csp  = 0;
			callsign = ((string)cs).strip();
			if(callsign.length == 0) {
				callsign = "[%X]".printf(v);
			}
        } else {
            callsign = "[%X]".printf(v);
        }
        sb.append_printf("callsign <%s> ", callsign);

        if ((valid & 1)  == 1) {
			var ri = Radar.radar_cache.lookup(v);
			if (ri == null) {
				ri = new Radar.RadarPlot();
				ri.source = Radar.RadarSource.MAVLINK;
				ri.srange = Radar.ADSB_DISTNDEF;
				ri.posvalid = true;
				sb.append(" * ");
			}
			ri.name = callsign;
            SEDE.deserialise_i32(rp+4, out i);
            lat = i / 1e7;
            sb.append_printf("lat %.6f ", lat);

            SEDE.deserialise_i32(rp+8, out i);
            lon = i / 1e7;
            sb.append_printf("lon %.6f ", lon);

            ri.latitude = lat;
            ri.longitude = lon;
            ri.lasttick = Mwp.nticks;

            if((valid & 2) == 2) {
                SEDE.deserialise_i32(rp+12, out i);
                var l = i / 1000.0;
                sb.append_printf("alt %.1f ", l);
                ri.altitude = l;
            }

            if((valid & 4) == 4) {
                uint16 h;
                SEDE.deserialise_u16(rp+16, out h);
                sb.append_printf("heading %u ", h);
                ri.heading = h/100;
            }
            if((valid & 8) == 8) {
                uint16 hv;
                SEDE.deserialise_u16(rp+18, out hv);
                ri.speed = hv/100.0;
                sb.append_printf("speed %u ", hv);
            }

			var et = *(rp+36);
			if (et != ri.etype) {
				ri.alert |= Radar.RadarAlert.SET;
			}
			ri.etype = et;
			ri.lq = *(rp+37);
			sb.append_printf("emitter %u tslc %u ", ri.etype, ri.lq);

			TimeSpan ts = -1000000*((int64)(ri.lq));
			ri.dt = now.add(ts);

            sb.append_printf("ticks %u ", ri.lasttick);

			ri.posvalid = true;

			Radar.upsert(v, ri);
			Radar.update(v, ((Mwp.debug_flags & Mwp.DEBUG_FLAGS.RADAR) != Mwp.DEBUG_FLAGS.NONE));
			Radar.update_marker(v);
		} else {
            sb.append("invald pos ");
        }

        if((Mwp.debug_flags & Mwp.DEBUG_FLAGS.RADAR) != Mwp.DEBUG_FLAGS.NONE)
            MWPLog.message(sb.str);
    }
}