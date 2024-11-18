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

namespace DeltaCache {
	double dlat=0;
	double dlon=0;
}

namespace Mwp {
	uint8 last_gmode;
	int lealt=0;
	double lvticks=0;
	double lfdiff = 0.0;

	// ealt in cm. returns cm/sec
    private bool calc_vario(int ealt, out double fdiff) {
        fdiff = lfdiff;
        if((replayer & (Player.BBOX_FAST)) != Player.FAST_MASK) {
			var lv = lastp.elapsed();
			var et  =  lv - lvticks;
			if (et > 0.5) {
				int adiff  = ealt - lealt;
				fdiff = (double)adiff / et;
				lealt = ealt;
				lvticks = lv;
				lfdiff = fdiff;
				return true;
			}
		}
        return false;
    }

    private void gps_alert(uint8 scflags) {
        bool urgent = ((scflags & SAT_FLAGS.URGENT) != 0);
        bool beep = ((scflags & SAT_FLAGS.BEEP) != 0);
        TTS.say(TTS.Vox.MODSAT, urgent);
        if(beep && replayer == Player.NONE) {
            Audio.play_alarm_sound(MWPAlert.SAT);
		}
        last_ga = lastrx;
    }

    private void sat_coverage() {
        uint8 scflags = 0;
        if(nsats != _nsats) {
            if(nsats < msats) {
                if(nsats < _nsats) {
                    scflags = SAT_FLAGS.URGENT|SAT_FLAGS.BEEP;
                } else if((lastrx - last_ga) > USATINTVL) {
                    scflags = SAT_FLAGS.URGENT;
                }
            } else {
                if(nsats < msats)
                    scflags = SAT_FLAGS.URGENT;
                else if((lastrx - last_ga) > UUSATINTVL) {
                    scflags = SAT_FLAGS.NEEDED;
                }
            }
        }

        if((scflags == 0) && ((lastrx - last_ga) > SATINTVL)) {
            scflags = SAT_FLAGS.NEEDED;
        }

        if(scflags != SAT_FLAGS.NONE) {
            gps_alert(scflags);
			MBus.update_fix();
        }
    }

	private void handle_n_frame(MWSerial ser, Msp.Cmds cmd, uint8[] raw) {
			MSP_NAV_STATUS ns = MSP_NAV_STATUS();
			uint8 flg = 0;
			uint8* rp = raw;
			ns.gps_mode = *rp++;

			if(ns.gps_mode == 15) {
				if (nticks - last_crit > CRITINTVL) {
					Audio.play_alarm_sound(MWPAlert.GENERAL);
					MWPLog.message("GPS Critial Failure!!!\n");
					Mwp.add_toast_text("GPS Critial Failure!!!");
					last_crit = nticks;
				}
			} else
				last_crit = 0;

			ns.nav_mode = *rp++;
			ns.action = *rp++;
			ns.wp_number = *rp++;
			ns.nav_error = *rp++;

			if(cmd == Msp.Cmds.NAV_STATUS)
				SEDE.deserialise_u16(rp, out ns.target_bearing);
			else {
				flg = 1;
				ns.target_bearing = *rp++;
			}
			ser.td.state.navmode = 	ns.nav_mode;
			ser.td.state.wpno = ns.wp_number;
			if(ns.nav_mode != last_nmode  || last_nwp != ns.wp_number) {
				TTS.say(TTS.Vox.NAV_STATUS);
			}

			if(ns.gps_mode == 3) {
				if (last_gmode != 3 || ns.wp_number != last_nwp) {
					var ms = MissionManager.current();
					if(ms != null && ns.wp_number > 0) {
						var lat = ms.points[ns.wp_number-1].lat;
						var lon = ms.points[ns.wp_number-1].lon;
						Posring.set_location(lat, lon);
					}
				}
			} else if (last_gmode == 3) {
				Posring.hide();
			}
			MBus.update_wp();

			if(Logger.is_logging) {
				Logger.status(ns);
			}

			bool bok = ((vi.fc_vers >= FCVERS.hasActiveWP) && bblosd_ok) || ((replayer & Player.BBOX) == 0);
			if(bok) {
				if (ns.gps_mode == 3) {
					var ms = MissionManager.current();
					uint np = (ms != null) ? ms.npoints : 0;
					if(np > 0 && ns.wp_number > 0) {
						StringBuilder sb = new StringBuilder();
						if ((conf.osd_mode & Mwp.OSD.show_mission) != 0) {
							if (last_nmode != 3 || ns.wp_number != last_nwp) {
								if(ns.wp_number == np && ms.points[np-1].action == Msp.Action.RTH) {
									sb.append("RTH");
								} else {
									sb.append_printf("%u", ns.wp_number);
									if(np > 0) {
										sb.append_printf("<span size='60%%'>/%u</span>", ms.npoints);
									}
								}
								//mss.m_wp = ns.wp_number;  // FIXME
								//mss.waypoint_changed(mss.m_wp); // FIXME
							}
						}
						if ((conf.osd_mode & Mwp.OSD.show_dist) != 0) {
							var dstr = show_wp_distance(ms, ser.td.gps, ns);
							if(dstr != null) {
								sb.append_c('\n');
								sb.append(dstr);
							}
						}
						Gis.map_show_osd(sb.str);
					}
				} else if (last_gmode == 3) {
					Gis.map_hide_osd();
					// mss.m_wp = -1;  // FIXME
					// mss.waypoint_changed(mss.m_wp); // FIXME
				}
			}
			last_nmode = ns.nav_mode;
			last_gmode = ns.gps_mode;
			last_nwp= ns.wp_number;
	}

