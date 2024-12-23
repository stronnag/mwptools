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

namespace BBLV {
	VideoPlayer vp = null;
}

namespace LogPlay {
	int child_pid;
	int speed = 0;
}

namespace Mwp {
	int playfd[2];
    Thread<int> thr;
    bool xlog;
    bool xaudio;
	ReplayThread robj;

    private void handle_replay_pause(bool from_vid=false) {
        magcheck = false;
        replay_paused = !replay_paused;

        if(!replay_paused) { // ProcessSignal.CONT;
            time_t now;
            time_t (out now);
            armtime += (now - pausetm);
        } else { //ProcessSignal.STOP;
            time_t (out pausetm);
        }
		if(!from_vid) {
			if(BBLV.vp != null) {
				BBLV.vp.set_playing(!replay_paused);
			}
		}
        if((replayer & (Player.BBOX|Player.OTX|Player.RAW)) != 0 && LogPlay.child_pid != 0) {
			if(!replay_paused) {
				MWPLog.message("Resuming %d\n", LogPlay.child_pid);
				ProcessLauncher.resume(LogPlay.child_pid);
			} else {
				MWPLog.message("Suspending %d\n", LogPlay.child_pid);
				ProcessLauncher.suspend(LogPlay.child_pid);
			}
        } else if(thr != null) {
			robj.pause(replay_paused);
        }
    }

	private void stop_replayer() {
        if(replay_paused)
            handle_replay_pause();

		if((replayer & (Player.BBOX|Player.OTX)) != 0 && LogPlay.child_pid != 0) {
			ProcessLauncher.kill(LogPlay.child_pid);
			LogPlay.child_pid = 0;
		}
		if((Mwp.replayer & Mwp.Player.MWP) == Mwp.Player.MWP && thr != null) {
			robj.stop();
		}
		replay_paused = false;
		if(BBLV.vp != null) {
			BBLV.vp.close();
			BBLV.vp = null;
		}
	}

	private string? check_mission_format(string lfn) {
		var tfile = lfn;
		string _fu;
		var res = MWPFileType.guess_content_type(lfn, out _fu);
		if (res != FType.MISSION) {
			var m = MissionManager.current();
            if(m != null && m.npoints > 0) {
				tfile=Utils.mstempname(false);
				XmlIO.to_xml_file(tfile, {m});
			} else {
				tfile = null;
			}
		}
		return tfile;
	}

	private void spawn_otx_task(string fn, bool delay, int idx, int typ=0, uint dura=0) {
        var dstr = "udp://localhost:%d".printf(playfd[1]);
		string tfile=null;
        string [] args={};
        if ((replayer & Player.RAW) == Player.RAW) {
            args += "mwp-log-replay";
            args += "-d";
            args += dstr;
            if (idx > 10) {
                double dly = (double)idx/1000.0;
                args += "-delay";
                args += "%.3f".printf(dly);
            }
        } else {
            if (x_fl2ltm) {
                args += "fl2ltm";
                if (MissionManager.last_file != null) {
					tfile = check_mission_format(MissionManager.last_file);
					if (tfile != null) {
						args += "-mission";
						args += tfile;
					}
                }
                args += "-device";
            }
            args += dstr;
            args += "--index";
            args += idx.to_string();
            if(delay == false)
                args += "--fast";

			if (LogPlay.speed > 1) {
				args += "-speed";
				args += LogPlay.speed.to_string();
			}

			if(BBL.skiptime > 0) {
				args += "-skiptime";
				args += BBL.skiptime.to_string();
			}

            args += "--type";
            args += typ.to_string();
            if (dura > 600) {
                uint intvl  =  100 * dura / 600;
                args += "-interval";
                args += intvl.to_string();
            } else if (x_fl2ltm) {
                args += "-interval";
                args += "100";
            }
        }
        args += fn;

		string sargs = string.joinv(" ",args);

		if((replayer & Player.BBOX) != 0  && BBL.videofile != null && BBLV.vp == null) {
			BBLV.vp = new VideoPlayer(BBL.videofile);
			BBLV.vp.play_state.connect((ps) => {
					if (ps != VideoMan.State.ENDED) {
						bool vps = (ps == VideoMan.State.PLAYING);
						if(vps == replay_paused) {
							handle_replay_pause(true);
						}
					}
				});
			BBLV.vp.present();
		}

		LogPlay.child_pid = 0;
		var subp = new ProcessLauncher();
		var res = subp.run_argv(args, ProcessLaunch.STDOUT|ProcessLaunch.STDERR);
		if (!res) {
			return;
		}
		MwpMisc.start_cpu_stats();
		LogPlay.child_pid = subp.get_pid();

		if((replayer & (Player.RAW|Player.MWP)) == 0) {
			if(conf.show_sticks != 1) {
				Sticks.create_sticks();
			}
		}

		string line = null;
		string csline = null;
		size_t len = 0;
		size_t cslen = 0;

		IOChannel error = subp.get_stderr_iochan();
		IOChannel cstdout = subp.get_stdout_iochan();
		cstdout.add_watch (IOCondition.IN|IOCondition.HUP, (src, cond) => {
				try {
					if (cond == IOCondition.HUP)
						return false;
					IOStatus eos = src.read_line (out csline, out cslen, null);
					if(eos == IOStatus.EOF)
                            return false;
					if(csline == null || cslen == 0)
						return true;
					MWPLog.message("<%s> %s", args[0], csline);
				} catch {}
				return true;
			});

		error.add_watch (IOCondition.IN|IOCondition.HUP, (src, cond) => {
				try {
					if (cond == IOCondition.HUP)
						return false;
					IOStatus eos = src.read_line (out line, out len, null);
					if(eos == IOStatus.EOF)
                            return false;
					if(line == null || len == 0)
						return true;
					MWPLog.message("<%s> %s", args[0], line);
				} catch {}
				return true;
			});
		MWPLog.message("%s # pid=%u\n", sargs, LogPlay.child_pid);

		subp.complete.connect(() => {
				double cpu0=0, cpu1=0;
				if (MwpMisc.end_cpu_stats(&cpu0, &cpu1) == 0) {
					MWPLog.message("FYI: CPU: on core: %.2f%%, system: %.2f%%\n", cpu0, cpu1);
				}
				try {
					cstdout.shutdown(false);
					error.shutdown(false);
				} catch {}

				LogPlay.child_pid = 0;
				if(tfile != null && tfile != MissionManager.last_file) {
                    FileUtils.unlink(tfile);
				}
				Sticks.done();
				cleanup_replay();
				replayer = 0;
			});
	}

