/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
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
using GLib;
using Clutter;

public enum Extra {
	Q_0 = 0,
	Q_1 = 1,
}

private static Clutter.Actor create_clutter_actor_from_file (string filename) {
	Clutter.Actor actor = new Clutter.Actor ();
	try {
		Gdk.Pixbuf pixbuf = new Gdk.Pixbuf.from_file (filename);
		Clutter.Image image = new Clutter.Image ();
		image.set_data (pixbuf.get_pixels (),
						pixbuf.has_alpha ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888,
						pixbuf.width,
						pixbuf.height,
						pixbuf.rowstride);
		actor.content = image;
		actor.set_size (pixbuf.width, pixbuf.height);
	} catch {}
	return actor;
}

/*
 * Extra date stored:
 * rplot: reference to RadarPlot item
 * idx	: WP index
 * extras:
 *		RadarPlot:
 *			Q_0 : INV Radar label
 *			Q_1 : ADS-B label
 *		Waypoint:
 *			Q_0 : Child marker for popover text
 */

public class MWPLabel : Champlain.Label {
	public Object? extras[2];
	public RadarPlot? rplot;
	public int idx;
	public MWPLabel.from_file(string filename) {
		var actor = create_clutter_actor_from_file (filename);
		Object(image: actor);
	}
	public MWPLabel.with_image(Actor actor) {
		Object(image: actor);
	}
	public MWPLabel.with_text(string text, string? font, Color? text_color, Color? label_color) {
		Object(text: text, font_name: font, text_color: text_color, color: label_color);
	}
}

public class MWPMarkers : GLib.Object {
    public Champlain.PathLayer path;                     // Mission outline
    public Champlain.MarkerLayer markers;                // Mission Markers
    public Champlain.MarkerLayer tmpmarkers;                // Mission Markers
    public Champlain.MarkerLayer rlayer;                 // Next WP pos layer
    public Champlain.Marker homep = null;                // Home position (just a location)
    public Champlain.Marker rthp = null;                 // RTH mission position
    public Champlain.Marker ipos = null;                 // Mission initiation point
    public Champlain.Point posring = null;               // next WP indication point
    public Champlain.PathLayer hpath;                    // planned path from RTH WP to home
    public Champlain.PathLayer ipath;                    // path from WP initiate to WP1
    private Champlain.PathLayer []jpath;                    // path from JUMP initiate to target
    private Champlain.PathLayer []rings;                 // range rings layers (per radius)
    private bool rth_land;
    private Champlain.MarkerLayer rdrmarkers;                // Mission Markers
    private Champlain.View _v;
    private List<uint> llist;
    private List<uint> llistb;

    private Clutter.Color black;
    private Clutter.Color near_black;
    private Clutter.Color grayish;
    private Clutter.Color white;

	private Clutter.Image yplane;
	private Clutter.Image rplane;
	private Clutter.Image inavradar;
	private Clutter.Image inavtelem;

    public signal void wp_moved(int ino, double lat, double lon, bool flag);
    public signal void wp_selected(int ino);

    bool can_interact;

	public static Clutter.Image load_image_from_file(string file, int w=-1, int h=-1) throws GLib.Error {
		var iconfile = MWPUtils.find_conf_file(file, "pixmaps");
		var pixbuf = new Gdk.Pixbuf.from_file_at_scale(iconfile, w, h, true);
        var image = new Clutter.Image ();
		image.set_data (pixbuf.get_pixels (),
						pixbuf.has_alpha ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888,
						pixbuf.width,
						pixbuf.height,
						pixbuf.rowstride);
        return image;
	}

