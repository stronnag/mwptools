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

namespace Mwp  {
    Mwp.MQI lastmsg;
    Queue<Mwp.MQI?> mq;
	MWSerial msp;
	Forwarder fwddev;
	bool mqtt_available;
#if MQTT
    MwpMQTT mqtt;
#endif
	uint stag = 0;
	Timer rctimer;
	int nrc_chan = 16;
	MspRC use_rc;

	public void clear_sidebar(MWSerial s) {
		if(s != null) {
			s.td.annul_all();
			s.td = {};
		}
		RSSI.set_title(RSSI.Title.RSSI);
		Battery.bat_annul();
		Battery.update = true;
		Battery.set_bat_stat(0);
		Mwp.panelbox.update(Panel.View.DIRN, 0xff);
		Mwp.panelbox.update(Panel.View.FVIEW, 0xff);
		Mwp.panelbox.update(Panel.View.AHI, 0xff);
		Mwp.panelbox.update(Panel.View.RSSI, 0xff);
		Mwp.panelbox.update(Panel.View.VOLTS, 0xff);
		Mwp.panelbox.update(Panel.View.VARIO, 0xff);
	}
}

namespace Msp {
	int hpid = 0;

	public void stop_hid() {
		if (hpid != 0) {
			ProxyPids.remove(hpid);
			ProcessLauncher.kill(hpid);
		}
		hpid = 0;
		Mwp.rctimer.stop();
		Mwp.use_rc &= ~(Mwp.MspRC.ON|Mwp.MspRC.SET|Mwp.MspRC.GET);
	}

	public void start_hid() {
		if (hpid == 0) {
			var pl = new ProcessLauncher();
			var hidopt = Environment.get_variable("MWP_HIDOPT");
			if(hidopt == null) {
				hidopt = "";
			}
			var cmd = "mwp-hid-server %s %s".printf(hidopt, Mwp.conf.msprc_settings);
			var res = pl.run_command(cmd, ProcessLaunch.STDIN|ProcessLaunch.STDOUT);
			if(res) {
				hpid = pl.get_pid();
				if(hpid != 0) {
					Mwp.rctimer.stop();
					ProxyPids.add(hpid);
					JSMisc.setup(pl);
					Mwp.use_rc |= Mwp.MspRC.ON;
					if (Mwp.MspRC.ACT in Mwp.use_rc) {
						Mwp.use_rc |= Mwp.MspRC.GET;
					}
					pl.complete.connect(() => {
							stop_hid();
						});
				}
			}
		}
		MWPLog.message(":HID DBG: pid=%d %x\n", hpid, Mwp.use_rc);
	}

