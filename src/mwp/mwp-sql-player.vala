public class SQLSlider : Adw.Window {
	private Gtk.Button play_button;
	private Gtk.Scale slider;
	private Gtk.Box vbox;
	private bool pstate;

	public signal void on_play(bool s);
	public signal void moved_slider(int n);

	public SQLSlider(double smax) {
		vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
		title = "mwp Flightlog player";
		set_icon_name("mwp_icon");
		transient_for=Mwp.window;
		default_width = 640;
		var tbox = new Adw.ToolbarView();
		var headerBar = new Adw.HeaderBar();
		tbox.add_top_bar(headerBar);
		play_button = new Gtk.Button.from_icon_name ("media-playback-start");
		add_slider(smax);
		pstate = false;
		tbox.set_content(vbox);
		set_content(tbox);
		tbox.vexpand=false;
		vbox.vexpand=false;
		this.vexpand = false;

		set_bg(this, "window {background: color-mix(in srgb, @window_bg_color 40%, transparent)  ;  color: @view_fg_color; border-radius: 12px 12px;}");

		set_bg(headerBar, "headerbar {background: rgba(0, 0, 0, 0.0);}");
		set_transient_for(Mwp.window);
		play_button.clicked.connect (() => {
				toggle_pstate();
			});
	}

	private void toggle_pstate() {
		pstate = !pstate;
		if (pstate) {
			play_button.icon_name = "media-playback-pause";
		} else {
			play_button.icon_name = "media-playback-start";
		}
		on_play(pstate);
	}

	private void add_slider(double smax) {
		slider = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0, smax, 1);
		slider.set_draw_value(false);
		slider.change_value.connect((stype, d) => {
				slider.set_value(d);
				if(pstate) {
					toggle_pstate();
				}
				moved_slider((int)(d+0.5));
				return true;
			});
		slider.hexpand = true;

		var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
		hbox.append(play_button);
		hbox.append (slider);
		vbox.append(hbox);
	}

	public void set_value(double v) {
		slider.set_value(v);
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
	private AsyncQueue<int> dragq;
	private SQLSlider slider;

	~SQLPlayer() {
		MWPLog.message("SQLPLAYER DESTROYED\n");
	}

	public void init(SQL.Db? d, int idx) {
		if (d != null) {
			xstack = Mwp.stack_size;
			lstamp = 0;
			tid = 0;
			Mwp.stack_size = 0;
			SQL.TrackEntry t = {};
			nentry = d.get_log_count(idx);
			slider = new SQLSlider(nentry);
			startat = 0;
			d.get_log_entry(idx, startat, out t);
			display(t, null);
			Mwp.armed = 0;
			Mwp.larmed = 0;
			Mwp.craft.new_craft (true);
			dragq = new  AsyncQueue<int>();

			Mwp.clear_sidebar(Mwp.msp);
			Mwp.init_have_home();
            Mwp.init_state();
			Mwp.set_replay_menus(false);
			Mwp.hard_display_reset();
			SQL.Meta m;
			var res = d.get_meta(idx, out m);
			if(res) {
				Mwp.vname = m.name;
				Mwp.set_typlab();
				Mwp.window.verlab.label = m.firmware;
			}

			slider.on_play.connect((s) => {
					Mwp.armed = 1;
					if(s) {
						d.get_log_entry(idx, startat, out t);
						display(t, null);
						get_next_entry(d,t);
					} else {
						if(tid != 0) {
							Source.remove(tid);
						}
					}
				});

			slider.moved_slider.connect((n) => {
					dragq.push(n);
				});

			slider.close_request.connect (() => {
					if(tid != 0) {
						Source.remove(tid);
						tid = 0;
					}
					dragq.push(-1);
					d = null;
					Mwp.set_replay_menus(true);

					return false;
			});

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
									display(tx, t);
									startat = tx.idx;
									return false;
								});
						} else {
							for(var j = startat+1; j <= n; j++) {
								SQL.TrackEntry tx = {};
								d.get_log_entry(t.id, j, out tx);
								startat = tx.idx;
								Idle.add(() => {
										display(tx, t);
										return false;
									});
								Thread.usleep(5);
							}
						}
					}
					return true;
				});

			slider.present();
			Mwp.init_have_home();
		}
	}

	public void get_next_entry(SQL.Db d, SQL.TrackEntry t0) {
		SQL.TrackEntry t;
		var nidx = t0.idx+1;
		if (nidx < nentry) {
			var res = d.get_log_entry(t0.id, nidx, out t);
			if (res) {
				var et = (t.stamp - t0.stamp)/1000;
				if(et > 0) {
					tid = Timeout.add(et, () => {
							tid = 0;
							display(t, t0);
							startat = t.idx;
							slider.set_value(t.idx);
							get_next_entry(d, t);
							return false;
						});
				}
			} else {
				//d.Close();
			}
		}
	}

	private void display(SQL.TrackEntry t, SQL.TrackEntry? t0) {
		if(t0 == null) {
			Mwp.home_changed(t.hlat, t.hlon);
			Mwp.sflags |= Mwp.SPK.GPS;
			Mwp.want_special |= Mwp.POSMODE.HOME;
			MBus.update_home();
			Mwp.process_pos_states(t.hlat, t.hlon, 0, "SQL Origin"); // FIXME ALT
		} else {
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

			if(Mwp.msp.td.gps.cog != t.cog) {
				Mwp.msp.td.gps.cog = t.cog;
				Mwp.panelbox.update(Panel.View.DIRN, Direction.Update.COG);
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

			if(fvup != 0) {
				Mwp.panelbox.update(Panel.View.FVIEW, fvup);
			}
			Mwp.update_pos_info(t.idx);
		}
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

		if(Mwp.xfailsafe != failsafe) {
			if(failsafe) {
				MWPLog.message("Failsafe asserted %ds\n", Mwp.duration);
				Mwp.add_toast_text("FAILSAFE");
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

		Mwp.armed_processing(mwflags,"SQLLOG");
		Mwp.duration = t.stamp / (1000*1000);
		var xws = Mwp.want_special;
		var mchg = (ltmflags != Mwp.last_ltmf);
		if (mchg) {
			Mwp.last_ltmf = ltmflags;
			if(ltmflags == Msp.Ltm.POSHOLD)
				Mwp.want_special |= Mwp.POSMODE.PH;
			else if(ltmflags == Msp.Ltm.WAYPOINTS) {
				Mwp.want_special |= Mwp.POSMODE.WP;
			} else if(ltmflags == Msp.Ltm.RTH)
				Mwp.want_special |= Mwp.POSMODE.RTH;
			else if(ltmflags == Msp.Ltm.ALTHOLD)
				Mwp.want_special |= Mwp.POSMODE.ALTH;
			else if(ltmflags == Msp.Ltm.CRUISE)
				Mwp.want_special |= Mwp.POSMODE.CRUISE;
			else if(ltmflags != Msp.Ltm.LAND) {
				Mwp.craft.set_normal();
			}
			var lmstr = Msp.ltm_mode(ltmflags);
			Mwp.window.fmode.set_label(lmstr);
			MWPLog.message("New SQLLOG Mode %s (%d) %d %ds %f %f %x %x\n",
						   lmstr, ltmflags, Mwp.armed, Mwp.duration, t.lat, t.lon,
						   xws, Mwp.want_special);
		}

		if(Mwp.want_special != 0 /* && have_home*/) {
			Mwp.process_pos_states(t.lat, t.lon, 0, "SQLLOG status", t.idx);
		}
	}
}