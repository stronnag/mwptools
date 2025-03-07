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

extern uint16 __builtin_bswap16(uint16 x);
extern uint32 __builtin_bswap32(uint32 x);

namespace CRSF {
	const uint8 GPS_ID = 0x02;
	const uint8 VARIO_ID = 0x07;
	const uint8 BARO_ID = 0x09;
	const uint8 BAT_ID = 0x08;
	const uint8 ATTI_ID = 0x1E;
	const uint8 FM_ID = 0x21;
	const uint8 DEV_ID = 0x29;
	const uint8 LINKSTATS_ID = 0x14;
	const double ATTITODEG = (57.29578 / 10000.0);

	public class Teledata : Object {
		public char id;
		public double lat;
		public double lon;
		public int heading;
		public int speed;
		public int alt;
		public int vario;
		public uint8 nsat;
		public uint8 fix;
		public int16 pitch;
		public int16 roll;
		public int16 yaw;
		public double volts;
		public uint16 rssi;
		public bool setlab;
	}


	private Teledata init(MWSerial ser) {
		var d = new Teledata();
		d.id = 'C';
		return d;
	}

	uint8 * deserialise_be_u24(uint8* rp, out uint32 v) {
        v = (*(rp) << 16 |  (*(rp+1) << 8) | *(rp+2));
        return rp + 3*sizeof(uint8);
	}

	private void crsf_analog(Teledata d) {
		MSP_ANALOG2 an = MSP_ANALOG2();
		an.rssi = d.rssi;
		an.vbat = (uint16)(100*d.volts);
		an.mahdraw = (Mwp.conf.smartport_fuel == 2 )? (uint16)Battery.curr.mah :0;
		an.amps = Battery.curr.centiA;
		Battery.process_msp_analog(an);
	}

