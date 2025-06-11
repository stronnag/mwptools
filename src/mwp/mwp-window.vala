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

using Gtk;

public delegate void ActionFunc ();

namespace Mwp {
	MWPSettings conf;
	MwpCombox dev_combox;
	Gtk.Entry dev_entry;
	DevManager devman;
	public Mwp.Window window;
	public Panel.Box panelbox;
	public Adw.ToastOverlay toaster;
	public StrIntStore amis;
	double current_lat;
	double current_lon;
	TileUtils.Dialog msd;
	Measurer.Measure dmeasure;
	MwpNotify dtnotify;
	Gtk.Label sensor_sts[6];
	Craft craft;
	GeoZoneManager gzr;
	uint8 gzcnt;
	private Overlay? gzone;
	private GZEdit gzedit;
	private bool cleaned;

	public bool add_ovly_active;

	public void cleanup() {
		if (!cleaned) {
			cleaned =true;
			Mwp.stop_replayer();
			final_clean();
		}
	}

	private void final_clean() {
		TTS.stop_audio();
		if (inhibit_cookie != 0) {
			MwpIdle.uninhibit(inhibit_cookie);
		}
		if (MBus.svc != null)
			MBus.svc.quit();
		ProxyPids.killall();
	}


	[GtkTemplate (ui = "/org/stronnag/mwp/mwpmain.ui")]
	public class Window : Adw.ApplicationWindow {
		[GtkChild]
		internal unowned Adw.ToastOverlay toaster;
		[GtkChild]
		internal unowned Gtk.SpinButton zoomlevel;
		[GtkChild]
		internal unowned Gtk.Label poslabel;
		[GtkChild]
		internal unowned Gtk.DropDown mapdrop;
		[GtkChild]
		internal unowned Gtk.DropDown protodrop;
		[GtkChild]
		internal unowned Gtk.DropDown actmission;
		[GtkChild]
		internal unowned Gtk.Box devbox;
		[GtkChild]
		internal unowned Gtk.MenuButton button_menu;
		[GtkChild]
		internal unowned Gtk.ToggleButton wpeditbutton;
		[GtkChild]
		internal unowned Gtk.Button conbutton;
		[GtkChild]
		internal unowned Gtk.Label gpslab;
		[GtkChild]
		internal unowned Gtk.Label gyro_sts;
		[GtkChild]
		internal unowned Gtk.Label acc_sts;
		[GtkChild]
		internal unowned Gtk.Label baro_sts;
		[GtkChild]
		internal unowned Gtk.Label mag_sts;
		[GtkChild]
		internal unowned Gtk.Label gps_sts;
		[GtkChild]
		internal unowned Gtk.Label sonar_sts;
		[GtkChild]
		internal unowned Gtk.Label elapsedlab;
		[GtkChild]
		internal unowned Gtk.Label validatelab;
		[GtkChild]
		internal unowned Gtk.Image armed_spinner;
		[GtkChild]
		internal unowned Gtk.Label statusbar1;
		[GtkChild]
		internal unowned Gtk.Label typlab;
		[GtkChild]
		internal unowned Gtk.Label verlab;
		[GtkChild]
		internal unowned Gtk.Label mmode;
		[GtkChild]
		internal unowned Gtk.Label fmode;
		[GtkChild]
		internal unowned Gtk.CheckButton follow_button;
		[GtkChild]
		internal unowned Gtk.DropDown viewmode;
		[GtkChild]
		internal unowned Gtk.CheckButton logger_cb;
		[GtkChild]
		internal unowned Gtk.CheckButton audio_cb;
		[GtkChild]
		internal unowned Gtk.Button arm_warn;
		[GtkChild]
		internal unowned Gtk.ToggleButton show_sidebar_button;
		[GtkChild]
		internal unowned Gtk.ToggleButton map_annotations;

		private StrIntStore pis;
		private Mwp.GotoDialog posdialog;
		private Mwp.SCWindow scwindow;
		private CloseCheck close_check;

		public signal void armed_state(bool armed);
		public signal void status_change(uint8 lflags);

		public async bool checker() {
			bool ok = false;
			var am = new Adw.AlertDialog("MWP Message",  "Mission has uncommitted changes");
			am. set_body_use_markup (true);
			am.add_response ("continue", "Cancel");
			am.add_response ("ok", "Save");
			am.add_response ("cancel", "Don't Save");
			string s = yield am.choose(this, null);
			if(s == "cancel") {
				ok = true;
			} else if (s == "continue") {
				ok = false;
			} else {
				var fc = MissionManager.setup_save_mission_file_as();
				try {
					var fh = yield fc.save(this,null);
					var fn = fh.get_path ();
					MissionManager.last_file = fn;
					MissionManager.write_mission_file(fn, 0);
					ok = true;
				} catch (Error e) {
					print("Failed to save file: %s\n", e.message);
				}
			}
			return ok;
		}

