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
		close_request.connect (() => {
				return false;
			});

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
}


public class SQLPlayer {
	private int xstack;
	private int lstamp;
	private int nentry;
	private uint tid;
	private int startat;

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
					MWPLog.message("SLIDER n=%d at=%d\n", n, startat);
					if(n >= startat) {
						var thr = new Thread<bool>("loader", () => {
								MWPLog.message("SLIDER Thread\n");
								for(var j = startat+1; j <= n; j++) {
									SQL.TrackEntry tx = {};
									var res = d.get_log_entry(t.id, j, out tx);
									startat = tx.idx;
									Idle.add(() => {
											display(tx, t);
											return false;
										});
									Thread.usleep(5);
								}
								return true;
							});
					}
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
							startat = t.idx;
							display(t, t0);
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
				fvup |= FlightBox.Update.GPS;
			}

			if(Mwp.msp.td.gps.cog != t.cog) {
				Mwp.msp.td.gps.cog = t.cog;
				fvup |= Direction.Update.COG;
			}

			bool fvh = (Math.fabs(Mwp.msp.td.atti.yaw - t.cse) > 1.0);

			if (fvh) {
				Mwp.msp.td.atti.yaw = t.cse;
			}
			Mwp.mhead = (int16)t.cse;
			var vdiff = (t.roll != Atti._sx) || (t.pitch != Atti._sy);
				//				MWPLog.message("::DBG:: %d %d %d %d %s\n", Atti._sx, Atti._sy, af.roll, af.pitch, vdiff.to_string());
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

			if(fvup != 0) {
				Mwp.panelbox.update(Panel.View.FVIEW, fvup);
			}
			Mwp.update_pos_info(t.idx);
		}
	}
}