    public MWPMarkers(ListBox lb, Champlain.View view, string mkcol ="#ffffff60") {
        _v = view;

        can_interact = true;
        Clutter.Color orange = {0xff, 0xa0, 0x0, 0x80};
        Clutter.Color rcol = {0xff, 0x0, 0x0, 0x80};

        black.init(0,0,0, 0xff);
        near_black.init(0x20,0x20,0x20, 0xa0);
        grayish.init(0x40,0x40,0x40, 0x80);

        white.init(0xff,0xff,0xff, 0xff);

        rth_land = false;
        markers = new Champlain.MarkerLayer();
        tmpmarkers = new Champlain.MarkerLayer();
        rlayer = new Champlain.MarkerLayer();
        path = new Champlain.PathLayer();
        hpath = new Champlain.PathLayer();
        ipath = new Champlain.PathLayer();
        jpath = {};
        rdrmarkers = new Champlain.MarkerLayer();

        view.add_layer(rdrmarkers);
        view.add_layer(rlayer);
        view.add_layer(path);
        view.add_layer(hpath);
        view.add_layer(ipath);
		view.add_layer(tmpmarkers);
        view.add_layer(markers);

        llist = new List<uint>();
        llist.append(10);
        llist.append(5);

        llistb = new List<uint>();
        llistb.append(5);
        llistb.append(5);

        hpath.set_stroke_color(orange);
        hpath.set_dash(llist);
        hpath.set_stroke_width (8);
        path.set_stroke_color(rcol);
        path.set_stroke_width (8);

        ipath.set_stroke_color(rcol);
        ipath.set_dash(llist);
        ipath.set_stroke_width (8);

        var colour = Color.from_string(mkcol);
        posring = new Champlain.Point.full(80.0, colour);
        rlayer.add_marker(posring);
        posring.hide();

		try {
			inavradar = load_image_from_file("inav-radar.svg", MWP.conf.misciconsize,MWP.conf.misciconsize);
			inavtelem = load_image_from_file("inav-telem.svg", MWP.conf.misciconsize,MWP.conf.misciconsize);
			yplane = load_image_from_file("plane100.svg",MWP.conf.misciconsize, MWP.conf.misciconsize);
			rplane = load_image_from_file("plane100red.svg", MWP.conf.misciconsize, MWP.conf.misciconsize);
		} catch {
			stderr.puts("Failed to load icons\n");
			Posix.exit(127);
		}
	}

    private unowned MWPLabel find_radar_item(RadarPlot r) {
        unowned MWPLabel rd = null;
		//        rdrmarkers.get_markers().foreach ((m) => {
		var rdrl =  rdrmarkers.get_markers();
		for (unowned GLib.List<weak Champlain.Marker> lp = rdrl.first(); lp != null; lp = lp.next) {
			if(rd == null) {
				unowned Champlain.Marker m = lp.data;
				if (((MWPLabel)m).name != "irdr")  {
					var a = ((MWPLabel)m).rplot;
					if(a != null) {
						if (r.id== a.id) {
							rd = m as MWPLabel;
							break;
						}
					}
				}
			}
		}
        return rd;
    }

	public void set_radar_stale(RadarPlot r) {
        var rp = find_radar_item(r);
        if(rp != null) {
            rp.rplot = r;
            rp.opacity = 100;
        }
    }

    public void remove_radar(RadarPlot r) {
        var rp = find_radar_item(r);
        if(rp != null) {
            unowned MWPLabel  _t = rp.extras[Extra.Q_1] as MWPLabel;
            if (_t != null)
                rdrmarkers.remove_marker(_t);
            rdrmarkers.remove_marker(rp);
        }
    }

    public void set_radar_hidden(RadarPlot r) {
        var rp = find_radar_item(r) as MWPLabel;
        if(rp != null) {
            rp.rplot = r;
            rp.visible = false;
        }
    }

    public void rader_layer_visible(bool vis) {
        if(vis)
            rdrmarkers.show();
        else
            rdrmarkers.hide();
    }