		private void check_mission_clean(ActionFunc func) {
			if(!MissionManager.is_dirty) {
				func();
			} else {
				checker.begin((o,res) => {
						var ok = checker.end(res);
						if(ok) {
							func();
						}
					});
			}
		}

		public Window (Adw.Application app) {
            Object (application: app);
			mapdrop.factory = null;
			protodrop.factory = null;
			actmission.factory = null;

			Mwp.window = this;
			Mwp.toaster = toaster;

			var provider = new Gtk.CssProvider ();
			string cssfile = MWPUtils.find_conf_file("mwp.css");
			if(cssfile != null) {
				MWPLog.message("Loaded %s\n", cssfile);
				provider.load_from_file(File.new_for_path(cssfile));
				Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			}
			bool winit = false;
			ulong active_id = 0;
			active_id = this.notify["is-active"].connect(() => {
					if(!winit && this.is_active) {
						winit = Cli.main_window_ready();
						MWPLog.message("Main window activated %s\n", winit.to_string());
						this.disconnect (active_id);
					}
				});

			var builder = new Builder.from_resource ("/org/stronnag/mwp/mwpmenu.ui");
			var menubar = builder.get_object("menubar") as MenuModel;
			button_menu.menu_model = menubar;

			// behave like grownup menus ...
			button_menu.always_show_arrow = false;
			var popover = button_menu.popover as Gtk.PopoverMenu;
			popover.has_arrow = false;
#if !DARWIN
			popover.flags = Gtk.PopoverMenuFlags.NESTED;
#else
			if(Environment.get_variable("MWP_MAC_NO_NEST") == null) {
				popover.flags = Gtk.PopoverMenuFlags.NESTED;
			}
#endif
			setup_accels(app);
			setup_misc_controls();
			map_annotations.active = false;
			map_annotations.toggled.connect(() => {
					add_ovly_active = map_annotations.active;
					Gis.check_annotations();
			});

			close_check = CloseCheck.NONE;
			close_request.connect(() => {
					if (MissionManager.is_dirty && !(CloseCheck.MISSIONX in close_check)) {
						close_check |= CloseCheck.MISSION;
					}
					if(msp != null && msp.available) {
						close_check |= CloseCheck.SERIAL;
					}
					if( (close_check & (CloseCheck.SERIAL|CloseCheck.MISSION)) == 0) {
						Mwp.cleanup();
						return false;
					} else {
						if(CloseCheck.MISSION in close_check)  {
							close_check |= CloseCheck.MISSIONX;
							close_check &= ~CloseCheck.MISSION;
							checker.begin((o,res) => {
									var ok = checker.end(res);
									if(ok) {
										close();
									} else {
										close_check -= CloseCheck.MISSIONX;
									}
								});
						} else if(CloseCheck.SERIAL in close_check) {
							msp.close_async.begin((o,r) => {
									msp.close_async.end(r);
									close_check &= ~CloseCheck.SERIAL;
									close();
								});
						}
						return true;
					}
				});

			armed_state.connect((s) => {
					s = !s;
					if(conf.armed_msp_placebo) {
						MWPLog.message("Armed changed MSP menus %s\n", s.to_string());
						set_mission_menus(s);
					}
					update_state();
					reboot_status();
				});

			init_basics();

			setup_terminal_reboot();
			follow_button.active = conf.autofollow;
			show_window();
		}

		private void show_locale() {
			var ulocale = UserLocale.get_name();
			char latbuf[16];
			char lonbuf[16];
			var lat = Mwp.conf.latitude;
			var lon = Mwp.conf.longitude;
			MWPLog.message("Locale: %s (%s %s / %.1f %.1f)\n", ulocale, lat.format(latbuf, "%.1f"), lon.format(lonbuf, "%.1f"), lat, lon);
		}