	public void init() {
		Mwp.mqtt_available = false;
		Mwp.msp = new MWSerial();
        Mwp.lastp = new Timer();
		Mwp.lastp.start();
		Mwp.rctimer = new Timer();
		Mwp.rctimer.stop();
		Mwp.msp.is_main = true;
		Mwp.mq = new Queue<Mwp.MQI?>();
        Mwp.lastmsg = Mwp.MQI(); //{cmd = Msp.Cmds.INVALID};
		Mwp.csdq = new Queue<string>();
		Mwp.fwddev = new Forwarder(Mwp.forward_device);
        Mwp.msp.serial_lost.connect(() => {
				close_serial();
			});

        Mwp.msp.serial_event.connect(() => {
				MWSerial.INAVEvent? m;
				while((m = Mwp.msp.msgq.try_pop()) != null) {
					if(Mwp.DebugFlags.MSP in Mwp.debug_flags) {
						MWPLog.message(":DBG: MSP recv: %s %u\n", m.cmd.format(), Mwp.msp.msgq.length());
					}
					Mwp.handle_serial(Mwp.msp, m.cmd,m.raw,m.len,m.flags,m.err);
				}
			});

		Mwp.msp.crsf_event.connect(() => {
				MWSerial.INAVEvent? m;
				while((m = Mwp.msp.msgq.try_pop()) != null) {
					CRSF.ProcessCRSF(Mwp.msp, m.raw);
				}
            });

        Mwp.msp.flysky_event.connect(() => {
				MWSerial.INAVEvent? m;
				while((m = Mwp.msp.msgq.try_pop()) != null) {
					Flysky.ProcessFlysky(Mwp.msp, m.raw);
				}
            });

        Mwp.msp.sport_event.connect(() => {
				MWSerial.INAVEvent? m;
				while((m = Mwp.msp.msgq.try_pop()) != null) {
					Frsky.process_sport_message (Mwp.msp, m.raw);
				}
            });

		if(Mwp.serial != null) {
            Mwp.prepend_combo(Mwp.dev_combox, Mwp.serial);
            Mwp.dev_combox.set_active(0);
        }

        Mwp.start_poll_timer();

#if MQTT
        Mwp.mqtt = newMwpMQTT();
		MQTT.init();
        Mwp.mqtt.mqtt_mission.connect((w,n) => {
				if(n > 0) {
					Mwp.wpmgr = {};
					for(var j = 0; j < n; j++) {
						Mwp.wpmgr.wps += w[j];
					}
					Mwp.wpmgr.npts = (uint8)n;
					var ms = MissionManager.current();
					if (ms != null) {
						MsnTools.clear(ms);
					}
					var mmsx = MultiM.wps_to_missonx(Mwp.wpmgr.wps);
					var nwp = MissionManager.check_mission_length(mmsx);
					if(nwp > 0) {
						MissionManager.msx = mmsx;
						MissionManager.mdx = 0;
						MissionManager.setup_mission_from_mm();
					}
				}
            });

		mqtt.mqtt_frame.connect((cmd, raw, len) => {
                Mwp.handle_serial(Mwp.msp, cmd, raw, (uint)len, 0, false);
            });

        mqtt.mqtt_craft_name.connect((s) => {
                Mwp.vname = s;
                Mwp.set_typlab();
            });
#endif
	}

	public void handle_connect() {
		Mwp.window.conbutton.sensitive = false;
		if (Mwp.window.conbutton.label == "Disconnect") {
			Mwp.msp.close_async.begin((obj,res) => {
					Mwp.msp.close_async.end(res);
				});
		} else {
			connect_serial();
		}
	}

	public void close_serial() {
		if(Mwp.cleaned == true) {
			return;
		}
		Assist.Window.instance().gps_available(false);
		if(!Mwp.zznopoll) {
			if(Mwp.xnopoll != Mwp.nopoll)
				Mwp.nopoll = Mwp.xnopoll;
		}
        MWPLog.message("Serial closed replay %d\n", Mwp.replayer);
		Mwp.csdq.clear();
		Mwp.clear_gps_flash();
        if(Mwp.inhibit_cookie != 0) {
			MwpIdle.uninhibit(Mwp.inhibit_cookie);
            Mwp.inhibit_cookie = 0;
        }
		//        map_hide_wp(); // FIXME
        if(Mwp.replayer == Mwp.Player.NONE) {
            Safehome.manager.online_change(0);
            Mwp.window.arm_warn.visible=false;
            Mwp.serstate = Mwp.SERSTATE.NONE;
            Mwp.sflags = 0;
            if (Mwp.conf.audioarmed == true) {
                Mwp.window.audio_cb.active = false;
            }
			if(Mwp.stag != 0) {
				Source.remove(Mwp.stag);
				Mwp.stag = 0;
			}
			Mwp.show_serial_stats();
            if(Mwp.rawlog == true) {
                Mwp.msp.raw_logging(false);
            }

            Mwp.gpsstats = {0, 0, 0, 0, 9999, 9999, 9999};
            Mwp.nsats = 0;
            Mwp._nsats = 0;
            Mwp.last_tm = 0;
            Mwp.last_ga = 0;
			Mwp.msp.td.alt.vario = 0;
			TelemTracker.ttrk.enable(Mwp.msp.get_devname());
#if MQTT
			if (Mwp.mqtt_available) {
				Mwp.mqtt_available = Mwp.mqtt.mdisconnect();
			}
#endif
            Mwp.window.conbutton.set_label("Connect");
            Mwp.set_mission_menus(false);
            MwpMenu.set_menu_state(Mwp.window, "navconfig", false);
            Mwp.duration = -1;
			//craft.remove_marker();
			Mwp.init_have_home();
            Mwp.xsensor = 0;
            Mwp.clear_sensor_array();
        } else {
            Mwp.show_serial_stats();
			Mwp.replayer = Mwp.Player.NONE;
        }

		if(Mwp.fwddev != null && Mwp.fwddev.available()) {
			Mwp.fwddev.close();
		}
        Mwp.set_replay_menus(true);
        Mwp.reboot_status();
		if(Mwp.gzone != null) {
			if(Mwp.gz_from_msp) {
				Mwp.gzr.dump(Mwp.gzone, Mwp.vname);
				Mwp.gzone.remove();
				Mwp.gzone = null;
				Mwp.gzr.reset();
				Mwp.set_gzsave_state(false);
				Mwp.gz_from_msp = false;
			}
		}
        if((Mwp.replayer & (Mwp.Player.BBOX|Mwp.Player.OTX|Mwp.Player.RAW)) == 0) {
            if(Mwp.sh_load == "-FC-") {
                Safehome.manager.remove_homes();
            }
        }
		//markers.remove_rings(view);
		Mwp.window.verlab.label = Mwp.window.verlab.tooltip_text = "";
		Mwp.window.typlab.set_label("");
		Mwp.window.mmode.set_label("");
		MwpMenu.set_menu_state(Mwp.window, "followme", false);
		Mwp.window.conbutton.sensitive = true;
		if(Mwp.MspRC.ON in Mwp.use_rc) {
			if(Mwp.conf.show_sticks != 1) {
				Sticks.done();
			}
			Msp.stop_hid();
		}
	}