	private string? show_wp_distance(Mission ms, GPSData g, MSP_NAV_STATUS ns) {
		string? res = null;
		var np = ns.wp_number - 1;
		if( ms.points[np].action != Msp.Action.JUMP &&
			ms.points[np].action != Msp.Action.SET_HEAD &&
			ms.points[np].action != Msp.Action.SET_POI) {
			double lat,lon;
			if(ms.points[np].action == Msp.Action.RTH) {
				HomePoint.get_location(out lat, out lon);
			} else {
				lat = ms.points[np].lat;
				lon = ms.points[np].lon;
			}

			double dist,cse;
			Geo.csedist(g.lat, g.lon, lat, lon, out dist, out cse);
			StringBuilder sb = new StringBuilder();
			if( ms.points[np].action ==  Msp.Action.POSHOLD_TIME && ns.nav_mode == 4) {
				if(phtim == 0)
					phtim = duration;
				var cdown = ms.points[np].param1 - (duration - phtim);
				sb.append_printf("<span size='60%%'>PH for %lus", cdown);
				sb.append("</span>");
			} else {
				phtim = 0;
				dist *= 1852.0;
				var icse = Math.lrint(cse) % 360;
				sb.append_printf("<span size='60%%'>%.1fm %ld°", dist, icse);
				if(g.gspeed > 0.0 && dist > 1.0)
					sb.append_printf(" %ds", (int)(dist/g.gspeed));
				else
					sb.append(" --s");
				sb.append("</span>");
			}
			res = sb.str;
		}
		return res;
    }

	private void set_pmask_poller(MWSerial.PMask pmask) {
		if (pmask == MWSerial.PMask.AUTO || pmask == MWSerial.PMask.INAV) {
			if (!zznopoll) {
				nopoll = false; // FIXNOPOLL
			}
		} else {
			xnopoll = nopoll;
			nopoll = true;
		}
		msp.set_pmask(pmask);
		msp.set_auto_mpm(pmask == MWSerial.PMask.AUTO);
	}

    private void init_have_home() {
        have_home = false;
		//        markers.negate_home();
        //ls.calc_mission(0);
        home_pos.lat = 0;
        home_pos.lon = 0;
        wp0.lon = xlon = 0;
        wp0.lat = xlat = 0;
        want_special = 0;
    }

    private void update_title_from_file(string fname) {
        var basename = GLib.Path.get_basename(fname);
        StringBuilder sb = new StringBuilder("mwp = ");
        sb.append(basename);
        Mwp.window.title = sb.str;
    }

	private void update_odo(double spd, double ddm) {
        Odo.stats.time = (uint)duration;
        Odo.stats.distance += ddm;
        if (spd > Odo.stats.speed) {
            Odo.stats.speed = spd;
            Odo.stats.spd_secs = Odo.stats.time;
        }
        if(msp.td.comp.range > Odo.stats.range) {
            Odo.stats.range = msp.td.comp.range;
            Odo.stats.rng_secs = Odo.stats.time;
        }
		if (msp.td.alt.alt > Odo.stats.alt) {
            Odo.stats.alt = msp.td.alt.alt;
            Odo.stats.alt_secs = Odo.stats.time;
        }
    }

