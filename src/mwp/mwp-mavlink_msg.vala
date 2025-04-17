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

namespace Mwp {
	bool handle_mavlink(MWSerial ser, Msp.Cmds cmd, uint8[]raw, uint len) {
		bool handled = true;
		if((Mwp.DebugFlags.MAVLINK in Mwp.debug_flags)) {
			MWPLog.message("::DBG:: [%x, %u] %s\n", cmd, len, cmd.format());
		}
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
					Mwp.window.update_state();
					var ls_state = Msp.ltm_mode(ltmflags);
					Mwp.window.fmode.set_label(ls_state);
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
			Mav.MAVLINK_GPS_GLOBAL_INT *m = (Mav.MAVLINK_GPS_GLOBAL_INT*)raw;
			ser.td.alt.alt = 1000*m->relative_alt;
			break;

		case Msp.Cmds.MAVLINK_MSG_RC_CHANNELS:
			break;

		case Msp.Cmds.MAVLINK_MSG_GPS_RAW_INT:
			Mav.MAVLINK_GPS_RAW_INT m = *(Mav.MAVLINK_GPS_RAW_INT*)raw;
			double ddm;
			int fix = m.fix_type;
			int fvup = 0;
			int ttup = 0;

			fix = int.min(fix, 3);

			if(m.eph != 65535) {
				ser.td.gps.hdop = m.eph/100.0;
			}
			double mlat = m.lat/1e7;
			double mlon = m.lon/1e7;

			if (Rebase.has_reloc()) {
				if (mlat != 0.0 && mlon != 0.0) {
					if (!Rebase.has_origin()) {
						Rebase.set_origin(mlat, mlon);
					}
					Rebase.relocate(ref mlat, ref mlon);
				}
			}

			var spd  = (m.vel == 0xffff) ? 0 : m.vel/100.0;

			var cse = calc_cse_dist_delta(mlat, mlon, out ddm);
			cse = (m.cog == 0xffff) ? cse : m.cog/100.0;
			double dalt = m.alt/1000.0 - ser.td.origin.alt;
			var pdiff = pos_diff(mlat, mlon, ser.td.gps.lat, ser.td.gps.lon);
			if (PosDiff.LAT in pdiff) {
				fvup |= FlightBox.Update.LAT;
				ttup |= TelemTracker.Fields.LAT;
				ser.td.gps.lat = mlat;
			}
			if (PosDiff.LON in pdiff) {
				fvup |= FlightBox.Update.LON;
				ttup |= TelemTracker.Fields.LON;
				ser.td.gps.lon = mlon;
			}

			if(Math.fabs(ser.td.alt.alt - dalt) > 1.0) {
				fvup |= FlightBox.Update.ALT;
				ttup |= TelemTracker.Fields.ALT;
				ser.td.alt.alt = dalt;
				ser.td.gps.alt = m.alt/1000.0;
			}

			if(Math.fabs(ser.td.gps.gspeed - spd) > 0.1) {
				fvup |= FlightBox.Update.SPEED;
				ttup |= TelemTracker.Fields.SPD;
				ser.td.gps.gspeed = spd;
			}

			if(ser.td.gps.nsats != m.satellites_visible || ser.td.gps.fix != fix) {
				fvup |= FlightBox.Update.GPS;
				ttup |= TelemTracker.Fields.SAT;
				ser.td.gps.nsats = m.satellites_visible;
				ser.td.gps.fix = (uint8)fix;
			}

			if(Math.fabs(cse-ser.td.gps.cog) > 1) {
				ser.td.gps.cog = cse;
				Mwp.panelbox.update(Panel.View.DIRN, Direction.Update.COG);
            }

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
								if(Math.fabs(ser.td.comp.range -  cg.range) > 1.0) {
									ser.td.comp.range =  cg.range;
									fvup |= FlightBox.Update.RANGE;
								}
								if(Math.fabs(ser.td.comp.bearing - cg.direction) > 1.0) {
									ser.td.comp.bearing =  cg.direction;
									fvup = FlightBox.Update.BEARING;
								}
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
				if(fvup != 0) {
					Mwp.panelbox.update(Panel.View.FVIEW, fvup);
				}
			} else {
				if (ttup != 0) {
					TelemTracker.ttrk.update(ser, ttup);
				}
			}
			break;

		case Msp.Cmds.MAVLINK_MSG_ATTITUDE:
			Mav.MAVLINK_ATTITUDE m = *(Mav.MAVLINK_ATTITUDE*)raw;
			mhead = (int16)(m.yaw*RAD2DEG);
			if(mhead < 0)
				mhead += 360;
			bool fvup = (Math.fabs(ser.td.atti.yaw - mhead) > 1.0);
				ser.td.atti.yaw = mhead;
				int16 roll = (int16)(-m.roll*Mwp.RAD2DEG);
				int16 pitch = (int16)(m.pitch*Mwp.RAD2DEG);

