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

namespace IconTools {
	public struct Hexcol {
		uint8 r;
		uint8 g;
		uint8 b;
		uint8 a;
		public string to_string() {
			return "#%02x%02x%02x%02x".printf(r, g, b, a);
		}
		public Gdk.RGBA to_rgba() {
			return {(float)r/255.0f, (float)g/255.0f, (float)b/255.0f, (float)a/255.0f};
		}
	}

	private Hexcol get_text_for(out string text, int no, int action, uint8 mflag = 0) {
		Hexcol colour;
		string symb;
        uint8 alpha = (uint8)Mwp.conf.mission_icon_alpha;

		if ((mflag & MsnTools.IFlags.SET_HEAD) != 0)
			action = Msp.Action.SET_HEAD;
		if ((mflag & MsnTools.IFlags.JUMPF) != 0)
			action = Msp.Action.JUMP;
		if ((mflag & MsnTools.IFlags.RTH) != 0)
			action = Msp.Action.RTH;

		if ((mflag & MsnTools.IFlags.FLYBY) != 0)
            alpha /= 2;

		if(alpha < 0x40)
			alpha = 0x40;

        switch (action) {
		case Msp.Action.WAYPOINT:
			symb = "#";
			colour = {0, 0xff, 0xff, alpha};
			break;

		case Msp.Action.POSHOLD_TIME:
			symb = "◷";
			colour = { 152, 70, 234, alpha};
			break;

		case Msp.Action.POSHOLD_UNLIM:
			symb = "∞";
			colour = { 0x4c, 0xfe, 0, alpha};
			break;

		case Msp.Action.RTH:
			symb = ((mflag & MsnTools.IFlags.RTHL) != 0) ? "▼" : "⏏";
			colour = { 0x00, 0xaa, 0xff, alpha};
			break;

		case Msp.Action.LAND:
			symb = "♜";
			colour = { 0xff, 0x9a, 0xf0, alpha};
			break;

		case Msp.Action.JUMP:
			symb = ((mflag & MsnTools.IFlags.JUMPB) != 0) ? "⟲" : "⟳" ; // "⇐";
			colour = { 0xed, 0x51, 0xd7, alpha};
			break;

		case Msp.Action.SET_POI:
		case Msp.Action.SET_HEAD:
			symb = "⌘";
			colour = { 0xff, 0xfb, 0x2b, alpha};
			break;

		default:
			symb = "??";
			colour = { 0xe0, 0xe0, 0xe0, alpha};
			break;
        }
		text = "%s\u2009%d".printf(symb, no);
		return colour;
    }
}

namespace MsnTools {
	private enum DELTAS {
        NONE=0,
        LAT=1,
        LON=2,
        POS=3,
        ALT=4,
        ANY=7
    }

	public enum IFlags {
		NONE = 0,
		SKIP = 1,
		RTH = 2,
		JUMPF = 4,
		JUMPB = (4+8),
		SET_HEAD = 16,
		FLYBY = 32,
		RTHL = (64+2),
		JUMPTARGET = 128,
	}
	public struct Elevdata {
		double amsl0;
		double amsl;
		double absa;
		double gclr;
		double rel;
	}

	Shumate.PathLayer []jumplist;

	Shumate.Marker tempmk = null;

	public void alt_updates(Mission m, Gtk.Bitset bs, double v, bool as_amsl) {
		for(var i = 0; i < m.npoints; i++) {
			if (bs.contains(i)) {
				if (m.points[i].is_geo()) {
					if(!as_amsl) {
						m.points[i].alt = (int)v;
							m.points[i].param3 &= ~1;
					} else {
						var e = DemManager.lookup(m.points[i].lat, m.points[i].lon);
						if (e != Hgt.NODATA) {
							m.points[i].param3 |= 1;
							m.points[i].alt = (int)(v+e);
						}
					}
				}
			}
		}
	}