    private void flash_gps() {
        Mwp.window.gpslab.label = "<span foreground = '%s'>⬤</span>".printf(conf.led);
        Timeout.add_once(25, () => {
                Mwp.window.gpslab.set_label("◯");
            });
    }

    private double calc_cse_dist_delta(double lat, double lon, out double ddm) {
        double c = 0;
        ddm = 0;

		if (lat != DeltaCache.dlat || lon != DeltaCache.dlat) {
			if(DeltaCache.dlat != 0 && DeltaCache.dlon != 0) {
				double d;
				Geo.csedist(DeltaCache.dlat, DeltaCache.dlon, lat, lon, out d, out c);
				ddm = d * 1852.0;
			}
			if (ddm < 128*1000) {
				DeltaCache.dlat = lat;
				DeltaCache.dlon = lon;
			} else {
				ddm = 0;
			}
		}
        return c;
    }

    private bool pos_valid(double lat, double lon) {
        bool vpos;
        if(have_home) {
            if( ((Math.fabs(lat - xlat) < 0.25) && (Math.fabs(lon - xlon) < 0.25)) || (xlon == 0 && xlat == 0)) {
                vpos = true;
                xlat = lat;
                xlon = lon;
            } else {
                vpos = false;
                if(xlat != 0.0 && xlon != 0.0) {
                    MWPLog.message("Ignore bogus %f %f (%f %f)\n", lat, lon, xlat, xlon);
				}
            }
        } else {
            vpos = true;
		}
        return vpos;
    }

    private bool update_pos_info() {
        bool pv;
        pv = pos_valid(msp.td.gps.lat, msp.td.gps.lon);
		if(pv) {
            if(Mwp.window.follow_button.active) {
				if(conf.view_mode > 0) {
					MapUtils.centre_on(msp.td.gps.lat, msp.td.gps.lon);
				} else {
					MapUtils.try_centre_on(msp.td.gps.lat, msp.td.gps.lon);
				}
				double cse = (usemag || ((replayer & Player.MWP) == Player.MWP)) ? mhead : msp.td.gps.cog;
                craft.set_lat_lon(msp.td.gps.lat, msp.td.gps.lon,cse);
            }
			MBus.update_location();
		}
        return pv;
    }

	private int get_heading_diff (int a, int b) {
        var d = int.max(a,b) - int.min(a,b);
        if(d > 180)
            d = 360 - d;
        return d;
    }

    private bool lat_lon_diff(double lat0, double lon0, double lat1, double lon1) {
        var d1 = lat0 - lat1;
        var d2 = lon0 - lon1;
        return (((Math.fabs(d1) > 1e-6) || Math.fabs(d2) > 1e-6));
    }

    private bool home_changed(double lat, double lon) {
        bool ret=false;
		double hlat, hlon;
		HomePoint.get_location(out hlat, out hlon);

		if (lat_lon_diff(lat, lon, hlat , hlon)) {
            if(have_home && (hlat != 0.0) && (hlon != 0.0)) {
                double d,cse;
                Geo.csedist(lat, lon, hlat, hlon, out d, out cse);
                d*=1852.0;
                if(d > conf.max_home_delta) {
                    Audio.play_alarm_sound(MWPAlert.GENERAL);
                    //navstatus.alert_home_moved(); // FIXME
                    MWPLog.message(
                        "Established home has jumped %.1fm [%f %f (ex %f %f)]\n",
                        d, lat, lon, hlat, hlon);
                }
            }
            wp0.lat = lat;
            wp0.lon = lon;
			HomePoint.set_home(lat, lon);
            have_home = true;
            ret = true;
        }
        return ret;
    }

