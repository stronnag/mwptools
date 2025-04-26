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
	bool telem;
	bool seenMSP;

    int replayer;
    Msp.Cmds[] requests;
    Msp.Cmds msp_get_status;
    uint32 xarm_flags;
    int tcycle;
    SERSTATE serstate;
    bool rxerr;
	uint64 acycle;
	uint64 anvals;
	double ptdiff;
    uint64 xbits;
    uint8 api_cnt;
    uint8 icount;
    bool usemag;
    int16 mhead;

    bool have_vers;
    bool have_api;
    bool have_status;
    bool have_wp;
    bool have_fcv;
    bool have_fcvv;
	bool have_mavlink;
    bool vinit;
    bool need_preview;
    bool xfailsafe;

    uint8 gpscnt;
    Mwp.POSMODE want_special;
    uint8 last_ltmf;
    uint8 mavc;
    uint16 mavsensors;
    bool force_mav;
    bool have_mspradio;
    uint16 sensor;
    uint16 xsensor;
    uint8 profile;

    /* for jump protection */
    double xlon;
	double xlat;

	bool inav;
	bool sensor_alm;
	uint8 xs_state;

	uint16  rhdop;
	uint8 wp_max;

	uint16 nav_wp_safe_distance;
	uint16 safehome_max_distance;
	uint16 inav_max_eph_epv;
	uint16 nav_rth_home_offset_distance;

	bool need_mission;

	uint8 last_nmode;
	uint8 last_nwp;
	int wpdist;
	uint8 msats;
	string? vname;

	uchar hwstatus[9];

	int magdt;
	int magtime;
	int magdiff;
	bool magcheck;

    Varios varios;
    Timer lastp;
    uint nticks;
    uint lastm;
    uint lastrx;
	uint last_ga;
	uint last_gps;
	uint last_crit;
	uint last_tm;
	uint lastok;
	uint last_an;
	bool replay_paused;
	VersInfo vi;

	uint inhibit_cookie;

	bool have_home;
    Position rth_pos;
    Position ph_pos;

    uint64 ph_mask;
    uint64 arm_mask;
    uint64 rth_mask;
    uint64 angle_mask;
    uint64 horz_mask;
    uint64 wp_mask;
    uint64 cr_mask;
    uint64 fs_mask;
    uint no_ofix;

    TelemStats telstats;

	bool seen_msp;

    uint8 sflags;
    uint8 nsats;
    uint8 _nsats;
    uint8 larmed;
    bool wdw_state;
    time_t armtime;
    time_t duration;
    time_t last_dura;
    time_t pausetm;
    uint32 rtcsecs;
    time_t phtim;

    uint8 armed;
    uint8 dac;
    bool gpsfix;
    bool ltm_force_sats;
    NAVCAPS navcap;

	const int MSP_WAITMS = 5;
#if USE_HID
	const double JSTKINTVL = 0.15;
	const int JSCHANSIZE = 32;
	int16 rcchans[16];
