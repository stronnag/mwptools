using Gtk;

public enum WPEditMask {
    SETHEAD = 1,
    JUMP = 2,
    RTH = 4
}

public struct EditItem {
    double p1;
    double p2;
    int no;
    int alt;
    int p3;
    int jump1;
    int jump2;
    int heading;
    int rthland;
    int amsl;
    int homeelev;
    MSP.Action action;
    uint8 flag;
    uint8 optional;
}

private class QLabel : Gtk.Label {
    public QLabel(string? s) {
        label = s;
        hexpand = false;
        halign = Gtk.Align.START;
        expand = false;
    }
}

private class QEntry : Gtk.Entry {
    public QEntry(string? etext, int len, Gtk.InputPurpose pp) {
        hexpand = false;
        halign = Gtk.Align.START;
        expand = false;
        input_purpose = pp;
        text=etext;
        width_chars = len;
    }
}

public class WPPopEdit : Gtk.Dialog {
    private Gtk.Box vbox;
    private Gtk.ComboBoxText wp_combo;
    private Gtk.Grid  grid0;
    private Gtk.Grid  grid;
    private string pos;
    private QEntry altent;
    private Gtk.CheckButton amslcb;
    private Gtk.CheckButton fbhcb;
    private QEntry speedent;
    private QEntry loiterent;
    private QEntry landent;
    private Gtk.CheckButton headcb;
    private QEntry headent;
    private Gtk.CheckButton jumpcb;
    private QEntry jump1ent;
    private QEntry jump2ent;
    private Gtk.CheckButton rthcb;
    private Gtk.CheckButton landcb;
    private Gtk.CheckButton wpaction[4];

    public WPPopEdit(Gtk.Window? window, string posit) {
        pos = posit;
        title = "WP Edit";
        add_button("Apply", Gtk.ResponseType.OK);
        set_position(Gtk.WindowPosition.MOUSE);
		//        set_transient_for(window);
        set_keep_above(true);
        build_box();
        var content = get_content_area ();
        content.pack_start (vbox, false, false, 0);
    }

    public void wpedit(EditItem wpt) {
        add_grid(wpt);
        show_all();
    }

    private QLabel qlabel(string? s) {
        return new QLabel(s);
    }

    private void build_box() {
        vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
        vbox.border_width = 2;
        wp_combo = new Gtk.ComboBoxText();
        wp_combo.hexpand = true;
        wp_combo.append("1", "WAYPOINT");
        wp_combo.append("2", "POSHOLD UNLIM");
        wp_combo.append("3", "POSHOLD TIME");
        wp_combo.append("5", "SET_POI");
        wp_combo.append("8", "LAND");

        grid0 = new Gtk.Grid();
        grid0.column_homogeneous = false;
        grid0.set_column_spacing (2);
        grid0.attach (wp_combo, 0, 1, 1, 1);
        grid = new Gtk.Grid();
        grid.column_homogeneous = true;
        grid.hexpand = false;
        vbox.pack_start (grid0, false, false, 0);
        vbox.pack_start (grid, false, false, 0);
    }

    private void add_grid(EditItem wpt) {
        bool isset = false;
        wp_combo.changed.connect(() => {
                if(isset) {
                    var no = wpt.no;
                    extract_data(wpt.action, ref wpt);
                    wpt.no = no;
                    refresh_grid(wpt);
                }
            });
        refresh_grid(wpt);
        isset = true;
    }

