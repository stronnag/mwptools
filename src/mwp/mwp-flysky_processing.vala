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

namespace Flysky {

	private void ProcessFlysky(MWSerial s, uint8[] raw) {
        Flysky.Telem t;
		if(Flysky.decode(raw, out t)) {
			Mwp.window.mmode.label = "FLYSKY";
			processFlysky_telem(s, t);
		}
	}

	private void processFlysky_telem(MWSerial ser, Flysky.Telem t) {
		if ((t.mask & (1 << Flysky.Func.VBAT)) != 0) {
			Battery.curr.ampsok = true;
			Battery.curr.centiA =  (uint16)t.curr;
			ser.td.power.volts = (float)t.vbat;
			if(ser.is_main) {
				Battery.set_bat_stat((uint16)t.vbat*100);
			}
		}

		if ((t.mask & (1 << Flysky.Func.LAT0|Flysky.Func.LAT1|Flysky.Func.LON0|Flysky.Func.LON1|Flysky.Func.STATUS)) != 0) {
			int hdop = (t.status % 100) / 10;
			int nsat = (t.status / 1000);
			hdop = hdop*10 + 1;
			int fix = 0;
			bool home = false;

			int ifix = (t.status % 1000) / 100;
			if (ifix > 4) {
				home = true;
				ifix =- 5;
			}
			fix = ifix & 3;
			MSP_RAW_GPS rg = MSP_RAW_GPS();
			rg.gps_fix =(uint8) fix;
			rg.gps_numsat = (uint8)nsat;
			rg.gps_lat = t.ilat;
			rg.gps_lon = t.ilon;
			rg.gps_altitude = (int16)t.alt;
			rg.gps_speed = (uint16)t.speed*100;
			rg.gps_ground_course = (uint16)t.cog*10;
			double ddm;
			double dlat = t.ilat / 1e7;
			double dlon = t.ilon / 1e7;
			if(Rebase.is_valid()) {
				Rebase.relocate(ref dlat, ref dlon);
			}

			var cse = Mwp.calc_cse_dist_delta(dlat, dlon, out ddm);
			var spd = (double)(rg.gps_speed/100.0);

			ser.td.gps.lat = dlat;
			ser.td.gps.lon = dlon;
			ser.td.gps.cog = t.heading;
			ser.td.gps.alt = t.alt;
			ser.td.gps.gspeed = t.speed;
			ser.td.gps.nsats = (uint8)nsat;
			ser.td.gps.fix = (uint8)fix;

			ser.td.atti.yaw = (int)cse;

			if (fix > 0) {
				if(Mwp.armed == 1) {
					if(ser.is_main) {
						Mwp.mhead = (int16)t.heading;
						Mwp.nsats = (uint8)nsat;
						Mwp.sat_coverage();
						Mwp._nsats = (uint8)nsat;
						Mwp.update_odo(spd, ddm);
						if(Mwp.have_home == false && (nsat > 5) && (t.ilat != 0 && t.ilon != 0) ) {
							Mwp.wp0.lat = dlat;
							Mwp.wp0.lon = dlon;
							Mwp.sflags |=  Mwp.SPK.GPS;
							Mwp.want_special |= Mwp.POSMODE.HOME;
							ser.td.origin.lat = dlat;
							ser.td.origin.lon = dlat;
							MBus.update_home();
						}

						Mwp.update_pos_info();
						if(Mwp.want_special != 0)
							Mwp.process_pos_states(dlat, dlon, t.alt, "Flysky");
						Mwp.rhdop = (uint16)hdop*100;
						if(rg.gps_fix != 0) {
							Mwp.last_gps = Mwp.nticks;
						}
						Mwp.flash_gps();
					}
				}
			}
		}

		if((t.mask & (1 << Flysky.Func.HOMEDIRN|Flysky.Func.HOMEDIST)) != 0) {
			ser.td.comp.range = t.homedist;
			ser.td.comp.bearing = t.homedirn;
		}

		if ((t.mask & (1 << Flysky.Func.STATUS)) != 0) {
			int mode = t.status % 10;
			int ifix = (t.status % 1000) / 100;
			bool fl_armed = (ifix > 4) ? true : false;
			bool failsafe = false;
			uint32 arm_flags = 0;
			uint64 mwflags = 0;
			uint8 ltmflags = 0;

			switch(mode) {
			case 0:
				ltmflags = Msp.Ltm.MANUAL;
				break;
			case 1:
				ltmflags = Msp.Ltm.ACRO;
				break;
			case 2:
				ltmflags = Msp.Ltm.HORIZON;
				break;
			case 3:
				ltmflags = Msp.Ltm.ANGLE;
				break;
			case 4:
				ltmflags = Msp.Ltm.WAYPOINTS;
				break;
			case 5:
				ltmflags = Msp.Ltm.ALTHOLD;
				break;
			case 6:
				ltmflags = Msp.Ltm.POSHOLD;
				break;
			case 7:
				ltmflags = Msp.Ltm.RTH;
				break;
			case 8:
				ltmflags = Msp.Ltm.LAUNCH;
				break;
			case 9:
				failsafe = true;
				break;
			}

			ser.td.state.ltmstate = ltmflags;
			ser.td.state.state = (uint8)fl_armed | (((uint8)failsafe) << 1);
			if(ser.is_main) {
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

				Mwp.armed = (fl_armed) ? 1 : 0;
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

				var achg = Mwp.armed_processing(mwflags,"Flysky");
				var xws = Mwp.want_special;
				var mchg = (ltmflags != Mwp.last_ltmf);
				if (mchg) {
					Mwp.last_ltmf = ltmflags;
					if(ltmflags == Msp.Ltm.POSHOLD)
						Mwp.want_special |= Mwp.POSMODE.PH;
					else if(ltmflags == Msp.Ltm.WAYPOINTS) {
						Mwp.want_special |= Mwp.POSMODE.WP;
						//if (NavStatus.nm_pts == 0 || NavStatus.nm_pts == 255)
						//	NavStatus.nm_pts = last_wp_pts;
					}  else if(ltmflags == Msp.Ltm.RTH)
						Mwp.want_special |= Mwp.POSMODE.RTH;
					else if(ltmflags == Msp.Ltm.ALTHOLD)
						Mwp.want_special |= Mwp.POSMODE.ALTH;
					else if(ltmflags == Msp.Ltm.CRUISE)
						Mwp.want_special |= Mwp.POSMODE.CRUISE;
					else if (ltmflags == Msp.Ltm.UNDEFINED)
						Mwp.want_special |= Mwp.POSMODE.UNDEF;
					else if(ltmflags != Msp.Ltm.LAND) {
						Mwp.craft.set_normal();
					}
					var lmstr = Msp.ltm_mode(ltmflags);
					MWPLog.message("New Flysky Mode %s (%d) %d %ds %f %f %x %x\n",
								   lmstr, ltmflags, Mwp.armed, Mwp.duration, Mwp.xlat, Mwp.xlon,
								   xws, Mwp.want_special);
					Mwp.window.fmode.set_label(lmstr);
				}

				if(achg || mchg)
					MBus.update_state();

				if(Mwp.want_special != 0 /* && have_home*/) {
					Mwp.process_pos_states(Mwp.xlat,Mwp.xlon, 0, "Flysky");
				}
			}
		}
	}
}
