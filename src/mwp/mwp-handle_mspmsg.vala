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

namespace Atti {
        int _sx;
        int _sy;
}

namespace Mwp {
	uint32 feature_mask;
	uint32 capability;
	bool mission_eeprom;
	int last_safehome;
	int safeindex;
	int imdx; // FIXME v. MissionManager
	bool prlabel;
	bool gz_from_msp;
	uint8 []boxids;
	int idcount;

	[Flags]
	private enum StartupTasks {
		SAFEHOMES,
		GEOZONES,
		MISSION,
		STATUS
	}

	StartupTasks starttasks = 0;
	bool need_startup= false;

    private void msp_publish_home(uint8 id) {
        if(id < Safehome.MAXHOMES) {
            var h = Safehome.manager.get_home(id);
            uint8 tbuf[10];
            tbuf[0] = id;
            tbuf[1] = (h.enabled) ? 1 : 0;
            var ll = (int32) (h.lat * 10000000);
            SEDE.serialise_i32(&tbuf[2], ll);
            ll = (int32)(h.lon * 10000000);
            SEDE.serialise_i32(&tbuf[6], ll);
            queue_cmd(Msp.Cmds.SET_SAFEHOME, tbuf, 10);
        } else {
			if (vi.fc_vers >= FCVERS.hasFWApp) {
				safeindex = 0;
				last_safehome = Safehome.MAXHOMES;
				var b = FWApproach.serialise(0);
				queue_cmd(Msp.Cmds.SET_FW_APPROACH, b, b.length);
			} else {
				queue_cmd(Msp.Cmds.EEPROM_WRITE,null, 0);
			}
		}
        run_queue();
    }

	private void set_typlab() {
        string s;

        if(vname == null || vname.length == 0)
            s = "No name";
        else {
            s = "«%s»".printf(vname);
        }
        Mwp.window.typlab.label = s;
    }

	private void request_common_setting(string s) {
		csdq.push_tail(s);
		uint8 msg[128];
		var k = 0;
		for(; k < s.length; k++) {
			msg[k] = s.data[k];
		}
		msg[k++] = 0;
		MWPLog.message("Request setting %s\n", s);
		queue_cmd(Msp.Cmds.COMMON_SETTING, msg, k);
	}