		private void init_basics() {
			use_rc = MspRC.OFF;
			conf = new MWPSettings();
			if(conf.uilang == "en") {
				Intl.setlocale(LocaleCategory.NUMERIC, "C");
			}
			show_locale();
			var msprcact = new GLib.SimpleAction.stateful ("usemsprc", null, false);
			msprcact.change_state.connect((s) => {
					var b = s.get_boolean();
					msprcact.set_state (s);
					if(b) {
						Mwp.use_rc |= Mwp.MspRC.ACT|Mwp.MspRC.GET|Mwp.MspRC.SET;
						Mwp.start_raw_rc_timer();
						if(msp.available && Mwp.conf.show_sticks != 1) {
							Sticks.create_sticks();
						}
					} else {
						Mwp.use_rc &= ~(Mwp.MspRC.ACT|Mwp.MspRC.GET|Mwp.MspRC.SET);
						if(msp.available && Mwp.conf.show_sticks != 1) {
							Sticks.done();
						}
					}
					MWPLog.message(":DBG: msprc action set to %s, use_rc=%x\n", b.to_string(), Mwp.use_rc);
				});
			window.add_action(msprcact);

			if(Misc.is_msprc_enabled()) {
				string dplx = Mwp.conf.msprc_full_duplex ? "full" : "half";
				MWPLog.message("MSP_SET_RAW_RC / HID enabled, %s duplex\n", dplx);
				msprcact.set_state (true);
				Mwp.use_rc |= Mwp.MspRC.ACT;
			}

			// conf.changed["msprc-enabled"].connect(() => {
			//		MWPLog.message(":DBG: msprc enabled %s\n", conf.msprc_enabled.to_string());
			//	});

			TelemTracker.init();
			Radar.init();
			devman = new DevManager(conf.bluez_disco);
			devman.device_added.connect((dd) => {
					string s = devname_for_dd(dd);
					if(dev_is_bt(dd) || Mwp.msp.available)
						append_combo(dev_combox, s);
					else
						prepend_combo(dev_combox, s);
				});
			devman.device_removed.connect((s) => {
					remove_combo(dev_combox,s);
				});
			build_serial_combo();
			Places.get_places();
			posdialog = new Mwp.GotoDialog();
			scwindow = new Mwp.SCWindow();
			GstDev.init();

			conbutton.clicked.connect(() => {
					Msp.handle_connect();
				});

			logger_cb.toggled.connect (() => {
					if (logger_cb.active) {
						Logger.start(conf.logsavepath, vname);
						if(armed != 0) {
							string devnam = null;
							if(msp.available) {
								devnam = dev_entry.text;
							}
							Logger.fcinfo(MissionManager.last_file,vi,capability,profile, null,
										  vname, devnam, boxids);
							if(gzone != null) {
								Logger.logstring("geozone", gzr.to_string());
							}
						}
					} else {
						Logger.stop();
					}
            });

			sensor_sts[0] = gyro_sts;
			sensor_sts[1] = acc_sts;
			sensor_sts[2] = baro_sts;
			sensor_sts[3] = mag_sts;
			sensor_sts[4] = gps_sts;
			sensor_sts[5] = sonar_sts;
			init_gps_flash();
		}