    private void process_pos_states(double lat, double lon, double alt, string? reason=null) {
        if (lat == 0.0 && lon == 0.0) {
            want_special = 0;
            last_ltmf = 0xff;
            return;
        }

        if((armed != 0) && ((want_special & POSMODE.HOME) != 0)) {
            have_home = true;
            want_special &= ~POSMODE.HOME;
            xlat = wp0.lat = lat;
            xlon = wp0.lon = lon;

			if(nrings != 0) {
				RangeCircles.initiate_rings(lat,lon, nrings, ringint);
            }
			craft.special_wp(Craft.Special.HOME, wp0.lat, wp0.lon);
            if(chome) {
				MapUtils.centre_on(lat, lon);
			}

            StringBuilder sb = new StringBuilder ();
            if(reason != null) {
                sb.append(reason);
                sb.append_c(' ');
            }
            sb.append(have_home.to_string());
            MWPLog.message("Set home %f %f (%s)\n", wp0.lat, wp0.lon, sb.str);
			/* FIXME
            mss.h_lat = wp0.lat;
            mss.h_long = wp0.lon;
            mss.h_alt = (int32)alt;
            mss.home_changed(wp0.lat, wp0.lon, mss.h_alt);
			*/

			double dist,cse;
            Geo.csedist(msp.td.gps.lat, msp.td.gps.lon, lat, lon, out dist, out cse);
            dist *= 1852;
            if(nav_rth_home_offset_distance > 0 || (dist > 10.0 && dist <= 200.0)) {
                Mwp.add_toast_text("Home relocated");
            }
            check_mission_home(); // FIXME
        }

        if((want_special & POSMODE.PH) != 0) {
            if(armed != 0 && msp.available) {
                MwpMenu.set_menu_state(Mwp.window, "followme", true);
            } else {
				MwpMenu.set_menu_state(Mwp.window, "followme", false);
			}
            want_special &= ~POSMODE.PH;
            ph_pos.lat = lat;
            ph_pos.lon = lon;
            ph_pos.alt = alt;
			craft.special_wp(Craft.Special.PH, lat, lon);
        }

        if((want_special & POSMODE.RTH) != 0) {
            want_special &= ~POSMODE.RTH;
            rth_pos.lat = lat;
            rth_pos.lon = lon;
            rth_pos.alt = alt;
			craft.special_wp(Craft.Special.RTH, lat, lon);
        }
        if((want_special & POSMODE.ALTH) != 0) {
            want_special &= ~POSMODE.ALTH;
			craft.special_wp(Craft.Special.ALTH, lat, lon);
        }
        if((want_special & POSMODE.CRUISE) != 0) {
            want_special &= ~POSMODE.CRUISE;
			craft.special_wp(Craft.Special.CRUISE, lat, lon);
        }
        if((want_special & POSMODE.WP) != 0) {
            want_special &= ~POSMODE.WP;
			craft.special_wp(Craft.Special.WP, lat, lon);
            //markers.update_ipos(ls, lat, lon); // FIXME
        }
        if((want_special & POSMODE.LAND) != 0) {
            want_special &= ~POSMODE.LAND;
			craft.special_wp(Craft.Special.LAND, lat, lon);
            // markers.update_ipos(ls, lat, lon); // FIXME
        }
        if((want_special & POSMODE.UNDEF) != 0) {
            want_special &= ~POSMODE.UNDEF;
			craft.special_wp(Craft.Special.UNDEF, lat, lon);
            // markers.update_ipos(ls, lat, lon); // FIXME
        }
    }

	private void check_mission_home() {
        if (have_home) {
             var ms = MissionManager.current();
            if(ms != null && ms.npoints > 0) {
                for(var i = 0; i < ms.npoints; i++) {
                    if (ms.points[i].flag == 0x48) {
						ms.points[i].lat = HomePoint.lat();
                        ms.points[i].lon = HomePoint.lon();
                    }
                }
            }
        }
    }

	private void hard_mission_clear() {
		var ms = MissionManager.current();
		if (ms != null) {
			MsnTools.clear(ms);
			ms = null;
		}
		if (Mwp.window.wpeditbutton.active == false) {
			HomePoint.try_hide();
		}
	}

	private void hard_display_reset(bool cm = false) {
		var ms = MissionManager.current();
		if(cm) {
			if (ms != null) {
				MsnTools.clear(ms);
				//wpmgr.wps = {};
			}
        }
        init_sstats();
        armed = 0;
        rhdop = 10000;
        init_have_home();
        Mwp.window.armed_spinner.stop();
        Mwp.window.armed_spinner.visible=false;
        if (conf.audioarmed == true)
            Mwp.window.audio_cb.active = false;
        if(conf.logarmed == true)
            Mwp.window.logger_cb.active=false;

		Battery.set_bat_stat(0);
		msp.td.gps.annul();
		msp.td.atti.annul();
		msp.td.alt.annul();
		msp.td.power.annul();
		msp.td.rssi.annul();
		msp.td.comp.annul();
		msp.td.origin.annul();

		duration = -1;
		craft.remove_all();
		RangeCircles.remove_rings();
        xsensor = 0;
        //clear_sensor_array();
		if(Kml.kmls != null) {
			Kml.remove_all();
		}

		if ((ms == null || ms.npoints == 0) && !Mwp.window.wpeditbutton.active) {
			HomePoint.try_hide();
		}

    }
}