	bool handle_msp(MWSerial ser, Msp.Cmds cmd, uint8[] raw, uint len, uint8 xflags, bool errs) {
		Mwp.window.mmode.label = "MSP";
		bool handled = true;

		if(errs == true) {
            lastrx = lastok = nticks;
            MWPLog.message("Msp Error: %s[0x%x,%d,%db] %s\n", cmd.to_string(), cmd, cmd, len,
                           (cmd == Msp.Cmds.COMMON_SETTING) ? (string)lastmsg.data : "");
            switch(cmd) {
			case Msp.Cmds.ADSB_VEHICLE_LIST:
				clear_poller_item(Msp.Cmds.ADSB_VEHICLE_LIST);
				break;

			case Msp.Cmds.NAME:
				if (xflags == '<') {
					MspRadar.handle_radar(ser, cmd, raw, len, xflags, errs);
				} else {
					queue_cmd(Msp.Cmds.BOARD_INFO,null,0);
					run_queue();
				}
				break;
			case Msp.Cmds.INAV_MIXER:
				queue_cmd(Msp.Cmds.BOARD_INFO,null,0);
				run_queue();
				break;
			case Msp.Cmds.NAV_CONFIG:
				navcap = NAVCAPS.NONE;
				break;

			case Msp.Cmds.COMMON_SERIAL_CONFIG:
				queue_cmd(Msp.Cmds.BOXIDS, null,0);
				run_queue();
				break;

			case Msp.Cmds.API_VERSION:
			case Msp.Cmds.BOXIDS:
				queue_cmd(Msp.Cmds.BOXNAMES, null,0);
				run_queue();
				break;

			case Msp.Cmds.IDENT:
				idcount = -7200;
				queue_cmd(Msp.Cmds.API_VERSION, null,0);
				run_queue();
				break;

			case Msp.Cmds.WP_MISSION_LOAD:
				queue_cmd(msp_get_status,null,0);
				run_queue();
				break;

			case Msp.Cmds.INAV_STATUS:
			case Msp.Cmds.BOX: // e.g. ACTIVEBOXES
				msp_get_status = Msp.Cmds.STATUS_EX;
				queue_cmd(msp_get_status,null,0);
				run_queue();
				break;

			case Msp.Cmds.STATUS_EX:
				msp_get_status = Msp.Cmds.STATUS;
				queue_cmd(msp_get_status,null,0);
				run_queue();
				break;

			case  Msp.Cmds.WP_GETINFO:
			case  Msp.Cmds.SET_RTC:
			case  Msp.Cmds.COMMON_SETTING:
				run_queue();
				break;
			case Msp.Cmds.COMMON_SET_TZ:
				rtcsecs = 0;
				queue_cmd(Msp.Cmds.BUILD_INFO, null, 0);
				run_queue();
				break;
			case  Msp.Cmds.COMMON_SET_SETTING:
				run_queue();
				break;
			case Msp.Cmds.GEOZONE:
			case Msp.Cmds.GEOZONE_VERTEX:
				gzr.reset();
				if(starttasks != 0) {
					handle_misc_startup();
				} else {
					queue_cmd(msp_get_status,null,0);
					run_queue();
				}
				break;
			default:
				queue_cmd(msp_get_status,null,0);
				run_queue();
				break;
            }
            return true;
        }
        else if(((debug_flags & DEBUG_FLAGS.MSP) != DEBUG_FLAGS.NONE) && cmd < Msp.Cmds.LTM_BASE) {
            MWPLog.message("Process Msp %s\n", cmd.to_string());
        }

        if(fwddev.available()) {
            if(cmd < Msp.Cmds.LTM_BASE && conf.forward == FWDS.ALL) {
                fwddev.send_command(cmd, raw, len);
            }
            if(cmd >= Msp.Cmds.LTM_BASE && cmd < Msp.Cmds.MAV_BASE) {
                if (conf.forward == FWDS.LTM || conf.forward == FWDS.ALL ||
                    (conf.forward == FWDS.minLTM &&
                     (cmd == Msp.Cmds.TG_FRAME ||
                      cmd == Msp.Cmds.TA_FRAME ||
                      cmd == Msp.Cmds.TS_FRAME )))
					fwddev.send_ltm((cmd - Msp.Cmds.LTM_BASE), raw, len);
            }
            if(cmd >= Msp.Cmds.MAV_BASE &&
               (conf.forward == FWDS.ALL ||
                (conf.forward == FWDS.minLTM &&
                 (cmd == Msp.Cmds.MAVLINK_MSG_ID_HEARTBEAT ||
                  cmd == Msp.Cmds.MAVLINK_MSG_ID_SYS_STATUS ||
                  cmd == Msp.Cmds.MAVLINK_MSG_GPS_RAW_INT ||
                  cmd == Msp.Cmds.MAVLINK_MSG_VFR_HUD ||
                  cmd == Msp.Cmds.MAVLINK_MSG_ATTITUDE ||
                  cmd == Msp.Cmds.MAVLINK_MSG_RC_CHANNELS_RAW)))) {
                fwddev.send_mav((cmd - Msp.Cmds.MAV_BASE), raw, len);
            }
        }

		if(Logger.is_logging) {
		   Logger.log_time();
		}

		lastrx = lastok = nticks;
		lastmsg.cmd = Msp.Cmds.INVALID;
        switch(cmd) {
		case Msp.Cmds.API_VERSION:
			have_api = true;
			vi.fc_api = raw[1] << 8 | raw[2];
			xarm_flags = 0xffff;
			if (vi.fc_api >= APIVERS.mspV2) {
				ser.use_v2 = true;
				queue_cmd(Msp.Cmds.NAME,null,0);
			} else {
				queue_cmd(Msp.Cmds.BOARD_INFO,null,0);
			}
			MWPLog.message("Using Msp v%c %04x\n", (ser.use_v2) ? '2' : '1', vi.fc_api);
			break;

		case Msp.Cmds.NAME:
			if (xflags == '<') {
				MspRadar.handle_radar(ser, cmd, raw, len, xflags, errs);
				return true;
			} else {
				if(len > 0) {
					raw[len] = 0;
					vname = (string)raw;
				} else {
					vname = "no-name";
				}
				MWPLog.message("Model name: \"%s\"\n", vname);
                Odo.view.set_name(vname);

				if (vi.fc_api >= APIVERS.mixer)
					queue_cmd(Msp.Cmds.INAV_MIXER,null,0);
				else
					queue_cmd(Msp.Cmds.BOARD_INFO,null,0);
				set_typlab();
			}
			break;

		case Msp.Cmds.INAV_MIXER:
			uint16 hx;
			hx = raw[6]<<8|raw[5];
			MWPLog.message("V2 mixer %u %u\n", raw[5], raw[3]);
			if(hx != 0 && hx < 0xff)
				vi.mrtype = raw[5]; // legacy types only
			else {
				switch(raw[3]) {
				case 0:
					vi.mrtype = 3;
					break;
				case 1:
					vi.mrtype = 8;
					break;
				case 3:
					vi.mrtype = 1;
					break;
				default:
					break;
				}
			}
			queue_cmd(Msp.Cmds.BOARD_INFO,null,0);
			break;

		case Msp.Cmds.COMMON_SERIAL_CONFIG:
			have_mavlink = false;
			for(var j = 1; j < len; j+= 9) {
				if ((raw[j]&0x10) == 0x10) {
					have_mavlink = true;
				}
			}
			if(vi.fc_vers >= FCVERS.hasMoreWP) {
				queue_cmd(Msp.Cmds.BOXIDS,null,0);
			} else {
				queue_cmd(Msp.Cmds.BOXNAMES,null,0);
			}
			break;

		case Msp.Cmds.COMMON_SET_TZ:
			rtcsecs = 0;
			queue_cmd(Msp.Cmds.BUILD_INFO, null, 0);
			break;

		case Msp.Cmds.RTC:
			uint16 millis;
			uint8* rp = raw;
			rp = SEDE.deserialise_i32(rp, out rtcsecs);
			SEDE.deserialise_u16(rp, out millis);
			var now = new DateTime.now_local();
			uint16 locmillis = (uint16)(now.get_microsecond()/1000);
			var rem = new DateTime.from_unix_local((int64)rtcsecs);
			string loc = "RTC local %s.%03u, fc %s.%03u\n".printf(
				now.format("%FT%T"),
				locmillis,
				rem.format("%FT%T"), millis);

			if(rtcsecs == 0) {
				uint8 tbuf[6];
				rtcsecs = (uint32)now.to_unix();
				SEDE.serialise_u32(tbuf, rtcsecs);
				SEDE.serialise_u16(&tbuf[4], locmillis);
				queue_cmd(Msp.Cmds.SET_RTC,tbuf, 6);
				run_queue();
			}

			MWPLog.message(loc);
			break;

		case Msp.Cmds.BOARD_INFO:
			raw[4]=0;
			vi.board = (string)raw[0:3];
			if(len > 8) {
				raw[len] = 0;
				vi.name = (string)raw[9:len];
			} else {
				vi.name = null;
			}
			queue_cmd(Msp.Cmds.FC_VARIANT,null,0);
			break;

		case Msp.Cmds.FC_VARIANT:
			if (xflags == '<') {
				MspRadar.handle_radar(ser, cmd, raw, len, xflags, errs);
				return true;
			} else {
				raw[len] = 0;
				inav = false;
				vi.fc_var = (string)raw[0:len];
				if (have_fcv == false) {
					have_fcv = true;
					switch(vi.fc_var) {
					case "INAV":
						navcap = NAVCAPS.WAYPOINTS|NAVCAPS.NAVSTATUS;
						//						if (Craft.is_mr(vi.mrtype))
						//navcap |= NAVCAPS.INAV_MR;
						//else
						//	navcap |= NAVCAPS.INAV_FW;

						vi.fctype = MWChooser.MWVAR.CF;
						inav = true;
						queue_cmd(Msp.Cmds.FEATURE,null,0);
						break;
					default:
						queue_cmd(Msp.Cmds.BOXNAMES,null,0);
						break;
					}
				}
			}
			break;

		case Msp.Cmds.FEATURE:
			SEDE.deserialise_u32(raw, out feature_mask);
			bool curf = (feature_mask & Msp.Feature.CURRENT) != 0;
			MWPLog.message("Feature Mask [%08x] : telemetry %s, gps %s, current %s\n",
						   feature_mask,
						   (0 != (feature_mask & Msp.Feature.TELEMETRY)).to_string(),
						   (0 != (feature_mask & Msp.Feature.GPS)).to_string(),
						   curf.to_string());
			queue_cmd(Msp.Cmds.BLACKBOX_CONFIG,null,0);
			break;

		case Msp.Cmds.GEOZONE:
			var cnt = gzr.zone_parse(raw, len);
			if (cnt >= GeoZoneManager.MAXGZ) {
				queue_gzvertex(0, 0);
			} else {
				queue_gzone(cnt);
			}
			break;

		case Msp.Cmds.GEOZONE_VERTEX:
			int8 nz;
			int8 nv = 0;
			bool res =  gzr.vertex_parse(raw, len, out nz, out nv);
			if (res) {
				queue_gzvertex(nz, nv);
			} else {
				reset_poller();
				res = gzr.validate();
				if (res) {
					MWPLog.message("Geozones validated\n");
					if(gzone != null) {
						gzone.remove();
						gzone = null;
						set_gzsave_state(false);
					}
					gzone = gzr.generate_overlay();
					set_gzsave_state(true);
					Idle.add(() => {
							gzone.display();
							gzedit.refresh(gzone);
							if (Logger.is_logging) {
								Logger.logstring("geozone", gzr.to_string());
							}
							return false;
						});
				} else {
					gzr.reset();
				}
				handle_misc_startup();
			}
			break;

		case Msp.Cmds.SET_GEOZONE:
			gzcnt++;
			if (gzcnt < GeoZoneManager.MAXGZ) {
				var mbuf = gzr.encode_zone(gzcnt);
				queue_cmd(Msp.Cmds.SET_GEOZONE, mbuf, mbuf.length);
			} else {
				MWPLog.message("Geozone completed, start vertices\n");
				gzr.init_vertex_iter();
				var mbuf = gzr.encode_next_vertex();
				if (mbuf.length > 0) {
					queue_cmd(Msp.Cmds.SET_GEOZONE_VERTEX, mbuf, mbuf.length);
				} else {
					// allow saving of empty zone set
					MWPLog.message("Geozone vertices upload completed\n");
					wpmgr.wp_flag = WPDL.RESET_POLLER|WPDL.REBOOT; // abusive ... ish
					queue_cmd(Msp.Cmds.EEPROM_WRITE,null, 0);
				}
			}
			break;

		case Msp.Cmds.SET_GEOZONE_VERTEX:
			var mbuf = gzr.encode_next_vertex();
			if (mbuf.length > 0) {
				queue_cmd(Msp.Cmds.SET_GEOZONE_VERTEX, mbuf, mbuf.length);
			} else {
				MWPLog.message("Geozone vertices upload completed\n");
				wpmgr.wp_flag = WPDL.RESET_POLLER|WPDL.REBOOT; // abusive ... ish
				queue_cmd(Msp.Cmds.EEPROM_WRITE,null, 0);
			}
			break;

		case Msp.Cmds.BLACKBOX_CONFIG:
			Msp.Cmds next = Msp.Cmds.FC_VERSION;
			if (raw[0] == 1 && raw[1] == 1)  // enabled and sd flash
				next = Msp.Cmds.DATAFLASH_SUMMARY;
			queue_cmd(next,null,0);
			break;

		case Msp.Cmds.DATAFLASH_SUMMARY:
			uint32 fsize;
			uint32 used;
			SEDE.deserialise_u32(raw+5, out fsize);
			SEDE.deserialise_u32(raw+9, out used);
			if(fsize > 0) {
				var pct = 100 * used  / fsize;
				MWPLog.message ("Data Flash %u /  %u (%u%%)\n", used, fsize, pct);
				if(conf.flash_warn > 0 && pct > conf.flash_warn)
					Utils.warning_box("Data flash is %u%% full".printf(pct),
									  Gtk.MessageType.WARNING);
			} else
				MWPLog.message("Flash claims to be 0 bytes!!\n");

			queue_cmd(Msp.Cmds.FC_VERSION,null,0);
			break;

		case Msp.Cmds.FC_VERSION:
			if (xflags == '<') {
				MspRadar.handle_radar(ser, cmd, raw, len, xflags, errs);
				return true;
			} else {
				if(have_fcvv == false) {
					have_fcvv = true;
					MwpMenu.set_menu_state(Mwp.window, "reboot", true);
#if UNIX
					MwpMenu.set_menu_state(Mwp.window, "terminal", true);
#endif
					vi.fc_vers = raw[0] << 16 | raw[1] << 8 | raw[2];
					Safehome.manager.online_change(vi.fc_vers);

					var fcv = "%s v%d.%d.%d".printf(vi.fc_var,raw[0],raw[1],raw[2]);
					Mwp.window.verlab.label = fcv;
					Mwp.window.verlab.tooltip_text = fcv;
					if(inav) {
						if(vi.fc_vers < FCVERS.hasMoreWP)
							wp_max = 15;
						else if (vi.board != "AFNA" && vi.board != "CC3D")
							wp_max =  (vi.fc_vers >= FCVERS.hasWP_V4) ? (uint8)conf.max_wps :  60;
						else
							wp_max = 30;

						mission_eeprom = (vi.board != "AFNA" &&
										  vi.board != "CC3D" &&
										  vi.fc_vers >= FCVERS.hasEEPROM);

						msp_get_status = (vi.fc_api < 0x200) ? Msp.Cmds.STATUS :
							(vi.fc_vers >= FCVERS.hasV2STATUS) ? Msp.Cmds.INAV_STATUS : Msp.Cmds.STATUS_EX;
						// ugly hack for jh flip32 franken builds post 1.73
						if((vi.board == "AFNA" || vi.board == "CC3D") &&
						   msp_get_status == Msp.Cmds.INAV_STATUS)
							msp_get_status = Msp.Cmds.STATUS_EX;

						if (vi.fc_api >= APIVERS.mspV2 && vi.fc_vers >= FCVERS.hasTZ && conf.adjust_tz) {
							var dt = new DateTime.now_local();
							int16 tzoffm = (short)((int64)dt.get_utc_offset()/(1000*1000*60));
							if(tzoffm != 0) {
								MWPLog.message("set TZ offset %d\n", tzoffm);
								queue_cmd(Msp.Cmds.COMMON_SET_TZ, &tzoffm, sizeof(int16));
							}  else
								queue_cmd(Msp.Cmds.BUILD_INFO, null, 0);
						} else
							queue_cmd(Msp.Cmds.BUILD_INFO, null, 0); //?BOXNAMES?
					} else {
						queue_cmd(Msp.Cmds.BOXNAMES,null,0);
					}
				}
			}
			break;

		case Msp.Cmds.BUILD_INFO:
			if(len > 18) {
				uint8 gi[16] = raw[19:len];
				gi[len-19] = 0;
				vi.fc_git = (string)gi;
			}
			uchar vs[4];
			SEDE.serialise_u32(vs, vi.fc_vers);
			if(vi.name == null)
				vi.name = "unknown";
			var vers = "%s v%d.%d.%d  %s (%s)".printf(vi.fc_var,
													  vs[2],vs[1],vs[0],
													  vi.name, vi.fc_git);
			Mwp.window.verlab.label = vers;
			Mwp.window.verlab.tooltip_text = vers;
			MWPLog.message("%s\n", vers);
			queue_cmd(Msp.Cmds.COMMON_SERIAL_CONFIG,null,0);
			break;

		case Msp.Cmds.IDENT:
			idcount = 0;
			last_gps = 0;
			have_vers = true;
			//bat_annul();
			hwstatus[0]=1;

			for(var j = 1; j < 9; j++)
				hwstatus[j] = 0;
			if (icount == 0) {
				vi = {0};
				vi.mvers = raw[0];
				vi.mrtype = raw[1];
				craft.park();
				SEDE.deserialise_u32(raw+3, out capability);
				MWPLog.message("set mrtype=%u cap =%x\n", vi.mrtype, raw[3]);

				if ((raw[3] & 0x10) == 0x10) {
					navcap = NAVCAPS.WAYPOINTS|NAVCAPS.NAVSTATUS|NAVCAPS.NAVCONFIG;
					wp_max = 120;
				} else {
					navcap = NAVCAPS.NONE;
				}
				MwpMenu.set_menu_state(Mwp.window, "reboot", false);
				MwpMenu.set_menu_state(Mwp.window, "terminal", false);
				var vers="MWvers v%03d".printf(vi.mvers);
				Mwp.window.verlab.label = Mwp.window.verlab.tooltip_text = vers;
				queue_cmd(Msp.Cmds.API_VERSION,null,0);
			}
			icount++;
			break;

		case Msp.Cmds.BOXNAMES:
		case Msp.Cmds.BOXIDS:
			if (cmd == Msp.Cmds.BOXIDS && xflags == '<') {
				MspRadar.handle_radar(ser, cmd, raw, len, xflags, errs);
				return true;
			}
			if(vi.fc_vers >= FCVERS.hasMoreWP) {
				gen_serial_stats();
				var nbyte = telstats.s.rxbytes + telstats.s.txbytes;
				var rcyt = nbyte/telstats.s.elapsed;
				if(telstats.s.elapsed > 0.5) {
					ser.set_weak();
				}
				MWPLog.message("Initial cycle %f (b=%u r=%.1f, bi=%.1f) %s\n",
							   telstats.s.elapsed, nbyte, rcyt, 8*rcyt, (ser.is_weak()) ? "*" : "");
			}

			if(replayer == Player.NONE) {
				if(navcap != NAVCAPS.NONE) {
					MwpMenu.set_menu_state(Mwp.window, "upload-mission", true);
					if(vi.fc_vers >= FCVERS.hasWP_V4)
						MwpMenu.set_menu_state(Mwp.window, "upload-missions", true);
					MwpMenu.set_menu_state(Mwp.window, "download-mission", true);
				}

				if(mission_eeprom) {
					MwpMenu.set_menu_state(Mwp.window, "restore-mission", true);
					MwpMenu.set_menu_state(Mwp.window, "store-mission", true);
					if(inav) {
						MwpMenu.set_menu_state(Mwp.window, "mission-info", true);
					}
				}

			}
			string boxnames = null;
			if (cmd == Msp.Cmds.BOXNAMES) {
				raw[len] = 0;
				boxnames = (string)raw;
				MWPLog.message("BOXNAMES: %s\n", boxnames);
				string []bsx = boxnames.split(";");
				uint i = 0;
				foreach(var bs in bsx) {
					switch(bs) {
					case "ARM":
						arm_mask = (1 << i);
						break;
					case "ANGLE":
						angle_mask = (1 << i);
						break;
					case "HORIZON":
						horz_mask = (1 << i);
						break;
					case "GPS HOME":
					case "NAV RTH":
						rth_mask = (1 << i);
						break;
					case "GPS HOLD":
					case "NAV POSHOLD":
						ph_mask = (1 << i);
						break;
					case "NAV WP":
					case "MISSION":
						wp_mask = (1 << i);
						break;
					case "NAV CRUISE":
						cr_mask = (1 << i);
						break;
					case "FAILSAFE":
						fs_mask = (1 << i);
						break;
					}
					i++;
				}
			} else {
				var sb = new StringBuilder();
				boxids = raw.copy();
				sb.append_c('[');
				for (var j = 0; j < len; j++) {
					var i = raw[j];
                    sb.append_printf(" %d", i);
					switch(i) {
					case Perm.ID.ARM:
						arm_mask = (1 << j);
						break;
					case Perm.ID.ANGLE:
						angle_mask = (1 << j);
						break;
					case Perm.ID.HORIZON:
						horz_mask = (1 << j);
						break;
					case Perm.ID.NAV_RTH:
						rth_mask = (1 << j);
						break;
					case Perm.ID.NAV_POSHOLD:
						ph_mask = (1 << j);
						break;
					case Perm.ID.NAV_WP:
						wp_mask = (1 << j);
						break;
					case Perm.ID.NAV_COURSE_HOLD:
						cr_mask = (1 << j);
						break;
					case Perm.ID.FAILSAFE:
						fs_mask = (1 << j);
						break;
					}
				}
				sb.append_c(']');
				MWPLog.message("Boxids: %s\n", sb.str);
			}
			MWPLog.message("Masks arm=%x angle=%x horz=%x ph=%x rth=%x wp=%x crz=%x fs=%x\n",
						   arm_mask, angle_mask, horz_mask, ph_mask,
						   rth_mask, wp_mask, cr_mask, fs_mask);

			set_typlab();

			if(Logger.is_logging) {
				string devnam = null;
				if(ser.available)
					devnam = dev_entry.text;
				Logger.fcinfo(MissionManager.last_file, vi, capability, profile, boxnames, vname, devnam, raw[0:len]);
			}
			need_mission = false;
			if((navcap & NAVCAPS.NAVCONFIG) == NAVCAPS.NAVCONFIG)
				queue_cmd(Msp.Cmds.STATUS,null,0);
			else {
				if(inav) {
					wpmgr.wp_flag = WPDL.GETINFO;
					queue_cmd(Msp.Cmds.WP_GETINFO, null, 0);
				}
				queue_cmd(Msp.Cmds.ACTIVEBOXES,null,0);
			}
			break;

		case Msp.Cmds.GPSSTATISTICS:
			LTM_XFRAME xf = LTM_XFRAME();
			SEDE.deserialise_u16(raw, out gpsstats.last_message_dt);
			SEDE.deserialise_u16(raw+2, out gpsstats.errors);
			SEDE.deserialise_u16(raw+6, out gpsstats.timeouts);
			SEDE.deserialise_u16(raw+10, out gpsstats.packet_count);
			SEDE.deserialise_u16(raw+14, out gpsstats.hdop);
			SEDE.deserialise_u16(raw+16, out gpsstats.eph);
			SEDE.deserialise_u16(raw+18, out gpsstats.epv);
			rhdop = xf.hdop = gpsstats.hdop;

			//			MWPLog.message(":DBG: GPS dt: %hu err %hu to %hu cnt %hu hdop %hu eph %hu epv %hu\n", gpsstats.last_message_dt, gpsstats.errors, gpsstats.timeouts, gpsstats.packet_count, gpsstats.hdop, gpsstats.eph, gpsstats.epv);

			ser.td.gps.hdop = xf.hdop/100.0;
			if(Logger.is_logging) {
			   Logger.ltm_xframe(xf);
			}
			break;

		case Msp.Cmds.ACTIVEBOXES:
			uint32 ab;
			SEDE.deserialise_u32(raw, out ab);
			StringBuilder sb = new StringBuilder();
			sb.append_printf("Activeboxes %u %08x", len, ab);
			if(len > 4) {
				SEDE.deserialise_u32(raw+4, out ab);
				sb.append_printf(" %08x", ab);
			}
			sb.append_c('\n');
			MWPLog.message(sb.str);
			need_startup = true;
			if(vi.fc_vers >= FCVERS.hasTZ) {
				string maxdstr = (vi.fc_vers >= FCVERS.hasWP1m) ? "nav_wp_max_safe_distance" : "nav_wp_safe_distance";
				MWPLog.message("Requesting common settings\n");
				request_common_setting(maxdstr);
				request_common_setting("inav_max_eph_epv");
				request_common_setting("gps_min_sats");
				if(vi.fc_vers > FCVERS.hasJUMP && vi.fc_vers <= FCVERS.hasPOI) { // also 2.6 feature
					request_common_setting("nav_rth_home_offset_distance");
				}
				if(vi.fc_vers >= FCVERS.hasSAFEAPI) {
					request_common_setting("safehome_max_distance");
				}
				if(vi.fc_vers >= FCVERS.hasFWApp) {
					request_common_setting("nav_fw_land_approach_length");
					request_common_setting("nav_fw_loiter_radius");
				}
			}

			if(vi.fc_vers > FCVERS.hasSAFEAPI && conf.autoload_safehomes) {
				starttasks += StartupTasks.SAFEHOMES;
			}
			if (vi.fc_vers >= FCVERS.hasGeoZones && ((feature_mask & Msp.Feature.GEOZONE) == Msp.Feature.GEOZONE)) {
				MwpMenu.set_menu_state(Mwp.window, "gz-dl", true);
				MwpMenu.set_menu_state(Mwp.window, "gz-ul", true);
				if(conf.autoload_geozones) {
					starttasks += StartupTasks.GEOZONES;
				}
			}
			if(need_mission) {
				need_mission = false;
				if(conf.auto_restore_mission) {
					starttasks += StartupTasks.MISSION;
				}
			}
			starttasks += StartupTasks.STATUS;
			// fired off by common settings ....

			break;

		case Msp.Cmds.COMMON_SET_SETTING:
			MWPLog.message("Received set_setting\n");
			if ((wpmgr.wp_flag & WPDL.SAVE_ACTIVE) != 0) {
				wpmgr.wp_flag &= ~WPDL.SAVE_ACTIVE;
				queue_cmd(Msp.Cmds.EEPROM_WRITE,null, 0);
			} else if ((wpmgr.wp_flag & WPDL.RESET_POLLER) != 0) {
				wp_reset_poller();
			}
			break;

		case Msp.Cmds.COMMON_SETTING:
			var lset =  csdq.pop_head();
			var sb = new StringBuilder();
			sb.append_printf("Received %s: ", lset);
			switch ((string)lset) {
			case "nav_wp_multi_mission_index":
				if (len == 1) {
					sb.append_printf("%u\n", raw[0]);
					if (raw[0] > 0) {
						imdx = raw[0]-1;
					} else {
						imdx = 0;
					}
					if ((wpmgr.wp_flag & WPDL.KICK_DL) != 0) {
					   wpmgr.wp_flag &= ~WPDL.KICK_DL;
					   start_download();
					}
				} else {
					sb.append_printf("length error %u\n", len);
				}
				break;
			case "gps_min_sats":
				if (len == 1) {
					msats = raw[0];
					sb.append_printf("%u\n", msats);
				} else {
					sb.append_printf("length error %u\n", len);
				}
				break;
			case "nav_wp_safe_distance":
				if (len == 2) {
					SEDE.deserialise_u16(raw, out nav_wp_safe_distance);
					wpdist = nav_wp_safe_distance / 100;
					sb.append_printf("%um\n", wpdist);
				} else {
					sb.append_printf("length error %u\n", len);
				}
				break;
			case "safehome_max_distance":
				if (len == 2) {
					SEDE.deserialise_u16(raw, out safehome_max_distance);
					safehome_max_distance /= 100;
					Safehome.manager.set_distance(safehome_max_distance);
					sb.append_printf("%um\n", wpdist);
				} else {
					sb.append_printf("length error %u\n", len);
				}
				break;
			case "nav_wp_max_safe_distance":
				if (len == 2) {
					SEDE.deserialise_u16(raw, out nav_wp_safe_distance);
					wpdist = nav_wp_safe_distance;
					sb.append_printf("%um\n", safehome_max_distance);
				} else {
					sb.append_printf("length error %u\n", len);
				}
				break;
			case "nav_fw_land_approach_length":
				if (len == 4) {
					SEDE.deserialise_u32(raw, out FWPlot.nav_fw_land_approach_length);
					FWPlot.nav_fw_land_approach_length /= 100;
					sb.append_printf("%um\n", FWPlot.nav_fw_land_approach_length);
				} else {
					sb.append_printf("length error %u\n", len);
				}
				break;
			case "nav_fw_loiter_radius":
				if(len == 2) {
					uint16 fwr;
					SEDE.deserialise_u16(raw, out fwr);
					FWPlot.nav_fw_loiter_radius = fwr / 100;
					sb.append_printf("%um\n", FWPlot.nav_fw_loiter_radius);
				} else {
					sb.append_printf("length error %u\n", len);
				}
				break;

			case "inav_max_eph_epv":
				// .. all the world's a VAX
				if (len == 4) {
					float f = (float)*((float*)raw);
					inav_max_eph_epv = (uint16)f;
					sb.append_printf("%u\n", inav_max_eph_epv);
				} else {
					sb.append_printf("length error %u\n", len);
				}
				break;
			case "nav_rth_home_offset_distance":
				if(len == 2) {
					SEDE.deserialise_u16(raw, out nav_rth_home_offset_distance);
					sb.append_printf("%um\n", nav_rth_home_offset_distance/100);
					if(nav_rth_home_offset_distance != 0) {
						request_common_setting("nav_rth_home_offset_direction");
					}
				} else {
					sb.append_printf("length error %u\n", len);
				}
				break;
			case "nav_rth_home_offset_direction":
				if (len == 2) {
					uint16 odir;
					SEDE.deserialise_u16(raw, out odir);
					sb.append_printf("%u°\n", odir);
				} else {
					sb.append_printf("length error %u\n", len);
				}
				break;
			default:
				sb.append_printf("**UNKNOWN**\n");
				break;
			}
			MWPLog.message(sb.str);
			if(csdq.is_empty ()) {
				if(need_startup) {
					need_startup = false;
					handle_misc_startup();
				}
			}
			break;

		case Msp.Cmds.STATUS:
			if (xflags == '<') {
				MspRadar.handle_radar(ser, cmd, raw, len, xflags, errs);
				return true;
			} else {
				handle_msp_status(raw, len);
			}
			break;
		case Msp.Cmds.STATUS_EX:
		case Msp.Cmds.INAV_STATUS:
			handle_msp_status(raw, len);
			break;

		case Msp.Cmds.SENSOR_STATUS:
			for(var i = 0; i < 9; i++)
				hwstatus[i] = raw[i];
			MWPLog.message("Sensor status %d\n", hwstatus[0]);
			if(hwstatus[0] == 0) {
				Mwp.window.arm_warn.visible=true;
			}
			break;

		case Msp.Cmds.WP_GETINFO:
			wpi = MSP_WP_GETINFO();
			uint8* rp = raw;
			rp++;
			wp_max = wpi.max_wp = *rp++;
			wpi.wps_valid = *rp++;
			wpi.wp_count = *rp;
			MWPLog.message("WP_GETINFO: %u/%u/%u\n",
						   wpi.max_wp, wpi.wp_count, wpi.wps_valid);
			last_wp_pts = wpi.wp_count;
			if((wpmgr.wp_flag & WPDL.GETINFO) != 0) {
				string s = "Waypoints in FC\nMax: %u / Mission points: %u Valid: %s".printf(wpi.max_wp, wpi.wp_count, (wpi.wps_valid==1) ? "Yes" : "No");
				Utils.warning_box(s, 5);
				wpmgr.wp_flag &= ~WPDL.GETINFO;
			}
			if((wpmgr.wp_flag & WPDL.SAVE_FWA) != 0) {
				wp_set_approaches(0);
			} else {
				handle_extra_up_tasks();
			}
			break;

		case Msp.Cmds.NAV_STATUS:
			handle_n_frame(ser, cmd, raw);
            break;

		case Msp.Cmds.NAV_POSHOLD:
			MWPLog.message("MW NAV_POSHOLD ignored\n");
			break;

		case Msp.Cmds.FW_CONFIG:
			MWPLog.message("NAV_FW_CONFIG WTF\n");
			break;

		case Msp.Cmds.NAV_CONFIG:
			MWPLog.message("MW NAV_CONFIG ignored\n");
			break;

		case Msp.Cmds.SET_NAV_CONFIG:
			MWPLog.message("SET_NAV_CONFIG WTF\n");
			break;

		case Msp.Cmds.COMP_GPS:
			int fvup = 0;
			MSP_COMP_GPS cg = MSP_COMP_GPS();
			uint8* rp;
			rp = SEDE.deserialise_u16(raw, out cg.range);
			rp = SEDE.deserialise_i16(rp, out cg.direction);
			cg.update = *rp;
			if ((int)cg.range != ser.td.comp.range) {
				ser.td.comp.range = (int)cg.range;
				fvup |= FlightBox.Update.RANGE;
			}
			if(ser.td.comp.bearing != (int)cg.direction) {
				ser.td.comp.bearing = (int)cg.direction;
				fvup |= FlightBox.Update.BEARING;
			}
			if(fvup != 0) {
				Mwp.panelbox.update(Panel.View.FVIEW, fvup);
			}
			if(Logger.is_logging) {
				Logger.comp_gps(cg.direction, cg.range, 1);
			}
			break;

		case Msp.Cmds.ATTITUDE:
			MSP_ATTITUDE at = MSP_ATTITUDE();
			uint8* rp;
			rp = SEDE.deserialise_i16(raw, out at.angx);
			rp = SEDE.deserialise_i16(rp, out at.angy);
			SEDE.deserialise_i16(rp, out at.heading);
			mhead = at.heading;
			if(mhead < 0) {
				mhead += 360;
			}
			at.angx /= 10;
			at.angy /= 10;

			var vdiff = (at.angx != Atti._sx) || (at.angy != Atti._sy);
			if(vdiff) {
				Atti._sx = at.angx;
				Atti._sy = at.angy;
				at.angx = -at.angx;
				if(at.angx < 0) {
					at.angx += 360;
				}
				at.angy = -at.angy;
				ser.td.atti.angx = at.angx;
				ser.td.atti.angy = at.angy;
				Mwp.panelbox.update(Panel.View.AHI, AHI.Update.AHI);
			}
			bool yawup = (ser.td.atti.yaw != mhead);
			if(yawup) {
				ser.td.atti.yaw = mhead;
				Mwp.panelbox.update(Panel.View.FVIEW, FlightBox.Update.YAW);
				Mwp.panelbox.update(Panel.View.DIRN, Direction.Update.YAW);
			}
			if(Logger.is_logging) {
				Logger.attitude(at.angx, at.angy, mhead);
			}
			break;

		case Msp.Cmds.ALTITUDE:
			  uint8* rp;
			  MSP_ALTITUDE al = MSP_ALTITUDE();
			  rp = SEDE.deserialise_i32(raw, out al.estalt);
			  SEDE.deserialise_i16(rp, out al.vario);
			  double dv = al.vario/100.0;
			  double dea = (double)al.estalt/100.0;

			  var altup = (Math.fabs(ser.td.alt.alt - dea) > 1.0);
			  var varup = (Math.fabs(ser.td.alt.vario - dv) > 1.0);

			  if(varup) {
				  ser.td.alt.vario = dv;
				  Mwp.panelbox.update(Panel.View.VARIO, Vario.Update.VARIO);
			  }
			  if(altup) {
				  ser.td.alt.alt = dea;
				  Mwp.panelbox.update(Panel.View.FVIEW, FlightBox.Update.ALT);
			  }
			  if(Logger.is_logging) {
				   Logger.altitude(ser.td.alt.alt, ser.td.alt.vario);
			  }
			  break;

		case Msp.Cmds.ANALOG2:
			MSP_ANALOG2 an = {0};
			SEDE.deserialise_u16(raw+1, out an.vbat);
			SEDE.deserialise_u16(raw+3, out an.amps);
			SEDE.deserialise_u32(raw+9, out an.mahdraw);
			SEDE.deserialise_u16(raw+22, out an.rssi);
			Battery.process_msp_analog(an);
			var rssiup = (ser.td.rssi.rssi != an.rssi);
			if(rssiup) {
				ser.td.rssi.rssi = an.rssi;
				Mwp.panelbox.update(Panel.View.RSSI, RSSI.Update.RSSI);
			}
			break;

		case Msp.Cmds.ANALOG:
			MSP_ANALOG2 an = {0};
			uint8 v8;
			uint16 pmah;
			v8 = raw[0];
			an.vbat = (uint16)v8;
			an.vbat *= 10;
			SEDE.deserialise_u16(raw+1, out pmah);
			an.mahdraw = pmah;
			SEDE.deserialise_i16(raw+3, out an.rssi);
			SEDE.deserialise_i16(raw+5, out an.amps);
			Battery.process_msp_analog(an);
			var rssiup = (ser.td.rssi.rssi != an.rssi);
			if(rssiup) {
				ser.td.rssi.rssi = an.rssi;
				Mwp.panelbox.update(Panel.View.RSSI, RSSI.Update.RSSI);
			}
			break;

		case Msp.Cmds.RAW_GPS:
			if (xflags == '<') {
				MspRadar.handle_radar(ser, cmd, raw, len, xflags, errs);
			} else {
				int fvup = 0;
				MSP_RAW_GPS rg = MSP_RAW_GPS();
				uint8* rp = raw;

				rg.gps_fix = *rp++;
				flash_gps();
				nsats = rg.gps_numsat = *rp++;
				rp = SEDE.deserialise_i32(rp, out rg.gps_lat);
				rp = SEDE.deserialise_i32(rp, out rg.gps_lon);
				rp = SEDE.deserialise_i16(rp, out rg.gps_altitude);
				rp = SEDE.deserialise_u16(rp, out rg.gps_speed);
				rp = SEDE.deserialise_u16(rp, out rg.gps_ground_course);
				if(len == 18) {
					SEDE.deserialise_u16(rp, out rg.gps_hdop);
					ser.td.gps.hdop = rg.gps_hdop/100.0;
				}

				double lat, lon;
				lat = rg.gps_lat/1.0e7;
				lon = rg.gps_lon/1.0e7;
				if(Rebase.is_valid()) {
					Rebase.relocate(ref lat,ref lon);
				}

				if(Math.fabs(lat - ser.td.gps.lat) > 1e-6) {
					ser.td.gps.lat = lat;
					fvup |= FlightBox.Update.LAT;
				}
				if(Math.fabs(lon - ser.td.gps.lon) > 1e-6) {
					ser.td.gps.lon = lon;
					fvup |= FlightBox.Update.LON;
				}

				if(Math.fabs(ser.td.alt.alt - rg.gps_altitude) > 1.0) {
					ser.td.gps.alt =  rg.gps_altitude;
					//fvup |= FlightBox.Update.ALT;
				}

				double gspd = rg.gps_speed/100.0;
				if(Math.fabs(ser.td.gps.gspeed - gspd) > 0.1) {
					ser.td.gps.gspeed = gspd;
					fvup |= FlightBox.Update.SPEED;
				}

				var dcog = rg.gps_ground_course/10.0;
				var cogup = (Math.fabs(ser.td.gps.cog -  dcog) > 1.0);
				if (cogup) {
					ser.td.gps.cog = dcog;
					Mwp.panelbox.update(Panel.View.DIRN, Direction.Update.COG);
				}

				if(Logger.is_logging) {
					Logger.raw_gps(lat, lon, ser.td.gps.cog, ser.td.gps.gspeed,
								   rg.gps_altitude, rg.gps_fix, rg.gps_numsat, rg.gps_hdop);
				}

				if(rg.gps_fix != 0) {
					if(replayer == Player.NONE) {
						if(inav)
							rg.gps_fix++;
					} else {
						last_gps = nticks;
					}
				}

				if((ser.td.gps.fix != rg.gps_fix) || (ser.td.gps.nsats != rg.gps_numsat)) {
					ser.td.gps.fix = rg.gps_fix;
					ser.td.gps.nsats = rg.gps_numsat;
					fvup |= FlightBox.Update.GPS;
				}

				if(fvup != 0) {
					Mwp.panelbox.update(Panel.View.FVIEW, fvup);
				}

				if (rg.gps_fix > 0) {
					if (vi.fc_api >= APIVERS.mspV2 && vi.fc_vers >= FCVERS.hasTZ) {
						if(rtcsecs == 0 && nsats >= msats && replayer == Player.NONE) {
							MWPLog.message("Request RTC pos: %f %f sats %d hdop %.1f\n",
										   lat, lon, nsats, rhdop/100.0);
							queue_cmd(Msp.Cmds.RTC,null, 0);
						}
					}
					sat_coverage();
					_nsats = nsats;

					if(armed == 1) {
						update_odo(ser.td.gps.gspeed, ser.td.comp.range);
						if(have_home == false && home_changed(wp0.lat, wp0.lon)) {
							sflags |=  SPK.GPS;
							want_special |= POSMODE.HOME;
							MBus.update_home();
						}
					}
					update_pos_info();
					if(want_special != 0) {
						process_pos_states(ser.td.gps.lat, ser.td.gps.lon, rg.gps_altitude, "RAW GPS");
					}
				}
			}
			break;

		case Msp.Cmds.SET_WP:
			if(wpmgr.wps.length > 0) {
				lastok = lastrx = nticks;
				wpmgr.wpidx++;
				if(wpmgr.wpidx < wpmgr.npts) {
					uint8 wtmp[32];
					var nb = serialise_wp(wpmgr.wps[wpmgr.wpidx], wtmp);
					Mwp.window.validatelab.set_text("WP:%3d".printf(wpmgr.wpidx+1));
					queue_cmd(Msp.Cmds.SET_WP, wtmp, nb);
				} else {
					remove_tid(ref upltid);

					if((wpmgr.wp_flag & WPDL.CALLBACK) != 0)
						upload_callback(wpmgr.npts);

					if ((wpmgr.wp_flag & WPDL.SAVE_EEPROM) != 0) {
						uint8 zb=42;
						wpmgr.wp_flag = (WPDL.GETINFO|WPDL.RESET_POLLER|WPDL.SET_ACTIVE|WPDL.SAVE_ACTIVE);
						queue_cmd(Msp.Cmds.WP_MISSION_SAVE, &zb, 1);
					} else if ((wpmgr.wp_flag & WPDL.GETINFO) != 0) {
						MWPLog.message("mission uploaded for %d points\n", wpmgr.npts);
						wpmgr.wp_flag |= WPDL.SET_ACTIVE|WPDL.RESET_POLLER;
						if(inav)
							queue_cmd(Msp.Cmds.WP_GETINFO, null, 0);
						else {
							wpmgr.wp_flag = WPDL.RESET_POLLER;
							wp_reset_poller();
						}
						Mwp.window.validatelab.set_text("✔"); // u+2714
						Utils.warning_box("Mission uploaded", 5);
					} else if ((wpmgr.wp_flag & WPDL.FOLLOW_ME) !=0 ) {
						request_wp(254);
						wpmgr.wp_flag &= ~WPDL.FOLLOW_ME;
						wp_reset_poller();
					} else {
						wp_reset_poller();
					}
				}
			}
			break;

		case Msp.Cmds.WP:
			handle_mm_download(raw, len);
			break;

		case Msp.Cmds.FW_APPROACH:
			var id = FWApproach.deserialise(raw, len);
			if(id == last_safehome-1) {
				if(id ==Safehome.MAXHOMES-1) {
					Safehome.manager.reset_fwa();
					Safehome.manager.set_status(sh_disp);
				} else {
					wp_get_approaches(id+1-Safehome.MAXHOMES);
				}
				handle_misc_startup();
			} else {
				id++;
				queue_cmd(Msp.Cmds.FW_APPROACH,&id,1);
			}
			break;

		case Msp.Cmds.SAFEHOME:
			uint8* rp = raw;
			uint8 id = *rp++;
			SafeHome shm = new SafeHome();
			shm.enabled = (*rp == 1) ? true : false;
			rp++;
			int32 ll;
			rp = SEDE.deserialise_i32(rp, out ll);
			shm.lat = ll / 10000000.0;
			SEDE.deserialise_i32(rp, out ll);
			shm.lon = ll / 10000000.0;
			Safehome.manager.receive_safehome(id, shm);
			id += 1;
			if (id < Safehome.MAXHOMES && id < last_safehome) {
				queue_cmd(Msp.Cmds.SAFEHOME,&id,1);
			} else {
				if(Rebase.is_valid()) {
					Safehome.manager.relocate_safehomes();
				}
				Safehome.manager.set_status(sh_disp);
				id = 0;
				last_safehome = Safehome.MAXHOMES;
				queue_cmd(Msp.Cmds.FW_APPROACH,&id,1);
			}
			break;

		case Msp.Cmds.SET_SAFEHOME:
			safeindex += 1;
			msp_publish_home((uint8)safeindex);
			break;

		case Msp.Cmds.SET_FW_APPROACH:
			safeindex++;
			if(safeindex == last_safehome) {
				if(safeindex <= Safehome.MAXHOMES) {
					queue_cmd(Msp.Cmds.EEPROM_WRITE,null, 0);
				} else {
					wp_set_approaches(safeindex-Safehome.MAXHOMES);
				}
			} else {
				if(safeindex < FWApproach.MAXAPPROACH) {
					var b = FWApproach.serialise(safeindex);
					queue_cmd(Msp.Cmds.SET_FW_APPROACH, b, b.length);
				} else {
					MWPLog.message("BUG: unexpected req for SET_FW %d\n", safeindex);
				}
			}
			break;

		case Msp.Cmds.WP_MISSION_SAVE:
			MWPLog.message("Confirmed mission save\n");
			if ((wpmgr.wp_flag & WPDL.GETINFO) != 0) {
				if(inav) {
					queue_cmd(Msp.Cmds.WP_GETINFO, null, 0);
				}
				Mwp.window.validatelab.set_text("✔"); // u+2714
				Utils.warning_box("Mission uploaded", 5);
			}
			break;

		case Msp.Cmds.EEPROM_WRITE:
			MWPLog.message("Wrote EEPROM\n");
			if ((wpmgr.wp_flag & WPDL.REBOOT) != 0) {
				wpmgr.wp_flag &= ~WPDL.REBOOT;
				queue_cmd(Msp.Cmds.REBOOT, null, 0);
			} else if ((wpmgr.wp_flag & WPDL.RESET_POLLER) != 0) {
				wpmgr.wp_flag &= ~WPDL.RESET_POLLER;
				wp_reset_poller();
			}
			break;

		case Msp.Cmds.PRIV_TEXT_EOM:
			var txt = (string)raw[0:len];
			Odo.view.set_text(txt);
			break;

		case Msp.Cmds.PRIV_TEXT_GEOZ:
			if (gzone == null) {
				var txt = (string)raw[0:len];
				gzr.from_string(txt);
				if(gzone != null) {
					set_gzsave_state(false);
					gzone.remove();
					gzone = null;
				}
				gzone = gzr.generate_overlay();
				Idle.add(() => {
						gzone.display();
						return false;
					});
			}
			break;

		case Msp.Cmds.MAVLINK_MSG_ID_RADIO:
			//			handle_radio(raw);
			break;

		case Msp.Cmds.REBOOT:
			MWPLog.message("Reboot scheduled\n");
			Msp.close_serial();
			Timeout.add_seconds_once(2, () => {
					var serdev = Mwp.dev_entry.text;
					MWPLog.message("Reconnecting %s\n", serdev);
					var sparts = serdev.split(" ");
					Msp.try_reopen(sparts[0]);
				});
			break;

		case Msp.Cmds.WP_MISSION_LOAD:
			wpmgr.wp_flag = WPDL.DOWNLOAD;
			queue_cmd(Msp.Cmds.WP_GETINFO, null, 0);
			break;

		case Msp.Cmds.SET_RTC:
			MWPLog.message("Set RTC ack\n");
			break;

		case Msp.Cmds.DEBUGMSG:
			var dstr = ((string)raw).chomp();
			MWPLog.message("DEBUG:%s\n", dstr);
			break;

		case Msp.Cmds.ADSB_VEHICLE_LIST:
			MspRadar.process_msp2_adsb(raw, len);
			break;

		case Msp.Cmds.RADAR_POS:
		case Msp.Cmds.COMMON_SET_RADAR_POS:
			MspRadar.process_inav_radar_pos(raw, len);
			break;

		default:
			handled = false;
			break;
		}
		return handled;
	}