		private void show_window() {

			ProxyPids.init();
			DemManager.init();

			Gis.init();
			Gis.map.viewport.notify["zoom-level"].connect(() => {
					var val = (int)Gis.map.viewport.zoom_level;
					var zval = (int)zoomlevel.value;
					if (val != zval)
						zoomlevel.value = (int)val;
            });

			zoomlevel.value_changed.connect(()=> {
					Gis.map.viewport.zoom_level = zoomlevel.value;
				});


			wpeditbutton.clicked.connect(() => {
					if(wpeditbutton.active) {
						if (HomePoint.hidden()) {
							double clat, clon;
							MapUtils.get_centre_location(out clat, out clon);
							HomePoint.set_home(clat, clon);
						}
					} else {
						if(MissionManager.msx.length==0) {
							HomePoint.try_hide();
						}
					}
				});

			arm_warn.clicked.connect(() => {
					show_arm_status();
				});

			var evtcm = new Gtk.EventControllerMotion();
			Gis.map.add_controller(evtcm);

			evtcm.motion.connect((x,y) => {
					Gis.map.viewport.widget_coords_to_location(Gis.base_layer, x, y,
															   out Mwp.current_lat,
															   out Mwp.current_lon);
					set_pos_label(Mwp.current_lat, Mwp.current_lon);
				});


			double _sx = 0;
			double _sy = 0;
			var gestd = new Gtk.GestureDrag();
			Gis.map.add_controller(gestd);
			gestd.drag_begin.connect((x,y) => {
					_sx = x;
					_sy = y;
				});

			gestd.drag_end.connect((x,y) => {
					var rng = (MwpScreen.has_touch_screen()) ? 4 : 2;
					if(Math.fabs(x) < rng && Math.fabs(y) < rng) {
						double lat, lon;
						if (wpeditbutton.active) {
							Gis.map.viewport.widget_coords_to_location(Gis.base_layer, _sx, _sy, out lat, out lon);
							MissionManager.insert_new(lat, lon);

						} else if(Measurer.active) {
							Gis.map.viewport.widget_coords_to_location(Gis.base_layer, _sx, _sy, out lat, out lon);
							dmeasure.add_point(lat, lon);
						}
					}
				});

			Battery.init();
			hwstatus[0] = 1; // Assume OK
			Msp.init();

			int fw,fh;
			Utils.check_pango_size(this, "Monospace", "_00:00:00.0N 000.00.00.0W_", out fw, out fh);
			// Must match 150% scaling in flight_view
            //			MWPLog.message(":DBG: FW0 %s, panetype %s, pane_width %s\n", fw0.to_string(),  conf.pane_type.to_string(), conf.p_pane_width.to_string());
			fw = 2+(150*fw)/100;

			var pane_type = conf.pane_type;
			if(conf.pane_type == 0) {
#if DARWIN
                if(pane_type == 0) {
                    pane_type = 1;
                }
                if(pane_type == 1) {
                    int mfact=128;
                    var mfe = Environment.get_variable("MWP_MAC_FACTOR");
                    if (mfe != null) {
                        mfact = int.parse(mfe);
                    }
                    fw = fw*mfact/100;
                    //                    MWPLog.message(":DBG: MACOS width %d\n", fw);
                }
#else
				pane_type = 1;
#endif
			}

			panelbox = new Panel.Box();
			if(pane_type == 1) {
				Adw.OverlaySplitView split_view = new 	Adw.OverlaySplitView();
				split_view.vexpand = true;
				split_view.sidebar_position = Gtk.PackType.END;
				toaster.set_child(split_view);
				show_sidebar_button.clicked.connect(() => {
						split_view.show_sidebar = show_sidebar_button.active;
					});
				split_view.sidebar_width_unit = Adw.LengthUnit.SP;
				split_view.min_sidebar_width = fw;
				split_view.content = Gis.overlay;
				split_view.sidebar = panelbox;
			} else {
				Gtk.Paned pane = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
				pane.set_start_child(Gis.overlay);
				pane.set_end_child(panelbox);
				pane.wide_handle = true;
				if (conf.p_pane_width > 0) {
					fw = conf.p_pane_width;
				}
				pane.position = window.default_width - fw;
				pane.shrink_end_child = false;
				pane.resize_end_child = false;
				toaster.set_child(pane);
				show_sidebar_button.clicked.connect(() => {
						pane.end_child.visible  = show_sidebar_button.active;
					});
				{
					var w = pane.get_first_child();
					while (w != null) {
						var s = w.get_type().name();
						if (s == "GtkPanedHandle") {
							var pevtck = new Gtk.EventControllerMotion();
							w.add_controller(pevtck);
							pevtck.leave.connect(() => {
									var ww = window.get_width();
									conf.p_pane_width = ww - pane.position;
									MWPLog.message(":DBG: leave paned ww=%d ppos=%d pw=%d\n",
												   ww, pane.position, conf.p_pane_width);
								});
							break;
						}
						w = w.get_next_sibling();
					}
				}
			}

			Gis.setup_map_sources(mapdrop);
			FWPlot.init();
			MissionManager.init();
			Safehome.manager = new SafeHomeDialog();

			dtnotify = new MwpNotify();
			Cli.handle_options();
			craft = new Craft();
			DND.init();
			GCS.init();
			Odo.init();
			gzr = new GeoZoneManager();
			gzedit = new GZEdit();
			set_initial_states();
#if !LINUX
			var swatcher = new SerialWatcher();
			swatcher.run();
#endif
			Radar.init_readers();
		}

		public void update_state() {
			bool mstate = false;
			bool wpstate = false;
			if(msp.available) {
				if(serstate == SERSTATE.POLLER) {
					mstate = (msp.td.state.ltmstate ==  Msp.Ltm.POSHOLD);
					wpstate = (msp.td.state.ltmstate ==  Msp.Ltm.WAYPOINTS);
				}
				//				MWPLog.message(":DBG: window state %d (%s)\n", msp.td.state.ltmstate, wpstate.to_string());
				MwpMenu.set_menu_state(Mwp.window, "followme", mstate);

				if (conf.armed_msp_placebo) {
					MwpMenu.set_menu_state(Mwp.window, "upload-mission", !wpstate);
				}
			}
		}

		private void set_initial_states() {
			set_mission_menus(false);
			reboot_status();
			set_replay_menus(true);
			string []opts={"stop-replay", "kml-remove", "gz-save", "gz-kml", "gz-clear", "gz-check"};
			foreach(var o in opts) {
				MwpMenu.set_menu_state(Mwp.window, o, false);
			}
		}