    private void extract_basic(MSP.Action act, ref EditItem wpt) {
        wpt.alt = int.parse(altent.text);
        wpt.p3 = 0;

        if (amslcb.active) {
            wpt.p3 |= 1;
        }
        wpt.flag = (fbhcb.active) ? 72 : 0;

        if(act == MSP.Action.POSHOLD_TIME) {
            wpt.p2 = double.parse(speedent.text);
            wpt.p1 = double.parse(loiterent.text);
        } else {
            wpt.p1 = double.parse(speedent.text);
            wpt.p2 = 0;
        }

        if(act == MSP.Action.LAND) {
            wpt.p2 = double.parse(landent.text);
        } else {
            wpt.optional = 0;
            if(headcb.active) {
                wpt.optional |= WPEditMask.SETHEAD;
            }
            wpt.heading = int.parse(headent.text);

            if(jumpcb.active) {
                wpt.optional |= WPEditMask.JUMP;
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

    public void extract_data(MSP.Action oldact, ref EditItem wpt) {
        string nstr;
        MSP.Action nv;
        if (oldact == MSP.Action.UNKNOWN) {
            nstr = wp_combo.get_active_id();
            nv = (MSP.Action)(int.parse(nstr));
        } else {
            nv = oldact;
        }

        switch(nv) {
        case MSP.Action.WAYPOINT:
        case MSP.Action.POSHOLD_UNLIM:
        case MSP.Action.POSHOLD_TIME:
        case MSP.Action.LAND:
            extract_basic(nv, ref wpt);
            break;
        default:
            break;
        }
        nstr = wp_combo.get_active_id();
        nv = (MSP.Action)(int.parse(nstr));
        wpt.action = nv;
    }

    private void refresh_grid(EditItem wpt) {
        grid.foreach ((element) => grid.remove (element));
        wp_combo.active_id = ((int)wpt.action).to_string();
        title = "WP Edit #%d".printf(wpt.no);
        switch(wpt.action) {
        case MSP.Action.WAYPOINT:
        case MSP.Action.POSHOLD_UNLIM:
        case MSP.Action.POSHOLD_TIME:
        case MSP.Action.SET_POI:
        case MSP.Action.LAND:
            set_base_elements(wpt);
            break;
        default:
            break;
        }
        grid.show_all();
    }

    private void set_base_elements(EditItem wpt) {
        int j = 0;
        Gtk.Label posl;
        string txt;

        grid.attach (qlabel("Position"), 0, j);
        posl = new QLabel(pos);
        posl.show();
        grid.attach (posl, 1, j, 2);

        if (wpt.action != MSP.Action.SET_POI) {
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
            if(wpt.action == MSP.Action.POSHOLD_TIME) {
                txt = "%.1f".printf(wpt.p2);
            } else {
                txt = "%.1f".printf(wpt.p1);
            }
            speedent = new QEntry(txt, 7, Gtk.InputPurpose.NUMBER);
            grid.attach (speedent, 1, j);

            if(wpt.action == MSP.Action.POSHOLD_TIME) {
                grid.attach (qlabel("Loiter Time"), 2, j);
                txt = "%.0f".printf(wpt.p1);
                loiterent = new QEntry(txt, 4, Gtk.InputPurpose.DIGITS);
                grid.attach (loiterent, 3, j);
            }
            if(wpt.action == MSP.Action.LAND) {
                grid.attach (qlabel("Land Altitude"), 2, j);
                txt = "%.0f".printf(wpt.p2);
                landent = new QEntry(txt, 5, Gtk.InputPurpose.DIGITS);
                grid.attach (landent, 3, j);
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
                amslcb.clicked.connect(() => {
                        if(wpt.homeelev != EvCache.EvConst.UNAVAILABLE) {
                            var na = int.parse(altent.text);
                            if (amslcb.active) {
                                na = na + wpt.homeelev;
                            } else {
                                na = na - wpt.homeelev;
                            }
                            altent.text = na.to_string();
                            set_alt_border(false);
                        } else {
                            set_alt_border(true);
                        }
                    });
            }
            j++;
            for(int k = 0; k < 4; k++) {
                wpaction[k] = new Gtk.CheckButton.with_label("Action #%d".printf(k+1));
                grid.attach (wpaction[k], k, j);
                wpaction[k].active = ((wpt.p3 & (1<<k+1)) != 0);
            }
        }
    }
    void set_alt_border(bool flag) {
        string css;
        if (flag) {
            css =  "entry { border-style: solid; border-color: red; border-width: 1px;}";
        } else {
            css =  "entry { border-style: solid; border-color: orange; border-width: 1px;}";
        }
        try {
            var provider = new CssProvider();
            provider.load_from_data(css);
            var stylec = altent.get_style_context();
            stylec.add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
        } catch (Error e) {
            MWPLog.message ("CSS: %s\n", e.message);
        };
    }
}