    private string get_arm_fail(uint32 af, char sep=',') {
        StringBuilder sb = new StringBuilder ();
        if(af == 0)
            sb.append("Ready to Arm");
        else {
            for(var i = 0; i < 32; i++) {
                if((af & (1<<i)) != 0) {
                    if(i < arm_fails.length) {
                        if (arm_fails[i] != null) {
                            sb.append(arm_fails[i]);
                            if ((1 << i) == ARMFLAGS.ARMING_DISABLED_NAVIGATION_UNSAFE) {
                                bool navmodes = true;

                                sb.append_c(sep);
                                if(gpsstats.eph > inav_max_eph_epv ||
								   gpsstats.epv > inav_max_eph_epv) {
                                    sb.append(" • Fix quality");
                                    sb.append_c(sep);
                                    navmodes = false;
                                }
                                if(_nsats < msats ) {
                                    sb.append_printf(" • %d satellites", _nsats);
                                    sb.append_c(sep);
                                    navmodes = false;
                                }

								if(wpdist > 0) {
									var ms = MissionManager.current();
									if(ms != null) {
									if(ms.npoints > 0) {
										double cw, dw;
										var mi = ms.get_waypoint(0);
										Geo.csedist(xlat, xlon, mi.lat, mi.lon,
													out dw, out cw);
										dw /= 1852;
										if(dw > wpdist) {
											sb.append_printf(" • 1st wp distance %dm/%.1fm", wpdist, dw);
											sb.append_c(sep);
											navmodes = false;
										};
									}
									}
								}

                                if(navmodes) {
                                    sb.append(" • Reason unknown; is a nav mode engaged?");
                                    sb.append_c(sep);
                                }
                            } else
                                sb.append_c(sep);
                        }
                    } else {
                        sb.append_printf("Unknown(%d)", i);
                        sb.append_c(sep);
                    }
                }
            }
            if(sb.len > 0 && sep != '\n')
                sb.truncate(sb.len-1);
        }
        return sb.str;
    }