    public void update_radar(ref unowned RadarPlot r) {
        var rp = find_radar_item(r);
        if(rp == null) {
			Clutter.Actor actor = new Clutter.Actor ();
			Clutter.Image img;

			if (r.source == RadarSource.INAV) {
				img = inavradar;
            } else if (r.source == RadarSource.TELEM) {
				img = inavtelem;
			} else if ((r.alert & RadarAlert.ALERT) == RadarAlert.ALERT) {
				img = rplane;
			} else {
				img =yplane;
			}
			float w,h;
			img.get_preferred_size(out w, out h);
			actor.set_size((int)w, (int)h);
			actor.content = img;

			rp  = new MWPLabel.with_image(actor);
			rp.set_pivot_point(0.5f, 0.5f);
			rp.set_draw_background (false);
			rp.set_flags(ActorFlags.REACTIVE);
            rp.set_selectable(false);
            rp.set_draggable(false);
            var textb = new Clutter.Actor ();
            var text = new Clutter.Text.full ("Sans 9", "", white);
            text.set_background_color(black);
            rp.set_text_color(white);
            textb.add_child (text);
            rp.extras[Extra.Q_0] = textb;

            rp.enter_event.connect((ce) => {
                    var _r = rp.rplot;
                    var _ta = rp.extras[Extra.Q_0] as Actor;
                    var _tx = _ta.last_child as Clutter.Text;
                    _tx.text = "  %s / %s \n  %s %s \n  %.0f %s %0.f %s %.0f°".printf(
                        _r.name, RadarView.status[_r.state],
                        PosFormat.lat(_r.latitude, MWP.conf.dms),
                        PosFormat.lon(_r.longitude, MWP.conf.dms),
                        Units.distance(_r.altitude), Units.distance_units(),
                        Units.speed(_r.speed), Units.speed_units(),
                        _r.heading);
                    _tx.set_position(ce.x, ce.y);
                    _v.add_child (_ta);
                    return false;
                });

            rp.leave_event.connect((ce) => {
                    var _ta = rp.extras[Extra.Q_0] as Clutter.Actor;
                    _v.remove_child(_ta);
                    return false;
                });

            if((r.source & RadarSource.M_INAV) != 0) {
                var irlabel = new MWPLabel.with_text (r.name, "Sans 9", null, null);
                irlabel.set_use_markup (true);
                irlabel.set_color (grayish);
                irlabel.set_location (r.latitude,r.longitude);
                irlabel.set_name("irdr");
                rp.extras[Extra.Q_1] = irlabel;
                rdrmarkers.add_marker(irlabel);
            }
            rdrmarkers.add_marker (rp);
        }
        rp.opacity = 200;
        rp.rplot = r;
        if(rp.name != r.name) {
            rp.name = r.name;
            if((r.source & RadarSource.M_INAV) != 0) {
                unowned MWPLabel _t = rp.extras[Extra.Q_1] as MWPLabel;
                if (_t != null) {
                    _t.text = r.name;
                }
            }
        }

        rp.set_color (white);
        rp.set_location (r.latitude,r.longitude);
		if ((r.source & RadarSource.M_ADSB) != 0) {
			var act = rp.get_image();
			if((r.alert & RadarAlert.SET) == RadarAlert.SET) {
				if((r.alert & RadarAlert.ALERT) == RadarAlert.ALERT) {
					act.content = rplane;
				} else if (r.alert == RadarAlert.SET) {
					act.content = yplane;
				}
				r.alert &= ~RadarAlert.SET;
			}
		}

        if((r.source & RadarSource.M_INAV) != 0) {
            var _t = rp.extras[Extra.Q_1] as MWPLabel;
            if (_t != null) {
                _t.set_location (r.latitude,r.longitude);
            }
        }
        rp.set_rotation_angle(Clutter.RotateAxis.Z_AXIS, r.heading);
    }

    public void set_rth_icon(bool iland) {
        rth_land = iland;
    }