#endif

	void serial_reset() {
		vi = {};
		navcap = 0;
		sflags = 0;
		nsats = 0;
		_nsats = 0;
		larmed = 0;
		wdw_state = false;
		armtime = 0;;
		duration = 0;
		last_dura = 0;
		pausetm = 0;;
		rtcsecs = 0;
		phtim = 0;
		idcount = 0;

		armed = 0;
		dac = 0;
		gpsfix = false;
		ltm_force_sats = false;

		replayer = 0;
		msp_get_status = Msp.Cmds.STATUS;
		requests ={};
		xarm_flags=0xffff;
		tcycle = 0;
		serstate = SERSTATE.NONE;
		rxerr = false;
		ptdiff = 0.0;
		icount = 0;
		usemag = false;
		xbits = 0;
		have_vers = false;
		have_api = false;
		have_status = false;
		have_wp = false;
		have_fcv = false;
		have_fcvv = false;
		have_mavlink = false;
		vinit = false;
		need_preview = false;
		xfailsafe = false;
		gpscnt = 0;
		want_special = 0;
		last_ltmf = 0;
		mavc = 0;
		mavsensors = 0;
		force_mav = false;
		have_mspradio = false;
		xsensor = 0;
		profile = 0;
		xlon = 0;
		xlat = 0;
		inav = false;
		sensor_alm = false;
		xs_state = 0;
		rhdop = 10000;
		gpsintvl = 0;
		wp_max = 0;

		xlon = 0;
		xlat = 0;

		inav = false;
		sensor_alm = false;
		xs_state = 0;

		rhdop = 10000;
		gpsintvl = 0;

		nav_wp_safe_distance = 10000;
		safehome_max_distance = 20000;
		inav_max_eph_epv = 1000;
		nav_rth_home_offset_distance = 0;
		need_mission = false;

		last_nmode = 0;
		last_nwp = 0;
		wpdist = 0;
		vname = null;
		magdt = -1;
		TTS.say_state = 0;

		nticks = 0;
		lastm = 0;
		lastrx = 0;
		last_ga = 0;
		last_gps = 0;
		last_crit = 0;
		last_tm = 0;
		lastok = 0;
		last_an = 0;
		inhibit_cookie = 0;
		HomePoint.try_hide();

		have_home = false;
		rth_pos = {};
		ph_pos = {};

		ph_mask=0;
		arm_mask=0;
		rth_mask=0;
		angle_mask=0;
		horz_mask=0;
		wp_mask=0;
		cr_mask=0;
		fs_mask=0;
		no_ofix = 0;
		telstats = {};
		seen_msp = false;
	}

    private void init_sstats() {
        if(telstats.s.msgs != 0) {
            gen_serial_stats();
		}
		/* FIXME */
		/*
		telemstatus.annul();
        radstatus.annul();
		*/

		anvals = acycle = 0;
        telstats = {};
    }

    private void init_state() {
		serial_reset();
        nsats = 0;
        clear_sensor_array();
        last_ltmf = 0xff;
        Mwp.window.validatelab.set_text("");
        msats = SATS.MINSATS;
		Battery.init();
		Battery.set_bat_stat(0);
        Battery.curr = {false, 0, 0, 0};
        varios.idx = 0;
    }

    public void request_wp(uint8 wp) {
        uint8 buf[2];
        have_wp = false;
        buf[0] = wp;
        queue_cmd(Msp.Cmds.WP,buf,1);
    }

	void msg_poller() {
        if(msp.available && serstate == SERSTATE.POLLER) {
			ptdiff = 0.0;
            send_poll();
        }
    }

	void resend_last() {
        if(msp.available) {
            if(lastmsg.cmd != Msp.Cmds.INVALID) {
                msp.send_command((uint16)lastmsg.cmd, lastmsg.data, lastmsg.len);
            } else
                run_queue();
		}
    }

     void run_queue() {
        if((replayer & (Player.BBOX|Player.OTX|Player.RAW)) != 0) {
            mq.clear();
        } else if(msp.available && !mq.is_empty()) {
			lastmsg = mq.pop_head();
			msp.send_command((uint16)lastmsg.cmd, lastmsg.data, lastmsg.len);
			if(Mwp.DebugFlags.MSP in Mwp.debug_flags) {
				MWPLog.message(":DBG: MSP send: %s\n", lastmsg.cmd.format());
			}
        }
    }

	 void start_poll_timer() {
        var lmin = 0;
		Timeout.add(TIMINTVL, () => {
                nticks++;
                if(msp.available) {
                    if(serstate != SERSTATE.NONE) {
                        var tlimit = conf.polltimeout / TIMINTVL;
						if (lastmsg.cmd == Msp.Cmds.WP_MISSION_SAVE ||
							lastmsg.cmd == Msp.Cmds.EEPROM_WRITE ||
							lastmsg.cmd == Msp.Cmds.ADSB_VEHICLE_LIST) {
							tlimit += MAVINTVL;
						}
						if(msp.is_weak() ) {
							tlimit *= 4;
						}

						if(((serstate == SERSTATE.POLLER || serstate == SERSTATE.TELEM)) &&
                           (nticks - lastrx) > NODATAINTVL) {
                            if(rxerr == false) {
                                Mwp.add_toast_text("No data for 5s");
                                rxerr=true;
                            }
							MWPLog.message("No data for 5s %s\n", rxerr.to_string());
							resend_last();
                        }

                        if(serstate != SERSTATE.TELEM) {
							// Long timeout
                            if(serstate == SERSTATE.POLLER && (nticks - lastrx) > RESTARTINTVL) {
                                serstate = SERSTATE.NONE;
                                MWPLog.message("Restart poll loop\n");
                                init_state();
                                init_sstats();
                                serstate = SERSTATE.NORMAL;
								idcount = 0;
                                queue_cmd(Msp.Cmds.IDENT,null,0);
                                if(inhibit_cookie != 0) {
									MWPLog.message("Not managing screen / power settings\n");
									MwpIdle.uninhibit(inhibit_cookie);
                                    inhibit_cookie = 0;
                                }
                                run_queue();
                            } else if ((nticks - lastok) > tlimit ) {
								if (lastmsg.cmd != Msp.Cmds.INVALID) {
									telstats.toc++;
									string res;
                                    res = lastmsg.cmd.format();
									if(nopoll == false)
										MWPLog.message("MSP Timeout %u %u %u (%s %s)\n",
													   nticks, lastok, lastrx, res, serstate.to_string());
									if (lastmsg.cmd == Msp.Cmds.ADSB_VEHICLE_LIST) {
										clear_poller_item(Msp.Cmds.ADSB_VEHICLE_LIST);
									}
									if (lastmsg.cmd == Msp.Cmds.IDENT) {
										idcount++;
										if(idcount == Mwp.conf.ident_limit) {
											Msp.close_serial();
											var wb5 = new Utils.Warning_box("No response received from the FC\nPlesae check connection and protocol\nConsider <tt>--no-poll</tt> if this is intentional\nSee also the <tt>ident-limit</tt> setting");
											wb5.present();
											idcount = 0;
										}
									}
									lastok = nticks;
									tcycle = 0;
									resend_last();
								}
                            }
                        } else {
                            if(armed != 0 && msp.available && gpsintvl != 0 && last_gps != 0) {
                                if (nticks - last_gps > gpsintvl) {
                                    if(replayer == Player.NONE)
                                        Audio.play_alarm_sound(MWPAlert.SAT);
                                    if(replay_paused == false)
                                        MWPLog.message("GPS stalled\n");
                                    Mwp.window.gpslab.label = "!";
                                    last_gps = nticks;
                                }
                            }

                            if(serstate == SERSTATE.TELEM && nopoll == false &&
                               last_tm > 0 &&
                               ((nticks - last_tm) > MAVINTVL)
                               && msp.available && replayer == Player.NONE) {
                                MWPLog.message("Restart poller on telemetry timeout\n");
                                have_status = false;
                                xbits = icount = api_cnt = 0;
                                init_sstats();
                                last_tm = 0;
                                serstate = SERSTATE.NORMAL;
                                queue_cmd(msp_get_status,null,0);
                                run_queue();
                            }
                        }
                    } else {
                        lastok = lastrx = nticks;
					}

                    if((nticks % STATINTVL) == 0) {
                        //gen_serial_stats(); // FIXME
                        //telemstatus.update(telstats, item_visible(DOCKLETS.TELEMETRY)); FIXME
                    }
                }

                if(duration != 0 && duration != last_dura) {
                    int mins;
                    int secs;
                    if(duration < 0) {
                        mins = secs = 0;
                        duration = 0;
                    } else {
                        mins = (int)duration / 60;
                        secs = (int)duration % 60;
                        if(mins != lmin) {
							//navstatus.update_duration(mins); // FIXME
							lmin = mins;
                        }
                    }
                    Mwp.window.elapsedlab.set_text("%02d:%02d".printf(mins,secs));
                    last_dura = duration;
                }
                return Source.CONTINUE;
            });
    }

    public void queue_cmd(Msp.Cmds cmd, void* buf, size_t len) {
        if(((debug_flags & DebugFlags.INIT) != DebugFlags.NONE)
           && (serstate == SERSTATE.NORMAL))
            MWPLog.message("Init MSP %s (%u)\n", cmd.to_string(), cmd);

        if(replayer == Player.NONE) {
            uint8 *dt = (buf == null) ? null : Memory.dup2(buf, (size_t)len);
            if(msp.available == true) {
                var mi = MQI() {cmd = cmd, len = len, data = dt};
                mq.push_tail(mi);
            }
        }
    }

	void send_poll() {
        if(serstate == SERSTATE.POLLER && requests.length > tcycle) {
			Msp.Cmds req = Msp.Cmds.NOOP;
			bool skip = false;
			do {
				skip = false;
				req=requests[tcycle];
				lastm = nticks;
				if (req == Msp.Cmds.ANALOG || req == Msp.Cmds.ANALOG2) {
					if (lastm - last_an > MAVINTVL) {
						last_an = lastm;
						mavc = 0;
					} else {
						skip = true;
					}
				}
				// only is not armed
				if (req == Msp.Cmds.GPSSTATISTICS && armed == 1) {
					skip = true;
				}

				if(req == Msp.Cmds.ADSB_VEHICLE_LIST) {
					if(lastm - last_ga < MAVINTVL*5) {
						skip = true;
					} else {
						last_ga = lastm;
					}
				}

				if(skip){
					tcycle = (tcycle + 1) % requests.length;
				}
			} while (skip);

			if(req == Msp.Cmds.WP) {
				uint8 buf[1] = {0};
				queue_cmd(req, buf, 1);
			} else if (req != Msp.Cmds.NOOP) {
				queue_cmd(req, null, 0);
			}
        }
    }

    private void reset_poller() {
		mleave = 0;
		if(msp.available) {
			if(Mwp.conf.no_poller_pause) {
				MWPLog.message(":DBG: Clear poller state %s\n", serstate.to_string());
			} else {
				MWPLog.message(":DBG: Reset Poller %s\n", serstate.to_string());
				if(starttasks == 0) {
					if(serstate != SERSTATE.NONE && serstate != SERSTATE.TELEM) {
						if(nopoll == false) { // FIXNOPOLL
							lastok = lastrx = last_gps = nticks;
							tcycle = 0;
							serstate = SERSTATE.POLLER;
							msg_poller();
						}
					}
				}
			}
		}
	}

	public void telem_init(Msp.Cmds cmd) {
		if ((Mwp.replayer & Mwp.Player.MWP) == 0) {
			var mtype= (cmd >= Msp.MAV_BASE) ? "MAVLink" : "LTM";
			var mstr = "%s telemetry".printf(mtype);
			MWPLog.message("Init %s\n", mstr);
			if (conf.manage_power && inhibit_cookie == 0) {
				inhibit_cookie = MwpIdle.inhibit();
				MWPLog.message("Managing screen idle and suspend (%x)\n", inhibit_cookie);
			}
			Mwp.window.mmode.label = mtype;
			serstate = SERSTATE.TELEM;
			init_sstats();
			last_tm = nticks;
			last_gps = nticks;
			if(last_tm == 0) {
				last_tm = 1;
			}
		}
	}

	public void reset_msgs() {
		last_tm = 0;
		last_gps = 0;
		nticks = 0;
		telem = false;
		seen_msp =  false;
	}

	public void show_unhandled(Msp.Cmds cmd, uint8[] raw, uint len) {
		uint mcmd;
		string mtxt;
		if (cmd < Msp.LTM_BASE) {
			mcmd = cmd;
			mtxt = "MSP";
		}
		else if (cmd >= Msp.LTM_BASE && cmd < Msp.MAV_BASE) {
			mcmd = cmd - Msp.LTM_BASE;
			mtxt = "LTM";
		} else {
			mcmd = cmd - Msp.MAV_BASE;
			mtxt = "MAVLink";
		}
		StringBuilder sb = new StringBuilder("** Unknown ");
		sb.printf("%s : %u / 0x%x (%ubytes)", mtxt, mcmd, mcmd, len);
		if(len > 0 && conf.dump_unknown) {
			sb.append(" [");
			foreach(var r in raw[0:len])
				sb.append_printf(" %02x", r);
			sb.append(" ]");
		}
		sb.append_c('\n');
		MWPLog.message (sb.str);
	}

	public void handle_serial(MWSerial ser, Msp.Cmds cmd, uint8[] raw, uint len, uint8 xflags, bool errs) {
		bool handled = false;
        if(cmd >= Msp.LTM_BASE && cmd < Msp.MAV_BASE) {
            telem = true;
            if (seenMSP == false) {
                Mwp.nopoll = true;
			}
			handled = Mwp.handle_ltm(ser, cmd, raw, len);
		} else if (cmd >= Msp.MAV_BASE && cmd < Msp.MAV_BASE+65535) {
			telem  = true;
            if(mavc == 0 &&  ser.available) {
                Mav.send_mav_beacon(ser);
            }
            mavc = (mavc+1) & MAV_BEAT_MASK;
			handled = Mwp.handle_mavlink(ser, cmd, raw, len);
        } else {
			seenMSP = true;
			telem = false;
			last_tm = 0;
			handled = Mwp.handle_msp(ser, cmd, raw, len, xflags, errs);
		}
		if(telem) {
			if(last_tm == 0) {
				telem_init(cmd);
				last_tm = 2;
			} else {
				if (nticks > 0)
					last_tm = nticks;
			}
		}
		if(!handled) {
			show_unhandled(cmd, raw, len);
        }
		lastrx = nticks;

        if(fwddev.available() && conf.forward  != FWDS.NONE) {
            if(conf.forward == FWDS.ALL) {
				if (cmd < Msp.LTM_BASE) {
					fwddev.forward_command(cmd, raw, len);
				} else if( cmd >= Msp.LTM_BASE && cmd < Msp.MAV_BASE) {
					fwddev.forward_ltm((uint16)(cmd - Msp.LTM_BASE), raw, len);
				} else if (cmd >= Msp.MAV_BASE) {
					fwddev.forward_mav((uint16)(cmd - Msp.MAV_BASE), raw, len, 0);
				}
			} else if ( conf.forward == FWDS.minLTM) {
				if(cmd == Msp.Cmds.TG_FRAME || cmd == Msp.Cmds.TA_FRAME || cmd == Msp.Cmds.TS_FRAME ) {
					fwddev.forward_ltm((uint16)(cmd - Msp.LTM_BASE), raw, len);
				}
            } else if(conf.forward == FWDS.minMAV) {
				if (cmd == Msp.Cmds.MAVLINK_MSG_ID_HEARTBEAT || cmd == Msp.Cmds.MAVLINK_MSG_ID_SYS_STATUS || cmd == Msp.Cmds.MAVLINK_MSG_GPS_RAW_INT || cmd == Msp.Cmds.MAVLINK_MSG_VFR_HUD || cmd == Msp.Cmds.MAVLINK_MSG_ATTITUDE || cmd == Msp.Cmds.MAVLINK_MSG_RC_CHANNELS_RAW) {
					fwddev.forward_mav((uint16)(cmd - Msp.MAV_BASE), raw, len, 0);
				}
			} else {
				if(cmd ==  Msp.Cmds.TG_FRAME ||
				   cmd ==  Msp.Cmds.MAVLINK_MSG_GPS_RAW_INT  ||
				   cmd == Msp.Cmds.RAW_GPS) {
					MessageForward.position();
				} else if (cmd == Msp.Cmds.TA_FRAME ||
						   cmd ==  Msp.Cmds.MAVLINK_MSG_ATTITUDE ||
						   cmd == Msp.Cmds.ATTITUDE) {
					MessageForward.attitude();
				} else if (cmd == Msp.Cmds.TS_FRAME ||
						   cmd == Msp.Cmds.MAVLINK_MSG_ID_SYS_STATUS ||
						   cmd == Msp.Cmds.STATUS ||
						   cmd == Msp.Cmds.STATUS_EX ||
						   cmd == Msp.Cmds.INAV_STATUS) {
					MessageForward.status();
				} else if (cmd == Msp.Cmds.TO_FRAME ||
						   cmd == Msp.Cmds.WP && raw[0] == 0 ||
						   cmd == Msp.Cmds.MAVLINK_MSG_GPS_GLOBAL_ORIGIN) {
					MessageForward.origin();
				}
			}
        }

		if(serstate == SERSTATE.POLLER) {
#if USE_HID
			if(!send_msp_rc())
#endif
			{
				if(mleave == 1 && !mq.is_empty()) {
					mleave = 2;
					// MWPLog.message(":DBG: 1 Interleaved %s %u => QUE\n", cmd.format(), raw[0]);
					run_queue();
				} else if (mleave == 2) {
					// MWPLog.message(":DBG: 2 Interleaved %s %u => POLL\n", cmd.format(), raw[0]);
					timed_poll();
					mleave = 1;
				} else if(!mq.is_empty()) {
					run_queue();
				} else {
					timed_poll();
				}
			}
		} else {
#if USE_HID
			if(!send_msp_rc())
#endif
			{
				if(!mq.is_empty()) {
					run_queue();
				}
			}
		}
    }