    private void report_bits(uint64 bits) {
        string mode = null;
        if((bits & angle_mask) == angle_mask) {
            mode = "Angle";
        }
        else if((bits & horz_mask) == horz_mask) {
            mode = "Horizon";
        } else if((bits & (ph_mask | rth_mask)) == 0) {
            mode = "Acro";
        }
        if(mode != null) {
            Mwp.window.fmode.set_label(mode);
        }
    }

    private void update_sensor_array() {
        alert_broken_sensors((uint8)(sensor >> 15));
        for(int i = 0; i < 5; i++) {
            uint16 mask = (1 << i);
            bool setx = ((sensor & mask) != 0);
            sensor_sts[i+1].label = "<span foreground = \"%s\">▌</span>".printf((setx) ? "green" : "red");
        }
        sensor_sts[0].label = sensor_sts[1].label;
    }

    private void  alert_broken_sensors(uint8 val) {
        if(val != xs_state) {
            string sound;
            MWPLog.message("sensor health %04x %d %d\n", sensor, val, xs_state);
            if(val == 1) {
                sound = (sensor_alm) ? MWPAlert.GENERAL : MWPAlert.RED;
                sensor_alm = true;
                Mwp.add_toast_text("SENSOR FAILURE");
				TTS.say(TTS.Vox.HW_BAD, true);
            } else {
				TTS.say(TTS.Vox.HW_OK);
                sound = MWPAlert.GENERAL;
                hwstatus[0] = 1;
			}
            Audio.play_alarm_sound(sound);
            xs_state = val;
            if(serstate != SERSTATE.TELEM) {
                MWPLog.message("request sensor info\n");
                queue_cmd(Msp.Cmds.SENSOR_STATUS,null,0);
            }
        }
    }


