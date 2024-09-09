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
	bool handle_ltm(MWSerial ser, Msp.Cmds cmd, uint8[]raw, uint len) {
		bool handled = true;
		lastrx = nticks;
		Mwp.window.mmode.label = "Ltm";

		switch(cmd) {
		case Msp.Cmds.TO_FRAME:
			LTM_OFRAME of = LTM_OFRAME();
			uint8* rp;
			rp = SEDE.deserialise_i32(raw, out of.lat);
			rp = SEDE.deserialise_i32(rp, out of.lon);
			rp = SEDE.deserialise_i32(rp, out of.alt);
			ser.td.origin.lat = of.lat/10000000.0;
			ser.td.origin.lon = of.lon/10000000.0;
			ser.td.origin.alt = of.alt/100.0;
			of.fix = raw[13];
			if(ser.is_main) {
				wp0.lat = ser.td.origin.lat;
				wp0.lon = ser.td.origin.lon;
				if (Rebase.has_reloc()) {
					if (!Rebase.has_origin()) {
						Rebase.set_origin(wp0.lat, wp0.lon);
					}
					Rebase.relocate(ref wp0.lat, ref wp0.lon);
				}

				if(home_changed(wp0.lat, wp0.lon)) {
					if(of.fix == 0) {
						no_ofix++;
					} else {
						//navstatus.cg_on(); // FIXME
						sflags |=  SPK.GPS;
						want_special |= POSMODE.HOME;
						process_pos_states(wp0.lat, wp0.lon, ser.td.origin.alt, "LTM OFrame");
					}
				} else if (!have_home) {
					have_home = true;
					sflags |=  SPK.GPS;
					want_special |= POSMODE.HOME;
					process_pos_states(wp0.lat, wp0.lon, ser.td.origin.alt, "LTM OFrame");
				}
				if(Logger.is_logging) {
					Logger.ltm_oframe(of);
				}
				MBus.update_home();
			}
			break;
		case Msp.Cmds.TN_FRAME:
			if(ser.is_main) {
				handle_n_frame(ser, cmd, raw);
			}
			break;

		case Msp.Cmds.TG_FRAME:
			sflags |=  SPK.ELEV;
			LTM_GFRAME gf = LTM_GFRAME();
			uint8* rp;

			rp = SEDE.deserialise_i32(raw, out gf.lat);
			rp = SEDE.deserialise_i32(rp, out gf.lon);
			gf.speed = *rp++;
			rp = SEDE.deserialise_i32(rp, out gf.alt);
			gf.sats = *rp;
			double lat = gf.lat/1.0e7;
			double lon = gf.lon/1.0e7;
			if(Rebase.is_valid()) {
				Rebase.relocate(ref lat, ref lon);
			}
			gf.alt /= 100;

			ser.td.gps.lat = lat;
			ser.td.gps.lon = lon;
			ser.td.gps.gspeed = gf.speed;
			ser.td.alt.alt = gf.alt; // cm
			var fix = (gf.sats & 3);
			var lsats = (gf.sats >> 2);
			ser.td.gps.nsats = lsats;
			ser.td.gps.fix = fix;
			double ddm;
			var cse = calc_cse_dist_delta(lat, lon, out ddm);
			ser.td.gps.cog = cse;
			if(fix > 0) {
				if(ser.is_main) {
					flash_gps();
					nsats = lsats;
					MSP_ALTITUDE al = MSP_ALTITUDE();
					al.estalt = gf.alt;
					double dv;
					if(calc_vario(gf.alt, out dv)) {
						ser.td.alt.vario = dv;
					}
					al.vario = (int16)dv;
					if (Logger.is_logging) {
						Logger.altitude(al.estalt, (int16)al.vario);
					}
					sat_coverage();
					_nsats = nsats;
					update_pos_info();
					if(Logger.is_logging) {
						Logger.raw_gps(lat, lon, cse, gf.speed, (int16)gf.alt, fix, lsats, rhdop);
					}
					if(armed != 0) {
						if(HomePoint.is_valid()) {
							if(nsats >= msats || ltm_force_sats) {
								if(pos_valid(lat, lon)) {
									double range,brg;
									double hlat, hlon;
									HomePoint.get_location(out hlat, out hlon);
									Geo.csedist(hlat, hlon, lat, lon, out range, out brg);
									if(range < 256) {
										var cg = MSP_COMP_GPS();
										cg.range = (uint16)Math.lround(range*1852);
										cg.direction = (int16)Math.lround(brg);
										ser.td.comp.range =  cg.range;
										ser.td.comp.bearing =  cg.direction;
										update_odo((double)gf.speed, ddm);
										if(Logger.is_logging) {
											Logger.comp_gps(cg.direction, cg.range, 1);
										}
									}
								}
							}
						} else {
							if(no_ofix == 10) {
								MWPLog.message("No home position yet\n");
							}
						}
						if((sensor & Msp.Sensors.MAG) == Msp.Sensors.MAG && last_nmode != 3 && magcheck && magtime > 0 && magdiff > 0) {
							int gcse = (int)cse;
							if(last_ltmf != Msp.Ltm.POSHOLD && last_ltmf != Msp.Ltm.LAND) {
								if(gf.speed > 3) {
									if(get_heading_diff(gcse, mhead) > magdiff) {
										if(magdt == -1) {
											magdt = (int)duration;
										}
									} else if (magdt != -1) {
										magdt = -1;
										Gis.map_hide_warning();
									}
								} else if (magdt != -1) {
									magdt = -1;
									Gis.map_hide_warning();
								}
							}
							if(magdt != -1 && ((int)duration - magdt) > magtime) {
								MWPLog.message(" ****** Heading anomaly detected %d %d %d\n", mhead, (int)gcse, magdt);
								Gis.map_show_warning("HEADING ANOMALY");
								Audio.play_alarm_sound(MWPAlert.RED);
								magdt = -1;
							}
						}
					}
					if(want_special != 0) {
						process_pos_states(lat, lon, gf.alt/100.0, "GFrame");
					}
				}
			}
			break;

		case Msp.Cmds.TX_FRAME:
			if (ser.is_main) {
				uint8* rp;
				LTM_XFRAME xf = LTM_XFRAME();
				rp = SEDE.deserialise_u16(raw, out rhdop);
				xf.hdop = rhdop;
				xf.sensorok = *rp++;
				xf.ltm_x_count = *rp++;
				xf.disarm_reason = *rp;
				ser.td.gps.hdop = rhdop/100.0;
				alert_broken_sensors(xf.sensorok);
				// hw_status // FIXME
				if(Logger.is_logging) {
					Logger.ltm_xframe(xf);
				}

				if(armed == 0 && xf.disarm_reason != 0 &&
				   xf.disarm_reason < disarm_reason.length)
					MWPLog.message("LTM Disarm (armed = %d) reason %s\n",
								   armed, disarm_reason[xf.disarm_reason]);
			}
			break;

		case Msp.Cmds.TA_FRAME:
			if(ser.is_main) {
				LTM_AFRAME af = LTM_AFRAME();
				uint8* rp;
				rp = SEDE.deserialise_i16(raw, out af.pitch);
				rp = SEDE.deserialise_i16(rp, out af.roll);
				rp = SEDE.deserialise_i16(rp, out af.heading);
				var h = af.heading;
				if(h < 0)
					h += 360;
				mhead = h;
				var vdiff = (af.roll != Atti._sx) || (af.pitch != Atti._sy);
				if(vdiff) {
					Atti._sx = af.roll;
					Atti._sy = af.pitch;
					af.roll = -af.roll;
					if(af.roll < 0) {
						af.roll += 360;
					}
					af.pitch = -af.pitch;
					ser.td.atti.angx = af.roll;
					ser.td.atti.angy = af.pitch;
					if(Logger.is_logging) {
						Logger.attitude(af.roll, af.pitch, mhead);
					}
				}
				ser.td.atti.yaw = mhead;
			}
			break;

			case Msp.Cmds.TS_FRAME:
				LTM_SFRAME sf = LTM_SFRAME ();
				uint8* rp;
				rp = SEDE.deserialise_u16(raw, out sf.vbat);
				rp = SEDE.deserialise_u16(rp, out sf.vcurr);
				sf.rssi = *rp++;
				sf.airspeed = *rp++;
				sf.flags = *rp++;
				ser.td.state.state = (sf.flags & 3);
				ser.td.rssi.rssi = sf.rssi * 1023 / 255; // scaled

				if (ser.is_main) {
					uint8 ltmflags = sf.flags >> 2;
					ser.td.state.ltmstate = ltmflags;
					uint64 mwflags = 0;
					uint8 saf = sf.flags & 1;
					bool failsafe = ((sf.flags & 2)  == 2);
					string ls_state = "";

					if(xfailsafe != failsafe) {
						if(failsafe) {
							MWPLog.message("Failsafe asserted %ds\n", duration);
							Mwp.add_toast_text("FAILSAFE");
							TTS.say(TTS.Vox.FAILSAFE, true);
						} else {
							MWPLog.message("Failsafe cleared %ds\n", duration);
						}
						xfailsafe = failsafe;
					}

					if ((saf & 1) == 1) {
						mwflags = arm_mask;
						armed = 1;
						dac = 0;
					} else {
						dac++;
						if(dac == 1 && armed != 0) {
							MWPLog.message("Assumed disarm from LTM %ds\n", duration);
							mwflags = 0;
							armed = 0;
							//init_have_home(); // FIXME
							/* schedule the bubble machine again .. */
							if(replayer == Player.NONE) {
								reset_poller();
							}
						}
					}
					if(ltmflags == Msp.Ltm.ANGLE)
						mwflags |= angle_mask;
					if(ltmflags == Msp.Ltm.HORIZON)
						mwflags |= horz_mask;
					if(ltmflags == Msp.Ltm.POSHOLD)
						mwflags |= ph_mask;
					if(ltmflags == Msp.Ltm.WAYPOINTS)
						mwflags |= wp_mask;
					if(ltmflags == Msp.Ltm.RTH || ltmflags == Msp.Ltm.LAND)
						mwflags |= rth_mask;
					else
						mwflags = xbits; // don't know better

					var achg = armed_processing(mwflags,"ltm");
					var xws = want_special;
					var mchg = (ltmflags != last_ltmf);
					if(mchg) {
						if (ltmflags !=  Msp.Ltm.POSHOLD &&
							ltmflags !=  Msp.Ltm.WAYPOINTS &&
							ltmflags !=  Msp.Ltm.RTH &&
							ltmflags !=  Msp.Ltm.LAND) { // handled by NAV_STATUS
							TTS.say(TTS.Vox.LTM_MODE);
						}
						last_ltmf = ltmflags;
						if(ltmflags == Msp.Ltm.POSHOLD)
							want_special |= POSMODE.PH;
						else if(ltmflags == Msp.Ltm.WAYPOINTS) {
							want_special |= POSMODE.WP;
							//if (NavStatus.nm_pts == 0 || NavStatus.nm_pts == 255)
							//	NavStatus.nm_pts = last_wp_pts; // FIXME
						} else if(ltmflags == Msp.Ltm.RTH)
							want_special |= POSMODE.RTH;
						else if(ltmflags == Msp.Ltm.ALTHOLD)
							want_special |= POSMODE.ALTH;
						else if(ltmflags == Msp.Ltm.CRUISE)
							want_special |= POSMODE.CRUISE;
						else if(ltmflags == Msp.Ltm.LAND)
							want_special |= POSMODE.LAND;
						else if (ltmflags == Msp.Ltm.UNDEFINED)
							want_special |= POSMODE.UNDEF;
						else if(ltmflags != Msp.Ltm.LAND) {
							if(craft != null)
								craft.set_normal();
						}
						ls_state = Msp.ltm_mode(ltmflags);
						MWPLog.message("New LTM Mode %s (%d) %d %ds %f %f %x %x\n",
									   ls_state, ltmflags, armed, duration,
									   xlat, xlon, xws, want_special);
						Mwp.window.fmode.set_label(ls_state);
					}

					if(mchg || achg) {
						MBus.update_state();
					}

					if(want_special != 0 /* && have_home*/) {
						process_pos_states(xlat,xlon, 0, "SFrame");
					}
					uint16 mah = sf.vcurr;
					uint16 ivbat = (sf.vbat + 50) / 10;

					if (((replayer & Player.BBOX) == Player.BBOX) && Battery.curr.bbla > 0) {
						Battery.curr.ampsok = true;
						Battery.curr.centiA = Battery.curr.bbla;
						if (mah > Battery.curr.mah) {
							Battery.curr.mah = mah;
						}
					} else if (replayer == Player.MWP_FAST || replayer == Player.OTX_FAST) {
						Battery.curr.ampsok = true;
						Battery.curr.mah = mah;
						// navstatus.current(curr, 2); FIXME
					} else if (Battery.curr.lmah == 0) {
						Battery.curr.lmahtm = nticks;
						Battery.curr.lmah = mah;
					} else if (mah > 0 && mah != 0xffff) {
						if (mah > Battery.curr.lmah) {
							var mahtm = nticks;
							var tdiff = (mahtm - Battery.curr.lmahtm);
							var cdiff = mah - Battery.curr.lmah;
							// should be time aware
							if(cdiff < 100 || Battery.curr.lmahtm == 0) {
								Battery.curr.ampsok = true;
								Battery.curr.mah = mah;
								var iamps = (uint16)(cdiff * 3600 / tdiff);
								if (iamps >=  0 && tdiff > 5) {
									Battery.curr.centiA = iamps;
									// navstatus.current(curr, 2);
									if (Battery.curr.centiA > Odo.stats.amps)
										Odo.stats.amps = Battery.curr.centiA;
									Battery.curr.lmahtm = mahtm;
									Battery.curr.lmah = mah;
								}
							} else {
								MWPLog.message("curr error %d\n",cdiff);
							}
							Battery.curr.lmahtm = mahtm;
							Battery.curr.lmah = mah;
						}
						else if (Battery.curr.lmah - mah > 100) {
							MWPLog.message("Negative energy usage %u %u\n", Battery.curr.lmah, mah);
						}
					}
					if(Logger.is_logging) {
						var ls_action = "%s %s".printf(((armed == 1) ? "armed" : "disarmed"),
												   ((failsafe) ? "failsafe" : ""));
						var b = new StringBuilder (ls_action.strip());
						b.append_c(' ');
						b.append(ls_state);
						Logger.ltm_sframe(sf, b.str);
					}
					Battery.set_bat_stat(ivbat);
				}
			break;
		case Msp.Cmds.Tq_FRAME:
			uint16 val = *(((uint16*)raw));
			Odo.stats.time = val;
			duration = (time_t)val;
			break;

		case Msp.Cmds.Ta_FRAME:
			uint16 val = *(((uint16*)raw));
			Battery.curr.bbla = val;
			Battery.curr.ampsok = true;
			if (Battery.curr.bbla > Odo.stats.amps)
				Odo.stats.amps = Battery.curr.bbla;
			break;

		case Msp.Cmds.Tr_FRAME:
			uint8* rp;
			int16 ail,ele,rud,thr;
			rp = SEDE.deserialise_i16(raw, out ail);
			rp = SEDE.deserialise_i16(rp, out ele);
			rp = SEDE.deserialise_i16(rp, out rud);
			SEDE.deserialise_i16(rp, out thr);
			Sticks.update(ail, ele, rud, thr);
			break;

		case Msp.Cmds.Tx_FRAME:
			MWPLog.message("Replay disarm %s (%u)\n", Msp.bb_disarm(raw[0]), raw[0]);
			//cleanup_replay(); // FIXME
			break;

		default:
			handled = false;
			break;
		}
		return handled;
	}
}