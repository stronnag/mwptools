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
    private WPMGR wpmgr;
    private uint8 last_wp_pts =0;
	private uint upltid;
	private uint timeo;

    private void remove_tid(ref uint tid) {
        if(tid > 0)
            Source.remove(tid);
        tid = 0;
    }

	private void wp_reset_poller() {
		wpmgr.npts = 0;
		wpmgr.wp_flag = 0;
		wpmgr.wps = {};
		reset_poller();
	}

	private int mission_has_land(int idx) {
		if (vi.fc_vers >= FCVERS.hasFWApp) {
			for(var j = idx; j < MissionManager.msx.length; j++) {
				MissionItem [] mis = MissionManager.msx[j].get_ways();
				foreach(MissionItem mi in mis) {
					if(mi.action == Msp.Action.LAND) {
						return j;
					}
				}
			}
		}
		return -1;
	}

	public size_t serialise_wp(MSP_WP w, uint8[] tmp) {
        uint8* rp = tmp;
        *rp++ = w.wp_no;
        *rp++ = w.action;
        rp = SEDE.serialise_i32(rp, w.lat);
        rp = SEDE.serialise_i32(rp, w.lon);
        rp = SEDE.serialise_i32(rp, w.altitude);
        rp = SEDE.serialise_i16(rp, w.p1);
        rp = SEDE.serialise_i16(rp, w.p2);
        rp = SEDE.serialise_i16(rp, w.p3);
        *rp++ = w.flag;
        return (rp-&tmp[0]);
    }

	private void wp_get_approaches(int j) {
		j = mission_has_land(j);
		if(j != -1) {
			lastm = nticks;
			uint8 k = (uint8)(j+Safehome.MAXHOMES);
			last_safehome = k+1;
			queue_cmd(Msp.Cmds.FW_APPROACH, &k, 1);
		} else {
			reset_wp_dl();
			handle_misc_startup();
		}
	}

	private void wp_set_approaches(int j) {
		wpmgr.wp_flag &= ~WPDL.SAVE_FWA;
		j = mission_has_land(j);
		if(j == -1) {
			handle_extra_up_tasks();
		} else {
			pause_poller(SERSTATE.EXTRA_WP);
			lastm = nticks;
			safeindex = Safehome.MAXHOMES+j;
			last_safehome = Safehome.MAXHOMES+j+1;
			var b = FWApproach.serialise(safeindex);
			queue_cmd(Msp.Cmds.SET_FW_APPROACH, b, b.length);
		}
	}

	private void handle_extra_up_tasks() {
		if ((wpmgr.wp_flag & WPDL.DOWNLOAD) != 0) {
			wpmgr.wp_flag &= ~WPDL.DOWNLOAD;
			download_mission();
		} else if ((wpmgr.wp_flag & WPDL.SET_ACTIVE) != 0) {
			wpmgr.wp_flag &= ~WPDL.SET_ACTIVE;
			if(vi.fc_vers >= FCVERS.hasWP_V4) {
				uint8 msg[128];
				var s = "nav_wp_multi_mission_index";
				var k = 0;
				for(k =0; k < s.length; k++) {
					msg[k] = s.data[k];
				}
				msg[k] = 0;
				uint actmm = (int8)MissionManager.mdx+1;
				if (actmm == 0)  {
					MWPLog.message("Warning:: mdx=-1 on save **FIXME**\n");
					actmm = 1;
				}
				msg[k+1] = (uint8)actmm;
				MWPLog.message("Set active mission %d\n", actmm);
				queue_cmd(Msp.Cmds.COMMON_SET_SETTING, msg, k+2);
			}
		} else if ((wpmgr.wp_flag & WPDL.RESET_POLLER) != 0) {
			wp_reset_poller();
		}
		if(last_wp_pts > 0 /*&& wpi.wps_valid == 1 && ls.get_list_size() == 0*/) { //FIXME
			need_mission = true;
		}
	}

    private void upload_callback(int pts) {
        wpmgr.wp_flag &= ~WPDL.CALLBACK;
        MBus.nwpts = pts;
		// must use Idle.add as we may not otherwise hit the mainloop
        Idle.add (() => { MBus.svc.callback(); return false; });
    }

    private void report_special_wp(MSP_WP w) {
        double lat, lon;
        lat = w.lat/1e7;
        lon = w.lon/1e7;
        if (w.wp_no == 0) {
			if (w.lat != 0  && w.lon != 0 && w.altitude != 0) {
				if(lat != wp0.lat && lon != wp0.lon) {
					wp0.lat = lat;
					wp0.lon = lon;
					set_td_origin(lat, lon);
				}
			}
		} else {
            MWPLog.message("Special WP#%d (%d) %.6f %.6f %dm %d°\n", w.wp_no, w.action, lat, lon, w.altitude/100, w.p1);
        }
    }

    private void handle_mm_download(uint8[] raw, uint len) {
        have_wp = true;
        MSP_WP w = MSP_WP();
        uint8* rp = raw;
        if((wpmgr.wp_flag & WPDL.CANCEL) != 0) {
			remove_tid(ref upltid);
			wp_reset_poller();
			Mwp.window.validatelab.set_text("⚠"); // u+26a0
			var wb8 = new Utils.Warning_box("Download cancelled", 10);
			wb8.present();
            return;
		}
        w.wp_no = *rp++;

		bool done = false;
		if(w.wp_no == 0 || w.wp_no > 253) {
            report_special_wp(w);
			return;
		} else {
			w.action = *rp++;
			rp = SEDE.deserialise_i32(rp, out w.lat);
			rp = SEDE.deserialise_i32(rp, out w.lon);
			rp = SEDE.deserialise_i32(rp, out w.altitude);
			rp = SEDE.deserialise_i16(rp, out w.p1);
			rp = SEDE.deserialise_i16(rp, out w.p2);
			rp = SEDE.deserialise_i16(rp, out w.p3);
			w.flag = *rp;
			wpmgr.wps += w;
		}

		if(vi.fc_vers >= FCVERS.hasWP_V4) {
			if (wpmgr.wps.length == wpmgr.npts) {
				done = true;
			}
		} else if (w.flag == 0xa5) {
			done = true;
		}

		if(done) {
			var ms = MissionManager.current();
			if (ms != null) {
				MsnTools.clear(ms);
			}
			var mmsx = MultiM.wps_to_missonx(wpmgr.wps);
			var nwp = MissionManager.check_mission_length(mmsx);
			if(nwp > 0) {
				MissionManager.msx = mmsx;
				MissionManager.is_dirty = false;
				MissionManager.mdx = imdx;
				MissionManager.setup_mission_from_mm();
				MWPLog.message("WP Download completed #%d (idx=%d)\n", nwp, MissionManager.mdx);
				Mwp.window.validatelab.set_text("✔"); // u+2714
				wp_get_approaches(0);
			} else {
				var wb9 = new Utils.Warning_box("Fallback safe mission, 0 points", 10);
				wb9.present();
				MWPLog.message("Fallback safe mission\n");
			}
		} else {
            Mwp.window.validatelab.set_text("WP:%3d".printf(w.wp_no));
			request_wp(w.wp_no+1);
		}
	}

	private void reset_wp_dl() {
		remove_tid(ref upltid);
		wp_reset_poller();
	}

	private void start_download() {
		pause_poller(SERSTATE.GET_WP);
		int rwp;
		//		wpi.max_wp, wpi.wp_count
		rwp = (wpi.wp_count > 0) ? wpi.wp_count : wp_max;
		timeo = 1500+(rwp*1000);
		start_wp_timer(timeo);
		MWPLog.message("Start download for %d WP\n", rwp);
		request_wp(1);
	}

    private void download_mission() {
        //check_mission_clean(do_download_mission); // FIXME
		do_download_mission();
    }

    private void do_download_mission() {
        wpmgr.wp_flag = 0;
		wpmgr.wps = {};
		wpmgr.npts = last_wp_pts;
		if (last_wp_pts > 0 || !inav) {
			imdx = 0;
			if  (vi.fc_vers >= FCVERS.hasWP_V4) {
				wpmgr.wp_flag = WPDL.KICK_DL;
				request_common_setting("nav_wp_multi_mission_index");
			} else {
				start_download();
			}
		} else {
			var wba = new Utils.Warning_box("No WPs in FC to download\nMaybe 'Restore' is needed?", 10);
			wba.present();
		}
    }
    public void start_wp_timer(uint timeo, string reason="WP") {
        upltid = Timeout.add(timeo, () => {
                MWPLog.message("%s operation probably failed\n", reason);
                string wmsg = "%s operation timeout.\nThe transfer has probably failed".printf(reason);
                var wbb = new Utils.Warning_box(wmsg);
				wbb.present();
                if((wpmgr.wp_flag & WPDL.CALLBACK) != 0) {
                    upload_callback(-2);
				}
				reset_poller();
                return Source.REMOVE;
            });
    }

	private void upload_mm(int id, WPDL flag) {
		var wps = MultiM.missonx_to_wps(MissionManager.msx, id);
		var  mlim = (id == -1) ? MissionManager.msx.length : 1;
		if(wps.length > wp_max || mlim > MAXMULTI) {
			var wbc = new Utils.Warning_box(
				"Mission set exceeds FC limits:\nWP: %d/%d\nSegments: %d/%u".printf(wps.length, wp_max, mlim, MAXMULTI));
			wbc.present();
			return;
		}

		if (wps.length == 0) {
			MSP_WP w0 = MSP_WP();
			w0.wp_no = 1;
			w0.action =  Msp.Action.RTH;
			w0.lat = 0;
			w0.lon = 0;
			w0.altitude = 25;
			w0.p1 = 0;
			w0.p2 = w0.p3 = 0;
			w0.flag = 0xa5;
			wps += w0;
		}
		wpmgr.npts = (uint8)wps.length;
        wpmgr.wpidx = 0;
        wpmgr.wps = wps;
        wpmgr.wp_flag = flag;

        pause_poller(SERSTATE.SET_WP);

        var timeo = 1500+(wps.length*1000);
        uint8 wtmp[32];
        var nb = serialise_wp(wpmgr.wps[wpmgr.wpidx], wtmp);
		MWPLog.message("Start mission upload for %u points\n", wps.length);
        queue_cmd(Msp.Cmds.SET_WP, wtmp, nb);
        start_wp_timer(timeo);
	}

	public void pause_poller(SERSTATE s) {
		if (msp.available) {
			MWPLog.message(":DBG: Pause poller %s\n", s.to_string());
			//serstate = s;
			//mq.clear();
		}
	}

}
