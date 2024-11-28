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

namespace Frsky {
    private uint8 sport_parse_lat_lon(uint val, out int32 value) {
        uint8 imode = (uint8)(val >> 31);
        value = (int)(val & 0x3fffffff);
        if ((val & (1 << 30))!= 0)
            value = -value;
        value = (50*value) / 3; // min/10000 => deg/10000000
        return imode;
    }

	public void process_sport_message (MWSerial ser, uint8[]buf) {
		ushort id;
		uint val;
		SEDE.deserialise_u16(&buf[2], out id);
		SEDE.deserialise_u32(&buf[4], out val);
		if(!SportDev.active) {
			Mwp.window.mmode.label = "S-PORT";
			SportDev.active = true;
			Mwp.xnopoll = Mwp.nopoll;
			Mwp.nopoll = true;
			Mwp.serstate = Mwp.SERSTATE.TELEM;
		}

        double r;
		if(Logger.is_logging) {
			Logger.log_time();
		}

        Mwp.lastrx = Mwp.lastok = Mwp.nticks;
        //if(rxerr) {
        //    set_error_status(null);
        //    rxerr=false;
        //}

        switch(id) {
		case SportDev.FrID.VFAS_ID:
			if(ser.is_main) {
				if (val /100  < 80) {
					SportDev.volts = val / 100.0;
					Mwp.sflags |=  Mwp.SPK.Volts;
				}
				ser.td.power.volts = (float)SportDev.volts;
				Battery.set_bat_stat((uint16)val);
			}
			break;
		case SportDev.FrID.GPS_LONG_LATI_ID:
			int32 ipos;
			uint8 lorl = sport_parse_lat_lon (val, out ipos);
			if (lorl == 0) {
				SportDev.lat = ipos;
			} else {
				SportDev.lon = ipos;
				MSP_ALTITUDE al = MSP_ALTITUDE();
				al.estalt = SportDev.alt;
				al.vario = SportDev.vario;
				double ddm;
				var dlat = SportDev.lat/1e7;
				var dlon = SportDev.lon/1e7;

				ser.td.gps.lat = dlat;
				ser.td.gps.lon = dlon;

				var cse = Mwp.calc_cse_dist_delta(dlat, dlon, out ddm);
				ser.td.atti.yaw = (int)cse;

				if(SportDev.fix > 0) {
					Mwp.sat_coverage();
					if(ser.is_main) {
						if(Mwp.armed != 0) {
							if(Mwp.have_home) {
								if(Mwp._nsats >= Mwp.msats) {
									if(Mwp.pos_valid(dlat, dlon)) {
										Mwp.last_gps = Mwp.nticks;
										double range,brg;
										double hlat, hlon;
										HomePoint.get_location(out hlat, out hlon);
										Geo.csedist(hlat, hlon, dlat, dlon, out range, out brg);
										if(range < 256) {
											var cg = MSP_COMP_GPS();
											cg.range = (uint16)Math.lround(range*1852);
											cg.direction = (int16)Math.lround(brg);
											ser.td.comp.range =  cg.range;
											ser.td.comp.bearing =  cg.direction;
											Mwp.update_odo(SportDev.spd, ddm);
										}
									}
								}
							} else {
								if(Mwp.no_ofix == 10) {
									MWPLog.message("No home position yet\n");
								}
							}
						}

						if(SportDev.fix > 0 && SportDev.sats >= Mwp.msats) {
							Mwp.update_pos_info();
					}
						if(Mwp.want_special != 0)
							Mwp.process_pos_states(dlat, dlon, SportDev.alt/100.0, "Sport");
					}
				}
			}
			break;
		case SportDev.FrID.GPS_ALT_ID:
			r =((int)val) / 100.0;
			SportDev.galt = r;
			ser.td.gps.alt = r;
			break;
		case SportDev.FrID.GPS_SPEED_ID:
			r = ((val/1000.0)*0.51444444);
			SportDev.spd = r;
			ser.td.gps.gspeed = r;
			break;
		case SportDev.FrID.GPS_COURS_ID:
			r = val / 100.0;
			SportDev.cse = r;
			ser.td.gps.cog = r;
			break;
		case SportDev.FrID.ADC2_ID: // AKA HDOP
			if(ser.is_main) {
				Mwp.rhdop = (uint16)((val &0xff)*10);
				SportDev.rhdop = Mwp.rhdop;
				SportDev.flags |= 1;
				ser.td.gps.hdop = Mwp.rhdop / 100.0;
			}
			break;
		case SportDev.FrID.ALT_ID:
			r = (int)val / 100.0;
			SportDev.alt = (int)val;
			Mwp.sflags |=  Mwp.SPK.ELEV;
			ser.td.alt.alt = r;
			break;
		case SportDev.FrID.T1_ID: // flight modes
		case SportDev.FrID.MODES:
			uint ival = val;
			uint32 arm_flags = 0;
			uint64 mwflags = 0;
			uint8 ltmflags = 0;
			bool failsafe = false;

			var modeU = ival % 10;
			var modeJ = ival / 10000;
			failsafe = (modeJ == 4);
			ser.td.state.state = (uint8)((modeU & 4) == 4) | (((uint8)failsafe) << 1);

			if(ser.is_main) {
				var modeT = (ival % 100) / 10;
				var modeH = (ival % 1000) / 100;
				var modeK = (ival % 10000) / 1000;


				if((modeU & 1) == 0)
					arm_flags |=  Mwp.ARMFLAGS.ARMING_DISABLED_OTHER;
				if ((modeU & 4) == 4) { // armed
					mwflags = Mwp.arm_mask;
					Mwp.armed = 1;
					Mwp.dac = 0;
				} else {
					Mwp.dac++;
					if(Mwp.dac == 1 && Mwp.armed != 0) {
						MWPLog.message("Assumed disarm from SPORT %ds\n", Mwp.duration);
						mwflags = 0;
						Mwp.armed = 0;
						Mwp.init_have_home();
					}
				}

				if(modeT == 0)
					ltmflags = Msp.Ltm.ACRO; // Acro
				if (modeT == 1)
					ltmflags = Msp.Ltm.ANGLE; // Angle
				else if (modeT == 2)
					ltmflags = Msp.Ltm.HORIZON; // Horizon
				else if(modeT == 4)
					ltmflags = Msp.Ltm.ACRO; // Acro

				if((modeH & 2) == 2)
					ltmflags = Msp.Ltm.ALTHOLD; // AltHold
				if((modeH & 4) == 4)
					ltmflags = Msp.Ltm.POSHOLD; // PH

				if(modeK == 1)
					ltmflags = Msp.Ltm.RTH; // RTH
				if(modeK == 2)
					ltmflags = Msp.Ltm.WAYPOINTS;  // WP
				//                            if(modeK == 4) ltmflags = 11;
				if(modeK == 8)
					ltmflags = Msp.Ltm.CRUISE; // Cruise

			// if(modeK == 2) emode = "AUTOTUNE";
				failsafe = (modeJ == 4);
				if(Mwp.xfailsafe != failsafe) {
					if(failsafe) {
						arm_flags |=  Mwp.ARMFLAGS.ARMING_DISABLED_FAILSAFE_SYSTEM;
						MWPLog.message("Failsafe asserted %ds\n", Mwp.duration);
						Mwp.add_toast_text("FAILSAFE");
					} else {
						MWPLog.message("Failsafe cleared %ds\n", Mwp.duration);
					}
					Mwp.xfailsafe = failsafe;
				}

				if(arm_flags != Mwp.xarm_flags) {
					Mwp.xarm_flags = arm_flags;
					if((arm_flags & ~(Mwp.ARMFLAGS.ARMED|Mwp.ARMFLAGS.WAS_EVER_ARMED)) != 0) {
						Mwp.window.arm_warn.visible=true;
					} else {
						Mwp.window.arm_warn.visible=false;
					}
				}

				if(ltmflags == Msp.Ltm.ANGLE)
					mwflags |= Mwp.angle_mask;
				if(ltmflags == Msp.Ltm.HORIZON)
					mwflags |= Mwp.horz_mask;
				if(ltmflags == Msp.Ltm.POSHOLD)
					mwflags |= Mwp.ph_mask;
				if(ltmflags == Msp.Ltm.WAYPOINTS)
					mwflags |= Mwp.wp_mask;
				if(ltmflags == Msp.Ltm.RTH || ltmflags == Msp.Ltm.LAND)
					mwflags |= Mwp.rth_mask;
				else
					mwflags = Mwp.xbits; // don't know better

				ser.td.state.ltmstate = ltmflags;

				var achg = Mwp.armed_processing(mwflags,"Sport");
				var xws = Mwp.want_special;
				var mchg = (ltmflags != Mwp.last_ltmf);
				if (mchg) {
					Mwp.last_ltmf = ltmflags;
					if(ltmflags == Msp.Ltm.POSHOLD)
						Mwp.want_special |= Mwp.POSMODE.PH;
					else if(ltmflags == Msp.Ltm.WAYPOINTS) {
						Mwp.want_special |= Mwp.POSMODE.WP;
						//					if (NavStatus.nm_pts == 0 || NavStatus.nm_pts == 255)
						//	NavStatus.nm_pts = last_wp_pts;
					} else if(ltmflags == Msp.Ltm.RTH)
						Mwp.want_special |= Mwp.POSMODE.RTH;
					else if(ltmflags == Msp.Ltm.ALTHOLD)
						Mwp.want_special |= Mwp.POSMODE.ALTH;
					else if(ltmflags == Msp.Ltm.CRUISE)
						Mwp.want_special |= Mwp.POSMODE.CRUISE;
					else if(ltmflags != Msp.Ltm.LAND) {
						Mwp.craft.set_normal();
					}
					var lmstr = Msp.ltm_mode(ltmflags);
					MWPLog.message("New SPort/LTM Mode %s (%d) %d %ds %f %f %x %x\n",
								   lmstr, ltmflags, Mwp.armed, Mwp.duration, Mwp.xlat, Mwp.xlon, xws, Mwp.want_special);
					Mwp.window.fmode.set_label(lmstr);
				}

				if(achg || mchg)
					MBus.update_state();

				if(Mwp.want_special != 0 /* && have_home*/) {
					Mwp.process_pos_states(Mwp.xlat, Mwp.xlon, 0, "SPort status");
				}
			}
			break;

		case SportDev.FrID.T2_ID: // GPS info
		case SportDev.FrID.GNSS:
			if(ser.is_main) {
				uint8 ifix = 0;
				Mwp._nsats = (uint8)(val % 100);
				uint16 hdp;
				hdp = (uint16)(val % 1000)/100;
				if (SportDev.flags == 0) { // prefer FR_ID_ADC2_ID
					SportDev.rhdop = Mwp.rhdop = 550 - (hdp * 50);
					ser.td.gps.hdop = Mwp.rhdop / 100.0;
				}
				uint8 gfix = (uint8)(val /1000);

				if ((gfix & 1) == 1)
					ifix = 3;
				if ((gfix & 2) == 2) {
					if(Mwp.have_home == false && Mwp.armed != 0) {
						if(Mwp.home_changed(ser.td.gps.lat, ser.td.gps.lon)) {
							if(SportDev.fix == 0) {
								Mwp.no_ofix++;
							} else {
								Mwp.sflags |=  Mwp.SPK.GPS;
								Mwp.want_special |= Mwp.POSMODE.HOME;
								Mwp.process_pos_states(ser.td.gps.lat, ser.td.gps.lon, 0.0, "SPort");
							}
						}
					}
				}
				if ((gfix & 4) == 4) {
					if (SportDev.range < 500) {
						MWPLog.message("SPORT: %s set home: changed home position %f %f\n",
									   id.to_string(), ser.td.gps.lat, ser.td.gps.lon);
						Mwp.home_changed(ser.td.gps.lat, ser.td.gps.lon);
						Mwp.want_special |= Mwp.POSMODE.HOME;
						Mwp.process_pos_states(ser.td.gps.lat, ser.td.gps.lon, 0.0, "SPort");
						MBus.update_home();
					} else {
						MWPLog.message("SPORT: %s Ignoring (bogus?) set home, range > 500m: requested home position %f %f\n", id.to_string(), ser.td.gps.lat, ser.td.gps.lon);
					}
				}

				if((Mwp._nsats == 0 && Mwp.nsats != 0) || (Mwp.nsats == 0 && Mwp._nsats != 0)) {
					Mwp.nsats = Mwp._nsats;
				}
				SportDev.sats = Mwp._nsats;
				SportDev.fix = ifix;
				Mwp.flash_gps();
				Mwp.last_gps = Mwp.nticks;
				ser.td.gps.fix = ifix;
				ser.td.gps.nsats = Mwp.nsats;
			}
			break;

		case SportDev.FrID.RSSI_ID:
			SportDev.rssi = (uint16)((val&0xff)*1023/100);
			ser.td.rssi.rssi =  SportDev.rssi;
			break;
		case SportDev.FrID.PITCH:
		case SportDev.FrID.ROLL:
			if(ser.is_main) {
				if (id == SportDev.FrID.ROLL)
					SportDev.roll = (int16)val;
				else
					SportDev.pitch = (int16)val;

				LTM_AFRAME af = LTM_AFRAME();
				af.pitch = SportDev.pitch;
				af.roll = SportDev.roll;
				af.heading = Mwp.mhead = (int16) SportDev.cse;
				ser.td.atti.angx = af.roll;
				ser.td.atti.angy = af.pitch;
				ser.td.atti.yaw = Mwp.mhead;

				if(Logger.is_logging) {
					Logger.attitude((double)SportDev.pitch, (double)SportDev.roll, (int)Mwp.mhead);
				}
			}
			break;

		case SportDev.FrID.HOME_DIST:
			if(ser.is_main) {
				int diff = (int)(SportDev.range - val);
				if(SportDev.range > 100 && (diff * 100 / SportDev.range) > 9)
					MWPLog.message("%s %um (mwp: %u, diff: %d)\n", id.to_string(), val, SportDev.range, diff);
			}
			break;

		case SportDev.FrID.CURR_ID:
			if(ser.is_main) {
				if((val / 10) < 999) {
					Battery.curr.ampsok = true;
					Battery.curr.centiA =  (uint16)(val * 10);
					if (Battery.curr.centiA > Odo.stats.amps) {
						Odo.stats.amps = Battery.curr.centiA;
					}
				}
				//			LTM_SFRAME sf = LTM_SFRAME ();
				//sf.vbat = (uint16)(SportDev.volts*1000);
				//sf.flags = ((failsafe) ? 2 : 0) | (armed & 1) | (ltmflags << 2);
				//sf.vcurr = (conf.smartport_fuel == 2) ? (uint16)curr.mah : 0;
				//sf.rssi = (uint8)(SportDev.rssi * 255/ 1023);
				//sf.airspeed = 0;
			}
			break;
		case SportDev.FrID.ACCX_ID:
			SportDev.ax = ((int)val) / 100.0;
			break;
		case SportDev.FrID.ACCY_ID:
			SportDev.ay = ((int)val) / 100.0;
			break;
		case SportDev.FrID.ACCZ_ID:
			if(ser.is_main) {
				SportDev.az = ((int)val) / 100.0;
				SportDev.pitch = -(int16)(180.0 * Math.atan2 (SportDev.ax, Math.sqrt(SportDev.ay*SportDev.ay + SportDev.az*SportDev.az))/Math.PI);
				SportDev.roll  = (int16)(180.0 * Math.atan2 (SportDev.ay, Math.sqrt(SportDev.ax*SportDev.ax + SportDev.az*SportDev.az))/Math.PI);
				ser.td.atti.angx = SportDev.roll;
				ser.td.atti.angy = SportDev.pitch;
				if(Logger.is_logging) {
					Logger.attitude((double)SportDev.pitch, (double)SportDev.roll, (int16) SportDev.cse);
				}
			}
			break;

		case SportDev.FrID.VARIO_ID:
			SportDev.vario = (int16)((int) val / 10);
			break;

		case SportDev.FrID.FUEL_ID:
			if(ser.is_main) {
				switch (Mwp.conf.smartport_fuel) {
				case 0:
					Battery.curr.mah = 0;
					break;
				case 1:
				case 2:
					Battery.curr.mah = (val > 0xffff) ? 0xffff : (uint16)val;
					break;
				case 3:
				default:
					Battery.curr.mah = val;
					break;
				}
			}
			break;
		default:
			break;
		}
    }
}