    private void get_text_for(MSP.Action typ, string no, out string text,
                              out  Clutter.Color colour, bool nrth=false,
                              bool jumpfwd=false, bool fby = false) {
        string symb;
        uint8 alpha = 0xc8;

        if (fby)
            alpha = 0x40;

        switch (typ) {
		case MSP.Action.WAYPOINT:
                if(nrth) {
                    colour = { 0, 0xaa, 0xff, alpha};
                        // nice to set different icon for land ⛳ or ⏬
//                    symb = (rth_land) ? "⏬WP" : "⏏WP";
                    symb = (rth_land) ? "▼WP" : "⏏WP";
                } else {
                    symb = "WP";
                    colour = { 0, 0xff, 0xff, alpha};
                }
                break;

		case MSP.Action.POSHOLD_TIME:
			symb = "◷";
			colour = { 152, 70, 234, alpha};
			break;

		case MSP.Action.POSHOLD_UNLIM:
			symb = "∞";
			colour = { 0x4c, 0xfe, 0, alpha};
			break;

		case MSP.Action.RTH:
			symb = (rth_land) ? "▼" : "⏏";
			colour = { 0xff, 0x0, 0x0, alpha};
			break;

		case MSP.Action.LAND:
			symb = "♜";
			colour = { 0xff, 0x9a, 0xf0, alpha};
			break;

		case MSP.Action.JUMP:
			// ⟲⟳⥀⥁
			if(jumpfwd)
				symb = "⟳" ; // "⇐";
			else
				symb = "⟲" ; //"⇒";

			colour = { 0xed, 0x51, 0xd7, alpha};
			break;

		case MSP.Action.SET_POI:
		case MSP.Action.SET_HEAD:
			symb = "⌘";
			colour = { 0xff, 0xfb, 0x2b, alpha};
			break;

		default:
			symb = "??";
			colour = { 0xe0, 0xe0, 0xe0, alpha};
			break;
        }
        text = "%s %s".printf(symb, no);
    }

    private double calc_extra_leg(Champlain.PathLayer p) {
        List<weak Champlain.Location> m= p.get_nodes();
        double extra = 0.0;
        if(homep != null) {
            double cse;
            Champlain.Location lp0 = m.first().data;
            Champlain.Location lp1 = m.last().data;

            Geo.csedist(lp0.get_latitude(), lp0.get_longitude(),
                        lp1.get_latitude(), lp1.get_longitude(),
                        out extra, out cse);
        }
        return extra;
    }

    public void add_home_point(double lat, double lon, ListBox l) {
        if(homep == null) {
            homep = new  Champlain.Marker();
            homep.set_location (lat,lon);
            hpath.add_node(homep);
        } else {
            homep.set_location (lat,lon);
        }
        calc_extra_distances(l);
    }

    void calc_extra_distances(ListBox l) {
        double extra = 0.0;
        if(homep != null) {
            if(ipos != null)
                extra = calc_extra_leg(ipath);

            if(rthp != null) {
                extra += calc_extra_leg(hpath);
            }
        }
        l.calc_mission(extra);
    }

    private uint find_rth_pos(out double lat, out double lon) {
        List<weak Champlain.Location> m= path.get_nodes();
        if(m.length() > 0) {
            Champlain.Location lp = m.last().data;
            lat = lp.get_latitude();
            lon = lp.get_longitude();
        } else {
            lat = lon = 0;
		}
        return m.length();
    }

    public void update_ipos(ListBox l, double lat, double lon) {
        if(ipos == null) {
            List<weak Champlain.Location> m= path.get_nodes();
            if(m.length() > 0) {
                Champlain.Location lp = m.first().data;
                var ip0 =  new  Champlain.Point();
                ip0.latitude = lp.latitude;
                ip0.longitude = lp.longitude;
                ipath.add_node(ip0);
                ipos =  new  Champlain.Point();
                ipos.set_location(lat, lon);
                ipath.add_node(ipos);
            }
            calc_extra_distances(l);
        }
    }

