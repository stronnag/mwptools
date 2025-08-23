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

public class SQLSlider : Gtk.Window {
	private Gtk.Button play_button;
	private Gtk.Button end_button;
	private Gtk.Button start_button;
	private Gtk.Scale slider;
	private Gtk.Box vbox;
	private bool pstate;
	private SQLPlayer sp;
	private GLib.Menu menu;
	private GLib.SimpleActionGroup dg;
	private Gtk.Label tlabel;
	private int smax;

	public SQLSlider(string fn, int idx) {
        Mwp.xlog = Mwp.conf.logarmed;
        //Mwp.xaudio = Mwp.conf.audioarmed;

		Mwp.conf.logarmed = false;
		//Mwp.conf.audioarmed = false;

		Mwp.craft.remove_all();
		sp = new SQLPlayer(/*dragq*/);
		sp.opendb(fn);

		smax = sp.init(idx) - 1;
		vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
		var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
		box.margin_top = 2;
		box.margin_bottom = 2;
		box.margin_start = 2;
		box.margin_end = 2;

		title = "mwp Flightlog player";
		set_icon_name("mwp_icon");
		transient_for=Mwp.window;
		default_width = 640;
		var hb  = new Gtk.HeaderBar();
		set_titlebar(hb);
		play_button = new Gtk.Button.from_icon_name("media-playback-start");
		end_button = new Gtk.Button.from_icon_name("media-skip-forward");
		start_button = new Gtk.Button.from_icon_name("media-skip-backward");
		add_slider(smax);
		slider.set_increments(1, smax/20);
		pstate = false;
		box.append(vbox);
		set_child(box);
		box.vexpand=false;
		vbox.vexpand=false;
		this.vexpand = false;

		set_bg(this, "window {background: color-mix(in srgb, @window_bg_color 40%, transparent)  ;  color: @view_fg_color; border-radius: 12px 12px;}");
		set_bg(hb, "headerbar {background: rgba(0, 0, 0, 0.0);}");

		play_button.clicked.connect (() => {
				toggle_pstate();
			});

		start_button.clicked.connect (() => {
				pstate = true;
				toggle_pstate();
				sp.move_at(0);
			});

		end_button.clicked.connect (() => {
				pstate = true;
				toggle_pstate();
				var cpos = slider.get_value();
				var incr = (smax-cpos)/12.0;
				Idle.add(() => {
						cpos = double.min(smax, cpos + incr);
						sp.move_at((int)cpos);
						if (cpos >= smax)
							return false;
						return true;
					});

			});

		sp.newpos.connect((v) => {
				slider.set_value(v);
				var n = (int)Math.round(v);
				var tm = sp.get_timer_for(n);
				format_time(tm, n);
			});

		close_request.connect (() => {
				sp.stop();
				sp = null;
				return false;
			});

		if(SLG.mlist.length > 1) {
			var  mb = new Gtk.MenuButton();
			mb.icon_name = "open-menu-symbolic";
			hb.pack_start(mb);
			menu = new GLib.Menu();
			mb.menu_model = menu;
			dg = new GLib.SimpleActionGroup();
			foreach (var m in SLG.mlist) {
				menu_append(m, idx);
			}
			insert_action_group("meta", dg);
		}

		var dbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);

		Gtk.DropDown dd = new Gtk.DropDown.from_strings({"1", "2", "4", "8", "16", "32"});
		dbox.append(new Gtk.Label("Speed:"));
		dbox.append(dd);
		hb.pack_start(dbox);

		dd.notify["selected"].connect(() =>  {
				var k = dd.selected;
				var ml = (Gtk.StringList)dd.model;
				var tstr = ml.get_string(k);
				int speed = int.parse(tstr);
				sp.speed = speed;
			});

		tlabel = new Gtk.Label("");
		tlabel.use_markup = true;

		format_time(0,0);
		hb.pack_end(tlabel);

