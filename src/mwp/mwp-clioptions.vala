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

	/* There is a single timer that monitors message state
	   This runs at 100ms (TIMINTVL). Other monitoring times are defined in terms of this
	   timer.
	   Two other monitoring intervals are defined by configuration.
	   poll-timeout : messging poll timeout (default 900ms)
	   gpsintvl     : gps-data timeout (default 150ms)
	 */

namespace Mwp {
	MSP_GPSSTATISTICS gpsstats;
    bool x_kmz;
    bool x_otxlog;
    bool x_aplog;
    bool x_fl2ltm;
    bool x_rawreplay;
    bool x_plot_elevations_rb;
	bool sticks_ok;
	bool bblosd_ok;
    uint8 spapi =  0;
	Queue<string> csdq;
	MSP_WP_GETINFO wpi;
	uint gpsintvl = 0;
    int nrings = 0;
    double ringint = 0;
	//    TelemTracker ttrk; // FIXME
}

namespace Cli {
	void handle_options() {
		var aa = Mwp.extra_files.steal();
		foreach(var a in aa) {
			string fn;
			var ftyp = MWPFileType.guess_content_type(a, out fn);
			if(ftyp != FType.UNKNOWN)  {
				MWPFileType.handle_file_by_type(ftyp, fn);
			}
		}
		parse_options();
		Timeout.add_once(1500, () => {
				parse_cli_files();
			});
	}

	private bool get_app_status(string app, out string bblhelp) {
        bool ok = true;
        bblhelp="";
        try {
			var bbl = new Subprocess(SubprocessFlags.STDERR_MERGE|SubprocessFlags.STDOUT_PIPE,
									 app, "--help");
			bbl.communicate_utf8(null, null, out bblhelp, null);
			bbl.wait_check_async.begin(null, (obj,res) => {
					try {
						ok = bbl.wait_check_async.end(res);
					} catch { /* exit status != 0 */ }
				});
        } catch (Error e) {
			bblhelp = e.message;
			ok = false;
		}
        return ok;
	}