	public void speed_updates(Mission m, Gtk.Bitset bs, double v, bool iz) {
		MissionManager.is_dirty = true;
		for(var i = 0; i < m.npoints; i++) {
			if (bs.contains(i)) {
				if (m.points[i].is_geo()) {
					if(m.points[i].action == Msp.Action.WAYPOINT ||
					   m.points[i].action == Msp.Action.LAND) {
						if(iz == false || m.points[i].param1 == 0) {
							m.points[i].param1 = (int)(v*100.0);
						}
					} else if(m.points[i].action == Msp.Action.POSHOLD_TIME) {
						if(iz == false || m.points[i].param2 == 0) {
							m.points[i].param2 = (int)(v*100.0);
						}
					}
				}
			}
		}
	}

	public void delta_updates(Mission m, Gtk.Bitset bs, double dlat, double dlon, int dalt, bool move_home) {
        double dnmlat = 0.0;
        double dnmlon = 0.0;
		double hlat, hlon;

        var dset = DELTAS.NONE;
		if(dlat != 0.0 ) {
			dset |= DELTAS.LAT;
			dnmlat = dlat / 1852.0;
        }
		if(dlon != 0.0) {
			dset |= DELTAS.LON;
			dnmlon = dlon / 1852.0;
        }
		if(dalt != 0) {
			dset |= DELTAS.ALT;
        }

		HomePoint.get_location(out hlat, out hlon);
		if(HomePoint.is_valid()) {
			if(move_home && (dset & DELTAS.POS) != DELTAS.NONE) {
				Geo.move_delta(hlat,hlon, dnmlat, dnmlon, out hlat, out hlon);
				HomePoint.set_home(hlat, hlon);
			}
        }
		if(dset != DELTAS.NONE) {
			MissionManager.is_dirty = true;
			for(var i = 0; i < m.npoints; i++) {
				if (bs.contains(i)) {
					if(m.points[i].is_geo()) {
						if(m.points[i].flag == 0x48) {
							m.points[i].lat = hlat;
							m.points[i].lon = hlon;
						} else if((dset & DELTAS.POS) != DELTAS.NONE) {
							double alat, alon;
							Geo.move_delta(m.points[i].lat, m.points[i].lon,
										   dnmlat, dnmlon, out alat, out alon);
							m.points[i].lat = alat;
							m.points[i].lon = alon;
						}

						if((dset & DELTAS.ALT) == DELTAS.ALT) {
							m.points[i].alt += dalt;
						}
					}
				}
			}
			renumber_mission(m);
			draw_mission(m);
		}
	}

	public void insert_new(Mission m, double lat, double lon) {
		var mi = new MissionItem();
		mi.lat = lat;
		mi.lon = lon;
		mi.alt = (int)Mwp.conf.altitude;
		mi.param1 = (int)(100*Mwp.conf.nav_speed);
		mi.action = Msp.Action.WAYPOINT;
		m.points.resize((int)m.npoints+1);
		m.points[m.npoints] = mi;
		MissionManager.is_dirty = true;
		renumber_mission(m);
		draw_mission(m);
	}

	public void add_shape(Mission m, int after, Shape.Point []pts) {
		var idx = m.get_index(after);
		MissionItem []nmis = {};

		for(int j = 0; j < m.npoints; j++) {
			nmis += m.points[j];
			if (j == idx) {
				foreach(var p in pts) {
					var mi = new MissionItem();
					mi.action = Msp.Action.WAYPOINT;
					mi.lat = p.lat;
					mi.lon = p.lon;
					mi.alt = (int)Mwp.conf.altitude;
					nmis += mi;
				}
			}
		}
		m.points = nmis;
		renumber_mission(m);
		draw_mission(m);
		MissionManager.is_dirty = true;
	}

	public void clear(Mission m) {
		m.points = {};
		renumber_mission(m);
		draw_mission(m);
		if(m.npoints == 0) {
			MissionManager.check_mm_list();
		}
		MissionManager.is_dirty = false; // Maybe ?
	}

	public void delete_range(Mission m, Gtk.Bitset bs) {
		MissionItem []nmis = {};
		for(var i = 0; i < m.npoints; i++) {
			if (!bs.contains(i)) {
				nmis += m.points[i];
			}
		}
		m.points = nmis;
		renumber_mission(m);
		draw_mission(m);
		if(m.npoints == 0) {
			MissionManager.check_mm_list();
		}
		MissionManager.is_dirty = true;
	}

