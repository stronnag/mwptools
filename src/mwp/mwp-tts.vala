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

/*
*/
namespace TTS {
    public enum Vox {
        DONE=1,
        NAV_ERR,
        NAV_STATUS,
        DURATION,
        FMODE,
        RANGE_BRG,
        ELEVATION,
        BARO,
        HEADING,
        VOLTAGE,
        MODSAT,
        LTM_MODE,
        GPS_CRIT,
        FAILSAFE,
        HW_OK,
        HW_BAD,
        HOME_CHANGED,
        HOME_OFFSET,
        AUDIO_TEST,
        SPORT_MODE,
        ARM_STATUS,
        HOST_POWER,
        MAH
    }

	public uint8 say_state = 0;
	internal AudioThread mt;
	uint spktid = 0;
    private int si = 0;
    private bool mt_voice = false;
	private int efdin= -1;
	private int epid = -1;
	private uint8 spkamp = 0;
	private string arm_msg = null;
	private int lsat_t = 0;

	public void start_audio(bool live = true) {
		string voice = null;
		switch(Mwp.spapi) {
		case 1:
			voice = Mwp.conf.evoice;
			if (voice == "default") {
				voice = "en"; // thanks, espeak-ng
			}
			break;
		case 2:
			voice = Mwp.conf.svoice;
			break;
		case 3:
			voice = Mwp.conf.fvoice;
			break;
		default:
			voice = null;
			break;
		}
		audio_init(voice, (Mwp.conf.uilang == "ev"), Mwp.exvox);
		say_state=Mwp.SAY_WHAT.Arm;

		if(live) {
			announce(Mwp.sflags);
		}
		Mwp.window.audio_cb.toggled.connect(() => {
				lsat_t = 0;
				spkamp = 0;
			});
		start_timer();
	}

	public void start_timer() {
		spktid = Timeout.add_seconds(Mwp.conf.speakint, () => {
				if(Mwp.replay_paused == false) {
					TTS.announce(Mwp.sflags);
				}
				return Source.CONTINUE;
			});
	}

    public void stop_timer() {
        if(spktid > 0) {
            Mwp.remove_tid(ref spktid);
        }
	}

    public void stop_audio() {
		stop_timer();
		audio_close();
	}

	private void audio_init (string? voice, bool use_en = false, string? espawn=null) {
        if(Mwp.vinit == false) {
            efdin=-1;
            Mwp.vinit = true;
            if(voice == null)
                voice = "default";

            if(espawn != null) {
				var subp = new ProcessLauncher();
				if(subp.run_command(espawn, ProcessLaunch.STDIN)) {
					efdin = subp.get_stdin_pipe();
					epid = subp.get_pid();
					MWPLog.message("Spawned voice helper \"%s\", %d\n", espawn, epid);
				} else {
                    MWPLog.message("Spawn failed for \"%s\"\n", espawn);
                }
            } else {
                si = MwpSpeech.init(voice);
                MWPLog.message("Initialised \"%s\" for speech%s\n",
                               Mwp.SPEAKERS[si],
                               (si == Mwp.SPEAKER_API.FLITE) ? ", nicely":"");
            }
        }
        if (mt != null) {
            audio_close();
        }
        mt = new AudioThread((si == Mwp.SPEAKER_API.FLITE));
        mt.start(use_en);
        mt_voice=true;
    }

    private void audio_close() {
		if(mt != null) {
			mt_voice=false;
			mt.clear();
			mt.message(TTS.Vox.DONE);
			mt.thread.join ();
			mt = null;
		}
		if(epid > 0) {
			ProcessLauncher.kill(epid);
			epid = -1;
		}
    }

	public void say(Vox c, bool urgent=false) {
		if(Mwp.window.audio_cb.active || c == Vox.AUDIO_TEST) {
			if(mt != null) {
				mt.message(c, urgent);
			} else {
				MWPLog.message(":BUG: audio say %s on null thread\n", c.to_string());
			}
		}
	}

    public void announce(uint8 mask) {
		if(Mwp.window.audio_cb.active) {
			if((say_state & Mwp.SAY_WHAT.Nav) == Mwp.SAY_WHAT.Nav) {
				if(((mask & Mwp.SPK.GPS) == Mwp.SPK.GPS)) {
					mt.message(TTS.Vox.HEADING);
					mt.message(TTS.Vox.RANGE_BRG);
				}
				if((mask & Mwp.SPK.ELEV) == Mwp.SPK.ELEV) {
					mt.message(TTS.Vox.ELEVATION);
				}
				else if((mask & Mwp.SPK.BARO) == Mwp.SPK.BARO) {
					mt.message(TTS.Vox.BARO);
				}
			}
			if((mask & Mwp.SPK.Volts) == Mwp.SPK.Volts && Mwp.msp.td.power.volts > 0.0) {
				mt.message(TTS.Vox.VOLTAGE);
				if(Mwp.conf.speak_amps > 0 && Battery.curr.mah > 0) {
					if((Mwp.conf.speak_amps & 0x10) == 0x10 || Mwp.replayer == 0) {
						int rpi = (Mwp.conf.speak_amps & 0xf);
						if (rpi == 1 ||
							(rpi == 2 && (spkamp & 1) != 0) ||
							(rpi == 4 && spkamp == 3)) {
							mt.message(TTS.Vox.MAH);
						}
					}
					spkamp = (spkamp + 1) % 4;
				}
			}
		}
    }

