public class SQLSlider : Gtk.Window {
	private Gtk.Button play_button;
	private Gtk.Scale slider;
	private Gtk.Box vbox;
	private bool pstate;
	private SQLPlayer sp;

	public SQLSlider(string fn, int idx) {
		sp = new SQLPlayer();
		double smax = sp.init(fn, idx);
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
		play_button = new Gtk.Button.from_icon_name ("media-playback-start");
		add_slider(smax);
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

		sp.newpos.connect((v) => {
				slider.set_value(v);
			});

		close_request.connect (() => {
				sp.stop();
				return false;
			});

		if(SLG.speedup) {
			toggle_pstate();
		}
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
		slider.set_draw_value(false);
		slider.change_value.connect((stype, d) => {
				slider.set_value(d);
				if(pstate) {
					toggle_pstate();
				}
				sp.add_queue((int)(d+0.5));
				return true;
			});
		slider.hexpand = true;

		var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
		hbox.append(play_button);
		hbox.append (slider);
		vbox.append(hbox);
	}

	private void set_bg(Gtk.Widget w, string css) {
		var provider = new Gtk.CssProvider();
		provider.load_from_data(css.data);
		var stylec = w.get_style_context();
		stylec.add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
	}
}


public class SQLPlayer : Object {
	private int xstack;
	private int lstamp;
	private int nentry;
	private uint tid;
	private int startat;
	private SQL.Db d;
	private int idx;

	public AsyncQueue<int?> dragq;
	public signal void newpos(int n);

	~SQLPlayer() {
		MWPLog.message("~SQLPlayer ... \n");
		Mwp.serstate = Mwp.SERSTATE.NONE;
		Mwp.replayer = Mwp.Player.NONE;
	}

	public void stop() {
		if(tid != 0) {
			Source.remove(tid);
			tid = 0;
		}
		dragq.push(-1);
		d = null;
		Mwp.set_replay_menus(true);
	}

	public void add_queue(int n) {
		var k = n;
		dragq.push(k);
	}

	public double init(string fn, int _idx) {
		idx = _idx;
		nentry = 0;
		d = new SQL.Db(fn);
		if (d != null) {
			dragq = new  AsyncQueue<int?>();
			xstack = Mwp.stack_size;
			lstamp = 0;
			tid = 0;
			Mwp.stack_size = 0;
			SQL.TrackEntry t = {};
			nentry = d.get_log_count(idx);
			startat = 0;
			d.get_log_entry(idx, startat, out t);
			display(t);
			Mwp.armed = 0;
			Mwp.larmed = 0;
			Mwp.craft.new_craft (true);
			Mwp.clear_sidebar(Mwp.msp);
			Mwp.init_have_home();
            Mwp.init_state();
			Mwp.set_replay_menus(false);
			Mwp.hard_display_reset();
			Mwp.serstate = Mwp.SERSTATE.TELEM;
			Mwp.replayer = Mwp.Player.SQL;
			SQL.Meta m;
			var res = d.get_meta(idx, out m);
			if(res) {
				Mwp.vname = m.name;
				Mwp.set_typlab();
				Mwp.window.verlab.label = m.firmware;
			}

			new Thread<bool>("loader", () => {
					while(true) {
						var n = dragq.pop();
						if (n < 0) {
							break;
						}
						if (n < startat) {
							for(var j = startat; j >= n; j--) {
								Idle.add(() => {
										Mwp.craft.remove_at(j);
										startat--;
										return false;
									});
							}
							SQL.TrackEntry tx = {};
							d.get_log_entry(t.id, n, out tx);
							Idle.add(() => {
									display(tx);
									startat = tx.idx;
									return false;
								});
						} else {
							for(var j = startat+1; j <= n; j++) {
								SQL.TrackEntry tx = {};
								d.get_log_entry(t.id, j, out tx);
								startat = tx.idx;
								Idle.add(() => {
										display(tx);
										return false;
									});
								Thread.usleep(5);
							}
						}
					}
					return true;
				});
		}
		return (double)nentry;
	}

	public void on_play(bool s) {
		Mwp.usemag = true;
		Mwp.armed = 1;
		if(s) {
			SQL.TrackEntry t = {};
			d.get_log_entry(idx, startat, out t);
			display(t);
			get_next_entry(t);
		} else {
			if(tid != 0) {
				Source.remove(tid);
				tid = 0;
			}
		}
	}

	public void get_next_entry(SQL.TrackEntry t0) {
		SQL.TrackEntry t;
		var nidx = t0.idx+1;
		if (nidx < nentry) {
			var res = d.get_log_entry(t0.id, nidx, out t);
			if (res) {
				var et = (t.stamp - t0.stamp)/1000;
				if(et > 0) {
					tid = Timeout.add(et, () => {
							tid = 0;
							display(t);
							startat = t.idx;
							newpos(t.idx);
							get_next_entry(t);
							return false;
						});
				}
			} else {
				d = null;
			}
		}
	}