	public void fbh_toggle(Mission m, Gtk.Bitset bs) {
		double hlat, hlon;
		HomePoint.get_location(out hlat, out hlon);
		for(var i = 0; i < m.npoints; i++) {
			if (bs.contains(i)) {
				if(m.points[i].flag == 0x48) {
					m.points[i].flag =0;
				} else if(m.points[i].flag == 0) {
					m.points[i].flag =0x48;
					m.points[i].lat = hlat;
					m.points[i].lon = hlon;
				}
			}
		}
		renumber_mission(m);
		draw_mission(m);
		MissionManager.is_dirty = true;
	}

	public void move_to(Mission m, int src, int dest) {
		MissionItem []nmis = {};
		var si =  m.get_index(src);
		var di =  m.get_index(dest);
		for(var j = 0; j < m.npoints; j++) {
			if(j == di) {
				nmis += m.points[si];
			}
			if (j != si) {
				nmis += m.points[j];
			}
		}
		m.points = nmis;
		renumber_mission(m);
		draw_mission(m);
		MissionManager.is_dirty = true;
		m.changed();
	}

	public void insert_before(Mission m, int n) {
		MissionItem []nmis = {};
		var k = m.get_index(n);
		for(var i = 0; i < m.npoints; i++) {
			if (i == k) {
				var mi = new MissionItem();
				double nlat, nlon;
				if (k == 0) {
					nlat = m.homey;
					nlon = m.homex;
				} else {
					nlat = m.points[k-1].lat;
					nlon = m.points[k-1].lon;
				}
				mi.lat = (nlat + m.points[k].lat)/2.0;
				mi.lon = (nlon + m.points[k].lon)/2.0;
				mi.action = Msp.Action.WAYPOINT;
				nmis += mi;
			}
			nmis += m.points[i];
		}
		m.points = nmis;
		MissionManager.is_dirty = true;
		renumber_mission(m);
		draw_mission(m);
	}

	public void insert_after(Mission m, int n) {
		MissionItem []nmis = {};
		var k = m.get_index(n);
		for(var i = 0; i < m.npoints; i++) {
			nmis += m.points[i];
			if (i == k) {
				var mi = new MissionItem();
				double nlat, nlon;
				if(k == m.npoints-1) {
					nlat = m.homey;
					nlon = m.homex;
				} else {
					if (m.points[k+1].is_geo()) {
						nlat = m.points[k+1].lat;
						nlon = m.points[k+1].lon;
					} else {
						HomePoint.get_location(out nlat, out nlon);
					}
				}
				mi.lat = (nlat + m.points[k].lat)/2.0;
				mi.lon = (nlon + m.points[k].lon)/2.0;
				mi.action = Msp.Action.WAYPOINT;
				nmis += mi;
			}
		}
		m.points = nmis;
		MissionManager.is_dirty = true;
		renumber_mission(m);
		draw_mission(m);
	}

	public void move_before(Mission m, int n) {
		var k = m.get_index(n);
		if (k == 0)
			return;
		int prev = k - 1;
		var mtmp = m.points[prev];
		m.points[prev] = m.points[k];
		m.points[k] = mtmp;
		MissionManager.is_dirty = true;
		renumber_mission(m);
		draw_mission(m);
	}

	public void move_after (Mission m, int n) {
		if (n == m.npoints)
			return;
		var k = m.get_index(n);
		if ((n == m.npoints -1) && ((m.points[k]._mflag & IFlags.RTH) == IFlags.RTH))
			return;
		int next = n;
		var mtmp = m.points[next];
		m.points[next] = m.points[k];
		m.points[k] = mtmp;
		MissionManager.is_dirty = true;
		renumber_mission(m);
		draw_mission(m);
	}

