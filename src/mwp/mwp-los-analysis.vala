/*
 * Copyright (C) 2023 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 3
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

using Gtk;
using Clutter;
using Champlain;
using GtkChamplain;


public class LOSPoint : Object {
	private static Champlain.MarkerLayer fmlayer;
	private static Champlain.PathLayer []players;
    private static Champlain.Label fmpt;
	private static Champlain.View _view;
	private static double xlat;
	private static double xlon;
	private static double xalt;
	public static bool is_init ;

	public static void init(Champlain.View view) {
		_view = view;
        Clutter.Color red = {0xff, 0x0, 0x0, 0xa0};
        Clutter.Color white = { 0xff,0xff,0xff, 0xff};
        fmlayer = new Champlain.MarkerLayer();
        fmpt = new Champlain.Label.with_text ("⨁", "Sans 10",null,null);
        fmpt.set_alignment (Pango.Alignment.RIGHT);
        fmpt.set_color (red);
        fmpt.set_text_color(white);
        view.add_layer (fmlayer);
		fmlayer.add_marker(fmpt);
		fmlayer.hide_all_markers();
		var pp = fmlayer.get_parent();
		pp.set_child_above_sibling(fmlayer, null);
		players = {};
	}

	public static void clear_los_lines() {
		clear_all();
		fmlayer.add_marker(fmpt);
	}

	public static void clear_all() {
		foreach(var p in players) {
			p.remove_all();
			_view.remove_layer(p);
		}
		players = {};
		fmlayer.remove_all();
	}

	public static void show_los(bool state) {
		if(state) {
			fmlayer.show_all_markers();
		} else {
			fmlayer.hide_all_markers();
		}
	}

	public static void set_lospt(double lat, double lon, double relalt) {
        fmpt.set_location (lat, lon);
		xlat = lat;
		xlon = lon;
		xalt = relalt;
	}

    public static void get_lospt(out double lat, out double lon, out double relalt) {
        lat = xlat;
        lon = xlon;
		relalt = xalt;
    }

	public static void add_path(double lat0, double lon0, double lat1, double lon1, uint8 col,
								double ldist, int incr) {
        Clutter.Color green = {0x0, 0xff, 0x0, 0xa0};
        Clutter.Color warning = {0xff, 0xa5, 0x0, 0xa0}; // {0xad, 0xff, 0x2f, 0xa0};
        Clutter.Color red = {0xff, 0x0, 0x0, 0xa0};

        var pmlayer = new Champlain.PathLayer();
		var llist = new List<uint>();
        llist.append(5);
        llist.append(5);
        llist.append(15);
        llist.append(5);
		Clutter.Color wcol;
		switch(col) {
		case 0:
			wcol = green;
			break;
		case 1:
			wcol = warning;
			pmlayer.set_stroke_color(warning);
			break;
		default:
			wcol = red;
			break;
		}
		if(incr < 8) {
			wcol.alpha = 0x60;
		}
		pmlayer.set_stroke_color(wcol);
        pmlayer.set_dash(llist);
        pmlayer.set_stroke_width (6);
		var ip0 =  new  Champlain.Point();
		ip0.latitude = lat0;
		ip0.longitude = lon0;
		pmlayer.add_node(ip0);
		ip0 =  new  Champlain.Point();
		ip0.latitude = lat1;
		ip0.longitude = lon1;
		pmlayer.add_node(ip0);
		players += pmlayer;
		_view.add_layer (pmlayer);
		var pp = fmlayer.get_parent();
		pp.set_child_below_sibling(pmlayer, null);
		if(col != 0) {
			double c,d;
			double dlat, dlon;
			Geo.csedist(lat0, lon0, lat1, lon1, out d, out c);
			d *= ldist;
			Geo.posit(lat0, lon0, c, d, out dlat, out dlon);
			var dlos = new Champlain.Point.full(15.0, wcol);
			dlos.set_location (dlat, dlon);
			fmlayer.add_marker(dlos);
		}
	}
}

public class LOSSlider : Gtk.Window {
	private double maxd;
	private MissionPreviewer mt;
	private LegPreview []plist;
	private HomePos _hp;
	private Gtk.Scale slider;
	private Gtk.Button button;
	private Gtk.Button abutton;
	private Gtk.Button cbutton;
	private Gtk.Button sbutton;
	private Gtk.Button ebutton;
	private Gtk.SpinButton mentry;
	private static bool is_running;
	private bool  _auto;
	private bool  _can_auto;
	private int _margin;
	private bool mlog;
	private int incr;

	public signal void new_margin(int m);

	public void set_log(bool _mlog) {
		mlog = _mlog;
	}

	private void update_from_pos(double ppos) {
		var pdist = maxd*ppos / 1000.0;
		var j = 0;
		for (; j < plist.length; j++) {
			if(plist[j].dist >= pdist) {
				break;
			}
		}
		double slat, slon;
		int salt, ealt, amsl;
		var k = plist[j].p1;
		if (k == -1) {
			slat = _hp.hlat;
			slon = _hp.hlon;
			salt = 0;
		} else {
			slat =  mt.get_mi(k).lat;
			slon =  mt.get_mi(k).lon;
			salt = mt.get_mi(k).alt;
			if (mt.get_mi(k).param3 == 1) {
				if (EvCache.get_elev(EvCache.EvConst.HOME, out amsl)) {
					salt -= amsl;
				}
			}
		}

		k = plist[j].p2;
		if (k == -1) {
			ealt = 0;
		} else {
			ealt = mt.get_mi(k).alt;
			if (mt.get_mi(k).param3 == 1) {
				if (EvCache.get_elev(EvCache.EvConst.HOME, out amsl)) {
					ealt -= amsl;
				}
			}
		}

		var deltad = 0.0;
		if (j != 0) {
			deltad = pdist - plist[j-1].dist;
		} else {
			deltad = pdist;
		}


		var csed = plist[j].cse;
		double nlat, nlon;
		Geo.posit(slat, slon, csed, deltad/1852.0, out nlat, out nlon);
		double dalt;
		dalt = (ealt - salt);
		var palt =  deltad / plist[j].legd;
		var fdalt = salt + dalt*palt;
		LOSPoint.set_lospt(nlat, nlon, fdalt);
	}

	private void reset_slider_buttons() {
		var ppos = slider.get_value ();
		if(ppos < 1) {
			button.sensitive = false;
			abutton.sensitive = _can_auto;
		} else if  (ppos > 999) {
			button.sensitive = true;
			abutton.sensitive = false;
		} else if (!_auto) {
			button.sensitive = true;
			abutton.sensitive = _can_auto;
		}
		if (!_auto) {
			update_from_pos(ppos);
		}
	}

	public LOSSlider (Gtk.Window? _w, Champlain.View view, int lmargin) {
		_can_auto = (MWP.has_bing_key || EvCache.is_local());
		_margin = lmargin;
		this.title = "LOS Analysis";
		this.window_position = Gtk.WindowPosition.CENTER;
		var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
		slider = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 1000, 1);
		slider.format_value.connect ((v) => {
				return "%.1f%%".printf(v/10.0);
			});
		slider.draw_value = true;
		slider.value_changed.connect (() => {
				reset_slider_buttons();
			});
		var hbox =  new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
		var mlab = new Gtk.Label("Margin (m):");

		mentry = new Gtk.SpinButton.with_range (0, 120, 1);
		mentry.value = _margin;

		var sbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL,1);
		sbutton = new  Gtk.Button.from_icon_name("media-skip-backward", Gtk.IconSize.BUTTON);
		ebutton = new  Gtk.Button.from_icon_name("media-skip-forward", Gtk.IconSize.BUTTON);
		sbutton.clicked.connect(() => {
				slider.set_value(0);
			});
		ebutton.clicked.connect(() => {
				slider.set_value(1000);
			});
		sbox.pack_start(sbutton, false, false, 1);
		sbox.pack_start (slider, true, true, 1); // ex t,f
		sbox.pack_end(ebutton, false, false, 1);
		box.pack_start (sbox, true, false, 1);
		incr = 10;

		var bbox = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
		abutton = new Gtk.Button.with_label ("Auto LOS");
		abutton.clicked.connect(() => {
				if (abutton.label == "Auto LOS") {
					_margin = mentry.get_value_as_int ();
					var ppos = slider.get_value ();
					abutton.label = "Stop";
					incr = 10;
					int es = 0;
					if ( Gtk.get_current_event_state(out es)) {
						if ((es & (Gdk.ModifierType.SHIFT_MASK|Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.MOD1_MASK)) != 0) {
							incr = 2;
						}
					}
					auto_run((int)ppos);
				} else {
					abutton.label = "Auto LOS";
					is_running = false;
				}
			});

		abutton.sensitive=_can_auto;
		button = new Gtk.Button.with_label ("Point LOS");
		button.clicked.connect(() => {
				Utils.terminate_plots();
				_margin = mentry.get_value_as_int ();
				run_elevation_tool();
				cbutton.sensitive = true;
			});

		cbutton = new Gtk.Button.with_label ("Clear");
		cbutton.clicked.connect(() => {
				LOSPoint.clear_los_lines();
				cbutton.sensitive = false;
			});
		cbutton.sensitive = false;
		bbox.set_layout (Gtk.ButtonBoxStyle.END);
		bbox.add (button);
		bbox.add (abutton);
		bbox.add (cbutton);
		box.pack_start(hbox);
		hbox.pack_start (mlab, false, false, 1);
		hbox.pack_start (mentry, false, false, 1);
		hbox.pack_end (bbox, false, false, 1);
		this.default_width = 600;
		set_transient_for (_w);
		if (LOSPoint.is_init == false) {
			LOSPoint.init(view);
		}

		this.destroy.connect(() => {
				_margin = mentry.get_value_as_int ();
				new_margin(_margin);
				is_running = false;
				LOSPoint.clear_all();
				Utils.terminate_plots();
			});
		this.add(box);
		this.show_all();
	}

	public void run(Mission ms, HomePos hp, int wpno, bool auto) {
		_auto = auto;
		_hp = hp;
		mt = new MissionPreviewer();
		mt.is_mr = true; // otherwise, gets confused by POSHOLD
		plist =  mt.check_mission(ms, hp, true);
		maxd =  plist[plist.length-1].dist;
		LOSPoint.show_los(true);
		if (_auto == false) {
			var j = 0;
			for (; j < plist.length; j++) {
				if(plist[j].p2 + 1 == wpno) {
					break;
				}
			}
			var adist = plist[j].dist;
			var pct = (int)(1000.0*adist/maxd);
			slider.set_value(pct);
		} else {
			incr = 10;
			auto_run(0);
		}
	}

	private void auto_run(int dp) {
		Utils.terminate_plots();
		slider.sensitive = false;
		button.sensitive = false;
		mentry.sensitive = false;
		cbutton.sensitive = false;
		sbutton.sensitive = false;
		ebutton.sensitive = false;

		is_running = true;
		_auto = true;
		abutton.label = "Stop";
		los_auto_async.begin(dp, (obj,res) => {
				los_auto_async.end(res);
				slider.sensitive = true;
				mentry.sensitive = true;
				abutton.label = "Auto LOS";
				cbutton.sensitive = true;
				sbutton.sensitive = true;
				ebutton.sensitive = true;
				_auto = false;
				is_running = false;
				reset_slider_buttons();
			});
	}

	private async bool los_auto_async(int dp) {
		var thr = new Thread<bool> ("mwp-losauto", () => {
				while (is_running) {
					update_from_pos((double)dp);
					Idle.add(() => {
							slider.set_value((double)dp);
							return false;
						});
					run_elevation_tool();
					dp += incr;
					if (dp > 1000) {
						break;
					}
				}
				Idle.add (los_auto_async.callback);
				if(dp > 1000) {
					Idle.add (()=> {
							slider.set_value(1000.0);
							return false;
						});
				}
				return true;
			});
		yield;
		return thr.join();
	}

	private void run_elevation_tool() {
        double lat,lon;
		double alt;
		LOSPoint.get_lospt(out lat, out lon, out alt);
		if ((lat == 0 && lon == 0) || ((lat - _hp.hlat).abs() < 1e-5 && (lon - _hp.hlon).abs() < 1e-5)) {
			return;
		}
		string[] spawn_args = {"mwp-plot-elevations"};
		if (_auto) {
			spawn_args += "-no-graph";
		}

		if (MWP.demdir != null) {
			spawn_args += "-localdem=%s".printf(MWP.demdir);
		}
		spawn_args += "-margin=%d".printf(_margin);
        spawn_args += "-home=%.8f,%.8f".printf(_hp.hlat, _hp.hlon);
		spawn_args += "-single=%.8f,%.8f,%.0f".printf(lat, lon, alt);
		if (mlog) {
			MWPLog.message("LOS %s\n", string.joinv(" ",spawn_args));
		}
		var msg = "";
		bool ok = false;
		try {
			var los = new Subprocess.newv(spawn_args, SubprocessFlags.STDOUT_PIPE);
			los.communicate_utf8(null, null, out msg, null);
			los.wait_check_async.begin(null, (obj,res) => {
					try {
						ok =  los.wait_check_async.end(res);
						msg = msg.chomp();
						var parts = msg.split(" ");
						uint8 losc  = (uint8)int.parse(parts[0]);
						double ldist = double.parse(parts[1]);
						if (!_auto || is_running) {
							Idle.add(() => {
									LOSPoint.add_path(_hp.hlat,  _hp.hlon, lat, lon, losc, ldist, incr);
									return false;
								});
						}
					}  catch (Error e) {
						MWPLog.message("LOS Spawn %s\n", e.message);
					}
				});
		} catch (Error e) {
			MWPLog.message("LOS Spawn %s\n", e.message);
		}
    }
}
