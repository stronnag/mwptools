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

namespace Mwp {
	bool handle_mavlink(MWSerial ser, Msp.Cmds cmd, uint8[]raw, uint len) {
		bool handled = true;
		switch (cmd) {
		case Msp.Cmds.MAVLINK_MSG_ID_HEARTBEAT:
			Mav.MAVLINK_HEARTBEAT m = *(Mav.MAVLINK_HEARTBEAT*)raw;
			force_mav = false;
			uint8 mavarmed;
			if ((m.base_mode & 128) == 128) {
				mavarmed = 1;
			} else {
				mavarmed = 0;
			}
			ser.td.state.state = mavarmed;

			if(ser.is_main) {
				armed = mavarmed;
				sensor = mavsensors;
				armed_processing(armed,"mav");
				uint8 ltmflags = (vi.fc_vers >= FCVERS.hasPOI) ?
					Mav.mav2inav(m.custom_mode, (m.type == Mav.TYPE.MAV_TYPE_FIXED_WING)) :
					Mav.xmav2inav(m.custom_mode, (m.type == Mav.TYPE.MAV_TYPE_FIXED_WING));

				var mchg = (ltmflags != last_ltmf);
				if (mchg) {
					last_ltmf = ltmflags;
					if(ltmflags == Msp.Ltm.POSHOLD)
						want_special |= POSMODE.PH;
					else if(ltmflags == Msp.Ltm.WAYPOINTS)
						want_special |= POSMODE.WP;
					else if(ltmflags == Msp.Ltm.RTH)
						want_special |= POSMODE.RTH;
					else if(ltmflags == Msp.Ltm.ALTHOLD)
						want_special |= POSMODE.ALTH;
					else if(ltmflags == Msp.Ltm.CRUISE)
						want_special |= POSMODE.CRUISE;
					else if(ltmflags != Msp.Ltm.LAND) {
					}
				}

				//			if(achg || mchg)
				//	update_mss_state(ltmflags);
				if(Logger.is_logging) {
					Logger.mav_heartbeat(m);
				}
			}
			break;

		case Msp.Cmds.MAVLINK_MSG_ID_SYS_STATUS:
			if(ser.is_main) {
				Mav.MAVLINK_SYS_STATUS m = *(Mav.MAVLINK_SYS_STATUS*)raw;
				if(sflags == 1) {
					mavsensors = 1;
					if((m.onboard_control_sensors_health & 0x8) == 0x8) {
						sflags |= SPK.BARO;
						mavsensors |= Msp.Sensors.BARO;
					}
					if((m.onboard_control_sensors_health & 0x20) == 0x20) {
						sflags |= SPK.GPS;
						mavsensors |= Msp.Sensors.GPS;
					}
					if((m.onboard_control_sensors_health & 0x4)== 0x4) {
						mavsensors |= Msp.Sensors.MAG;
					}
				}
				Battery.set_bat_stat(m.voltage_battery/10);
				Battery.curr.centiA = m.current_battery/10;
				if(Battery.curr.centiA != 0 || Battery.curr.mah != 0) {
					Battery.curr.ampsok = true;
					if (Battery.curr.centiA > Odo.stats.amps)
						Odo.stats.amps = Battery.curr.centiA;
				}
				if(Logger.is_logging) {
					Logger.mav_sys_status(m);
				}
			}
			break;

		case Msp.Cmds.MAVLINK_MSG_GPS_GLOBAL_INT:
			break;

		case Msp.Cmds.MAVLINK_MSG_RC_CHANNELS:
			break;

		case Msp.Cmds.MAVLINK_MSG_GPS_RAW_INT:
			Mav.MAVLINK_GPS_RAW_INT m = *(Mav.MAVLINK_GPS_RAW_INT*)raw;
			double ddm;
			int fix = m.fix_type;

			if(m.eph != 65535) {
				ser.td.gps.hdop = m.eph/100.0;
			}
			double mlat = m.lat/1e7;
			double mlon = m.lon/1e7;
			var spd  = (m.vel == 0xffff) ? 0 : m.vel/100.0;

			var cse = calc_cse_dist_delta(mlat, mlon, out ddm);
			cse = (m.cog == 0xffff) ? cse : m.cog/100.0;
			double dalt = m.alt/1000.0;

			ser.td.gps.lat = mlat;
			ser.td.gps.lon = mlon;
			ser.td.alt.alt = dalt;
			ser.td.gps.nsats = m.satellites_visible;
			ser.td.gps.cog = cse;
			ser.td.gps.fix = (uint8)fix;
			ser.td.gps.gspeed = spd;

			if(ser.is_main) {
				gpsfix = (fix > 1);
				if(gpsfix) {
					nsats = m.satellites_visible;
					usemag = (m.cog == 0xffff);
					last_gps = nticks;
					Mwp.sat_coverage();
					_nsats = nsats;
					if(armed == 1) {
						if(m.vel != 0xffff) {
							update_odo(m.vel/100.0, ddm);
						}
						if(have_home == false) {
							sflags |=  SPK.GPS;
							home_changed(mlat, mlon);
							want_special |= POSMODE.HOME;
						} else {
							double range,brg;
							double hlat, hlon;
							HomePoint.get_location(out hlat, out hlon);
							Geo.csedist(hlat, hlon, mlat, mlon, out range, out brg);

							if(range >= 0.0 && range < 256) {
								var cg = MSP_COMP_GPS();
								cg.range = (uint16)Math.lround(range*1852);
								cg.direction = (int16)Math.lround(cse);
								ser.td.comp.range =  cg.range;
								ser.td.comp.bearing =  cg.direction;
							}
						}
					}
					update_pos_info();
					if(want_special != 0)
						process_pos_states(mlat, mlon, dalt, "MavGPS");
					if(Logger.is_logging) {
						Logger.mav_gps_raw_int (m);
					}
				}
			}
			break;

		case Msp.Cmds.MAVLINK_MSG_ATTITUDE:
			if(ser.is_main) {
				Mav.MAVLINK_ATTITUDE m = *(Mav.MAVLINK_ATTITUDE*)raw;
				mhead = (int16)(m.yaw*RAD2DEG);
				if(mhead < 0)
					mhead += 360;
				ser.td.atti.yaw = mhead;
				ser.td.atti.angx = (int16)(m.roll*57.29578);
				ser.td.atti.angy = -(int16)(m.pitch*57.29578);
			}
			break;

		case Msp.Cmds.MAVLINK_MSG_RC_CHANNELS_RAW:
			if(ser.is_main) {
				Mav.MAVLINK_RC_CHANNELS m = *(Mav.MAVLINK_RC_CHANNELS*)raw;
				if (Logger.is_logging) {
					Logger.mav_rc_channels(m);
				}
			}
			break;

		case Msp.Cmds.MAVLINK_MSG_GPS_GLOBAL_ORIGIN:
			Mav. MAVLINK_GPS_GLOBAL_ORIGIN m = *(Mav.MAVLINK_GPS_GLOBAL_ORIGIN *)raw;
			ser.td.origin.lat = m.latitude / 1e7;
			ser.td.origin.lon = m.longitude / 1e7;
			if (ser.is_main) {
				wp0.lat  = ser.td.origin.lat;
				wp0.lon  = ser.td.origin.lon;
				if(home_changed(wp0.lat, wp0.lon)) {
					sflags |=  SPK.GPS;
					want_special |= POSMODE.HOME;
					process_pos_states(wp0.lat, wp0.lon, m.altitude / 1000.0, "MAvOrig");
				}
				if(Logger.is_logging) {
					Logger.mav_gps_global_origin(m);
				}
			}
			break;

		case Msp.Cmds.MAVLINK_MSG_VFR_HUD:
			if(ser.is_main) {
				Mav.MAVLINK_VFR_HUD m = *(Mav.MAVLINK_VFR_HUD *)raw;
				mhead = (int16)m.heading;
				ser.td.gps.gspeed = m.groundspeed;
				ser.td.atti.yaw = mhead;
				ser.td.alt.alt = (m.alt * 100);
				//(int16)(m.climb*10)}; // FIXME vario
			}
			break;

		case Msp.Cmds.MAVLINK_MSG_ID_RADIO_STATUS:
			ser.td.rssi.rssi = raw[4]*1023/255;
			break;

		case Msp.Cmds.MAVLINK_MSG_ID_OWNSHIP:
			//                dump_mav_os_msg(raw);
			break;

		case Msp.Cmds.MAVLINK_MSG_ID_TRAFFIC_REPORT:
			//process_mavlink_radar(raw);
			break;

		case Msp.Cmds.MAVLINK_MSG_ID_DATA_REQUEST:
		case Msp.Cmds.MAVLINK_MSG_ID_STATUS:
			break;

		case Msp.Cmds.MAVLINK_MSG_SCALED_PRESSURE:
			break;

		case Msp.Cmds.MAVLINK_MSG_BATTERY_STATUS:
			/*
			int32 mavmah;
			int16 mavamps;

			SEDE.deserialise_i32(raw, out mavmah);
			SEDE.deserialise_i16(&raw[30], out mavamps);
			Battery.curr.centiA = mavamps;
			Battery.curr.mah = mavmah;
			if(Battery.curr.centiA != 0 || Battery.curr.mah != 0) {
				Battery.curr.ampsok = true;
				if (Battery.curr.centiA > Odo.stats.amps)
					Odo.stats.amps = Battery.curr.centiA;
			}
			*/
			break;

		case Msp.Cmds.MAVLINK_MSG_STATUSTEXT:
			if(ser.is_main) {
				uint8 sev = raw[0];
				raw[51] = 0;
				string text = (string)raw[1:50];
				var stext = text.strip();
				MWPLog.message("INFO: mavstatus (%d) %s\n", sev, stext);
			}
			break;

		default:
			handled = false;
			break;
		}
		return handled;
	}
}
