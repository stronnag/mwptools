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
	private Champlain.MarkerLayer fmlayer;
	private Champlain.PathLayer []players;
    private Champlain.Label fmpt;
    private bool is_visible = false;
	private bool has_loc;
	private Champlain.View _view;
	private double xlat;
	private double xlon;
	private double xalt;
	public LOSPoint(Champlain.View view) {
		_view = view;
        Clutter.Color red = {0xff, 0x0, 0x0, 0xa0};
        Clutter.Color white = { 0xff,0xff,0xff, 0xff};
        fmlayer = new Champlain.MarkerLayer();
        fmpt = new Champlain.Label.with_text ("⨁", "Sans 10",null,null);
        fmpt.set_alignment (Pango.Alignment.RIGHT);
        fmpt.set_color (red);
        fmpt.set_text_color(white);
        view.add_layer (fmlayer);
	}

	~LOSPoint() {
		show_los(false);
		foreach(var p in players) {
			p.remove_all();
			_view.remove_layer(p);
		}
		fmlayer.remove_all();
		_view.remove_layer(fmlayer);
    }

	public void show_los(bool state) {
		if(state != is_visible) {
            if(state) {
				fmlayer.add_marker(fmpt);
                var pp = fmlayer.get_parent();
                pp.set_child_above_sibling(fmlayer, null);
			} else {
                fmlayer.remove_marker(fmpt);
            }
            is_visible = state;
		}
	}
	public void set_lospt(double lat, double lon, double relalt) {
        has_loc = true;
        fmpt.set_location (lat, lon);
		xlat = lat;
		xlon = lon;
		xalt = relalt;
	}

    public void get_lospt(out double lat, out double lon, out double relalt) {
        lat = xlat;
        lon = xlon;
		relalt = xalt;
    }

	public void add_path(double lat0, double lon0, double lat1, double lon1, bool ok) {
        Clutter.Color red1 = {0xf0, 0x0, 0x0, 0x60};
        Clutter.Color green1 = {0x0, 0xf0, 0x0, 0x60};
        var pmlayer = new Champlain.PathLayer();
		var llist = new List<uint>();
        llist.append(5);
        llist.append(5);
        llist.append(15);
        llist.append(5);

		if (ok) {
			pmlayer.set_stroke_color(green1);
		} else {
			pmlayer.set_stroke_color(red1);
		}
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
	}

    public bool has_location() {
        return has_loc;
    }
}

public class LOSSlider : Gtk.Window {
	private LOSPoint lp;
	private double maxd;
	private MissionPreviewer mt;
	private LegPreview []plist;
	private HomePos _hp;
	private Gtk.Scale slider;
	public LOSSlider (Gtk.Window? _w, Champlain.View view) {
		this.title = "LOS Analysis";
		this.window_position = Gtk.WindowPosition.CENTER;
		var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
		slider = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 1000, 1);
		slider.draw_value = false;
		slider.value_changed.connect (() => {
				var ppos = slider.get_value ();
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
				}
				var csed = plist[j].cse;
				double nlat, nlon;
				Geo.posit(slat, slon, csed, deltad/1852.0, out nlat, out nlon);
				double dalt;
				dalt = (ealt - salt);
				var palt =  deltad / plist[j].legd;
				var fdalt = salt + dalt*palt;
				lp.set_lospt(nlat, nlon, fdalt);
			});
		box.pack_start (slider, true, false, 1);
		var bbox = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
		var button = new Gtk.Button.with_label ("Perform LOS");
		button.clicked.connect(() => {
				run_elevation_tool();
			});
		bbox.set_layout (Gtk.ButtonBoxStyle.END);
		bbox.add (button);
		box.pack_start (bbox, false, false, 1);
		this.default_width = (600);
		set_transient_for (_w);
		lp = new LOSPoint(view);
		this.destroy.connect(() => {
				terminate_plots();
				lp = null;
			});
		this.add(box);
		this.show_all();
	}

	public void run(Mission ms, HomePos hp, int wpno) {
		_hp = hp;
		mt = new MissionPreviewer();
		plist =  mt.check_mission(ms, hp, true);
		maxd =  plist[plist.length-1].dist;
		lp.show_los(true);
		//		lp.set_lospt(mt.get_mi(wpno).lat, mt.get_mi(wpno).lon, 0);
		var j = 0;
		for (j = 0; j < plist.length; j++) {
			if(plist[j].p2 + 1 == wpno) {
				break;
			}
		}
		var adist = plist[j].dist;
		var pct = (int)(1000.0*adist/maxd);
		slider.set_value(pct);
	}

    private void run_elevation_tool() {
        double lat,lon;
		double alt;
        string[] spawn_args = {"mwp-plot-elevations"};
        spawn_args += "-home=%.8f,%.8f".printf(_hp.hlat, _hp.hlon);
		lp.get_lospt(out lat, out lon, out alt);
		spawn_args += "-single=%.8f,%.8f,%.0f".printf(lat, lon, alt);
        MWPLog.message("LOS %s\n", string.joinv(" ",spawn_args));
		var msg = "";
		bool ok = false;
		try {
			var los = new Subprocess.newv(spawn_args, SubprocessFlags.STDOUT_PIPE);
			los.communicate_utf8(null, null, out msg, null);
			los.wait_check_async.begin(null, (obj,res) => {
					try {
						ok =  los.wait_check_async.end(res);
						msg = msg.chomp();
						MWPLog.message("DBG: LOS child <%s>\n", msg);
						var havelos  = (msg[0] == '0');
						MWPLog.message("DBG: LOS to POI %s\n", havelos.to_string());
						lp.add_path(_hp.hlat,  _hp.hlon, lat, lon, havelos);
					}  catch (Error e) {
						MWPLog.message("LOS Spawn %s\n", e.message);
					}
				});
		} catch (Error e) {
			MWPLog.message("LOS Spawn %s\n", e.message);
		}
    }

	private void terminate_plots() {
		try {
			var kplt = new Subprocess(0, "pkill", "gnuplot");
			kplt.wait_check_async.begin(null, (obj,res) => {
					try {
						kplt.wait_check_async.end(res);
					}  catch {}
				});
		} catch {}
	}
}