    public void arm_status(string s) {
		if(Mwp.window.audio_cb.active) {
			if((say_state & Mwp.SAY_WHAT.Arm) == Mwp.SAY_WHAT.Arm) {
				arm_msg = s;
				mt.message(TTS.Vox.ARM_STATUS);
			}
		}
    }

	/*
    public void alert_home_moved() {
        if((say_state & Mwp.SAY_WHAT.Nav) == Mwp.SAY_WHAT.Nav)
            mt.message(TTS.Vox.HOME_CHANGED, true);
    }

    public void alert_home_offset() {
        if((say_state & Mwp.SAY_WHAT.Nav) == Mwp.SAY_WHAT.Nav)
            mt.message(TTS.Vox.HOME_OFFSET, true);
    }
	*/
    public void gps_crit() {
		if(Mwp.window.audio_cb.active) {
			if((say_state & Mwp.SAY_WHAT.Nav) == Mwp.SAY_WHAT.Nav)
				mt.message(TTS.Vox.GPS_CRIT, true);
		}
	}
}

public class AudioThread : Object {
    private Timer timer;
    private double lsat_t;
    private uint lsats;
    private bool use_en = false;
    private bool nicely = false;

    private AsyncQueue<TTS.Vox?> msgs;
    public Thread<int> thread {private set; get;}

    public AudioThread (bool _n) {
        nicely = _n;
        msgs = new AsyncQueue<TTS.Vox?> ();
    }

    public void message(TTS.Vox c, bool urgent=false) {
        if (msgs.length() > 10) {
            clear();
            MWPLog.message("cleared voice queue\n");
        }
        if(!urgent)
            msgs.push(c);
        else {
            msgs.push_front(c);
        }
    }

    public void clear() {
        while (msgs.try_pop() != null)
            ;
    }

    string say_nicely(int v) {
        StringBuilder sb = new StringBuilder();
        if(nicely) {
            bool hasn = false;
            if(v < 0) {
                sb.append_c('-');
                v = -v;
            }

            if(v > 1000) {
                int x = (v/1000)*1000;
                sb.append_printf("%d ",x);
                v = v % 1000;
                hasn = true;
            }
            if(v > 100) {
                int x = (v/100)*100;
                sb.append_printf("%d",x);
                v = v % 100;
                hasn = true;
            }
            if(hasn && v != 0)
                sb.append_printf(" and %d", v);
            else if (!hasn)
                sb.append_printf("%d",v);
        } else
            sb.append_printf("%d", v);
        return sb.str;
    }