	public string wp_info_label(Mission m, int idx) {
		var sb = new StringBuilder();
		sb.append_printf("WP%d:", m.points[idx].no);
		sb.append_printf(" %s", Msp.get_wpname(m.points[idx].action));
		if(m.points[idx]._mflag != 0) {
			sb.append(" +");
			string []wacts = {};
			if((m.points[idx]._mflag & IFlags.RTH) !=0) {
				wacts += "RTH";
			}
			string wj=null;
			if((m.points[idx]._mflag & IFlags.JUMPB) == IFlags.JUMPB) {
				wj = "Jump back";
			} else if((m.points[idx]._mflag & IFlags.JUMPF) == IFlags.JUMPF) {
				wj = "Jump forward";
			}
			if(wj != null) {
				for(var j = idx; j < m.npoints; j++) {
					if (m.points[j].action == Msp.Action.JUMP) {
						wj += " to WP%d x %d".printf(m.points[j].param1, m.points[j].param2);
						break;
					}
				}
				wacts += wj;
			}
			if((m.points[idx]._mflag & IFlags.SET_HEAD) !=0) {
				wacts += "Set heading";
			}
			if((m.points[idx]._mflag & IFlags.FLYBY) !=0) {
				wacts += "Fly-by-home";
			}
			if((m.points[idx]._mflag & IFlags.JUMPTARGET) !=0) {
				wacts += "Jump target";
			}
			var wstr = string.joinv(",", wacts);
			sb.append(wstr);
		}
		return sb.str;
	}

	public void clear_display() {
		if(FWApproach.is_active((int)MissionManager.mdx+8)) {
			FWPlot.remove_all((int)MissionManager.mdx+8);
		}

		foreach (var jp in jumplist) {
			jp.remove_all();
			Gis.map.remove_layer(jp);
		}
		Gis.mp_layer.remove_all();
		Gis.mm_layer.remove_all();

		jumplist={};
	}

	public void delete(Mission m, int n) {
		MissionItem []nmis = {};
		for(int i = 0; i < m.npoints; i++) {
			if (m.points[i].no == n) {
				continue;
			}
			nmis += m.points[i];
		}
		m.points = nmis;
		MissionManager.is_dirty = true;
		renumber_mission(m);
		draw_mission(m);
		if(m.npoints == 0) {
			MissionManager.check_mm_list();
		}
	}

	public void renumber_mission(Mission m) {
		int n = 1;
		for(var i = 0; i < m.points.length; i++) {
			m.points[i].no = n;
			n++;
		}
		m.npoints = m.points.length;
		if (m.npoints == 0) {
			//MissionManager.check_mission();
		} else {
			m.calc_mission_distance();
		}
		m.changed();
	}

	private int find_jumper(Mission m, int i) {
		while (--i >= 0) {
			if(m.points[i].is_geo()) {
				return i;
			}
		}
		return -1;
	}

