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
    bool x_fl2kml;
    bool x_rawreplay;
    bool x_mwpset;
    bool x_plot_elevations_rb;
	bool sticks_ok;
	bool bblosd_ok;
    uint8 spapi =  0;
	MSP_WP_GETINFO wpi;
	uint gpsintvl = 0;
    int nrings = 0;
    double ringint = 0;
	Rebase rebase;
}

namespace Cli {
	void handle_options() {
		var aa = Mwp.extra_files.steal();
		foreach(var a in aa) {
			string fn;
			if(a != Mwp.mission &&
			   a != Mwp.clifile &&
			   a != Mwp.bfile &&
			   a != Mwp.rfile &&
			   a != Mwp.kmlfile) {
				var ftyp = MWPFileType.guess_content_type(a, out fn);
				if(ftyp != FType.UNKNOWN)  {
					MWPFileType.handle_file_by_type(ftyp, fn);
				}
			}
		}
		parse_options();
	}

	public bool main_window_ready() {
		if(Gis.map != null) {
			var w = Gis.map.get_width();
			if ( w > 0) {
				if(Mwp.current_lat == 0 && Mwp.current_lon == 0) {
					MapUtils.get_centre_location(out Mwp.current_lat, out Mwp.current_lon);
				}
				parse_cli_files();
				return true;
			}
		}
		return false;
	}

	private bool get_app_status(string app, out string bblhelp) {
		var p = new ProcessLauncher();
		var res = p.run_argv({app, "--version"}, ProcessLaunch.STDOUT|ProcessLaunch.STDERR);
		bblhelp="";
		if(res) {
			var sout = p.get_stdout_iochan();
			try {
				size_t slen;
				sout.read_to_end(out bblhelp, out slen);
			} catch (Error e) {
				res = false;
			}
			try {sout.shutdown(false); } catch {}
		}
		return res;
	}

	private uint extract_version(string text) {
		uint vsum = 0;
		var parts = text.split("\n");
		var ptext = parts[parts.length-1];
		var lparts = ptext.split(" ");
		if (lparts.length == 3) {
			var vparts = lparts[1].split(".");
			for(var i = 0; i < 3 && i < vparts.length; i++) {
				var v = uint.parse(vparts[i],16);
				vsum  = (vsum << 8) | v;
			}
		}
		return vsum;
	}

#if UNIX
	const int FL2LTMVERS = 0x10024;
#else
	const int FL2LTMVERS = 0x10026;
#endif
	const int FL2KMLVERS = 0x10031;

