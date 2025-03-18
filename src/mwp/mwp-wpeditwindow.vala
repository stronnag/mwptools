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

[Flags]
public enum WPEditMask {
    SETHEAD,
    JUMP,
    RTH,
	ATHOME
}

public struct EditItem {
    double p1;
    double p2;
    int p3;
    int no;
    int alt;
    int jump1;
    int jump2;
    int heading;
    int rthland;
	Msp.Action action;
    uint8 flag;
    uint8 optional;
	MsnTools.Elevdata elv;
}

private const int MAX_Q_WIDTH=7;

private class QLabel : Gtk.Widget {
	public Gtk.Label l;
    public QLabel(string? s) {
		l = new Gtk.Label(s);
        l.hexpand = false;
        l.halign = Gtk.Align.START;
        l.vexpand = false;
    }
}

private class QEntry : Gtk.Entry {
    public QEntry(string? etext, int len, Gtk.InputPurpose pp) {
		editable = true;
        hexpand = false;
        halign = Gtk.Align.START;
        vexpand = false;
        input_purpose = pp;
        text=etext;
        width_chars = len;
		max_width_chars = (len < MAX_Q_WIDTH) ? MAX_Q_WIDTH : len;
    }
}

public class WPPopEdit : Adw.Window {
    private Gtk.Box vbox;
    private Gtk.DropDown wp_combo;
    private Gtk.Grid  grid0;
    private Gtk.Grid  grid;
    private QEntry altent;
    private Gtk.CheckButton amslcb;
    private Gtk.CheckButton fbhcb;
    private QEntry speedent;
    private QEntry loiterent;
    private QEntry landent;
    private Gtk.CheckButton headcb;
    private Gtk.CheckButton athomecb;
    private QEntry headent;
    private Gtk.CheckButton jumpcb;
    private QEntry jump1ent;
    private QEntry jump2ent;
    private Gtk.CheckButton rthcb;
    private Gtk.CheckButton landcb;
    private Gtk.CheckButton wpaction[4];
	private Gtk.Button apply;

	private QEntry appalt;
	private QEntry fwdirn1;
	private QEntry fwdirn2;
    private Gtk.DropDown dref_combo;
    private Gtk.CheckButton ex1;
    private Gtk.CheckButton ex2;
	private QEntry poslat;
	private QEntry poslon;
	private Gtk.Label poselv;

	private uint8 posupd;
	public signal void completed(bool state);
	public signal void marker_changed(Msp.Action act);

	public void set_jump_dst(int n) {
		if(jump1ent != null) {
			jump1ent.text = n.to_string();
		}
	}

	public WPPopEdit(int no) {
		posupd = 0;
		var sbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);

		var tbox = new Adw.ToolbarView();
		var headerBar = new Adw.HeaderBar();
		tbox.add_top_bar(headerBar);

		title = "WP Edit";
        set_transient_for(Mwp.window);
        build_box();
		sbox.append(vbox);