		private void setup_misc_controls() {
			pis = new StrIntStore();
			protodrop.set_model(pis.model);
			protodrop.set_factory(pis.factory);
			pis.append(new StrIntItem("Auto", MWSerial.PMask.AUTO));
			pis.append(new StrIntItem("INAV", MWSerial.PMask.INAV));
			pis.append(new StrIntItem("S.Port", MWSerial.PMask.SPORT));
			pis.append(new StrIntItem("CRSF", MWSerial.PMask.CRSF));
			pis.append(new StrIntItem("MPM", MWSerial.PMask.MPM));

			amis = new StrIntStore();
			actmission.set_model(amis.model);
			actmission.set_factory(amis.factory);

			dev_combox = new MwpCombox();
			devbox.append(dev_combox);
			dev_combox.hexpand = true;
			dev_entry = dev_combox.entry;
			dev_entry.set_width_chars(16);

			var dg = new GLib.SimpleActionGroup();
			var saq = new GLib.SimpleAction("item", VariantType.STRING);
			saq.activate.connect((a) =>  {
					var s = a.get_string();
					dev_combox.set_text(s);
				});
			dg.add_action(saq);
			this.insert_action_group("menu", dg);

			viewmode.notify["selected"].connect(() =>  {
					conf.view_mode =  viewmode.get_selected();
					if (conf.view_mode != 2) {
						Gis.map.viewport.rotation = 0;
					}
				});
		}

		private void launch_manual() {
			var ul = new Gtk.UriLauncher("https://stronnag.github.io/mwptools/");
			ul.launch.begin(null, null);
		}

		private void launch_posdialog() {
			posdialog.present();
		}

		private void launch_scwindow() {
			scwindow.present();
		}

		private void launch_safehomes() {
			Safehome.manager.display_ui();
		}

		private void launch_radar() {
			Radar.display();
		}

		private void launch_radar_devices() {
			var rdr = new Radar.Device.Dialog();
			rdr.present();
		}

		private void launch_bbl() {
			BBL.replay_bbl(null);
		}

		private void launch_etx() {
			ETX.replay_etx(null);
		}

		private void launch_raw() {
			Raw.replay_raw(null);
		}

		private void launch_json() {
			Mwpjs.replay_js(null);
		}

		private void set_def_loc() {
			double clat, clon;
			MapUtils.get_centre_location(out clat, out clon);
			conf.latitude = clat;
			conf.longitude = clon;
			conf.zoom = (uint)Gis.map.viewport.zoom_level;
		}

		private void get_location() {
			Clip.get_location(false);
		}
		private void fmt_get_location() {
			Clip.get_location(true);
		}

		private void mapseed() {
			Mwp.msd = new TileUtils.Dialog();
			msd.run_seeder();
		}

		private void start_measurer() {
			if (Measurer.active == false) {
				Mwp.dmeasure = new Measurer.Measure();
				Mwp.dmeasure.run();
			}
		}

		private void show_ttracker() {
			TelemTracker.ttrk.show_dialog();
		}

		private void show_odo() {
			Odo.view.unhide();
		}

		private void stop_replay() {
			Mwp.stop_replayer();
		}

		private void do_hard_reset() {
			 hard_display_reset(false);
		}

		private void do_mission_clear() {
			hard_mission_clear();
		}

		private void do_mission_upload() {
			upload_mm(MissionManager.mdx, WPDL.GETINFO|WPDL.SAVE_FWA);
		}

		private void do_missions_upload() {
			upload_mm(-1, WPDL.GETINFO|WPDL.SAVE_FWA|WPDL.SET_ACTIVE);
		}

		private void restore_mission() {
			uint8 zb[1]={0};
			queue_cmd(Msp.Cmds.WP_MISSION_LOAD, zb, 1);
		}

		private void store_mission() {
			upload_mm(-1, WPDL.SAVE_EEPROM|WPDL.SET_ACTIVE);
		}

		private void do_gz_save() {
			GZUtils.save_dialog(false);
		}

		private void do_gz_kml() {
			GZUtils.save_dialog(true);
		}

		private void do_gz_edit() {
			if(gzone == null) {
				gzone = new Overlay();
			}
			set_gzsave_state(true);
			gzedit.edit(gzone);
		}

		private void do_gz_clear() {
			if(gzone!=null) {
				gzedit.clear();
				gzone.remove();
				gzone = null;
			}
			gzr.reset();
			set_gzsave_state(false);
		}

		private void do_gz_dl() {
			gzedit.clear();
			gzr.reset();
			pause_poller(SERSTATE.MISC_BULK);
			queue_gzone(0);
		}

		private void do_gz_check() {
			var s = gzr.validate_shapes("Zones fail validation", "Zones validate");
			var wb6 = new Utils.Warning_box(s);
			wb6.present();
		}

		private void gz_upload_dialog() {
			var warnmsg = "Uploading Geozones requires that the FC be rebooted in order for the FC to reevaluate the Geozones.\n\nClick OK to upload and reboot";
			var am = new Adw.AlertDialog("Reboot required",  warnmsg);
			am.add_response ("cancel", "Cancel");
			am.add_response ("ok", "OK");
			am.set_close_response ("cancel");
			am.response.connect((s) => {
					if (s == "ok") {
						gzcnt = 0;
						pause_poller(SERSTATE.MISC_BULK);
						MWPLog.message("Geozone upload started\n");
						var mbuf = gzr.encode_zone(gzcnt);
						queue_cmd(Msp.Cmds.SET_GEOZONE, mbuf, mbuf.length);
					}
					am.close();
				});
			am.present(Mwp.window);
		}

