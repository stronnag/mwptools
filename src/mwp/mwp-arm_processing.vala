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
	private bool armed_processing(uint64 flag, string reason="") {
        bool changed = false;
        if(armed == 0) {
            armtime = 0;
            duration = -1;
            //mss.m_wp = -1; // FIXME
            if(replayer == Player.NONE) {
				init_have_home();
			}
            no_ofix = 0;
        } else {
            if(armtime == 0)
                time_t(out armtime);

            if(replayer == Player.NONE) {
                time_t(out duration);
                duration -= armtime;
            }
        }
		if(armed != larmed) {
            changed = true;
			//  navstatus.set_replay_mode((replayer != Player.NONE)); // FIXME
            // radstatus.annul(); /; FIXME
            if (armed == 1) {
				string devnam;
				if(Mwp.msp.available) {
					devnam = dev_entry.text;
				} else {
					devnam = "unknown";
				}
				Logger.fcinfo(devnam);

				Mwp.window.armed_state(true);
				magdt = -1;
                Odo.stats = {0};
				Odo.stats.atime = armtime;
                Odo.stats.alt = -9999;
				Odo.stats.cname = vname;
				Odo.stats.live = (replayer == Player.NONE || Environment.get_variable("MWP_ODO_LIVE") != null);
                Odo.view.reset(Odo.stats);
				if (Odo.stats.live) {
					Odo.view.add_summary_event("Armed");
				}
				DeltaCache.dlat = DeltaCache.dlon = 0.0;
                reboot_status();
                init_have_home(); // FIXME
				Mwp.craft.new_craft(!no_trail, stack_size, mod_points);
                MWPLog.message("Craft is armed, special=%x\n", want_special);
				Mwp.window.armed_spinner.set_visible(true);
                check_mission_home();

				if(BBLV.vp != null) {
					BBLV.vp.start_at(BBL.nsecs);
				}

				sflags |= SPK.Volts;

                if (conf.audioarmed == true) {
                    TTS.say_state |= SAY_WHAT.Nav;
                    MWPLog.message("Enable nav speak (%x)\n", sflags);
                    //navstatus.set_audio_status(say_state);
                    Mwp.window.audio_cb.active = true;
                }
                if(conf.logarmed == true && !mqtt_available) {
                    Mwp.window.logger_cb.active = true;
                }
				Logger.armed(true,duration,flag, sensor,telem);
				Logger.origin();
			} else {
				Mwp.window.armed_state(false);
                if(Odo.stats.time > 5) {
                    MWPLog.message("Distance = %.1f, max speed = %.1f time = %u\n",
                                   Odo.stats.distance, Odo.stats.speed, Odo.stats.time);
                    Odo.view.display_ui(Odo.stats, true);
                    //map_hide_wp(); // FIXME
                }
				if (Odo.stats.live) {
					Odo.view.add_summary_event("Disarmed");
				}
                MWPLog.message("Disarmed %s\n", reason);
				Mwp.window.armed_spinner.set_visible(false);
                MwpMenu.set_menu_state(Mwp.window, "followme", false);
                duration = -1;
                armtime = 0;
                want_special = 0;
                if (conf.audioarmed == true) {
                    Mwp.window.audio_cb.active = false;
                    TTS.say_state &= ~SAY_WHAT.Nav;
                    if((debug_flags & DebugFlags.ADHOC) != 0) {
                        MWPLog.message("Disable nav speak\n");
					}
                }
                if(conf.logarmed == true) {
					Logger.armed(false,duration,flag, sensor,telem);
					Mwp.window.logger_cb.active=false;
                }
                reboot_status();
			}
        }
		Logger.armed((armed == 1), duration, flag, sensor, telem);
        larmed = armed;
        return changed;
    }
}