	private void handle_msp_status(uint8[]raw, uint len) {
        uint64 bxflag;
        uint64 lmask;

        SEDE.deserialise_u16(raw+4, out sensor);

		if(msp_get_status != Msp.Cmds.INAV_STATUS) {
            uint32 bx32;
            SEDE.deserialise_u32(raw+6, out bx32);
            bxflag = bx32;
        } else {
            SEDE.deserialise_u64(raw+13, out bxflag);
		}
        lmask = (angle_mask|horz_mask);

        armed = ((bxflag & arm_mask) == arm_mask) ? 1 : 0;

		msp.td.state.state = armed;

        if (nopoll == true) {
            have_status = true;
            if((sensor & Msp.Sensors.GPS) == Msp.Sensors.GPS) {
                sflags |= SPK.GPS;
                craft.new_craft(true);
            }
            update_sensor_array();
        } else {
			uint32 arm_flags = 0;
            uint16 loadpct;
            if(msp_get_status != Msp.Cmds.STATUS) {
                if(msp_get_status == Msp.Cmds.STATUS_EX) {
                    uint16 xaf;
                    SEDE.deserialise_u16(raw+13, out xaf);
                    arm_flags = xaf;
                    SEDE.deserialise_u16(raw+11, out loadpct);
                    profile = raw[10];
                } else {// msp2_inav_status
                    SEDE.deserialise_u32(raw+9, out arm_flags);
                    SEDE.deserialise_u16(raw+6, out loadpct);
                    profile = (raw[8] & 0xf);
                }
                if(arm_flags != xarm_flags) {
                    xarm_flags = arm_flags;
                    string arming_msg = get_arm_fail(xarm_flags);
                    MWPLog.message("Arming flags: %s (%04x), load %d%% %s\n",
                                   arming_msg, xarm_flags, loadpct,
                                   msp_get_status.to_string());
                    if (Mwp.conf.audioarmed == true) {
                        Mwp.window.audio_cb.active = true;
					}
                    if(Mwp.window.audio_cb.active == true) {
                        // navstatus.arm_status(arming_msg); // FIXME
					}
                    if((arm_flags & ~(ARMFLAGS.ARMED|ARMFLAGS.WAS_EVER_ARMED)) != 0) {
						Mwp.window.arm_warn.visible=true;
                    } else {
                        Mwp.window.arm_warn.visible=false;
                    }
                }
            } else {
                profile = raw[10];
			}

            if(have_status == false) {
				have_status = true;
                StringBuilder sb0 = new StringBuilder ();
                foreach (var sn in Msp.Sensors.all()) {
                    if((sensor & sn) == sn) {
                        sb0.append(sn.to_string());
                        sb0.append_c(' ');
                    }
                }
                update_sensor_array();
                MWPLog.message("Sensors: %s (%04x)\n", sb0.str, sensor);

                if(!prlabel) {
                    prlabel = true;
                    var lab = Mwp.window.verlab.get_label();
                    StringBuilder sb = new StringBuilder();
                    sb.append(lab);

                    if(/*naze32 &&*/ vi.fc_api != 0)
                        sb.append_printf(" API %d.%d", vi.fc_api >> 8,vi.fc_api & 0xff);
                    if(navcap != NAVCAPS.NONE)
                        sb.append(" Nav");
                    sb.append_printf(" Pr %d", profile);
                    Mwp.window.verlab.tooltip_text = sb.str;
                }

                want_special = 0;
                MWPLog.message("%s %s\n", Mwp.window.verlab.label, Mwp.window.typlab.label);

                if(replayer == Player.NONE) {
                    MWPLog.message("switch val == %08x (%08x)\n", bxflag, lmask);
                }

                var reqsize = build_pollreqs();
                var nreqs = requests.length;
                    // data we send, response is structs + this
                var qsize = nreqs * ((msp.use_v2) ? 9 : 6);
                reqsize += qsize + 1;

				var sb = new StringBuilder("Poller cycle for ");
				sb.append_printf(" %d items, %lu / %lu bytes (", nreqs,qsize,reqsize);
				foreach(var r in requests) {
					var srq = r.to_string();
					srq = srq[9:srq.length];
					sb.append(srq);
					sb.append(",");
				}
				sb.overwrite(sb.len-1, ")\n");
				MWPLog.message(sb.str);
                if(nopoll == false && nreqs > 0) {
                    if  (replayer == Player.NONE) {
                        MWPLog.message("Start poller\n");
                        tcycle = 0;
                        lastm = nticks;
                        serstate = SERSTATE.POLLER;
                        Audio.start_audio();
                    }
                }
                report_bits(bxflag);
                Craft.RMIcon ri = 0;
                if ((rth_mask != 0) && ((bxflag & rth_mask) == 0))
                    ri |= Craft.RMIcon.RTH;
                if ((ph_mask != 0) && ((bxflag & ph_mask) == 0))
                    ri |= Craft.RMIcon.PH;
                if ((wp_mask != 0) && ((bxflag & wp_mask) == 0))
                    ri |= Craft.RMIcon.WP;
                if(ri != 0 && craft != null)
                    craft.remove_special(ri);
            } else {
                if(requests.length == 0 && ((sensor & Msp.Sensors.GPS) == Msp.Sensors.GPS)) {
                    build_pollreqs();
                }
                if(sensor != xsensor) {
                    update_sensor_array();
                    xsensor = sensor;
                }
            }

                // acro/horizon/angle changed
            uint8 ltmflags = 0;

            if((bxflag & lmask) != (xbits & lmask)) {
                report_bits(bxflag);
            }

            if ((bxflag & horz_mask) != 0)
                ltmflags = Msp.Ltm.HORIZON;
            else if((bxflag & angle_mask) != 0)
                ltmflags = Msp.Ltm.ANGLE;
            else
                ltmflags = Msp.Ltm.ACRO;

            if (armed != 0) {
                if (fs_mask != 0) {
                    bool failsafe = ((bxflag & fs_mask) != 0);
                    if(xfailsafe != failsafe) {
                        if(failsafe) {
                            arm_flags |=  ARMFLAGS.ARMING_DISABLED_FAILSAFE_SYSTEM;
                            MWPLog.message("Failsafe asserted %ds\n", duration);
                            Mwp.add_toast_text("FAILSAFE");
							msp.td.state.state |= 2;
                        } else {
                            MWPLog.message("Failsafe cleared %ds\n", duration);
							msp.td.state.state &= ~2;
                        }
                        xfailsafe = failsafe;
                    }
                }
                if ((rth_mask != 0) &&
                    ((bxflag & rth_mask) != 0) &&
                    ((xbits & rth_mask) == 0)) {
                    MWPLog.message("set RTH on %08x %u %ds\n", bxflag,bxflag,
                                   (int)duration);
                    want_special |= POSMODE.RTH;
                    ltmflags = Msp.Ltm.RTH;
                } else if ((ph_mask != 0) &&
                         ((bxflag & ph_mask) != 0) &&
                         ((xbits & ph_mask) == 0)) {
                    MWPLog.message("set PH on %08x %u %ds\n", bxflag, bxflag,
                                   (int)duration);
                    want_special |= POSMODE.PH;
                    ltmflags = Msp.Ltm.POSHOLD;
                } else if ((wp_mask != 0) &&
                         ((bxflag & wp_mask) != 0) &&
                         ((xbits & wp_mask) == 0)) {
                    MWPLog.message("set WP on %08x %u %ds\n", bxflag, bxflag,
                                   (int)duration);
                    want_special |= POSMODE.WP;
                    ltmflags = Msp.Ltm.WAYPOINTS;
                } else if ((cr_mask != 0)  &&
                           ((bxflag & cr_mask) != 0) &&
                           ((xbits & cr_mask) == 0)) {
                    MWPLog.message("set CRUISE on %08x %u %ds\n", bxflag, bxflag,
                                   (int)duration);
                    want_special |= POSMODE.CRUISE;
                    ltmflags = Msp.Ltm.CRUISE;
                } else if ((xbits != bxflag) && craft != null) {
                    craft.set_normal();
                }

				if(ltmflags != last_ltmf) {
					msp.td.state.ltmstate = ltmflags;
					if (ltmflags !=  Msp.Ltm.POSHOLD &&
						ltmflags !=  Msp.Ltm.WAYPOINTS &&
						ltmflags !=  Msp.Ltm.RTH &&
						ltmflags !=  Msp.Ltm.LAND) { // handled by NAV_STATUS
						TTS.say(TTS.Vox.LTM_MODE);
					}
					Mwp.window.update_state();
					last_ltmf = ltmflags;
				}
				if (want_special != 0) {
                    var lmstr = Msp.ltm_mode(ltmflags);
                    Mwp.window.fmode.set_label(lmstr);
                }
            }
            xbits = bxflag;
            armed_processing(bxflag,"msp");
			MBus.update_state();
        }
    }
	private void queue_gzone(int cnt) {
		uint8 zb=(uint8)cnt;
		queue_cmd(Msp.Cmds.GEOZONE, &zb, 1);
		run_queue();
	}