		var bbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL,2);
		bbox.halign = Gtk.Align.END;
		bbox.hexpand = true;
		bbox.append(apply);
		bbox.add_css_class("toolbar");

		tbox.set_content(sbox);
		tbox.add_bottom_bar(bbox);

		set_content(tbox);

		apply.clicked.connect(()=>{
				completed(true);
			});

		close_request.connect(() => {
				completed(false);
				return false;
			});
	}

    public void wpedit(EditItem wpt) {
        add_grid(wpt);
        present();
    }

    private Gtk.Label qlabel(string? s) {
        return new QLabel(s).l;
    }

    private void build_box() {
        vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
		//        vbox.margin = 2;
        wp_combo = new Gtk.DropDown.from_strings({
				"WAYPOINT", "POSHOLD UNLIM", "POSHOLD TIME", "SET_POI", "LAND"});
		dref_combo = new Gtk.DropDown.from_strings({"Left", "Right"});

        grid0 = new Gtk.Grid();
        grid0.column_homogeneous = false;
		grid0.hexpand = false;
        grid0.set_column_spacing (2);
        grid0.attach (wp_combo, 0, 1, 1, 1);
        grid = new Gtk.Grid();
        grid.column_homogeneous = false; // was true
        grid.hexpand = false;
		apply = new Gtk.Button.with_label("Apply");
        apply.hexpand = false;
        apply.halign = Gtk.Align.END;

		vbox.append (grid0);
        vbox.append (grid);
    }

    private void add_grid(EditItem wpt) {
        bool isset = false;
		wp_combo.notify["selected"].connect(() => {
                if(isset) {
                    var no = wpt.no;
                    extract_data(wpt.action, ref wpt);
					marker_changed(wpt.action);
                    wpt.no = no;
                    refresh_grid(wpt);
                }
            });
        refresh_grid(wpt);
        isset = true;
    }

    private void extract_basic(Msp.Action act, ref EditItem wpt) {
        wpt.alt = int.parse(altent.text);
        wpt.p3 = 0;

        if (amslcb.active) {
            wpt.p3 |= 1;
        }
        wpt.flag = (fbhcb.active) ? 72 : 0;

        if(act == Msp.Action.POSHOLD_TIME) {
            wpt.p2 = DStr.strtod(speedent.text, null);
		wpt.p1 = DStr.strtod(loiterent.text, null);
        } else {
		wpt.p1 = DStr.strtod(speedent.text, null);
            wpt.p2 = 0;
        }

        if(act == Msp.Action.LAND) {
            wpt.p2 = DStr.strtod(landent.text, null);
        } else {
            wpt.optional = 0;
            if(headcb.active) {
                wpt.optional |= WPEditMask.SETHEAD;
            } else {
				headent.text = "";
			}
            wpt.heading = int.parse(headent.text);

            if(jumpcb.active) {
                wpt.optional |= WPEditMask.JUMP;
			} else {
				jump1ent.text = "";
				jump2ent.text = "";
			}
            wpt.jump1 = int.parse(jump1ent.text);
            wpt.jump2 = int.parse(jump2ent.text);
            if(rthcb.active) {
                wpt.optional |= WPEditMask.RTH;
            }
            wpt.rthland = (landcb.active) ? 1 : 0;
        }

        for(int k = 0; k < 4; k++) {
            if (wpaction[k].active) {
                wpt.p3 |= (1<<k+1);
            }
        }
    }

	private Msp.Action get_action_from_combo() {
		Msp.Action nv;
		var nid = wp_combo.get_selected();
		switch(nid) {
		case 0:
			nv = Msp.Action.WAYPOINT;
			break;
		case 1:
			nv = Msp.Action.POSHOLD_UNLIM;
			break;
		case 2:
			nv = Msp.Action.POSHOLD_TIME;
			break;
		case 3:
			nv = Msp.Action.SET_POI;
			break;
		case 4:
			nv = Msp.Action.LAND;
			break;
		default:
			nv =  Msp.Action.UNKNOWN;
			break;
		}
		return nv;
	}

	public uint8 extractll(out double llat, out double llon) {
		var res = posupd;
		llat = 0;
		llon = 0;
		if ((posupd & 1) == 1) {
			llat = InputParser.get_latitude(poslat.text);
			poslat.text = PosFormat.lat(llat, Mwp.conf.dms);
		}
		if ((posupd & 2) == 2) {
			llon = InputParser.get_longitude(poslon.text);
			poslon.text = PosFormat.lon(llon, Mwp.conf.dms);
		}
		posupd = 0;
		return res;
	}


	public void extract_data(Msp.Action oldact, ref EditItem wpt) {
        Msp.Action nv;
        if (oldact == Msp.Action.UNKNOWN) {
			nv = get_action_from_combo();
        } else {
            nv = oldact;
        }

        switch(nv) {
        case Msp.Action.WAYPOINT:
        case Msp.Action.POSHOLD_UNLIM:
        case Msp.Action.POSHOLD_TIME:
        case Msp.Action.LAND:
            extract_basic(nv, ref wpt);
            break;

		case Msp.Action.SET_POI:
			wpt.optional = (athomecb.active) ? WPEditMask.ATHOME : 0;
			break;
		default:
            break;
        }
        wpt.action =  get_action_from_combo();
		if(nv == Msp.Action.LAND) {
		}
	}

    private void refresh_grid(EditItem wpt) {
		//        grid.foreach ((element) => grid.remove (element));
		for(var i = 0; i < 8; i++) {
			for(var j = 0; j < 8; j++) {
				var w = grid.get_child_at(i, j);
				if (w != null) {
					grid.remove(w);
				}
			}
		}
        wp_combo.selected = get_index_for_action(wpt.action);
        title = "WP Edit #%d".printf(wpt.no);
        switch(wpt.action) {
        case Msp.Action.WAYPOINT:
        case Msp.Action.POSHOLD_UNLIM:
        case Msp.Action.POSHOLD_TIME:
        case Msp.Action.SET_POI:
        case Msp.Action.LAND:
            set_base_elements(wpt);
            break;
        default:
            break;
        }
        grid.visible=true;
    }

	private int get_index_for_action(Msp.Action act) {
		int id;
		switch (act) {
		case Msp.Action.WAYPOINT:
			id = 0;
			break;
        case Msp.Action.POSHOLD_UNLIM:
			id = 1;
			break;
        case Msp.Action.POSHOLD_TIME:
			id = 2;
			break;
        case Msp.Action.SET_POI:
			id = 3;
			break;
        case Msp.Action.LAND:
			id = 4;
			break;
		default:
			id = 0;
			break;
		}
		return id;
	}

	private string format_elev(double lat, double lon) {
		string res="";
		var elev = DemManager.lookup(lat, lon);
		if (elev != Hgt.NODATA) {
			res = " %.0f%s".printf(Units.distance(elev), Units.distance_units());
		}
		return res;
	}

	private void showlle(double la, double lo) {
		poslat.text = PosFormat.lat(la, Mwp.conf.dms);
		poslon.text = PosFormat.lon(lo, Mwp.conf.dms);
		var elv = format_elev(la, lo);
		poselv.label = elv;
	}

	public void setup_ll_listener(int idx) {
		unowned MWPMarker? m0 = MsnTools.search_markers_by_id(idx);
		showlle(m0.latitude, m0.longitude);
		m0.drag_motion.connect((la, lo) => {
				showlle(la, lo);
			});
	}

	private void set_base_elements(EditItem wpt) {
        int j = 0;
        string txt;
		var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
		box.hexpand = false;
        grid.attach (qlabel("Position"), 0, j);
		poslat = new QEntry("", 12,  Gtk.InputPurpose.FREE_FORM);
		poslon = new QEntry("", 12,  Gtk.InputPurpose.FREE_FORM);
		poselv = new QLabel("").l;
		poselv.max_width_chars = 8;
		poselv.width_chars = 6;
        poselv.visible=true;
		box.append(poslat);
		box.append(poslon);
		box.append(poselv);
		setup_ll_listener(wpt.no);
        grid.attach (box, 1, j, 2);


		poslat.changed.connect(() => {
				posupd |= 1;
			});
		poslon.changed.connect(() => {
				posupd |= 2;
			});

        if (wpt.action != Msp.Action.SET_POI) {
            j++;
            grid.attach (qlabel("Altitude"), 0, j);
            txt = "%d".printf(wpt.alt);
            altent = new QEntry(txt, 6, Gtk.InputPurpose.DIGITS);
            grid.attach (altent, 1, j);
            amslcb = new Gtk.CheckButton.with_label("AMSL");
            amslcb.active = ((wpt.p3 & 1) == 1);
            grid.attach (amslcb, 2, j);
            fbhcb = new Gtk.CheckButton.with_label("FBH");
            fbhcb.active = (wpt.flag == 72);
            grid.attach (fbhcb, 3, j);
            j++;
            grid.attach (qlabel("Speed"), 0, j);
            if(wpt.action == Msp.Action.POSHOLD_TIME) {
                txt = "%.1f".printf(wpt.p2);
            } else {
                txt = "%.1f".printf(wpt.p1);
            }
            speedent = new QEntry(txt, 7, Gtk.InputPurpose.NUMBER);
            grid.attach (speedent, 1, j);

            if(wpt.action == Msp.Action.POSHOLD_TIME) {
                grid.attach (qlabel("Loiter Time"), 2, j);
                txt = "%.0f".printf(wpt.p1);
                loiterent = new QEntry(txt, 4, Gtk.InputPurpose.DIGITS);
                grid.attach (loiterent, 3, j);
            }
            if(wpt.action == Msp.Action.LAND) {
                grid.attach (qlabel("Land Altitude"), 2, j);
				var fwl = FWApproach.get(MissionManager.mdx+8);
				amslcb.active = fwl.aref;
				if (fwl.dirn1 == 0 && fwl.dirn2 == 0) {
					txt = "%.0f".printf(wpt.p2);
				} else {
					txt = "%.2f".printf(fwl.landalt);
				}
                landent = new QEntry(txt, 6, Gtk.InputPurpose.NUMBER);
                grid.attach (landent, 3, j);
				j++;
                grid.attach (qlabel("Approach Alt"), 0, j);
				txt = "%.2f".printf(fwl.appalt);
                appalt = new QEntry(txt, 6, Gtk.InputPurpose.NUMBER);
                grid.attach (appalt, 1, j);

				grid.attach (qlabel("From"), 2, j);
				dref_combo.selected = (fwl.dref) ? 1 : 0;
				grid.attach (dref_combo, 3, j);
				j++;
				grid.attach (qlabel("Direction 1"), 0, j);
				txt = "%d".printf(fwl.dirn1);
                fwdirn1 = new QEntry(txt, 5, Gtk.InputPurpose.NUMBER);
                grid.attach (fwdirn1, 1, j);
				ex1 = new Gtk.CheckButton.with_label("Exclusive");
				ex1.active = fwl.ex1;
				grid.attach (ex1, 2, j);
				j++;

				grid.attach (qlabel("Direction 2"), 0, j);
				txt = "%d".printf(fwl.dirn2);
                fwdirn2 = new QEntry(txt, 5, Gtk.InputPurpose.NUMBER);
                grid.attach (fwdirn2, 1, j);
				ex2 = new Gtk.CheckButton.with_label("Exclusive");
				ex2.active = fwl.ex2;
				grid.attach (ex2, 2, j);

				amslcb.toggled.connect(() => {
                        if(wpt.elv.amsl0 != (int)Hgt.NODATA) {
							var na = DStr.strtod(appalt.text, null);
                            if (amslcb.active) {
                                na = na + wpt.elv.amsl0;
                            } else {
                                na = na - wpt.elv.amsl0;
                            }
                            appalt.text = "%.2f".printf(na);
                            set_alt_border(appalt, false);
                            var na1 = DStr.strtod(altent.text, null);
                            if (amslcb.active) {
                                na1 = na1 + wpt.elv.amsl0;
                            } else {
                                na1 = na1 - wpt.elv.amsl0;
                            }
                            altent.text = "%0f".printf(na1);
                            set_alt_border(altent, false);
                        } else {
                            set_alt_border(altent, true);
							set_alt_border(appalt, true);
                        }
                    });

			} else {
                j++;
                headcb = new Gtk.CheckButton.with_label("Set Head");
                headcb.active = ((wpt.optional & WPEditMask.SETHEAD) == WPEditMask.SETHEAD);
                grid.attach (headcb, 0, j);

                txt = "%d".printf(wpt.heading);
                headent = new QEntry(txt, 3, Gtk.InputPurpose.DIGITS);
                grid.attach (headent, 1, j);

                j++;
                jumpcb = new Gtk.CheckButton.with_label("Jump to");
                jumpcb.active = ((wpt.optional & WPEditMask.JUMP) == WPEditMask.JUMP);
                grid.attach (jumpcb, 0, j);
                txt = "%d".printf(wpt.jump1);
                jump1ent = new QEntry(txt, 3, Gtk.InputPurpose.DIGITS);
				jump1ent.tooltip_text = "Enter the WP number of a valid, visible geographic WP. mwp will adjust the target number as required";
                grid.attach (jump1ent, 1, j);

                grid.attach (qlabel("Iterations"), 2, j);

                txt = "%d".printf(wpt.jump2);
                jump2ent = new QEntry(txt, 3, Gtk.InputPurpose.DIGITS);
                grid.attach (jump2ent, 3, j);

                j++;
                rthcb = new Gtk.CheckButton.with_label("RTH");
                rthcb.active = ((wpt.optional & WPEditMask.RTH) == WPEditMask.RTH);
                grid.attach (rthcb, 0, j);

                landcb = new Gtk.CheckButton.with_label("& Land");
                landcb.active = (wpt.rthland == 1);
                grid.attach (landcb, 1, j);
                amslcb.toggled.connect(() => {
                        if(wpt.elv.amsl0 != Hgt.NODATA) {
                            var na = DStr.strtod(altent.text, null);
                            if (amslcb.active) {
                                na = na + wpt.elv.amsl0;
                            } else {
                                na = na - wpt.elv.amsl0;
                            }
                            altent.text = "%.0f".printf(na);
                            set_alt_border(altent, false);
                        } else {
                            set_alt_border(altent, true);
                        }
                    });
            }
            j++;
            for(int k = 0; k < 4; k++) {
                wpaction[k] = new Gtk.CheckButton.with_label("Action #%d".printf(k+1));
                grid.attach (wpaction[k], k, j);
                wpaction[k].active = ((wpt.p3 & (1<<k+1)) != 0);
            }
        } else {
			j++;
			athomecb = new Gtk.CheckButton.with_label("At home");
			athomecb.active = false;
			grid.attach (athomecb, 0, j);
		}
    }

	public FWApproach.approach extract_land() {
		FWApproach.approach l = {};
		l.landalt = DStr.strtod(landent.text, null);
		l.appalt = DStr.strtod(appalt.text, null);
		l.dirn1 = (int16) int.parse(fwdirn1.text);
		l.ex1 = ex1.active;
		l.dirn2 = (int16) int.parse(fwdirn2.text);
		l.ex2 = ex2.active;
		l.aref = amslcb.active;
		l.dref = (dref_combo.selected == 1);
		return l;
	}

	void set_alt_border(Gtk.Widget w, bool flag) {
        string css;
        if (flag) {
            css =  "entry { border-style: solid; border-color: red; border-width: 1px;}";
        } else {
            css =  "entry { border-style: solid; border-color: orange; border-width: 1px;}";
        }
		var provider = new CssProvider();
		provider.load_from_string(css);
		w.get_style_context().add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
    }
}