		if(SLG.speedup) {
			toggle_pstate();
		}
	}

	private void disable_item(int k) {
		var nm = menu.get_n_items();
		for(int j = 0; j < nm; j++) {
			var alabel = "item_%02d".printf(j);
			bool state = (j != k);
			var ac = dg.lookup_action(alabel) as SimpleAction;
			if (ac != null) {
				ac.set_enabled(state);
			}
		}
	}

	 private void menu_append(string s, int id) {
		 var jn = menu.get_n_items();
		 var alabel = "item_%02d".printf(jn);
		 var aq = new GLib.SimpleAction(alabel, null);

		 int oid = int.parse(s);

		 aq.activate.connect(() => {
				 disable_item(jn);
				 pstate = true;
				 toggle_pstate();
				 smax = sp.init(oid) - 1;
				 slider.set_value(0.0);
				 slider.set_range(0.0, smax);
				 slider.set_increments(1, smax/20);
				 if(SLG.speedup) {
					 toggle_pstate();
				 }
			 });
		 if(oid == id) {
			 aq.set_enabled(false);
		 }
		 dg.add_action(aq);
		 menu.append(s, "meta.%s".printf(alabel));
	 }

	private void toggle_pstate() {
		pstate = !pstate;
		if (pstate) {
			play_button.icon_name = "media-playback-pause";
		} else {
			play_button.icon_name = "media-playback-start";
		}
		sp.on_play(pstate);
	}

	private void add_slider(double smax) {
		slider = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0, smax, 1);
		slider.set_draw_value(Environment.get_variable("MWP_PREFER_XLOG") != null);
		slider.change_value.connect((stype, d) => {
				if(pstate) {
					toggle_pstate();
				}
				sp.move_at((int)Math.round(d));
				return true;
			});

		slider.value_changed.connect(() => {
				var v = slider.get_value();
				var n = (int)Math.round(v);
				var tm = sp.get_timer_for(n); // Round
				format_time(tm, n);
				if(v == smax) {
					if(pstate) {
						toggle_pstate();
					}
				}
			});

		slider.hexpand = true;

		var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
		hbox.append(play_button);
		hbox.append (slider);
		hbox.append(start_button);
		hbox.append(end_button);
		vbox.append(hbox);
	}

	private void set_bg(Gtk.Widget w, string css) {
		var provider = new Gtk.CssProvider();
		provider.load_from_data(css.data);
		var stylec = w.get_style_context();
		stylec.add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
	}

	private void format_time(int64 tm, int n) {
		int mins;
		int secs;
		int itm = (int)((tm + 500*1000)/(1000*1000));
		mins = (int)itm / 60;
		secs = (int)itm % 60;
		var pct = (n * 100) / smax;
		tlabel.label = "<tt>%03d:%02d %3d%%</tt>".printf(mins,secs,pct);
	}
}

public class SQLPlayer : Object {
	private int xstack;
	private int lstamp;
	private int nentry;
	private uint tid;
	private int startat;
	private SQL.Db db;
	private int idx;

	private SQL.TrackEntry[] trks;

	public int speed;
	public signal void newpos(int n);

	public  enum DrawMode {
		OFF,
		ON,
		FORCE
	}

	~SQLPlayer() {
		if (db != null) {
			db = null;
		}
		trks={};
		MWPLog.message("~SQLPlayer ... disarm %s (%d)\n", Msp.bb_disarm(Mwp.msp.td.state.reason), Mwp.msp.td.state.reason);
		Mwp.serstate = Mwp.SERSTATE.NONE;
		Mwp.replayer = Mwp.Player.NONE;
		Mwp.stack_size = xstack;
		Mwp.conf.logarmed = Mwp.xlog;
		//		Mwp.conf.audioarmed = Mwp.xaudio;
	}

	public SQLPlayer() {
		speed = 1;
		Mwp.window.close_request.connect(() => {
				db = null;
				return false;
			});
	}

	public void stop() {
		Sticks.done();
		if(tid != 0) {
			Source.remove(tid);
			tid = 0;
		}
		db.populate_odo(idx);
		Odo.view.populate(Odo.stats);
		db = null;
		Mwp.set_replay_menus(true);
	}

	public void opendb(string fn) {
		nentry = 0;
		xstack = Mwp.stack_size;
		db = new SQL.Db(fn);
	}

	private void move_fwd(int m, int n) {
		DrawMode draw = DrawMode.OFF;
		int jmod = (n+1-m) / 8;
		if (jmod < 8)
			jmod = 8;
		for(var j = m; j <= n; j++) {
			if ((j % jmod) == 0) {
				draw = DrawMode.FORCE;
				newpos(j);
			} else {
				draw = DrawMode.OFF;
			}
			display(trks[j], draw);
			startat = j;
		}
	}