		private void do_gz_ul() {
			var s = gzr.validate_shapes("Upload Cancelled");
			if (s.length == 0) {
				gz_upload_dialog();
			} else {
				var wb7 = new Utils.Warning_box(s);
				wb7.present();
			}
		}

		private void test_audio() {
			Audio.play_alarm_sound(MWPAlert.GENERAL);
			TTS.say(TTS.Vox.AUDIO_TEST);
		}

		private void run_mwpset() {
			var subp = new ProcessLauncher();
			subp.run_argv({"mwpset"}, 0);
			subp.complete.connect(() => {});
		}

		private void run_prefs() {
			var prefs = new Prefs.Window();
			prefs.present();
			prefs.run();
		}

		private void load_mission() {
			check_mission_clean(MissionManager.load_mission_file);
		}

		private void append_mission() {
			check_mission_clean(MissionManager.append_mission_file);
		}

		private void do_download_mission() {
			check_mission_clean(download_mission);
		}

		private void run_area_planner() {
			check_mission_clean(area_planner);
		}

		private void launch_vidwin() {
			VideoMan.load_v4l2_video();
		}

		private void area_planner() {
			do_mission_clear();
			var s = new Survey.Dialog();
			s.present();
			s.close_request.connect(() => {
					s.cleanup();
					return false;
				});
		}

		private void show_gps_stats() {
			var g = new GPSStats.Window();
			g.present();
		}

		private void do_assist() {
			var a = Assist.Window.instance();
			a.init();
			a.present();
		}

		private void do_msprc() {
			var m = new Msprc.Window();
			m.present();
		}

		private void do_cli_open() {
			IChooser.Filter []ifm = { {"CLI File", {"txt"}}, };
			var fc = IChooser.chooser(Mwp.conf.missionpath, ifm);
			fc.title = "Open CLI File";
			fc.modal = true;
			fc.open.begin (Mwp.window, null, (o,r) => {
					try {
						var file = fc.open.end(r);
						Mwp.clifile = file.get_path ();
						Cli.parse_cli_files();
					} catch (Error e) {
						MWPLog.message("Declined to open mission file: %s\n", e.message);
					}
				});
		}

		private void do_trackdump() {
			if(msp != null) {
				msp.td.to_log(0xff);
			}
		}

		private void do_show_channels() {
			if(nrc_chan > 0 &&  (Mwp.use_rc & (Mwp.MspRC.ACT|Mwp.MspRC.SET)) == (Mwp.MspRC.ACT|Mwp.MspRC.SET)) {
				Chans.show_window();
			}
		}