    public void negate_ipos() {
        ipath.remove_all();
        ipos = null;
    }


    public void negate_jpos() {
        foreach(var p in jpath) {
            p.remove_all();
        }
        jpath={};
    }

    private void update_rth (ListBox l) {
        double lat,lon;
        uint irth = find_rth_pos(out lat, out lon);
        if(irth != 0) {
            if(rthp == null) {
                rthp = new  Champlain.Marker();
                rthp.set_location (lat,lon);
                hpath.add_node(rthp);
            } else {
                rthp.set_location (lat,lon);
            }
            calc_extra_distances(l);
        }
    }

    public void negate_home() {
        if(homep != null) {
            hpath.remove_node(homep);
        }
        homep = null;
    }

    public void remove_rings(Champlain.View view) {
        if (rings.length != 0) {
            foreach (var r in rings) {
                r.remove_all();
                view.remove_layer(r);
            }
            rings = {};
        }
    }

    public void initiate_rings(Champlain.View view, double lat, double lon, int nrings, double ringint, string colstr) {
        remove_rings(view);
        var pp = path.get_parent();
        Clutter.Color rcol = Color.from_string(colstr);

        ShapeDialog.ShapePoint []pts;
        for (var i = 1; i <= nrings; i++) {
            var rring = new Champlain.PathLayer();
            rring.set_stroke_color(rcol);
            rring.set_stroke_width (2);
            view.add_layer(rring);
            pp.set_child_below_sibling(rring, path);
            double rng = i*ringint;
            pts = ShapeDialog.mkshape(lat, lon, rng, 36);
            foreach(var p in pts) {
                var pt = new  Champlain.Marker();
                pt.set_location (p.lat,p.lon);
                rring.add_node(pt);
            }
            rings += rring;
        }
    }