	private void queue_gzvertex(int8 nz, int8 nv) {
		uint8 zb[2];
		zb[0] = (uint8) nz;
		zb[1] = (uint8) nv;
		queue_cmd(Msp.Cmds.GEOZONE_VERTEX, zb, 2);
		run_queue();
	}

	public void request_fc_safehomes() {
		last_safehome = Safehome.MAXHOMES;
		uint8 shid = 0;
		MWPLog.message("Load FC safehomes\n");
		queue_cmd(Msp.Cmds.SAFEHOME,&shid,1);
	}

	public void save_safehomes_fc() {
		safeindex = 0;
		msp_publish_home(0);
	}

	public void handle_misc_startup() {
		if (SAFEHOMES in starttasks) {
			starttasks -= StartupTasks.SAFEHOMES;
			last_safehome = Safehome.MAXHOMES;
			uint8 shid = 0;
			MWPLog.message("Load FC safehomes\n");
			queue_cmd(Msp.Cmds.SAFEHOME,&shid,1);
			run_queue();
		} else if (GEOZONES in starttasks) {
			starttasks -= StartupTasks.GEOZONES;
			MWPLog.message("Load FC Geozones\n");
			gzr.reset();
			queue_gzone(0);
			gz_from_msp = true;
			run_queue();
		} else if (MISSION in starttasks) {
			starttasks -= StartupTasks.MISSION;
			MWPLog.message("Auto-download FC mission\n");
			download_mission();
		} else if (STATUS in starttasks) {
			starttasks -= StartupTasks.STATUS;
			queue_cmd(msp_get_status,null,0);
			run_queue();
		}
		//		MWPLog.message(":DBG: misc startup %d\n", starttasks);
	}
}