		private void setup_accels(Adw.Application app) {
			GLib.ActionEntry[] winacts = {
				{"quit",  Mwp.window.close},
				{"about",  About.show_about},
				{"centre-on",  launch_posdialog},
				{"keys", launch_scwindow},
				{"manual", launch_manual},
				{"kml-load", Kml.load_file},
				{"kml-remove", Kml.remove_kml},
				{"radar-view", launch_radar},
				{"radar-devices", launch_radar_devices},
				{"mission-open", load_mission},
				{"mission-append", append_mission},
				{"clifile", do_cli_open},
				{"mission-save", MissionManager.save_mission_file},
				{"mission-save-as", MissionManager.save_mission_file_as},
				{"mman", MissionManager.mm_manager},
				{"safe-homes", launch_safehomes},
				{"recentre", MissionManager.zoom_to_mission},
				{"defloc", set_def_loc},
				{"cliploc", get_location},
				{"fmtcliploc", fmt_get_location},
				{"seed-map", mapseed},
				{"dmeasure", start_measurer},
				{"replay-bb-log", launch_bbl},
				{"replay-etx-log", launch_etx},
				{"replay-raw-log", launch_raw},
				{"replay-mwp-log", launch_json},
				{"vstream", launch_vidwin},
				{"ttrack-view", show_ttracker},
				{"flight-stats", show_odo},
				{"stop-replay", stop_replay},
				{"hardreset", do_hard_reset},
				{"clearmission", do_mission_clear},
				{"pausereplay", do_replay_pause},
				{"upload-mission", do_mission_upload},
				{"upload-missions",do_missions_upload},
				{"download-mission", do_download_mission},
				{"restore-mission", restore_mission},
				{"store-mission", store_mission},
				{"gz-load", GZUtils.load_dialog},
				{"gz-save", do_gz_save},
				{"gz-kml", do_gz_kml},
				{"gz-edit", do_gz_edit},
				{"gz-clear", do_gz_clear},
				{"gz-dl", do_gz_dl},
				{"gz-ul", do_gz_ul},
				{"gz-check", do_gz_check},
				{"followme", Follow.run},
				{"audio-test", test_audio},
				{"prefs", run_prefs},
				{"mwpset", run_mwpset},
				{"toggle-fs", toggle_fs},
				{"go-base", go_base},
				{"go-home", go_home},
				{"toggle-home", toggle_home},
				{"handle-connect", Msp.handle_connect},
				{"show-serial-stats", show_serial_stats},
				{"areap", run_area_planner},
				{"gps-stats", show_gps_stats},
				{"vlegend", Gis.toggle_vlegend},
				{"assistnow", do_assist},
				{"trackdump", do_trackdump},
				{"msprc", do_msprc},
				{"show-channels", do_show_channels},
			};

            add_action_entries (winacts, this);

			var lsaq = new GLib.SimpleAction.stateful ("locicon", null, false);
			lsaq.change_state.connect((s) => {
					var b = s.get_boolean();
					double clat, clon;
					MapUtils.get_centre_location(out clat, out clon);
					GCS.default_location(clat, clon);
					GCS.set_visible(b);
					lsaq.set_state (s);
				});
			window.add_action(lsaq);

			app.set_accels_for_action ("win.vlegend", { "<primary>v" });
			app.set_accels_for_action ("win.about", { "<primary>a" });
			app.set_accels_for_action ("win.cliploc", { "<primary>l" });
			app.set_accels_for_action ("win.fmtcliploc", { "<primary><shift>l" });
			app.set_accels_for_action ("win.mission-open", { "<primary>m" });
			app.set_accels_for_action ("win.dmeasure", { "<primary>d" });
			app.set_accels_for_action ("win.hardreset", { "<primary>i" });
			app.set_accels_for_action ("win.clearmission", { "<primary>c" });
			app.set_accels_for_action ("win.pausereplay", { "space" });
			app.set_accels_for_action ("win.go-base", { "<primary>b" });
			app.set_accels_for_action ("win.go-home", { "<primary>h" });
			app.set_accels_for_action ("win.toggle-home", { "<primary><shift>h" });
			app.set_accels_for_action ("win.toggle-fs", { "F11" });
			app.set_accels_for_action ("win.handle-connect", { "<primary><shift>c" });
			app.set_accels_for_action ("win.show-serial-stats", { "<primary>s" });
			app.set_accels_for_action ("win.upload-mission", { "<primary>u" });
			app.set_accels_for_action ("win.upload-missions", { "<primary><shift>u" });
			app.set_accels_for_action ("win.restore-mission", { "<primary>r" });
			app.set_accels_for_action ("win.store-mission", { "<primary>e" });
			app.set_accels_for_action ("win.prefs", { "<primary>p" });
			app.set_accels_for_action ("win.terminal", { "<shift>t" });
			app.set_accels_for_action ("win.reboot", { "<primary>exclam" });
			app.set_accels_for_action ("win.flight-stats", { "<primary><shift>a" });
			app.set_accels_for_action ("win.quit", { "<primary>q" });

			MwpMenu.set_menu_state(Mwp.window, "followme", false);
			if(Environment.get_variable("MWP_FOLLOW_ME") != null) {
				MwpMenu.set_menu_state(Mwp.window, "followme", true);
			}

			var fn = MWPUtils.find_conf_file("accels");
			if (fn != null) {
				//var aplist = app.list_action_descriptions();
				if(fn != null) {
					var fs = FileStream.open(fn, "r");
					if (fs != null) {
						string line;
						while ((line = fs.read_line()) != null) {
							line = line.strip();
							if(line.has_prefix("#")) {
								continue;
							}
							var parts = line.split(" ");
							if (parts.length == 2) {
								var act = parts[0];
								if(!act.has_prefix("win.")) {
									act = "win.%s".printf(act);
								}
								var accel = parts[1];
								uint u1,u2;
								if (Gtk.accelerator_parse (accel,out u1, out u2)) {
									app.set_accels_for_action(act, {accel});
								}
							}
						}
					}
				}
			}
#if WINDOWS
        MwpMenu.set_menu_state(Mwp.window, "terminal", false);
#endif
		}
	}

	private void go_base() {
		MapUtils.centre_on(Mwp.conf.latitude, Mwp.conf.longitude);
	}
	private void go_home() {
		if(HomePoint.is_valid()) {
			MapUtils.centre_on(HomePoint.hp.latitude, HomePoint.hp.longitude);
		} else toggle_home();
	}
	private void toggle_home() {
		if(HomePoint.is_valid()) {
			HomePoint.try_hide();
		} else {
			double clat, clon;
			MapUtils.get_centre_location(out clat, out clon);
			HomePoint.set_home(clat, clon);
		}
	}

	private void toggle_fs() {
		if(window.maximized) {
			window.unmaximize();
		} else {
			window.maximize();
		}
	}