    public MWPLabel add_single_element( ListBox l,  Gtk.TreeIter iter, bool rth) {
        Gtk.ListStore ls = l.list_model;
        MWPLabel marker;
        GLib.Value cell;
        bool fby;

        ls.get_value (iter, ListBox.WY_Columns.ACTION, out cell);
        var typ = (MSP.Action)cell;
        ls.get_value (iter, ListBox.WY_Columns.IDX, out cell);
        var no = (string)cell;
        ls.get_value (iter, ListBox.WY_Columns.INT2, out cell);
        var p2 = (int)((double)cell);
        if (typ == MSP.Action.WAYPOINT && p2 > 0)
            typ = MSP.Action.POSHOLD_TIME;
        string text;
        Clutter.Color colour;
        Gtk.TreeIter ni;

		ls.get_value (iter, ListBox.WY_Columns.FLAG, out cell);
        fby = ((int)cell == 0x48);

        var ino = int.parse(no);

        bool nrth = l.wp_has_rth(iter, out ni);
        var xtyp = typ;
        bool jumpfwd = false;

        if(typ == MSP.Action.WAYPOINT || typ == MSP.Action.POSHOLD_TIME) {
            Gtk.TreeIter xiter = iter;
            bool done = false;
            for(var next=ls.iter_next(ref xiter);next; next=ls.iter_next(ref xiter)) {
                ls.get_value (xiter, ListBox.WY_Columns.ACTION, out cell);
                var ntyp = (MSP.Action)cell;
                switch (ntyp) {
                case MSP.Action.JUMP:
                    if(typ == MSP.Action.WAYPOINT)
                        xtyp = MSP.Action.JUMP; // arbitrary choice really
                    ls.get_value (xiter, ListBox.WY_Columns.INT1, out cell);
                    var jwp = (int)((double)cell);
                    jumpfwd = (jwp > ino);
                    done = true;
                    break;
                case MSP.Action.SET_HEAD:
                    break;
                default:
                    done = true;
                    break;
                }
                if(done)
                    break;
            }
        }
        get_text_for(xtyp, no, out text, out colour, nrth, jumpfwd, fby);

		marker = new MWPLabel.with_text (text,"Sans 10",null,null);
		marker.idx = ino;
        marker.set_alignment (Pango.Alignment.RIGHT);
        marker.set_color (colour);
        marker.set_text_color(black);
        ls.get_value (iter, 2, out cell);
        var lat = (double)cell;
        ls.get_value (iter, 3, out cell);
        var lon = (double)cell;

        marker.set_location (lat,lon);
        marker.set_draggable(!fby);
        marker.set_selectable(true);
        marker.set_flags(ActorFlags.REACTIVE);

        if (rth == false) {
            if(typ != MSP.Action.SET_POI)
                path.add_node(marker);
        }

		var str = "__WP%d__".printf(ino);
        var mc = new MWPLabel.with_text (str, "Sans 9", null, null);
        mc.set_color (near_black);
        mc.set_text_color(white);
        mc.opacity = 255;
        mc.x = 40;
        mc.y = 5;
        marker.extras[Extra.Q_0] = mc;

		marker.captured_event.connect((e) => {
				if(e.get_type() == Clutter.EventType.BUTTON_PRESS)
					if(e.button.button == 1) {
						wp_selected(ino);
						return true;
					}
               return false;
           });

        marker.button_press_event.connect((e) => {
                if(can_interact) {
                    if(e.button == 3) {
                        var _t1 = marker.extras[Extra.Q_0] as MWPLabel;
                        if (_t1 != null)
                            marker.remove_child(_t1);
						Idle.add(() => {
								var p = MWP.ViewPop();
								p.id = MWP.POPSOURCE.Mission;
								p.mk = null;
								p.funcid = ino;
								MWP.popqueue.push(p);
								return false;
							});
						return true;
                    }
                }
                return false;
            });

        marker.enter_event.connect((ce) => {
                var _t1 = marker.extras[Extra.Q_0] as MWPLabel;
                if(_t1.get_parent() == null) {
                    var s = l.get_marker_tip(marker.idx);
                    if(s == null)
                        s = "RTH";
                    _t1.text = s;
                    marker.add_child(_t1);
                    var par = marker.get_parent();
                    if (par != null)
                        par.set_child_above_sibling(marker,null);
					return true;
                }
                return false;
            });

        marker.leave_event.connect((ce) => {
                var _t1 = marker.extras[Extra.Q_0] as MWPLabel;
                if(_t1.get_parent() != null) {
                    marker.remove_child(_t1);
					return true;
				}
                return false;
            });

        marker.drag_motion.connect((dx,dy,evt) => {
                var _t1 = marker.extras[Extra.Q_0] as MWPLabel;
				wp_moved(ino, marker.get_latitude(), marker.get_longitude(), false);
				calc_extra_distances(l);
				var s = l.get_marker_tip(ino);
				_t1.set_text(s);
            });

        ((MWPLabel)marker).drag_finish.connect(() => {
                GLib.Value val;
                bool need_alt = true;
                ls.get_value (iter, ListBox.WY_Columns.ACTION, out val);
                var act =  (MSP.Action)val;
                if(act == MSP.Action.UNASSIGNED) {
                    string mtxt;
                    Clutter.Color col;
                    ls.set_value (iter, ListBox.WY_Columns.TYPE, MSP.get_wpname(act));
                    ls.set_value (iter, ListBox.WY_Columns.ACTION, MSP.Action.WAYPOINT);
                    get_text_for(act, no, out mtxt, out col);
                    marker.set_color (col);
                    marker.set_text(mtxt);
                } else {
                    if (act == MSP.Action.RTH ||
                        act == MSP.Action.SET_HEAD ||
                        act == MSP.Action.JUMP) {
                        need_alt = false;
                    } else {
                        ls.get_value (iter, ListBox.WY_Columns.FLAG, out val);
                        uint8 flag = (uint8)((int)val);
                        if(flag == 'H') {
                            need_alt = false;
                        }
                    }
                }
                wp_moved(ino, marker.get_latitude(), marker.get_longitude(), need_alt);
                calc_extra_distances(l);
                var _t1 = marker.extras[Extra.Q_0] as MWPLabel;
                _t1.set_text(l.get_marker_tip(ino));
            } );

        markers.add_marker (marker);
        return (MWPLabel)marker;
    }