	public int64 get_timer_for(int n) {
		if (n < 0) {
			n = 0;
		}
		if(n >= nentry) {
			n = nentry-1;
		}
		return trks[n].stamp;
	}


	public void move_at(int n) {
		if (n < 0) {
			//MWPLog.message("SQLLOG WARN Min N %d (%d, %d)\n", n, startat, nentry);
			n = 0;
		}
		if(n >= nentry) {
			//MWPLog.message("SQLLOG WARN Max N %d (%d, %d)\n", n, startat, nentry);
			n = nentry-1;
		}
		if (n <= startat) {
			Mwp.craft.remove_back(startat, n);
			startat = n;
		} else {
			var js = startat+1;
			move_fwd(js, n);
		}
		display(trks[n], DrawMode.FORCE);
		newpos(n);
	}

	public SQL.Meta [] get_metas() {
		SQL.Meta []ms;
		db.get_metas(out ms);
		return ms;
	}

	public int  init(int _idx) {
		idx = _idx;
		SQL.Meta m;
		var res = db.get_meta(idx, out m);
		lstamp = 0;
		tid = 0;
		nentry = db.get_log_count(idx);
		startat = 0;
		Mwp.armed = 0;
		Mwp.larmed = 0;
		Mwp.craft.new_craft (true);
		Mwp.clear_sidebar(Mwp.msp);
		Mwp.init_have_home();
		Mwp.init_state();

		if(SLG.useartefacts) {
			var sfwa = db.get_misc(idx, "climisc");
			if (sfwa != null) {
				Safehome.manager.load_string(sfwa, Mwp.sh_disp);
			}
			var msxml = db.get_misc(idx, "mission");
			if (msxml != null) {
				Mwp.hard_display_reset(true);
				var _msx = XmlIO.read_xml_string(msxml, true);
				if (_msx != null) {
					MissionManager.msx = _msx;
					MissionManager.mdx = 0;
					MissionManager.setup_mission_from_mm();
				}
			} else {
				var mfn = db.get_misc(idx, "mission-file");
				if (mfn != null) {
					Mwp.hard_display_reset(true);
					MissionManager.open_mission_file(mfn, false);
				} else {
					Mwp.hard_display_reset(false);
				}
			}

			var gzstr = db.get_misc(idx, "geozone");
			if (gzstr != null) {
				if(Mwp.gzone != null) {
					Mwp.set_gzsave_state(false);
					Mwp.gzone.remove();
					Mwp.gzone = null;
				}
				Mwp.gzr.from_string(gzstr);
				Mwp.gzone = Mwp.gzr.generate_overlay();
				Mwp.gzone.display();
			}
		}

		if(res) {
			Mwp.vname = m.name;
			Mwp.set_typlab();
			Mwp.window.verlab.label = m.firmware;
			Mwp.feature_mask = (uint32)m.features;
			Mwp.sensor = (uint16)m.sensors;
			Mwp.update_sensor_array();
			Mwp.msp.td.state.reason = m.disarm;
			if ((Mwp.feature_mask & Msp.Feature.GPS) == Msp.Feature.GPS) {
				Mwp.sflags |= Mwp.SPK.GPS;
			}
			if ((Mwp.feature_mask & Msp.Feature.VBAT) == Msp.Feature.VBAT) {
					Mwp.sflags |= Mwp.SPK.Volts;
			}
			if((Mwp.sensor & Msp.Sensors.BARO) == Msp.Sensors.BARO) {
				Mwp.sflags |= Mwp.SPK.BARO;
			} else if((Mwp.sensor & Msp.Sensors.GPS) == Msp.Sensors.GPS) {
				Mwp.sflags |= Mwp.SPK.ELEV;
			}
		}
		Mwp.stack_size = 0;
		Mwp.set_replay_menus(false);
		Mwp.serstate = Mwp.SERSTATE.NONE; // TELEM
		Mwp.replayer = Mwp.Player.SQL;
		Mwp.usemag = true;
		Odo.stats = {};
		Odo.view.clear_text();
		setup_odo();
		trks = new SQL.TrackEntry[nentry]{};
		db.get_log(idx, ref trks);

		display(trks[startat]);
		if (trks[startat].thr > 0) {
			if(Mwp.conf.show_sticks != 1) {
				Sticks.create_sticks();
			}
		}
		return nentry;
	}