    private void spawn_bbox_task(string fn, int index, int btype,
                                 bool delay, uint8 force_gps, uint duration) {
        if(x_fl2ltm) {
            replayer |= Player.OTX;
            spawn_otx_task(fn, delay, index, btype, duration);
		}
    }

	private void run_replay(string fn, bool delay, Player rtype,
                            int idx=0, int btype=0, uint8 force_gps=0, uint duration =0) {
        xlog = conf.logarmed;
        xaudio = conf.audioarmed;
        int sr = 0;
        bool rawfd = false;
        xnopoll = nopoll;
        nopoll = true;

        if ((rtype & Player.MWP) != 0 || (rtype & Player.BBOX) != 0 && x_fl2ltm == false) {
            rawfd = true;
        }

        if(msp.available) {
			Msp.close_serial();
		}

        if (rawfd) {
            sr = MwpPipe.pipe(playfd);
        } else {
            sr = msp.randomUDP(playfd);
			set_pmask_poller(MWSerial.PMask.AUTO);
        }

        if(sr == 0) {
            replay_paused = false;
            MWPLog.message("Replay \"%s\" log %s model %d\n",
                           (rtype == Player.OTX) ? "otx" :
                           (rtype == Player.BBOX) ? "bbox" :
                           (rtype == Player.RAW) ? "raw" : "mwp",
                           fn, btype);

            init_have_home();
            conf.logarmed = false;
            if(delay == false)
                conf.audioarmed = false;

            init_state();
            serstate = SERSTATE.NONE;
            Mwp.window.conbutton.sensitive = false;
            update_title_from_file(fn);
            replayer = rtype;
            if(delay == false)
                replayer |= Player.FAST_MASK;

            if(rawfd) {
                msp.open_fd(playfd[0],-1, true);
				set_pmask_poller(MWSerial.PMask.INAV);
			}
            set_replay_menus(false);
			Mwp.hard_display_reset();
            MwpMenu.set_menu_state(Mwp.window, "stop-replay", true);
            magcheck = delay; // only check for normal replays (delay == true)
            switch(replayer) {
            case Player.MWP:
            case Player.MWP_FAST:
                Mwpjs.check_mission(fn);
                robj = new ReplayThread();
                thr = robj.run(playfd[1], fn, delay);
                break;
            case Player.BBOX:
            case Player.BBOX_FAST:
                spawn_bbox_task(fn, idx, btype, delay, force_gps, duration);
                break;
            case Player.RAW:
            case Player.RAW_FAST:
                replayer|= Player.OTX;
                spawn_otx_task(fn, delay, idx, btype, duration);
                break;
            case Player.OTX:
            case Player.OTX_FAST:
                spawn_otx_task(fn, delay, idx, btype, duration);
                break;
            }
        } else {
			MWPLog.message("[replayer]: get replay fd failed %d (raw %s)\n", sr, rawfd.to_string());
		}
    }

    private void cleanup_replay() {
        if (replayer != Player.NONE) {
            MWPLog.message("============== Replay complete ====================\n");
            if ((replayer & Player.MWP) == Player.MWP) {
                if(thr != null) {
                    thr.join();
                    thr = null;
                }
            }
			//            if (is_shutdown) FIXME
            //    return;
			Msp.close_serial();

            set_replay_menus(true);
            MwpMenu.set_menu_state(Mwp.window, "stop-replay", false);
            if (replayer != Player.OTX && replayer != Player.RAW)
                Posix.close(playfd[1]);

            if (conf.audioarmed == true) {
                Mwp.window.audio_cb.active = false;
			}
            conf.logarmed = xlog;
            conf.audioarmed = xaudio;
            duration = -1;
            armtime = 0;
            Mwp.window.armed_spinner.visible=false;
            Mwp.window.conbutton.sensitive = true;
            armed = larmed = 0;
            replay_paused = false;
            window.title = "mwp";
			if(!zznopoll) {
				nopoll = xnopoll;
			}
        }
    }
}