	private void display(SQL.TrackEntry t) {
		if (Rebase.has_reloc()) {
			if (!Rebase.has_origin()) {
				Rebase.set_origin(t.hlat, t.hlon);
			}
			Rebase.relocate(ref t.hlat, ref t.hlon);
		}

		if(Mwp.home_changed(t.hlat, t.hlon)) {
			Mwp.sflags |= Mwp.SPK.GPS;
			Mwp.want_special |= Mwp.POSMODE.HOME;
			Mwp.process_pos_states(t.hlat, t.hlon, 0, "SQL Origin"); // FIXME ALT
		}

		if (Rebase.has_reloc()) {
			if (Rebase.has_origin()) {
				Rebase.relocate(ref t.lat,ref t.lon);
			}
		}

		int fvup = 0;
		var pdiff = Mwp.pos_diff(t.lat, t.lon, Mwp.msp.td.gps.lat, Mwp.msp.td.gps.lon);
		if (Mwp.PosDiff.LAT in pdiff) {
			Mwp.msp.td.gps.lat = t.lat;
			fvup |= FlightBox.Update.LAT;
		}
		if (Mwp.PosDiff.LON in pdiff) {
			Mwp.msp.td.gps.lon = t.lon;
			fvup |= FlightBox.Update.LON;
		}
		if(Math.fabs(Mwp.msp.td.alt.alt - t.alt) > 1.0) {
			Mwp.msp.td.alt.alt = t.alt;
			fvup |= FlightBox.Update.ALT;
		}
		if(Math.fabs(Mwp.msp.td.gps.gspeed - t.spd) > 0.1) {
			Mwp.msp.td.gps.gspeed = t.spd;
			fvup |= FlightBox.Update.SPEED;
		}
		if(Mwp.msp.td.gps.nsats != t.numsat) {
			Mwp.msp.td.gps.fix = (uint8)t.fix;
			Mwp.msp.td.gps.nsats = (uint8)t.numsat;
			Mwp.msp.td.gps.hdop = t.hdop/100.0;
			fvup |= FlightBox.Update.GPS;
		}

		bool fvg = false;
		if(Mwp.msp.td.gps.cog != t.cog) {
			Mwp.msp.td.gps.cog = t.cog;
			Mwp.panelbox.update(Panel.View.DIRN, Direction.Update.COG);
			fvg = true;
		}
		if(Math.fabs(Mwp.msp.td.comp.range -  t.vrange) > 1.0) {
			Mwp.msp.td.comp.range =  (int)t.vrange;
			fvup |= FlightBox.Update.RANGE;
		}
		if(Math.fabs(Mwp.msp.td.comp.bearing - t.bearing) > 1.0) {
			Mwp.msp.td.comp.bearing =  t.bearing;
			fvup |= FlightBox.Update.BEARING;
		}

		bool fvh = (Math.fabs(Mwp.msp.td.atti.yaw - t.cse) > 1.0);

		if (fvh) {
			Mwp.msp.td.atti.yaw = t.cse;
		}
		Mwp.mhead = (int16)t.cse;
		var vdiff = (t.roll != Atti._sx) || (t.pitch != Atti._sy);
		if(vdiff) {
			Atti._sx = t.roll;
			Atti._sy = t.pitch;
			Mwp.msp.td.atti.angx = -t.roll;
			Mwp.msp.td.atti.angy = -t.pitch;
			Mwp.panelbox.update(Panel.View.AHI, AHI.Update.AHI);
		}
		if(fvh) {
			Mwp.panelbox.update(Panel.View.FVIEW, FlightBox.Update.YAW);
			Mwp.panelbox.update(Panel.View.DIRN, Direction.Update.YAW);
		}
		if(fvh || fvg) {
			if ((int16)t.windx != Mwp.msp.td.wind.w_x || (int16)t.windy != Mwp.msp.td.wind.w_y) {
				Mwp.msp.td.wind.has_wind = true;
				Mwp.msp.td.wind.w_x = (int16)t.windx;
				Mwp.msp.td.wind.w_y = (int16)t.windy;
				Mwp.panelbox.update(Panel.View.WIND, WindEstimate.Update.ANY);
			}
		}

		int xrssi = t.rssi * 1023/100;
		if (xrssi != Mwp.msp.td.rssi.rssi) {
			Mwp.msp.td.rssi.rssi = xrssi;
			Mwp.panelbox.update(Panel.View.RSSI, RSSI.Update.RSSI);
		}

		double dv;
		if(Mwp.calc_vario(t.alt, out dv)) {
			Mwp.msp.td.alt.vario = dv;
			Mwp.panelbox.update(Panel.View.VARIO, Vario.Update.VARIO);
		}

			/* hwfail / direction sanity / WP status */

		process_status(t);
		process_energy(t);
		Mwp.alert_broken_sensors((uint8)t.hwfail);

		if(fvup != 0) {
			Mwp.panelbox.update(Panel.View.FVIEW, fvup);
		}
		Mwp.update_pos_info(t.idx);
	}

	private void process_energy(SQL.TrackEntry t) {
		MSP_ANALOG2 an = MSP_ANALOG2();
		an.vbat = (uint16)(100*t.volts);
		Battery.curr.mah = (uint16)t.energy;
		an.mahdraw = (uint16)Battery.curr.mah;
		an.amps = Battery.curr.centiA = (uint16)t.amps*100;
		Battery.process_msp_analog(an);
	}

	private void process_status(SQL.TrackEntry t) {
		bool c_armed = true;
		uint64 mwflags = 0;
		uint8 ltmflags = 0;
		bool failsafe = false;

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
		Mwp.duration = t.stamp / (1000*1000);
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
		}
		if(Mwp.want_special != 0 /* && have_home*/) {
			Mwp.process_pos_states(t.lat, t.lon, 0, "Sql status", t.idx);
		}
	}
}