    public void start(bool _use_en = false) {
        use_en = _use_en;
        lsats = 255;
        timer = new Timer();
        timer.start();
        lsat_t = timer.elapsed();

        thread = new Thread<int> ("mwp audio", () => {
                TTS.Vox c;
                while((c = msgs.pop()) != TTS.Vox.DONE) {
                    string s=null;
                    switch(c) {
					case TTS.Vox.AUDIO_TEST:
						s = "MWP audio test, version %s".printf(MwpVers.get_id());
						break;
					case TTS.Vox.HW_OK:
						s = "Sensors OK";
						break;
					case TTS.Vox.HW_BAD:
						s = "Sensor Failure";
						break;
					case TTS.Vox.GPS_CRIT:
						s = "GPS Critical Failure";
						break;
					case TTS.Vox.HOME_CHANGED:
						s = "Home relocated";
						break;
					case TTS.Vox.HOME_OFFSET:
						s = null; //"Home offset applied";
						break;
					case TTS.Vox.FAILSAFE:
						s="FAIL SAFE";
						break;
					case TTS.Vox.ARM_STATUS:
						s = TTS.arm_msg;
						break;

					case TTS.Vox.DURATION:
						var ms = ((int)Mwp.duration > 60 > 120) ? "minutes" : "minute";
						s = "%d %s".printf((int)Mwp.duration /60, ms);
						break;
					case TTS.Vox.MAH:
						s = "%u milliamp hour".printf(Battery.curr.mah);
						break;
					case TTS.Vox.VOLTAGE:
						s = "Voltage %.1f".printf(Mwp.msp.td.power.volts).replace(".0","");
						break;
					case TTS.Vox.ELEVATION:
						s = "Elevation %s.".printf(say_nicely((int)Units.distance(Mwp.msp.td.alt.alt)));
						break;
					case TTS.Vox.BARO:
						double estalt = (double)Mwp.msp.td.alt.alt;
						if(estalt < 0.0 || estalt > 20.0) {
							estalt = Math.round(estalt);
							s = "Altitude %s".printf(say_nicely((int)estalt));
						} else
							s = "Altitude %.1f".printf(estalt).replace(".0","");
						break;
					case TTS.Vox.HEADING:
						s = "Heading %s".printf(say_nicely(Mwp.msp.td.atti.yaw));
						break;

					case TTS.Vox.RANGE_BRG:
						StringBuilder sbrg = new StringBuilder();
						sbrg.append("Range ");
						if(Mwp.msp.td.comp.range > 999 && Mwp.conf.p_distance == 0) {
							double km = Mwp.msp.td.comp.range/1000.0;
							sbrg.append("%.1fk".printf(km));
						}
						else {
							sbrg.append(say_nicely((int)Units.distance(Mwp.msp.td.comp.range)));
						}
						if(Mwp.conf.say_bearing) {
							var brg = Mwp.msp.td.comp.bearing;
							if(brg < 0)
								brg += 360;
							sbrg.append(", bearing ");
							sbrg.append(say_nicely(brg));
						}
						s = sbrg.str;
						break;
					case TTS.Vox.MODSAT:
						if(lsats != Mwp.msp.td.gps.nsats || (Mwp.nticks - lsat_t) > Mwp.SATINTVL) {
							string ss = "";
							if(Mwp.msp.td.gps.nsats != 1)
								ss = "s";
							s = "%d satellite%s".printf(Mwp.msp.td.gps.nsats, ss);
							lsats = Mwp.msp.td.gps.nsats;
							lsat_t = Mwp.nticks;
						}
						break;
					case TTS.Vox.LTM_MODE:
						s = Msp.ltm_mode(Mwp.msp.td.state.ltmstate);
						break;

					case TTS.Vox.NAV_STATUS:
						switch(Mwp.msp.td.state.navmode) {
						case 0:
							s = "Pilot has control";
							break;
						case 1:
							s = "Return to home initiated";
							break;
						case 2:
							s = "Returning home";
							break;
						case 3:
							s = "Position hold";
							break;
						case 4:
							s = "Timed position hold";
							break;
						case 5:
							var wpno = Mwp.msp.td.state.wpno;
							if(wpno == 0)
								s = "Starting Mission";
							else
								s = "Navigating to way point %d".printf(wpno);
							break;
						case 7:
							s = "Starting jump at %d".printf(Mwp.msp.td.state.wpno);
							break;
						case 8:
							s = "Starting to land";
							break;
						case 9:
							s = "Landing";
							break;
						case 10:
							s = "Landed";
							break;
						case 11:
							s = "Settling before land";
							break;
						case 12:
							s = "Starting descent";
							break;
						case 13:
							s = "Hover above home";
							break;
						case 14:
							s = "Emergency landing";
							break;
						}
						break;
						/*
					case TTS.Vox.HOST_POWER:
						s = NavStatus.host_batt_status;
						break;
					case TTS.Vox.NAV_ERR:
						s = Msp.nav_error(NavStatus.n.nav_error);
						break;
					case TTS.Vox.FMODE:
						s = "%s mode".printf(NavStatus.fmode);
						break;
					case TTS.Vox.RANGE_BRG:
						StringBuilder sbrg = new StringBuilder();
						sbrg.append("Range ");
						if(NavStatus.cg.range > 999 && MWP.conf.p_distance == 0) {
							double km = NavStatus.cg.range/1000.0;
							sbrg.append("%.1fk".printf(km));
						}
						else
							sbrg.append(say_nicely((int)Units.distance(NavStatus.cg.range)));
						if(MWP.conf.say_bearing) {
							var brg = NavStatus.cg.direction;
							if(brg < 0)
								brg += 360;
							if(NavStatus.recip)
								brg = ((brg + 180) % 360);
							sbrg.append(", bearing ");
							sbrg.append(say_nicely(brg));
						}
						s = sbrg.str;
						break;
					case TTS.Vox.MODSAT:
						var now = timer.elapsed();
						if(lsats != NavStatus.numsat || (now - lsat_t) > 10) {
							string ss = "";
							if(NavStatus.numsat != 1)
								ss = "s";
							s = "%d satellite%s".printf(NavStatus.numsat,ss);
							lsats = NavStatus.numsat;
							lsat_t = now;
						}
						break;
					case TTS.Vox.LTM_MODE:
						var xfmode = NavStatus.xfmode;
						if((xfmode > 0 && xfmode < 5) || xfmode == 8 ||
						   xfmode > 17)
							s = Msp.ltm_mode(xfmode);
						break;
					case TTS.Vox.SPORT_MODE:
						s = Msp.ltm_mode(NavStatus.xfmode);
						break;
*/
					default:
						break;
                    }
                    if(s != null) {
                        if(use_en) {
                            s = s.replace(",",".");
						}
						//						MWPLog.message(":DBG: Say %s\n", s);
                        if(TTS.efdin != -1) {
							StringBuilder sb = new StringBuilder(s);
							sb.append("\n\n");
							var sdta = sb.str.data;
							Posix.write(TTS.efdin, sdta, sdta.length);
                        } else {
                            MwpSpeech.say(s);
						}
                    }
                }
				if (TTS.efdin != -1) {
					Posix.close(TTS.efdin);
					TTS.efdin = -1;
				}
				if(TTS.epid > 0) {
					ProcessLauncher.kill(TTS.epid);
					TTS.epid = -1;
				}
                return 0;
            });
    }
}