	private void parse_options() {
		Mwp.gpsstats = {0, 0, 0, 0, 9999, 9999, 9999};
		MWSerial.debug = ((Mwp.debug_flags & Mwp.DebugFlags.SERIAL) == Mwp.DebugFlags.SERIAL);
#if MQTT
        MWPLog.message("MQTT enabled via the \"%s\" library\n", MwpMQTT.provider());
#endif
        string []  ext_apps = {
            Mwp.conf.blackbox_decode, // 0
			"flightlog2kml",  // 1
			"gnuplot",  // 2
			"mwp-plot-elevations", // 3
			"unzip", // 4
			null, // 5
			"fl2ltm", // 6
			"mavlogdump.py",  // 7
            "mwp-log-replay", // 8
			"mwpset" //9
		};
        bool [] appsts = new bool[ext_apps.length];
        var si = 0;
		var pnf = 0;
        foreach (var s in ext_apps) {
            if (s != null) {
				var ppath = Environment.find_program_in_path(s);
                appsts[si] = (ppath != null);
				if (appsts[si] == false) {
					StringBuilder vsb = new StringBuilder();
					vsb.append_printf("Failed to find \"%s\" on $PATH", s);
					if(si == 0 || si > 4) {
						vsb.append("; see https://stronnag.github.io/mwptools/replay-tools/");
					}
					vsb.append_c('\n');
					MWPLog.message(vsb.str);
					pnf += 1;
				} else if  (Mwp.DebugFlags.INIT in Mwp.debug_flags)  {
					MWPLog.message(":DBG: Path %s => %s\n", s, ppath);
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
			} else {
				var iv = int.parse(text);
				if (iv < 5) {
					res = false;
				}
			}
			appsts[0] = res;
		}
		if(appsts[0] == false) {
			MWPLog.message("\"%s\" too old or missing, replay disabled\n", Mwp.conf.blackbox_decode);
		}

		if(appsts[6]) {
			string text;
			uint vsum = 0;
			var ok  = get_app_status("fl2ltm", out text);
			text = text.chomp();
			if(ok == false || text == null || text.length == 0) {
				ok = false;
			} else {
				vsum = extract_version(text);
				if (vsum > 0x10000) {
					Mwp.sticks_ok = true;
					if (vsum >= FL2LTMVERS) {
						Mwp.bblosd_ok = true;
						MWPLog.message("Using %s (%x)\n", text, vsum);
						ok = true;
					}  else {
						ok = false;
					}
				}
			}
			appsts[6] = ok;
		}
		if (appsts[6] == false) {
			var oldmsg = "fl2ltm too old or missing, upgrade recommended";
			MWPLog.message("%s\n", oldmsg);
			Mwp.add_toast_text(oldmsg);
		}

		if(appsts[1]) {
			string text;
			var ok = get_app_status("flightlog2kml", out text);
			text = text.chomp();
			if(ok == false || text == null || text.length == 0) {
				ok = false;
			} else {
				uint vsum = extract_version(text);
				if (vsum >= FL2KMLVERS) {
					ok = true;
					MWPLog.message("Using %s (%x)\n", text, vsum);
				} else {
					ok = false;
				}
			}
			appsts[1] = ok;
		}

		if (appsts[1] == false) {
			var oldmsg = "flightlog2kml may be too old, upgrade recommended";
			MWPLog.message("%s\n", oldmsg);
			Mwp.add_toast_text(oldmsg);
		}

		if (Mwp.conf.show_sticks == 1)
			Mwp.sticks_ok = false;

		Mwp.x_fl2kml = (appsts[0]&&appsts[1]);
		Mwp.x_plot_elevations_rb = (appsts[2]&&appsts[3]);
        Mwp.x_kmz = appsts[4];
		Mwp.x_fl2ltm = Mwp.x_otxlog = (appsts[0]&&appsts[6]);
		Mwp.x_aplog = appsts[7];
        Mwp.x_rawreplay = appsts[8];
		Mwp.x_mwpset = appsts[9];

		MwpMenu.set_menu_state(Mwp.window, "mwpset", Mwp.x_mwpset);

		if(Mwp.x_plot_elevations_rb == false) {
			MWPLog.message(":DBG: No TA for you!\n");
			MwpMenu.set_menu_state(Mwp.window, "mta", false);
		}

        XmlIO.uc = Mwp.conf.ucmissiontags;
        XmlIO.meta = Mwp.conf.missionmetatag;
		// Ugly MM xml for the configurator
        if (Environment.get_variable("CFG_UGLY_XML") != null) {
			XmlIO.ugly = true;
		}

        if(Mwp.exvox == null) {
			uint8 spapi_mask  = MwpSpeech.get_api_mask();
            MWPLog.message("Mask %d, api [%s]\n", spapi_mask, Mwp.conf.speech_api);

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
                Mwp.ringint = DStr.strtod(parts[1], null);
            }
        }

        if(Mwp.rebasestr != null) {
			double dlat = 0;
			double dlon = 0;
			uint zz = 0;
			if (LLparse.llparse(Mwp.rebasestr, ref dlat, ref dlon, ref zz)) {
				Mwp.rebase.set_reloc(dlat, dlon);
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
			new ProcessLauncher().run_command(Mwp.conf.atstart, 0);
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

        if(Mwp.rebase.has_reloc()) {
            Mwp.clat = Mwp.rebase.reloc.lat;
            Mwp.clon = Mwp.rebase.reloc.lon;
			MWPLog.message(":DBG: Using reloc %f %f\n", Mwp.clat, Mwp.clon);
        }

		if(Mwp.llstr != null) {
			LLparse.llparse(Mwp.llstr, ref Mwp.clat, ref Mwp.clon, ref zm);
			if (zm == -1) {
				zm =  Mwp.conf.zoom;
			}
			MapUtils.centre_on(Mwp.clat, Mwp.clon, zm);
			Mwp.set_pos_label(Mwp.clat, Mwp.clon);
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
		if (Mwp.clifile != null) {
			if (Mwp.mission == null) {
				Mwp.mission = Mwp.clifile;
			}
			Mwp.sh_load = Mwp.clifile;
			Mwp.gz_load = Mwp.clifile;
			Mwp.sh_disp = true;
			Mwp.clifile = null;
		}

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
				SLG.replay_bbl(vfn);
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
				  if(Mwp.rebase.is_valid()) {
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