				var vdiff = ((Math.fabs(ser.td.atti.angx-roll) > 1) || (Math.fabs(ser.td.atti.angy-pitch) > 1));
				ser.td.atti.angx = (int16)roll;
				ser.td.atti.angy = (int16)pitch;
				if(ser.is_main) {
					if(fvup) {
						Mwp.panelbox.update(Panel.View.FVIEW, FlightBox.Update.YAW);
						Mwp.panelbox.update(Panel.View.DIRN, Direction.Update.YAW);
					}
					if(vdiff) {
						Mwp.panelbox.update(Panel.View.AHI, AHI.Update.AHI);
					}
				} else {
					if(fvup) {
						TelemTracker.ttrk.update(ser, TelemTracker.Fields.CSE);
					}
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

			double mlat =  m.latitude / 1e7;
			double mlon = m.longitude / 1e7;

			if (Rebase.has_reloc()) {
				if (mlat != 0.0 && mlon != 0.0) {
					if (!Rebase.has_origin()) {
						Rebase.set_origin(mlat, mlon);
					}
					Rebase.relocate(ref mlat, ref mlon);
				}
			}
			if (ser.is_main) {
				if(home_changed(mlat, mlon)) {
					ser.td.origin.alt = m.altitude/1000;
					sflags |=  SPK.GPS;
					want_special |= POSMODE.HOME;
					process_pos_states(mlat, mlon, m.altitude / 1000.0, "MAvOrig");
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
			var rssi = raw[4]*1023/255;
			if (rssi != ser.td.rssi.rssi) {
				ser.td.rssi.rssi = rssi;
				if(ser.is_main) {
				   Mwp.panelbox.update(Panel.View.RSSI, RSSI.Update.RSSI);
				} else {
					TelemTracker.ttrk.update(ser, TelemTracker.Fields.RSSI);
				}
			}
			break;

		case Msp.Cmds.MAVLINK_MSG_ID_OWNSHIP:
			//                dump_mav_os_msg(raw);
			break;

		case Msp.Cmds.MAVLINK_MSG_ID_TRAFFIC_REPORT:
			MspRadar.process_mavlink_radar(raw);
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
				string text = (string)raw[1:len];
				var stext = text.strip();
				MWPLog.message("INFO: mavstatus (%d) %s\n", sev, stext);
				if(len > 1) {
					if (stext != Mwp.window.statusbar1.label) {
						if (stext.validate()) {
							Mwp.window.statusbar1.label = stext;
						}
					}
				}
			}
			break;

		case Msp.Cmds.MAVLINK_MSG_MESSAGE_INTERVAL:
		case Msp.Cmds.MAVLINK_MSG_ID_76:
		case Msp.Cmds.MAVLINK_MSG_ID_AUTOPILOT_VERSION:
			break;

		default:
			handled = false;
			break;
		}
		return handled;
	}
}

namespace Mav {
	/*
	uint32 swvers = 0;
	uint8 gitid[8];
	void genvers() {
		if (swvers == 0) {
			var v1 = MwpVers.get_id();
			var v2 = MwpVers.get_build();
			var v0 = uint.parse(v1[0:2]);
			swvers = (v0 << 16);
			v0 = uint.parse(v1[3:5]);
			swvers |= (v0 << 8);
			v0 = uint.parse(v1[6:8]);
			swvers |= v0;
			gitid = v2.data[0:8];
		}
	}
	void send_mav_autopilot(MWSerial m) {
		uint8 msg[128] = {0};
		var len = make_mav_autopilot(msg);
		m.send_mav(((uint16)Msp.Cmds.MAVLINK_MSG_ID_AUTOPILOT_VERSION-(uint16)Msp.MAV_BASE), msg[:len], len);
	}
	uint make_mav_autopilot(uint8[] msg) {
		uint8*rp;
		genvers();
		SEDE.serialise_u32(msg+16, swvers); // sw_version
		rp = msg+52;
		for(var i = 0; i < 8; i++) {
			*rp++ = gitid[i];
		}
		return (uint)((intptr)rp - (intptr)msg);
	}
	*/

	uint make_mav_heartbeat(uint8[] msg) {
		uint32 flag = 0;
		uint8*rp;
		if (Mwp.vi.mrtype != 0) {
			flag = Mav.inav2mav(Mwp.msp.td.state.ltmstate, ((Mwp.Vehicle)Mwp.vi.mrtype).is_fw());
		}
		rp = SEDE.serialise_u32(msg, flag); // custom_mode
		*rp++ = 6; // type (GCS)
		*rp++ = 8; // autopilot (INVALID)
		*rp++ = (Mwp.armed == 0) ? 0 : Mav.MODE_FLAG.MAV_MODE_FLAG_SAFETY_ARMED;
		*rp++ = 4; //Mav.MAV_STATE.MAV_STATE_ACTIVE;
		*rp++ = (Mwp.conf.forward ==  Mwp.FWDS.MAV1) ? 1 : 2;
		return (uint)((intptr)rp - (intptr)msg);
	}

	void send_mav_heartbeat(MWSerial m) {
		uint8 msg[16] = {0};
		var len = make_mav_heartbeat(msg);
		m.send_mav(((uint16)Msp.Cmds.MAVLINK_MSG_ID_HEARTBEAT-(uint16)Msp.MAV_BASE), msg[:len], len);
	}

	void send_mav_beacon(MWSerial m) {
		send_mav_heartbeat(m);
		//send_mav_autopilot(m);
	}
}