	private void setup_odo() {
		db.populate_odo(idx);
		Odo.view.populate(Odo.stats);
		var smstr = db.get_misc(idx, "summary");
		if (smstr != null) {
			Odo.view.set_text(smstr);
		}
	}

	public void on_play(bool s) {
		if(s) {
			display(trks[startat]);
			get_next_entry();
		} else {
			if(tid != 0) {
				Source.remove(tid);
				tid = 0;
			}
		}
		//setup_odo();
	}

	public void get_next_entry() {
		if (startat < nentry-1) {
			uint et = (uint)((trks[startat+1].stamp - trks[startat].stamp)/1000);
			if(et >= 0) {
				tid = Timeout.add(et / speed, () => {
						tid = 0;
						startat++;
						display(trks[startat]);
						newpos(startat);
						get_next_entry();
						return false;
					});
			}
		}
	}

	private void display(SQL.TrackEntry t, DrawMode upd=DrawMode.ON) {
		if (Mwp.rebase.has_reloc()) {
			if (!Mwp.rebase.has_origin()) {
				Mwp.rebase.set_origin(t.hlat, t.hlon);
			}
			Mwp.rebase.relocate(ref t.hlat, ref t.hlon);
		}

		if(!Mwp.have_home) {
			Mwp.home_changed(t.hlat, t.hlon);
			Mwp.want_special |= Mwp.POSMODE.HOME;
			Mwp.process_pos_states(t.hlat, t.hlon, 0, "SQL Origin", -2);
		}

		if (Mwp.rebase.has_reloc()) {
			if (Mwp.rebase.has_origin()) {
				Mwp.rebase.relocate(ref t.lat,ref t.lon);
			}
		}

		int fvup = 0;
		var pdiff = Mwp.pos_diff(t.lat, t.lon, Mwp.msp.td.gps.lat, Mwp.msp.td.gps.lon);
		if (Mwp.PosDiff.LAT in pdiff || upd == DrawMode.FORCE) {
			Mwp.msp.td.gps.lat = t.lat;
			fvup |= FlightBox.Update.LAT;
		}
		if (Mwp.PosDiff.LON in pdiff || upd == DrawMode.FORCE) {
			Mwp.msp.td.gps.lon = t.lon;
			fvup |= FlightBox.Update.LON;
		}
		if(Math.fabs(Mwp.msp.td.alt.alt - t.alt) > 1.0 || upd == DrawMode.FORCE) {
			Mwp.msp.td.alt.alt = t.alt;
			fvup |= FlightBox.Update.ALT;
		}
		if(Math.fabs(Mwp.msp.td.gps.gspeed - t.spd) > 0.1 || upd == DrawMode.FORCE) {
			Mwp.msp.td.gps.gspeed = t.spd;
			fvup |= FlightBox.Update.SPEED;
		}
		if(Mwp.msp.td.gps.nsats != t.numsat || upd == DrawMode.FORCE) {
			Mwp.msp.td.gps.fix = (uint8)t.fix;
			Mwp.msp.td.gps.nsats = (uint8)t.numsat;
			Mwp.msp.td.gps.hdop = t.hdop/100.0;
			fvup |= FlightBox.Update.GPS;
		}

		bool fvg = false;
		if(Mwp.msp.td.gps.cog != t.cog || upd == DrawMode.FORCE) {
			Mwp.msp.td.gps.cog = t.cog;
			if (upd != DrawMode.OFF)
				Mwp.panelbox.update(Panel.View.DIRN, Direction.Update.COG);
			fvg = true;
		}
		var ival = Math.round(t.vrange);
		if(Math.fabs(Mwp.msp.td.comp.range -  ival) > 1.0 || upd == DrawMode.FORCE) {
			Mwp.msp.td.comp.range =  (int)ival;
			fvup |= FlightBox.Update.RANGE;
		}
		ival = Math.round(t.bearing);
		if(Math.fabs(Mwp.msp.td.comp.bearing - ival) > 1.0 || upd == DrawMode.FORCE) {
			Mwp.msp.td.comp.bearing =  (int)ival;
			fvup |= FlightBox.Update.BEARING;
		}

		bool fvh = (Math.fabs(Mwp.msp.td.atti.yaw - t.cse) > 1.0 || upd == DrawMode.FORCE);

		if (fvh) {
			Mwp.msp.td.atti.yaw = t.cse;
		}
		Mwp.mhead = (int16)t.cse;
		var vdiff = (t.roll != Atti._sx) || (t.pitch != Atti._sy);
		if(vdiff || upd == DrawMode.FORCE) {
			Atti._sx = t.roll;
			Atti._sy = t.pitch;
			Mwp.msp.td.atti.angx = t.roll;
			Mwp.msp.td.atti.angy = t.pitch;
			if (upd != DrawMode.OFF)
				Mwp.panelbox.update(Panel.View.AHI, AHI.Update.AHI);
		}
		if(fvh || upd == DrawMode.FORCE) {
			if (upd != DrawMode.OFF) {
				Mwp.panelbox.update(Panel.View.FVIEW, FlightBox.Update.YAW);
				Mwp.panelbox.update(Panel.View.DIRN, Direction.Update.YAW);
			}
		}
		if(upd == DrawMode.FORCE || ((fvh || fvg) && ((int16)t.windx != Mwp.msp.td.wind.w_x || (int16)t.windy != Mwp.msp.td.wind.w_y))) {
			Mwp.msp.td.wind.has_wind = true;
			Mwp.msp.td.wind.w_x = (int16)t.windx;
			Mwp.msp.td.wind.w_y = (int16)t.windy;
			if (upd != DrawMode.OFF) {
				Mwp.panelbox.update(Panel.View.WIND, WindEstimate.Update.ANY);
			}
		}

		int xrssi = t.rssi * 1023/100;
		if (xrssi != Mwp.msp.td.rssi.rssi || upd == DrawMode.FORCE) {
			Mwp.msp.td.rssi.rssi = xrssi;
			if (upd != DrawMode.OFF) {
				Mwp.panelbox.update(Panel.View.RSSI, RSSI.Update.RSSI);
			}
		}

		double dv;
		if(Mwp.calc_vario(t.alt, out dv) || upd == DrawMode.FORCE) {
			Mwp.msp.td.alt.vario = dv;
			if (upd != DrawMode.OFF) {
				Mwp.panelbox.update(Panel.View.VARIO, Vario.Update.VARIO);
			}
		}

		Mwp.check_heading(t.cog, (int)t.spd);

		process_status(t);

		var res = process_energy(t);
		if ( upd == DrawMode.FORCE) {
			res = (Voltage.Update.VOLTS|Voltage.Update.CURR);
		}
		if (res != 0) {
			if (upd != DrawMode.OFF) {
				Mwp.panelbox.update(Panel.View.VOLTS, res);
			}
		}

		Mwp.alert_broken_sensors((uint8)t.hwfail);

		if(fvup != 0) {
			if (Mwp.conf.alt_prefer_agl) {
				fvup = AGL.prefer_agl(fvup, ref Mwp.msp.td);
			}
			if (upd != DrawMode.OFF) {
				Mwp.panelbox.update(Panel.View.FVIEW, fvup);
			}
		}
		process_nav(t);
		Mwp.duration = (int)((t.stamp + (500*1000)) / (1000*1000));
		Mwp.update_pos_info(t.idx);
		if (upd != DrawMode.OFF) {
			Sticks.update(t.ail, t.ele, t.rud, t.thr);
		}
	}