	public void draw_mission(Mission m) {
		bool have_hp = false;
		bool have_jump = false;
		Shumate.PathLayer []jumps = {};
		int jumptgt;

		clear_display();
		// Separate loop as we may write "forwards" for jumps
		for(var i = 0; i < m.npoints; i++) {
			m.points[i]._mflag = IFlags.NONE;
		}
		for(var i = 0; i < m.npoints; i++) {
			switch(m.points[i].action) {
			case  Msp.Action.JUMP:
				m.points[i]._mflag = IFlags.SKIP;
				var jumper = find_jumper(m,i);
				if(jumper != -1) {
					m.points[jumper]._mflag |= IFlags.JUMPF;
					jumptgt = m.get_index(m.points[i].param1);
					if (jumptgt != -1) {
						m.points[jumptgt]._mflag |= IFlags.JUMPTARGET;
					}
					if (jumptgt < jumper) {
						m.points[jumper]._mflag |= IFlags.JUMPB;
					}
				}
				have_jump = true;
				break;
			case Msp.Action.SET_HEAD:
				m.points[i-1]._mflag |= IFlags.SET_HEAD;
				m.points[i]._mflag = IFlags.SKIP;
				break;
			case Msp.Action.RTH:
				m.points[i-1]._mflag |= IFlags.RTH;
				m.points[i]._mflag = IFlags.SKIP;
				break;
			default:
				if(m.points[i].flag == 'H') {
					m.points[i]._mflag |= IFlags.FLYBY;
					have_hp = true;
				}
				break;
			}
		}
		if(have_hp) {
			HomePoint.hp.opacity = 0.5;
		}

		for(var i = 0; i < m.npoints; i++) {
			if (m.points[i]._mflag == IFlags.SKIP) {
				continue;
			}
			string label;

			var mcol = IconTools.get_text_for(out label, m.points[i].no, m.points[i].action,
											  m.points[i]._mflag);
			var mk = new MWPLabel(label);
			mk.set_colour(mcol.to_string());
			mk.set_text_colour("black");
			mk.no = m.points[i].no;
			var lat = m.points[i].lat;
			var lon = m.points[i].lon;
			var dodrag = true;
			if (m.points[i].flag == 'H' || (lat == 0 && lon == 0)) {
				lat = m.homey;
				lon = m.homex;
				dodrag = false;
			}
			mk.set_draggable(dodrag);
			mk.set_location (lat, lon);
			Gis.mm_layer.add_marker(mk);
			if (m.points[i].action != Msp.Action.SET_POI) {
				Gis.mp_layer.add_node(mk);
			}

			if(m.points[i].action == Msp.Action.LAND) {
				if(FWApproach.is_active((int)MissionManager.mdx+8)) {
					FWPlot.update_laylines((int)MissionManager.mdx+8, mk, true);
				}
			}

			mk.set_tooltip_markup(set_tip(mk, m, true));
			mk.drag_motion.connect((la, lo) => {
					if(tempmk != null) {
						tempmk.latitude = la;
						tempmk.longitude = lo;
					}
					MissionManager.is_dirty = true;
					var idx = m.get_index(mk.no);
					if(m.points[idx].action == Msp.Action.LAND) {
						if(FWApproach.is_active((int)MissionManager.mdx+8)) {
							FWPlot.update_laylines((int)MissionManager.mdx+8, mk, true);
						}
					}
					m.points[idx].lat = la;
					m.points[idx].lon = lo;
					mk.set_tooltip_markup(set_tip(mk,m,false));
				});

			mk.drag_begin.connect((t) => {
					if(t) {
						Gis.mp_layer.remove_node(mk);
						tempmk = new Shumate.Marker();
						tempmk.set_location (mk.latitude, mk.longitude);
						Gis.mp_layer.insert_node(tempmk, m.npoints-mk.no);
					}
					mk.set_tooltip_markup(set_tip(mk,m,false));
				});

			mk.drag_end.connect((t) => {
					tempmk = null;
					MissionManager.is_dirty = true;
					if(t) {
						Gis.mp_layer.remove_all();
						Gis.mm_layer.get_markers().@foreach((mm) => {
								Gis.mp_layer.add_node(mm);
							});
					}
					m.calc_mission_distance();
					mk.set_tooltip_markup(set_tip(mk,m,true));
				});

			mk.popup_request.connect((n,x,y) => {
					MT._m = m;
					MT._mk = mk;
					var pop = new Gtk.PopoverMenu.from_model(MT.wppopmenu);
					pop.set_has_arrow(true);
					var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL,1);
					var plab = new Gtk.Label("WP %d".printf(mk.no));
					plab.hexpand = true;
					box.append(plab);
					if(n == -1) {
						pop.set_autohide(false);
						var button = new Gtk.Button.from_icon_name("window-close");
						button.halign = Gtk.Align.END;
						box.append(button);
						button.clicked.connect(() => {
								pop.popdown();
							});
					} else {
						pop.set_autohide(true);
					}
					pop.add_child(box, "label");
					pop.set_parent(mk);
					MwpMenu.set_menu_state(Mwp.window, "wmove-before", (mk.no != 1));
					bool eom = (mk.no == m.npoints || (mk.no == m.npoints-1 && m.points[m.npoints-1].action == Msp.Action.RTH));
					MwpMenu.set_menu_state(Mwp.window, "wmove-after", !eom);
					int idx = m.get_index(mk.no);
					bool ok = (m.points[idx].action == Msp.Action.SET_POI);
					MwpMenu.set_menu_state(Mwp.window, "addshape", ok);
					pop.popup();
				});
		}