	private uint8 pmask_to_mask(uint j) {
		switch(j) {
		case 0:
			return 0xff;
		default:
			return (uint8)(1 << (j-1));
		}
	}

	private void serial_complete_setup(string serdev, bool ostat) {
		Mwp.window.conbutton.sensitive = true;
		Mwp.hard_display_reset();
		if (ostat == true) {
			Mwp.xarm_flags=0xffff;
			Mwp.lastrx = Mwp.lastok = Mwp.nticks;
			Mwp.set_replay_menus(false);
			if(Mwp.rawlog == true) {
				Mwp.msp.raw_logging(true);
			}
			Mwp.window.conbutton.set_label("Disconnect");
			if(Mwp.forward_device != null) {
				Mwp.fwddev.try_open(Mwp.msp);
			}
			if (!Mwp.mqtt_available) {
				var pmsk = Mwp.window.protodrop.selected;
				var pmask = (MWSerial.PMask)pmask_to_mask(pmsk);
				set_pmask_poller(pmask);
				var u = UriParser.dev_parse(serdev);
				if(u.scheme == "udp" && (u.host == null || u.host == "")) {
					Mwp.nopoll = true;
				}
				Mwp.msp.setup_reader();
				//var cmode = Mwp.msp.get_commode();

				var stimer = Environment.get_variable("MWP_STATS_LOG");
				if(stimer != null) {
					var ssecs = uint.parse(stimer);
					if(ssecs > 0) {
						Mwp.stag = Timeout.add_seconds(ssecs, () => {
								Mwp.show_serial_stats();
								return true;
							});
					}
				}

				MWPLog.message("Connected %s (nopoll %s)\n", serdev, Mwp.nopoll.to_string());
				if(Mwp.nopoll == false) {
					bool forced_mav = false;
					if (u.qhash != null) {
						var v = u.qhash.get("mavlink");
						if (v != null) {
							uint8 mvers = (uint8)uint.parse(v);
							if(mvers < 1)
								mvers = 1;
							if(mvers > 2)
								mvers = 2;
							Mwp.msp.mavvid = mvers;
							forced_mav = true;
							Mwp.serstate = Mwp.SERSTATE.TELEM;
							Mav.send_mav_beacon(Mwp.msp);
						}
					}
					Mwp.init_state();
					Mwp.init_sstats();

					if (!forced_mav) {
						Mwp.serstate = Mwp.SERSTATE.NORMAL;
						Mwp.msp.use_v2 = false;
						if(Misc.is_msprc_enabled()) {
							start_hid();
							if ((Mwp.MspRC.ON|Mwp.MspRC.ACT) in Mwp.use_rc) {
								MWPLog.message("Requesting HID Info\n");
								var jbuf = new uint8 [1024];
								JSMisc.read_hid_async.begin(jbuf, "info\n",  (o, r) => {
										var sz = JSMisc.read_hid_async.end(r);
										string jstr = (string)jbuf[:sz];
										MWPLog.message("Raw RC: %s", jstr);
										if(jstr.has_prefix("Channels: ")) {
											Mwp.nrc_chan = int.parse(jstr.substring(10));
											MWPLog.message(":DBG: Channels %d\n", Mwp.nrc_chan);
										}
										Mwp.rctimer.start();
										if(Mwp.conf.show_sticks != 1) {
											Sticks.create_sticks();
										}
									});
							}
						}
						Mwp.queue_cmd(Msp.Cmds.IDENT,null,0);
						Mwp.run_queue();
					}
				} else {
					Mwp.serstate = Mwp.SERSTATE.TELEM;
				}
			}
		} else {
			string estr = null;
			Mwp.msp.get_error_message(out estr);
			var wb0 = new Utils.Warning_box("""Unable to open serial device:
Error: <i>%s</i>

* Check that <u>%s</u> is available / connected.
* Please verify you are a member of the owning group, typically 'dialout' or 'uucp'""".printf(estr, serdev), 0);

			wb0.present();
		}
		Mwp.reboot_status();
	}