	private void do_replay_pause() {
		if(replayer != Player.NONE) {
			handle_replay_pause();
		}
	}

	public void set_zoom_range(double zmin, double zmax) {
		window.zoomlevel.adjustment.set_lower(zmin);
		window.zoomlevel.adjustment.set_upper(zmax);
	}

	public void set_pos_label(double lat, double lon) {
		if (!conf.pos_is_centre) {
			Mwp.window.poslabel.label = PosFormat.pos(lat, lon, Mwp.conf.dms, true);
		}
	}

	public bool set_zoom_sanely(double zval) {
        var sane = true;
        var mmax = Gis.map.viewport.get_max_zoom_level();
        var mmin = Gis.map.viewport.get_min_zoom_level();
        if (zval > mmax) {
            sane= false;
            zval = mmax;
        } else if (zval < mmin) {
            sane = false;
            zval = mmin;
        }
		double clat, clon;
		MapUtils.get_centre_location(out clat, out clon);
		Gis.map.go_to_full(clat, clon, zval);
		return sane;
    }

	public Adw.Toast add_toast_text(string s, uint tmo=5) {
		var t = new Adw.Toast(s);
		t.set_timeout(tmo);
		Mwp.window.toaster.add_toast(t);
		return t;
	}

    public void clear_sensor_array() {
        xs_state = 0;
        for(int i = 0; i < 6; i++)
            sensor_sts[i].label = " ";
    }

    public void reboot_status() {
		var state = ((Mwp.msp != null && Mwp.msp.available && Mwp.armed == 0));
		MwpMenu.set_menu_state(Mwp.window, "reboot", state);
#if UNIX
        MwpMenu.set_menu_state(Mwp.window, "terminal", state);
#endif
    }

    private void set_replay_menus(bool state) {
		const string [] ms = {
			"replay-mwp-log",
			"replay-bb-log",
			"replay-etx-log",
			"replay-raw-log"
		};
        var n = 0;
        foreach(var s in ms) {
            var istate = state;
			if( ((n == 1) && (x_fl2ltm == false))  ||
                ((n == 2) && (x_otxlog == false)) ||
                ((n == 3) && x_rawreplay == false)) {
                istate = false;
			}
            MwpMenu.set_menu_state(Mwp.window, s, istate);
            n++;
        }
		MwpMenu.set_menu_state(Mwp.window, "msprc", state);
    }

	private void set_mission_menus(bool state) {
        const string[] ms0 = {
			"store-mission",
			"restore-mission",
			"upload-mission",
			"download-mission",
			"mission-info",
		};
        foreach(var s in ms0) {
            MwpMenu.set_menu_state(Mwp.window, s, state);
		}
		if(Mwp.vi.fc_vers == 0 || Mwp.vi.fc_vers >= Mwp.FCVERS.hasWP_V4) {
			MwpMenu.set_menu_state(Mwp.window, "upload-missions", state);
		}
		if((feature_mask & Msp.Feature.GEOZONE) == 0) {
			state = false;
		}
		MwpMenu.set_menu_state(Mwp.window, "gz-dl", state);
		MwpMenu.set_menu_state(Mwp.window, "gz-ul", state);
	}

	void show_arm_status() {
		StringBuilder sb = new StringBuilder();
		if((xarm_flags & ~(ARMFLAGS.ARMED|ARMFLAGS.WAS_EVER_ARMED)) != 0) {
			sb.append("<b>Arm Status</b>\n");
			string arm_msg = get_arm_fail(xarm_flags,'\n');
			sb.append(arm_msg);
		}
		if(hwstatus[0] == 0) {
			sb.append("<b>Hardware Status</b>\n");
			for(var i = 0; i < 8; i++) {
				uint ihs = hwstatus[i+1];
				string shs = (ihs < health_states.length) ?
					health_states[ihs] : "*broken*";
				sb.append_printf("%s : %s\n", sensor_names[i], shs);
			}
		}
		var pop = new Gtk.Popover();
		Gtk.Label label = new Gtk.Label(sb.str);
		label.set_use_markup (true);
		pop.set_child(label);
		pop.set_parent(Mwp.window.arm_warn);
        pop.position = Gtk.PositionType.BOTTOM;
        pop.set_offset(0, 10);
		pop.set_has_arrow(true);
        pop.set_autohide(true);
		pop.popup();
	}

	private void set_gzsave_state(bool val) {
		MwpMenu.set_menu_state(Mwp.window, "gz-save", val);
		MwpMenu.set_menu_state(Mwp.window, "gz-kml", val);
		MwpMenu.set_menu_state(Mwp.window, "gz-clear", val);
		MwpMenu.set_menu_state(Mwp.window, "gz-check", val);
		//MwpMenu.set_menu_state(Mwp.window, "gz-edit", val);
	}
}