	private void ProcessCRSF(MWSerial ser, uint8 []buffer) {
		Teledata d;
		if(ser.td.r == null || ((Teledata)ser.td.r).id != 'C') {
			d = init(ser);
			ser.td.r = (Object)d;
		} else {
			d = (Teledata)ser.td.r;
		}

		if (ser.is_main) {
			if(!d.setlab) {
				Mwp.window.mmode.label = "CRSF";
				Mwp.xnopoll = Mwp.nopoll;
				Mwp.nopoll = true;
				Mwp.serstate = Mwp.SERSTATE.TELEM;
				d.setlab = true;
			}
		}
		uint8 id = buffer[2];
		uint8 *ptr = &buffer[3];
		uint32 val32;
		uint16 val16;


		switch(id) {
		case CRSF.GPS_ID:
			int fvup = 0;
			int ttup = 0;
			ptr= SEDE.deserialise_u32(ptr, out val32);  // Latitude (deg * 1e7)
			int32 lat = (int32)__builtin_bswap32(val32);
			ptr= SEDE.deserialise_u32(ptr, out val32); // Longitude (deg * 1e7)
			int32 lon = (int32)__builtin_bswap32(val32);
			ptr= SEDE.deserialise_u16(ptr, out val16); // Groundspeed ( km/h * 10 )
			double gspeed = 0;
			if (val16 != 0xffff) {
				gspeed = __builtin_bswap16(val16) / 36.0; // m/s
			}
			ptr= SEDE.deserialise_u16(ptr, out val16);  // COG Heading ( degree * 100 )
			double hdg = 0;
			if (val16 != 0xffff) {
				hdg = __builtin_bswap16(val16) / 100.0; // deg
			}
			ptr= SEDE.deserialise_u16(ptr, out val16);
			int32 alt= (int32)__builtin_bswap16(val16) - 1000; // m
			uint8 nsat = *ptr;
			var dlat = lat / 1e7;
			d.lat = dlat;
			var dlon = lon / 1e7;
			d.lon = dlon;
			d.heading = (int)hdg;
			d.alt = (int)alt;
			d.nsat = nsat;
			d.speed = (int)gspeed;
			if (nsat > 5)
				d.fix = 3;
			else
				d.fix = 1;

			double ddm;
			if(Rebase.is_valid()) {
				Rebase.relocate(ref dlat, ref dlon);
			}

			Mwp.calc_cse_dist_delta(dlat, dlon, out ddm);

			var pdiff = Mwp.pos_diff(dlat, dlon, ser.td.gps.lat, ser.td.gps.lon);
			if (Mwp.PosDiff.LAT in pdiff) {
				ser.td.gps.lat = dlat;
				fvup |= FlightBox.Update.LAT;
				ttup |= TelemTracker.Fields.LAT;
			}
			if (Mwp.PosDiff.LON in pdiff) {
				ser.td.gps.lon = dlon;
				fvup |= FlightBox.Update.LON;
				ttup |= TelemTracker.Fields.LON;
			}

			if(Math.fabs(ser.td.alt.alt - alt) > 1.0) {
				ser.td.gps.alt = alt;
				ser.td.alt.alt = alt;
				fvup |= FlightBox.Update.ALT;
				ttup |= TelemTracker.Fields.ALT;
			}

			if(Math.fabs(ser.td.gps.gspeed - gspeed) > 0.1) {
				ser.td.gps.gspeed = gspeed;
				fvup |= FlightBox.Update.SPEED;
				ttup |= TelemTracker.Fields.SPD;
			}

			if(ser.td.gps.nsats != nsat) {
				ser.td.gps.fix = d.fix;
				ser.td.gps.nsats = nsat;
				fvup |= FlightBox.Update.GPS;
				ttup |= TelemTracker.Fields.SAT;
			}

			if(ser.td.gps.cog != hdg) {
				ser.td.gps.cog = hdg;
				fvup |= Direction.Update.COG;
				ttup |= TelemTracker.Fields.CSE;
			}

			if (d.fix > 0) {
				if(ser.is_main) {
					Mwp.nsats = nsat;
					Mwp.sat_coverage();
					Mwp._nsats = nsat;
					Mwp.last_gps = Mwp.nticks;
					Mwp.flash_gps();
					if(Mwp.armed == 1) {
						if(HomePoint.is_valid()) {
							double dv;
							if (Mwp.calc_vario(alt, out dv)) {
								ser.td.alt.vario = dv;
								Mwp.panelbox.update(Panel.View.VARIO, Vario.Update.VARIO);
							}
							if(nsat >= Mwp.msats) {
								if(Mwp.pos_valid(dlat, dlon)) {
									double range,brg;
									double hlat, hlon;
									HomePoint.get_location(out hlat, out hlon);
									Geo.csedist(hlat, hlon, dlat, dlon, out range, out brg);
									if(range < 256) {
										var cg = MSP_COMP_GPS();
										cg.range = (uint16)Math.lround(range*1852);
										cg.direction = (int16)Math.lround(brg);
										if(Math.fabs(ser.td.comp.range -  cg.range) > 1.0) {
											ser.td.comp.range =  cg.range;
											fvup |= FlightBox.Update.RANGE;
										}
										if(Math.fabs(ser.td.comp.bearing - cg.direction) > 1.0) {
											ser.td.comp.bearing =  cg.direction;
											fvup = FlightBox.Update.BEARING;
										}
										Mwp.update_odo(gspeed, ddm);
									}
								}
							}
						} else if(Mwp.have_home == false && (nsat > 5) && (lat != 0 && lon != 0) ) {
							Mwp.wp0.lat = dlat;
							Mwp.wp0.lon = dlon;
							Mwp.sflags |= Mwp.SPK.GPS;
							Mwp.want_special |= Mwp.POSMODE.HOME;
							MBus.update_home();
						}
					}
					Mwp.update_pos_info();
					if(Mwp.want_special != 0) {
						Mwp.process_pos_states(dlat, dlon, ser.td.alt.alt, "CRSF");
					}
				}
			}
			if(ser.is_main) {
				if(fvup != 0) {
					Mwp.panelbox.update(Panel.View.FVIEW, fvup);
				}
			} else {
				if (ttup != 0) {
					TelemTracker.ttrk.update(ser, ttup);
				}
			}
			break;
		case CRSF.BAT_ID:
			if (ser.is_main) {
				ptr= SEDE.deserialise_u16(ptr, out val16);  // Voltage ( mV * 100 )
				double volts = 0;
				if (val16 != 0xffff) {
					volts = __builtin_bswap16(val16) / 10.0; // Volts
				}
				ptr= SEDE.deserialise_u16(ptr, out val16);  // Voltage ( mV * 100 )
				double amps = 0;
				if (val16 != 0xffff) {
					amps = __builtin_bswap16(val16) / 10.0; // Amps
				}
				ptr = CRSF.deserialise_be_u24(ptr, out val32);
				uint32 capa = val32;
				d.volts = volts;
				Battery.curr.mah = capa;
				Battery.curr.centiA = (int16)amps*100;
				Battery.curr.ampsok = true;
				if (Battery.curr.centiA > Odo.stats.amps)
					Odo.stats.amps = Battery.curr.centiA;
				crsf_analog(d);
			}
			break;

		case CRSF.VARIO_ID:
			if(ser.is_main) {
				ptr= SEDE.deserialise_u16(ptr, out val16);  // Voltage ( mV * 100 )
				d.vario = (int)__builtin_bswap16(val16);
			}
			break;
		case CRSF.BARO_ID:
			ptr= SEDE.deserialise_u16(ptr, out val16);
			d.alt = (int)__builtin_bswap16(val16);
			if (buffer.length > 5) {
				SEDE.deserialise_u16(ptr, out val16);
				d.vario = (int)__builtin_bswap16(val16);
			}
			ser.td.alt.alt = d.alt;
			break;
		case CRSF.ATTI_ID:
			ptr= SEDE.deserialise_u16(ptr, out val16);  // Pitch radians *10000
			double pitch = 0;
			pitch = ((int16)__builtin_bswap16(val16)) * CRSF.ATTITODEG;
			ptr= SEDE.deserialise_u16(ptr, out val16);  // Roll radians *10000
			double roll = 0;
			roll = ((int16)__builtin_bswap16(val16)) * CRSF.ATTITODEG;
			ptr= SEDE.deserialise_u16(ptr, out val16);  // radians *10000
			double yaw = 0;
			yaw = ((int16)__builtin_bswap16(val16)) * CRSF.ATTITODEG;
			if (yaw < 0) {
				yaw += 360;
			}
			bool fvup = (ser.td.atti.yaw != (int)yaw);
			if(ser.is_main) {
				d.yaw = Mwp.mhead = (int16)yaw ;
				d.pitch = (int16)pitch;
				d.roll = (int16)roll;
				LTM_AFRAME af = LTM_AFRAME();
				af.pitch = d.pitch;
				af.roll = d.roll;
				af.heading = (int16)yaw;
				if(ser.td.atti.angy != d.pitch || ser.td.atti.angx != d.roll) {
					ser.td.atti.angy = d.pitch;
					ser.td.atti.angx = d.roll;
					Mwp.panelbox.update(Panel.View.AHI, AHI.Update.AHI);
				}
				if(fvup) {
					ser.td.atti.yaw = (int)yaw;
					Mwp.panelbox.update(Panel.View.FVIEW, FlightBox.Update.YAW);
					Mwp.panelbox.update(Panel.View.DIRN, Direction.Update.YAW);
				}
			} else {
				if(fvup) {
					ser.td.atti.yaw = (int)yaw;
					TelemTracker.ttrk.update(ser, TelemTracker.Fields.CSE);
				}
			}
			break;
		case CRSF.FM_ID:
			bool c_armed = true;
			uint32 arm_flags = 0;
			uint64 mwflags = 0;
			uint8 ltmflags = 0;
			bool failsafe = false;
			string fm = (string)ptr;
				//			stdout.printf("FM %s\n", (string)ptr );
			switch(fm) {
			case "AIR":
			case "ACRO":
				// Ardupilot WTF ...
			case "QACRO":
				ltmflags = Msp.Ltm.ACRO;
				break;
			case "!FS!":
				failsafe = true;
				break;
			case "MANU":
				// Ardupilot WTF ...
			case "MAN":
				ltmflags = Msp.Ltm.MANUAL; // RTH
				break;
			case "LAND":
				ltmflags = Msp.Ltm.LAND;
				break;
			case "RTH":
				// Ardupilot WTF ...
			case "RTL":
			case "QRTL":
			case "QLAND":
			case "AUTORTL":
			case "SMRTRTL":
				ltmflags = Msp.Ltm.RTH; // RTH
				break;

			case "HOLD":
				//Ardupilot WTF ...
			case "LOIT":
			case "CIRC":
			case "GUID":
			case "GUIDED":
			case "QLOIT":
			case "POSHLD":
				ltmflags = Msp.Ltm.POSHOLD; // PH
				break;

			case "CRUZ":
			case "CRSH":
				// Ardupilot WTF ...
			case "CRUISE":
				ltmflags = Msp.Ltm.CRUISE; // Cruise
				break;

			case "AH":
				// Ardupilot WTF ...
			case "ALTHOLD":
				ltmflags = Msp.Ltm.ALTHOLD; // AltHold
				break;

			case "WP":
				// Ardupilot WTF ...
			case "AUTO":
				ltmflags = Msp.Ltm.WAYPOINTS;  // WP
				break;

			case "ANGL":
				// Ardupilot WTF ...
			case "FBWA":
			case "STAB":
			case "TRAIN":
			case "TKOF":
			case "ATUNE":
			case "ADSB":
			case "THRML":
			case "L2QLND":
				ltmflags = Msp.Ltm.ANGLE; // Angle
				break;

			case "HOR":
				// Ardupilot WTF ...
			case "FBWB":
			case "QSTAB":
			case "QHOV":
				ltmflags = Msp.Ltm.HORIZON; // Horizon
				break;

				// Ardupilot WTF ...
			case "ATUN":
			case "AVD_ADSB":
			case "BRAKE":
			case "DRFT":
			case "FLIP":
			case "FLOHOLD":
			case "FOLLOW":
			case "GUID_NOGPS":
			case "HELI_ARO":
			case "SPORT":
			case "SYSID":
			case "THROW":
			case "TRTLE":
			case "ZIGZAG":
				ltmflags = Msp.Ltm.ACRO;
				break;
			case "OK":
				ltmflags = Msp.Ltm.UNDEFINED;
				break;

			default:
				c_armed = false;
				break;
			}
			ser.td.state.state = (uint8)c_armed | (((uint8)failsafe) << 1);
			ser.td.state.ltmstate = ltmflags;

			if(ser.is_main) {
				if(Mwp.xfailsafe != failsafe) {
					if(failsafe) {
						arm_flags |= Mwp.ARMFLAGS.ARMING_DISABLED_FAILSAFE_SYSTEM;
						MWPLog.message("Failsafe asserted %ds\n", Mwp.duration);
						Mwp.add_toast_text("FAILSAFE");
					} else {
						MWPLog.message("Failsafe cleared %ds\n", Mwp.duration);
					}
					Mwp.xfailsafe = failsafe;
				}

				Mwp.armed = (c_armed) ? 1 : 0;
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

				var achg = Mwp.armed_processing(mwflags,"CRSF");
				var xws = Mwp.want_special;
				var mchg = (ltmflags != Mwp.last_ltmf);
				if (mchg) {
					Mwp.last_ltmf = ltmflags;
					if(ltmflags == Msp.Ltm.POSHOLD)
						Mwp.want_special |= Mwp.POSMODE.PH;
					else if(ltmflags == Msp.Ltm.WAYPOINTS) {
						Mwp.want_special |= Mwp.POSMODE.WP;
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
					Mwp.window.fmode.set_label(lmstr);
					MWPLog.message("New CRSF Mode %s (%d) %d %ds %f %f %x %x\n",
								   lmstr, ltmflags, Mwp.armed, Mwp.duration, Mwp.xlat, Mwp.xlon,
								   xws, Mwp.want_special);
				}

				if(achg || mchg)
					MBus.update_state();

				if(Mwp.wp0.lat == 0.0 && Mwp.wp0.lon == 0.0) {
					if(d.fix > 1) {
						Mwp.wp0.lat = d.lat;
						Mwp.wp0.lon = d.lon;
					}
				}
				if(Mwp.want_special != 0 /* && have_home*/) {
					Mwp.process_pos_states(Mwp.xlat, Mwp.xlon, 0, "CRSF status");
				}
			}
			break;

		case CRSF.LINKSTATS_ID:
			if(ptr[2] == 0) {
				d.rssi = (ptr[0] > ptr[1]) ? ptr[0] : ptr[1];
				d.rssi = 1023*d.rssi/255;
				RSSI.set_title(RSSI.Title.RSSI);
			} else {
				d.rssi = 1023*ptr[2]/100;
				RSSI.set_title(RSSI.Title.LQ);
			}
			bool rssiup = (ser.td.rssi.rssi != d.rssi);
			ser.td.rssi.rssi = d.rssi;
			if(rssiup) {
				if(ser.is_main) {
					Mwp.panelbox.update(Panel.View.RSSI, RSSI.Update.RSSI);
				} else {
					TelemTracker.ttrk.update(ser, TelemTracker.Fields.RSSI);
				}
			}
			break;

		case CRSF.DEV_ID:
			if((Mwp.debug_flags & Mwp.DEBUG_FLAGS.SERIAL) != Mwp.DEBUG_FLAGS.NONE) {
				MWPLog.message("CRSF-DEV %s\n", (string)(ptr+5));
			}
			break;
		default:
			break;
		}
	}
}