    public void add_list_store(ListBox l) {
        Gtk.TreeIter iter;
        Gtk.ListStore ls = l.list_model;
        bool rth = false;
        MWPLabel mk = null;

        remove_all();
        for(bool next=ls.get_iter_first(out iter);next;next=ls.iter_next(ref iter)) {
            GLib.Value cell;
            ls.get_value (iter, ListBox.WY_Columns.ACTION, out cell);
            var typ = (MSP.Action)cell;
            switch (typ) {
                case MSP.Action.RTH:
                    rth = true;
                    update_rth(l);
                    if(mk != null) {
                        add_rth_motion(mk);
                    }
                    break;

                case MSP.Action.SET_HEAD:
                case MSP.Action.JUMP:
//                    ls.set_value(iter,ListBox.WY_Columns.MARKER, (Champlain.Label)null);
                break;
                case MSP.Action.POSHOLD_UNLIM:
                case MSP.Action.LAND:
                    mk = add_single_element(l,iter,rth);
                    rth = true;
                    break;

                default:
                    mk = add_single_element(l,iter,rth);
                    break;
            }
        }
        refesh_jumpers(ls);
        calc_extra_distances(l);
//        dump_path();
    }

    private void add_rth_motion(Champlain.Marker lp) {
        lp.drag_motion.connect(() => {
                double nlat, nlon;
                nlat = lp.get_latitude();
                nlon = lp.get_longitude();
                rthp.set_location (nlat,nlon);
            });
    }

    public void set_ring(Champlain.Marker lp) {
        var nlat = lp.get_latitude();
        var nlon = lp.get_longitude();
        posring.set_location (nlat,nlon);
        posring.show();
    }

    public void set_home_ring() {
        if (homep != null)
            set_ring(homep);
        else
            clear_ring();
    }

    public void clear_ring() {
        posring.hide();
    }

	public void freeze_mission(bool act) {
		if (act == true) {
			markers.set_all_markers_draggable ();
		} else {
			markers.set_all_markers_undraggable ();
		}
		var mlist = markers.get_markers();
		for (unowned GLib.List<weak Champlain.Marker> lp = mlist.first(); lp != null; lp = lp.next) {
			var m = (MWPLabel)lp.data;
			m.set_reactive(act);
		}
	}

    public void remove_all() {
        path.remove_all();
        hpath.remove_all();
        ipath.remove_all();
        negate_jpos();
        markers.remove_all();
        homep = rthp = ipos = null;
    }

    public MWPLabel? get_marker_for_idx(int idx) {
		var mlist = markers.get_markers();
		for (unowned GLib.List<weak Champlain.Marker> lp = mlist.first(); lp != null; lp = lp.next) {
			var m = (MWPLabel)lp.data;
			if( m.idx == idx) {
				return m;
			}
		}
		return null;
    }

    private int get_prev_geo_wp(Gtk.ListStore ls, int ino) {
        Gtk.TreeIter iter;
        GLib.Value val;
        ino--;
        while(true) {
            if(ls.iter_nth_child(out iter, null, ino)) {
                ls.get_value (iter, ListBox.WY_Columns.ACTION, out val);
                var xact = (MSP.Action)val;
                if(!((xact == MSP.Action.SET_HEAD) ||
                     (xact == MSP.Action.JUMP) ||
                     (xact == MSP.Action.RTH))) {
                    return ino+1;
                }
            } else {
                return -1;
            }
            ino--;
        }
    }