	private void parse_options() {
		Mwp.gpsstats = {0, 0, 0, 0, 9999, 9999, 9999};
		MWSerial.debug = ((Mwp.debug_flags & Mwp.DEBUG_FLAGS.SERIAL) == Mwp.DEBUG_FLAGS.SERIAL);
#if MQTT
        MWPLog.message("MQTT enabled via the \"%s\" library\n", MwpMQTT.provider());
#endif
        string []  ext_apps = {
            Mwp.conf.blackbox_decode,
			null,
			"gnuplot",
			"mwp-plot-elevations",
			"unzip", null,
			"fl2ltm",
			"mavlogdump.py",
            "mwp-log-replay"};
        bool appsts[9];
        var si = 0;
		var pnf = 0;
        foreach (var s in ext_apps) {
            if (s != null) {
                appsts[si] = (Environment.find_program_in_path(s) != null);
                if (appsts[si] == false) {
					StringBuilder vsb = new StringBuilder();
					vsb.append_printf("Failed to find \"%s\" on $PATH", s);
					if(si == 0 || si > 4) {
						vsb.append("; see https://stronnag.github.io/mwptools/replay-tools/");
					}
					vsb.append_c('\n');
					MWPLog.message(vsb.str);
					pnf += 1;
				}
            }
            si++;
        }

		if(pnf > 0 && !(pnf == 1 && appsts[7] == false)) {
			MWPLog.message("FYI, PATH is %s\n", Environment.get_variable("PATH"));
		}

		if (appsts[0]) {
			string text;
			var res = get_app_status(Mwp.conf.blackbox_decode, out text);
			if(res == false) {
				MWPLog.message("%s %s\n", Mwp.conf.blackbox_decode, text);
			} else if (!text.contains("--datetime")) {
				MWPLog.message("\"%s\" too old, replay disabled\n", Mwp.conf.blackbox_decode);
				res = false;
			}
			appsts[0] = res;
		}

		if(appsts[6]) {
			string text;
			var res = get_app_status("fl2ltm", out text);
			if(res == false) {
				MWPLog.message("fl2ltm %s\n", text);
			} else {
				int vsum = 0;
				var parts = text.split("\n");
				bool ok = false;
				text = "fl2ltm";
				foreach (var p in parts) {
					if (p.has_prefix("fl2ltm")) {
						var lparts = p.split(" ");
						if (lparts.length == 3) {
							var vparts = lparts[1].split(".");
							for(var i = 0; i < 3 && i < vparts.length; i++) {
								vsum = int.parse(vparts[i]) + 100 * vsum;
							}
						}
						if (vsum > 10000) {
							Mwp.sticks_ok = true;
							if (vsum >= 10024) {
								Mwp.bblosd_ok = true;
								ok = true;
							}
						}
						text = p;
						break;
					}
				}
				if (!ok) {
					var oldmsg = "\"%s\" (%d) may be too old, upgrade recommended".printf(text, vsum);
					MWPLog.message(oldmsg+"\n");
					Mwp.add_toast_text(oldmsg);
					res = false;
				} else {
					MWPLog.message("Using %s (%d)\n", text, vsum);
				}
			}
			appsts[6] = res;
		}
		if (Mwp.conf.show_sticks == 1)
			Mwp.sticks_ok = false;

		Mwp.x_plot_elevations_rb = (appsts[2]&&appsts[3]);
        Mwp.x_kmz = appsts[4];
		Mwp.x_fl2ltm = Mwp.x_otxlog = appsts[6];
		Mwp.x_aplog = appsts[7];
        Mwp.x_rawreplay = appsts[8];

        XmlIO.uc = Mwp.conf.ucmissiontags;
        XmlIO.meta = Mwp.conf.missionmetatag;
		// Ugly MM xml for the configurator
        if (Environment.get_variable("CFG_UGLY_XML") != null) {
			XmlIO.ugly = true;
		}
		Mwp.csdq = new Queue<string>();

        if(Mwp.exvox == null) {
			uint8 spapi_mask  = MwpSpeech.get_api_mask();
			if (spapi_mask != 0) {
				for(uint8 j = Mwp.SPEAKER_API.ESPEAK; j < Mwp.SPEAKER_API.COUNT; j++) {
					if(Mwp.conf.speech_api == Mwp.SPEAKERS[j] && ((spapi_mask & (1<<(j-1))) != 0)) {
						Mwp.spapi = j;
						break;
					}
				}
			}
			MWPLog.message("Using speech api %d [%s]\n", Mwp.spapi, Mwp.SPEAKERS[Mwp.spapi]);
		} else {
            MWPLog.message("Using external speech api [%s]\n", Mwp.exvox);
        }
        MwpSpeech.set_api(Mwp.spapi);
		TTS.start_audio();

        Mwp.gpsintvl = Mwp.conf.gpsintvl / Mwp.TIMINTVL;

		if(Mwp.rrstr != null) {
            var parts = Mwp.rrstr.split(",");
            if(parts.length == 2) {
                Mwp.nrings = int.parse(parts[0]);
                Mwp.ringint = double.parse(parts[1]);
            }
        }

        if(Mwp.rebasestr != null) {
			double dlat = 0;
			double dlon = 0;
			uint zz = 0;
			if (LLparse.llparse(Mwp.rebasestr, ref dlat, ref dlon, ref zz)) {
				Rebase.set_reloc(dlat, dlon);
				MWPLog.message("Rebase to %f %f\n", dlat, dlon);
			}
        }

        if(Mwp.conf.ignore_nm == false) {
            if(Mwp.offline == false) {
                try {
                    NetworkManager nm = Bus.get_proxy_sync (BusType.SYSTEM,
                                                            "org.freedesktop.NetworkManager",
                                                            "/org/freedesktop/NetworkManager");
                    NMSTATE istate = (NMSTATE)nm.State;
                    if(istate != NMSTATE.NM_STATE_CONNECTED_GLOBAL && istate != NMSTATE.UNKNOWN) {
                        Mwp.offline = true;
                        MWPLog.message("Forcing proxy offline [%s]\n", istate.to_string());
                    }
                } catch {}
            }
        }

        if(Mwp.conf.atstart != null && Mwp.conf.atstart.length > 0) {
            try {
                Process.spawn_command_line_async(Mwp.conf.atstart);
            } catch {};
        }

		Mwp.msp.use_v2 = false;
        if (Mwp.relaxed) {
            MWPLog.message("using \"relaxed\" MSP for main port\n");
            Mwp.msp.set_relaxed(true);
        }
		Mwp.msp.force4 = Mwp.force4;

		Mwp.clat = Mwp.conf.latitude;
        Mwp.clon = Mwp.conf.longitude;
        var zm = Mwp.conf.zoom;

        if(Rebase.has_reloc()) {
            Mwp.clat = Rebase.reloc.lat;
            Mwp.clon = Rebase.reloc.lon;
        }

		if(Mwp.llstr != null) {
			LLparse.llparse(Mwp.llstr, ref Mwp.clat, ref Mwp.clon, ref zm);
			Gis.map.center_on(Mwp.clat, Mwp.clon);
			Mwp.set_zoom_sanely(zm);
			Mwp.set_pos_label(Mwp.clat, Mwp.clon);
		}

		if(Mwp.sh_load == null) {
			if(Mwp.conf.load_safehomes != "") {
				var parts = Mwp.conf.load_safehomes.split(",");
				Mwp.sh_load = parts[0];
				Mwp.sh_disp = (parts.length == 2 && (parts[1] == "Y" || parts[1] == "y"));
				if (Mwp.sh_load != "-FC-") {
					Safehome.manager.load_homes(Mwp.sh_load, Mwp.sh_disp);
					if(Rebase.is_valid()) {
						Safehome.manager.relocate_safehomes();
					}
				}
			}
		}

		if(Mwp.conf.mag_sanity != "") {
            var parts = Mwp.conf.mag_sanity.split(",");
            if (parts.length == 2) {
                Mwp.magdiff=int.parse(parts[0]);
                Mwp.magtime=int.parse(parts[1]);
                MWPLog.message("Enabled mag anomaly checking %d⁰, %ds\n", Mwp.magdiff,Mwp.magtime);
                Mwp.magcheck = true;
            }
        }
	}