	private void process_nav(SQL.TrackEntry t) {
		var ns =  MSP_NAV_STATUS();
		ns.nav_mode = (uint8)(t.navmode & 0xff);
		var extra = (uint8)((t.navmode >> 8) &0xff);
		ns.wp_number = (uint8)t.activewp;
		if (extra != 0) {
			ns.gps_mode	= extra & 0xf;
			ns.action = extra >> 4;
		} else {
			switch(t.fmode) {
			case Msp.Ltm.POSHOLD,Msp.Ltm.ALTHOLD:
				ns.gps_mode	= 1;
				break;
			case Msp.Ltm.RTH:
				ns.gps_mode	= 2;
				break;
			case Msp.Ltm.WAYPOINTS:
				ns.gps_mode	= 3;
				ns.action = 1;
				break;
			default:
				ns.gps_mode	= 0;
				break;
			}
		}
		Mwp.handle_n_frame(Mwp.msp, ns);
	}

	private int process_energy(SQL.TrackEntry t) {
		MSP_ANALOG2 an = MSP_ANALOG2();
		an.vbat = (uint16)(100*t.volts);
		an.mahdraw = (uint16)t.energy;
		an.amps = (uint16)(t.amps*100);
		return Battery.process_msp_analog(an);
	}

	private void process_status(SQL.TrackEntry t) {
		bool c_armed = true;
		uint64 mwflags = 0;
		uint8 ltmflags = 0;

		var failsafe = ((t.status & 2) == 2);
		ltmflags = (uint8)t.fmode;
		Mwp.msp.td.state.state = (uint8)t.status;
		Mwp.msp.td.state.ltmstate = ltmflags;
		string ls_state = "";

		if(Mwp.xfailsafe != failsafe) {
			if(failsafe) {
				MWPLog.message("Failsafe asserted %ds\n", Mwp.duration);
				Mwp.add_toast_text("FAILSAFE");
				TTS.say(TTS.Vox.FAILSAFE, true);
			} else {
				MWPLog.message("Failsafe cleared %ds\n", Mwp.duration);
			}
			Mwp.xfailsafe = failsafe;
		}

		Mwp.armed = (c_armed) ? 1 : 0;

		if(ltmflags == Msp.Ltm.ANGLE)
			mwflags |= Mwp.angle_mask;
		if(ltmflags == Msp.Ltm.HORIZON)
			mwflags |= Mwp.horz_mask;
		if(ltmflags == Msp.Ltm.POSHOLD)
			mwflags |= Mwp.ph_mask;
		if(ltmflags == Msp.Ltm.WAYPOINTS)
			mwflags |= Mwp.wp_mask;
		if(ltmflags == Msp.Ltm.RTH || ltmflags == Msp.Ltm.LAND)
			mwflags |= Mwp.rth_mask;
		else
			mwflags = Mwp.xbits; // don't know better


		Mwp.armed_processing(mwflags,"Sql");

		var xws = Mwp.want_special;
		var mchg = (ltmflags != Mwp.last_ltmf);
		if (mchg) {
			Mwp.window.update_state();
			if (ltmflags !=  Msp.Ltm.POSHOLD &&
				ltmflags !=  Msp.Ltm.WAYPOINTS &&
				ltmflags !=  Msp.Ltm.RTH &&
				ltmflags !=  Msp.Ltm.LAND) { // handled by NAV_STATUS
				TTS.say(TTS.Vox.LTM_MODE);
			}
			if(ltmflags == Msp.Ltm.POSHOLD) {
				Mwp.want_special |= Mwp.POSMODE.PH;
			} else if(ltmflags == Msp.Ltm.WAYPOINTS) {
				Mwp.want_special |= Mwp.POSMODE.WP;
				//if (NavStatus.nm_pts == 0 || NavStatus.nm_pts == 255)
				//	NavStatus.nm_pts = last_wp_pts; // FIXME
			} else if(ltmflags == Msp.Ltm.RTH) {
				Mwp.want_special |= Mwp.POSMODE.RTH;
			} else if(ltmflags == Msp.Ltm.ALTHOLD) {
				Mwp.want_special |= Mwp.POSMODE.ALTH;
			} else if(ltmflags == Msp.Ltm.CRUISE) {
				Mwp.want_special |= Mwp.POSMODE.CRUISE;
			} else if(ltmflags == Msp.Ltm.LAND) {
				Mwp.want_special |= Mwp.POSMODE.LAND;
			} else if (ltmflags == Msp.Ltm.UNDEFINED) {
				Mwp.want_special |= Mwp.POSMODE.UNDEF;
			} else if(ltmflags != Msp.Ltm.LAND) {
				if(Mwp.craft != null) {
					Mwp.craft.set_normal();
				}
			} else {
				MWPLog.message("::DBG:: Unknown LTM %d\n", ltmflags);
			}
			ls_state = Msp.ltm_mode(ltmflags);
			MWPLog.message("New LTM Mode %s (%d %d) %d %ds %f %f %x %x\n",
						   ls_state, ltmflags, Mwp.last_ltmf, Mwp.armed, Mwp.duration,
						   t.lat, t.lon, xws, Mwp.want_special);
			Mwp.window.fmode.set_label(ls_state);
			Mwp.last_ltmf = ltmflags;
			Logger.mode_flags();
		}
		if(Mwp.want_special != 0 /* && have_home*/) {
			Mwp.process_pos_states(t.lat, t.lon, 0, "Sql status", t.idx);
		}
	}
}