    public void refesh_jumpers(Gtk.ListStore ls) {
        Gtk.TreeIter iter;
        GLib.Value cell;
        negate_jpos();

        for(bool next=ls.get_iter_first(out iter); next; next=ls.iter_next(ref iter)) {
            ls.get_value (iter, ListBox.WY_Columns.ACTION, out cell);
            var typ = (MSP.Action)cell;
            if (typ == MSP.Action.JUMP) {
                ls.get_value (iter, ListBox.WY_Columns.IDX, out cell);
                var ino = int.parse((string)cell);
                ls.get_value (iter, ListBox.WY_Columns.INT1, out cell);
                var jwp = (int)((double)cell);
                var jp = get_prev_geo_wp(ls, ino);
                var imarker = get_marker_for_idx(jp);
                var jmarker = get_marker_for_idx(jwp);

                if(imarker != null && jmarker != null) {
                    Clutter.Color rcol = {0xed, 0x51, 0xd7, 0xc8};
                    var pp = markers.get_parent();
                    var jpl = new Champlain.PathLayer();
                    _v.add_layer(jpl);
                    pp.set_child_below_sibling(jpl, markers);
                    jpl.set_stroke_color(rcol);
                    jpl.set_stroke_width (8);
                    if (jwp < jp)
                        jpl.set_dash(llist);
                    else
                        jpl.set_dash(llistb);

                    jpl.add_node(imarker);
                    jpl.add_node(jmarker);
                    jpath += jpl;
                }
            }
        }
    }

	private Clutter.Color get_colour(MSP.Action typ) {
		Clutter.Color colour;
		switch (typ) {
		case MSP.Action.WAYPOINT:
			colour = { 0, 0xff, 0xff, 0xff};
			break;
		case MSP.Action.POSHOLD_TIME:
			colour = { 152, 70, 234, 0xff};
			break;
		case MSP.Action.POSHOLD_UNLIM:
			colour = { 0x4c, 0xfe, 0, 0xff};
			break;
		case MSP.Action.RTH:
			colour = { 0x0, 0xaa, 0xff, 0xff};
			break;
		case MSP.Action.LAND:
			colour = { 0xff, 0x9a, 0xf0, 0xff};
			break;
		case MSP.Action.JUMP:
			colour = { 0xed, 0x51, 0xd7, 0xff};
			break;
		case MSP.Action.SET_POI:
		case MSP.Action.SET_HEAD:
			colour = { 0xff, 0xfb, 0x2b, 0xff};
			break;
		default:
			colour = { 0xe0, 0xe0, 0xe0, 0xff};
			break;
        }
		return colour;
	}

	public void remove_tmp_mission() {
		tmpmarkers.remove_all();
	}

    public void set_markers_active(bool act) {
        can_interact = act;
        if(act) {
            markers.set_all_markers_draggable();
        } else {
            markers.set_all_markers_undraggable();
        }
    }

	public  void temp_mission_markers(Mission ms) {
		Champlain.Point p = null;

		if (FakeHome.is_visible) {
			Clutter.Color hcol = {0x8c, 0x43, 0x43, 0xa0};
			p = new Champlain.Point.full(MWP.conf.misciconsize, hcol);
			p.latitude = FakeHome.homep.latitude;
			p.longitude = FakeHome.homep.longitude;
			tmpmarkers.add_marker(p);
		}

		foreach (var m in ms.get_ways()) {
			var col = get_colour(m.action);
			if (m.no > 0 && (m.action == MSP.Action.RTH ||
							 m.action == MSP.Action.JUMP ||
							 m.action == MSP.Action.SET_HEAD)) {
				p.set_color(col);
			} else {
				p = new Champlain.Point.full(MWP.conf.misciconsize, col);
				p.latitude = m.lat;
				p.longitude = m.lon;
				tmpmarkers.add_marker(p);
			}
		}
	}
}
