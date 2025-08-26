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

namespace LogPlay {
	int child_pid;
}

namespace Mwp {
	int playfd[2];
    bool xlog;
    bool xaudio;

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
        if((replayer & Player.RAW) != 0 && LogPlay.child_pid != 0) {
			if(!replay_paused) {
				MWPLog.message("Resuming %d\n", LogPlay.child_pid);
				ProcessLauncher.resume(LogPlay.child_pid);
			} else {
				MWPLog.message("Suspending %d\n", LogPlay.child_pid);
				ProcessLauncher.suspend(LogPlay.child_pid);
			}
        }
    }

	private void stop_replayer() {
        if(replay_paused)
            handle_replay_pause();

		if( LogPlay.child_pid != 0) {
			ProcessLauncher.kill(LogPlay.child_pid);
			LogPlay.child_pid = 0;
		}
		replay_paused = false;
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
			string sargs = string.joinv(" ",args);

			LogPlay.child_pid = 0;
			var subp = new ProcessLauncher();
			var res = subp.run_argv(args, ProcessLaunch.STDOUT|ProcessLaunch.STDERR);
			if (!res) {
				return;
			}
			MwpMisc.start_cpu_stats();
			LogPlay.child_pid = subp.get_pid();

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
	}

	private void run_replay(string fn, bool delay, Player rtype,
                            int idx=0, int btype=0, uint8 force_gps=0, uint duration =0) {
        xlog = conf.logarmed;
        xaudio = conf.audioarmed;
        int sr = 0;
        xnopoll = nopoll;
        nopoll = true;

		RSSI.set_title(RSSI.Title.RSSI);

        if(msp.available) {
			msp.close();
		}

		Mwp.clear_sidebar(Mwp.msp);

		sr = msp.randomUDP(playfd);
		set_pmask_poller(MWSerial.PMask.AUTO);
		msp.set_ro(true);

        if(sr == 0) {
            replay_paused = false;
            MWPLog.message("Replay \"raw\" log %s model %d\n", fn, btype);

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

            set_replay_menus(false);
			Mwp.hard_display_reset();
            MwpMenu.set_menu_state(Mwp.window, "stop-replay", true);
            magcheck = delay; // only check for normal replays (delay == true)
			replayer|= Player.OTX;
			spawn_otx_task(fn, delay, idx, btype, duration);
        } else {
			MWPLog.message("[replayer]: get replay fd failed %d\n", sr);
		}
    }

    private void cleanup_replay() {
        if (replayer != Player.NONE) {
            MWPLog.message("============== Replay complete ====================\n");
    		msp.close();
			msp.set_ro(false);

            set_replay_menus(true);
            MwpMenu.set_menu_state(Mwp.window, "stop-replay", false);

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