    private void connect_serial() {
		var serdev = Mwp.dev_entry.text;
		bool ostat = false;
		Mwp.serstate = Mwp.SERSTATE.NONE;
		Mwp.clear_sidebar(Mwp.msp);
		if(Radar.lookup_radar(serdev) || serdev == Mwp.forward_device) {
			var wb1 = new Utils.Warning_box("The selected device is assigned to a special function (radar / forwarding).\nPlease choose another device", 60);
			wb1.present();
			return;
		} else if (serdev.has_prefix("mqtt://") ||
				   serdev.has_prefix("ssl://") ||
				   serdev.has_prefix("mqtts://") ||
				   serdev.has_prefix("ws://") ||
				   serdev.has_prefix("wss://") ) {
#if MQTT
			Mwp.mqtt_available = ostat = mqtt.setup(serdev);
			Mwp.rawlog = false;
			Mwp.nopoll = true;
			Mwp.serstate = Mwp.SERSTATE.TELEM;
			serial_complete_setup(serdev, ostat);
#else
			new Utils.Warning_box("MQTT is not enabled in this build\nPlease see the wiki for more information\nhttps://github.com/stronnag/mwptools/wiki/mqtt---bulletgcss-telemetry\n", 60);
			return;
#endif
		} else {
			if (TelemTracker.ttrk.is_used(serdev)) {
				new Utils.Warning_box("The selected device is use for Telemetry Tracking\n", 60);
				return;
			}
			TelemTracker.ttrk.disable(serdev);
			MWPLog.message("Trying OS open for %s\n", serdev);
			Mwp.msp.open_async.begin(serdev, Mwp.conf.baudrate, (obj,res) => {
					ostat = Mwp.msp.open_async.end(res);
					serial_complete_setup(serdev,ostat);
				});

		}
    }

	private void try_reopen(string devname) {
		Timeout.add(2000, () => {
				var serdev = Mwp.dev_entry.text.split(" ")[0];
				if (serdev != devname) {
					return true;
				}
				if (!Mwp.msp.available) {
					connect_serial();
				}
				return false;
			});
	}

	private void set_pmask_poller(MWSerial.PMask pmask) {
		if (pmask == MWSerial.PMask.AUTO || pmask == MWSerial.PMask.INAV) {
			if (!Mwp.zznopoll) {
				Mwp.nopoll = false; // FIXNOPOLL
			}
		} else {
			Mwp.xnopoll = Mwp.nopoll;
			Mwp.nopoll = true;
		}
		Mwp.msp.set_pmask(pmask);
		Mwp.msp.set_auto_mpm(pmask == MWSerial.PMask.AUTO);
	}
}