#if USE_HID
	private bool send_msp_rc() {
		if(Mwp.use_msp_rc && rctimer.is_active() && rctimer.elapsed() > Mwp.JSTKINTVL) {
			JSMisc.read_hid_async.begin((uint8[])rcchans, "raw",  (o, r) => {
					var sz = JSMisc.read_hid_async.end(r);
					if(sz  == JSCHANSIZE && rcchans[0] > 0) {
						msp.send_command(Msp.Cmds.SET_RAW_RC, (uint8[])rcchans, JSCHANSIZE);
						rctimer.start();
						Sticks.update(rcchans[0], rcchans[1], rcchans[3], rcchans[2]);
					} else {
						rctimer.stop();
					}
				});
			return true;
		}
		return false;
	}
#endif

	private void timed_poll() {
		if (requests.length > 0) {
			var et = lastp.elapsed();
			var twait = (uint)(1000*(et-ptdiff));
			if (twait < Mwp.MSP_WAITMS) {
				twait = Mwp.MSP_WAITMS - twait;
				Timeout.add(twait, () => { next_poll();return false;});
			} else {
				next_poll();
			}
			acycle += twait;
			anvals++;
		}
	}

	private void next_poll() {
		ptdiff = lastp.elapsed();
		tcycle = (tcycle + 1) % requests.length;
		send_poll();
		run_queue();
	}

    ulong build_pollreqs() {
        ulong reqsize = 0;
        requests.resize(0);
        sensor_alm = false;
        requests += msp_get_status;
        reqsize += (msp_get_status ==  Msp.Cmds.STATUS_EX) ? MSize.MSP_STATUS_EX :
            (msp_get_status ==  Msp.Cmds.INAV_STATUS) ? MSize.MSP2_INAV_STATUS :
            MSize.MSP_STATUS;

        if (msp_get_status ==  Msp.Cmds.INAV_STATUS) {
            requests += Msp.Cmds.ANALOG2;
            reqsize += MSize.MSP_ANALOG2;
        } else {
            requests += Msp.Cmds.ANALOG;
            reqsize += MSize.MSP_ANALOG;
        }
        sflags = SPK.Volts;
        var missing = 0;

        if(force_mag) {
            usemag = true;
		} else {
            usemag = ((sensor & Msp.Sensors.MAG) == Msp.Sensors.MAG);
        }

        if((sensor & Msp.Sensors.GPS) == Msp.Sensors.GPS) {
            sflags |= SPK.GPS;
            if((navcap & NAVCAPS.NAVSTATUS) == NAVCAPS.NAVSTATUS) {
                requests += Msp.Cmds.NAV_STATUS;
                reqsize += MSize.MSP_NAV_STATUS;
            }
            requests += Msp.Cmds.RAW_GPS;
            requests += Msp.Cmds.COMP_GPS;

            if((navcap & NAVCAPS.NAVCONFIG) == 0) {
                requests += Msp.Cmds.GPSSTATISTICS;
                reqsize += MSize.MSP_GPSSTATISTICS;
            }
            requests += Msp.Cmds.WP;
            reqsize += (MSize.MSP_RAW_GPS + MSize.MSP_COMP_GPS+MSize.MSP_WP);
        } else
            missing |= Msp.Sensors.GPS;

        if((sensor & Msp.Sensors.ACC) == Msp.Sensors.ACC) {
            requests += Msp.Cmds.ATTITUDE;
            reqsize += MSize.MSP_ATTITUDE;
        }

        if(((sensor & Msp.Sensors.BARO) == Msp.Sensors.BARO) ) {
            sflags |= SPK.BARO;
            requests += Msp.Cmds.ALTITUDE;
            reqsize += MSize.MSP_ALTITUDE;
        } else
            missing |= Msp.Sensors.BARO;

		if((vi.fc_vers >= FCVERS.hasAdsbList) && conf.msp2_adsb != 0) {
			if((conf.msp2_adsb == 1) || // "on"
			   (conf.msp2_adsb == 2 && have_mavlink && !msp.is_weak())) {
				requests +=  Msp.Cmds.ADSB_VEHICLE_LIST;
				reqsize += 160; // or more ...
			}
		}

        if(missing != 0) {
			string []nsensor={};
			if((missing & Msp.Sensors.GPS) != 0)
				nsensor += "GPS";
			if((missing & Msp.Sensors.BARO) != 0)
				nsensor += "BARO";
			if((missing & Msp.Sensors.MAG) != 0)
				nsensor += "MAG";
			var nss = string.joinv("/",nsensor);
			var msg = "No %s detected".printf(nss);
			Mwp.add_toast_text(msg);
			MWPLog.message("no %s, sensor = 0x%x\n", nss, sensor);
			if(gpscnt < 5) {
				gpscnt++;
			}
        } else {
            gpscnt = 0;
			Mwp.window.statusbar1.label = "";
        }
        return reqsize;
    }

	void clear_poller_item(Msp.Cmds cmd) {
		for (var ll = 0; ll < requests.length; ll++) {
			if (requests[ll] ==  cmd) {
				requests[ll] = Msp.Cmds.NOOP;
			}
		}
	}

    void  gen_serial_stats() {
        if(msp.available)
            telstats.s = msp.dump_stats();
        telstats.avg = (anvals > 0) ? (ulong)(acycle/anvals) : 0;
    }

    public void show_serial_stats() {
        gen_serial_stats();
		double mrate = (telstats.s.elapsed > 0) ? telstats.s.msgs / telstats.s.elapsed : 0.0;
        MWPLog.message("%.3fs, rx %lub, tx %lub, (%.0fb/s, %0.fb/s) to %d wait %d, avg poll loop %lu ms messages %d msg/s %.1f\n",
                       telstats.s.elapsed, telstats.s.rxbytes, telstats.s.txbytes,
                       telstats.s.rxrate, telstats.s.txrate,
                       telstats.toc, telstats.tot, telstats.avg ,
                       telstats.s.msgs, mrate);
    }
}