	public void parse_cli_files() {
		if (Mwp.mission != null) {
			var fn = Mwp.mission;
			Mwp.mission = null;
			var vfn = MWPFileType.validate_cli_file(fn);
			if (vfn != null) {
				var ms = MissionManager.open_mission_file(vfn);
				if(ms != null) {
					Mwp.clat = ms.cy;
					Mwp.clon = ms.cx;
				}
			}
		}

		if(Mwp.kmlfile != null) {
			var ks = Mwp.kmlfile.split(",");
			Mwp.kmlfile = null;
			foreach(var kf in ks) {
				var vfn = MWPFileType.validate_cli_file(kf);
				if (vfn != null) {
					Kml.try_load_overlay(vfn);
				}
			}
		}

		if(Mwp.rfile != null) {
			var vfn = MWPFileType.validate_cli_file(Mwp.rfile);
			Mwp.rfile = null;
			if(vfn != null) {
				Mwp.run_replay(vfn, true, Mwp.Player.MWP);
			}
		} else if(Mwp.bfile != null) {
			var vfn = MWPFileType.validate_cli_file(Mwp.bfile);
			Mwp.bfile = null;
			if(vfn != null) {
				BBL.replay_bbl(vfn);
			}
		} else if(Mwp.otxfile != null) {
			var vfn = MWPFileType.validate_cli_file(Mwp.otxfile);
			Mwp.otxfile = null;
			if(vfn != null) {
				ETX.replay_etx(vfn);
			}
		}

		if(Mwp.sh_load != null && Mwp.sh_load != "-FC-") {
			var vfn = MWPFileType.validate_cli_file(Mwp.sh_load);
			Mwp.sh_load = null;
			if (vfn != null) {
				Safehome.manager.load_homes(vfn, Mwp.sh_disp);
				  if(Rebase.is_valid()) {
					  Safehome.manager.relocate_safehomes();
				  }
			}
		}

		if(Mwp.gz_load != null) {
			var vfn = MWPFileType.validate_cli_file(Mwp.gz_load);
			Mwp.gz_load = null;
			if (vfn != null) {
				Mwp.gzr.from_file(vfn);
				if(Mwp.gzone != null) {
					Mwp.gzone.remove();
				}
				Mwp.gzone = Mwp.gzr.generate_overlay();
				Mwp.gzone.display();
				Mwp.set_gzsave_state(true);
			}
		}

	}
}