		if(have_jump) {
			for(var i = 0; i < m.npoints; i++) {
				if ((m.points[i]._mflag & IFlags.JUMPF) != 0) {
					var jtarget = m.points[i+1].param1;
					unowned MWPMarker? j1 = null;
					unowned MWPMarker? j2 = null;
					j1 = search_markers_by_id(m.points[i].no);
					j2 = search_markers_by_id(jtarget);
					if (j1 != null && j2 != null) {
						var jp = new Shumate.PathLayer(Gis.map.viewport);
						jp.set_stroke_width(4.0);
						var llistb = new List<uint>();
						llistb.append(5);
						llistb.append(5);
						jp.set_dash(llistb);
						jp.add_node(j1);
						jp.add_node(j2);
						Gis.map.insert_layer_behind(jp, Gis.mp_layer);
						jumps += jp;
						jumplist = jumps;
					}
				}
			}
		}

		if(have_hp && HomePoint.is_valid()) {
			HomePoint.hp.drag_motion.connect((la, lo) => {
					int []ll = {};
					m.homey = la;
					m.homex = lo;
					for(var k = 0; k < m.npoints; k++) {
						if ((m.points[k]._mflag & IFlags.FLYBY) != 0) {
							ll += m.points[k].no;
							m.points[k].lat = la;
							m.points[k].lon = lo;
						}
					}
					if(ll.length > 0) {
						var mklist =  Gis.mm_layer.get_markers();
						for (unowned GLib.List<weak Shumate.Marker> lp = mklist.first();
							 lp != null; lp = lp.next) {
							unowned MWPMarker mx = lp.data as MWPMarker;
							foreach(var l in ll) {
								if (mx.no == l) {
									mx.latitude = la;
									mx.longitude = lo;
									break;
								}
							}
						}
					}
				});
		}
	}

	private string set_tip(MWPLabel mk, Mission m, bool extended) {
		var i = m.get_index(mk.no);
		var sb = new StringBuilder();
		sb.append_printf("<b>%s</b>\n%s",  wp_info_label(m, i),
						 PosFormat.pos(mk.latitude, mk.longitude, Mwp.conf.dms, true));
		Elevdata e = resolve_elevations(m.points[i]);
		if(e.amsl0 != Hgt.NODATA) {
			sb.append_printf("\nAMSL: %.1fm, AGL: %.1fm, Rel.: %.1fm", e.absa,e.gclr,e.rel);
		}
		if(extended) {
			if(HomePoint.is_valid()) {
				double d,c;
				double hlat, hlon;
				HomePoint.get_location(out hlat, out hlon);
				Geo.csedist(hlat, hlon, m.points[i].lat, m.points[i].lon, out d, out c);
				sb.append_printf("\nRange %.0fm, bearing %03.0f°", d*1852.0, c);
			}
			foreach(var sts in m.points[i].stats) {
				sb.append_printf("\nto WP%d =>  %.0fm, %03d°", sts.next+1, sts.dist, sts.cse);
			}
		}
		return sb.str;
	}

	public unowned MWPMarker? search_markers_by_id (int id) {
		SearchFunc<MWPMarker?,int> id_cmp = (g,t) =>  {
			return (int) (g.no > t) - (int) (g.no < t);
		};
		var lst = Gis.mm_layer.get_markers();
		unowned var ll = lst.search(id, id_cmp);
		if (ll != null && ll.length() > 0) {
			return (MWPMarker)ll.nth_data(0);
		}
		return null;
	}

	public Elevdata resolve_elevations(MissionItem  mi) {
		Elevdata e = {0};
		e.amsl0 = Hgt.NODATA;
		if(HomePoint.get_elevation(out e.amsl0) && e.amsl0 != Hgt.NODATA) {
			e.amsl = DemManager.lookup(mi.lat, mi.lon);
			if ((mi.param3 & 1) != 0) {
				e.absa = mi.alt;
				e.rel = mi.alt - e.amsl0;
			} else {
				e.rel = mi.alt;
				e.absa = e.amsl0 + e.rel;
			}
			e.gclr = e.absa - e.amsl;
		}
		return e;
	}
}
