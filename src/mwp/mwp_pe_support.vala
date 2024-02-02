/*
 * Copyright (C) 2018 Jonathan Hudson <jh+mwptools@daria.co.uk>
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

public class FakeHome : GLib.Object {
    public enum USERS {
        None = 0,
        Mission = 1,
        Editor = 2,
        Terrain = 4,
        ElevMode = 8
    }

    public static USERS usedby = USERS.None;
    public static bool has_loc {private set; get;}
    public static double xlat {private set; get;}
    public static double xlon {private set; get;}

    public FakeHomeDialog fhd;
    private static Champlain.MarkerLayer hmlayer;
    public static Champlain.Label homep;
    public static bool is_visible = false;
    public signal void fake_move(double lat, double lon);
    public static  Champlain.Label? homept;

    public struct PlotElevDefs {
        string hstr;
        string margin;
        string rthalt;
    }

	public static Champlain.MarkerLayer get_hmlayer() {
		return hmlayer;
	}

    public FakeHome(Champlain.View view) {
        Clutter.Color brown = {0x8c, 0x43, 0x43, 0xa0};
        Clutter.Color white = { 0xff,0xff,0xff, 0xff};
        hmlayer = new Champlain.MarkerLayer();
        homep = new Champlain.Label.with_text ("⏏", "Sans 10",null,null);
        homep.set_alignment (Pango.Alignment.RIGHT);
        homep.set_color (brown);
        homep.set_text_color(white);
        homept = null;
        homep.enter_event.connect((ce) => {
                int elev;
                if(EvCache.get_elev(EvCache.EvConst.HOME, out elev)) {
                    if(homept == null) {
                        homept = new Champlain.Label.with_text("%dm".printf(elev), "Sans 10", null, null);
                        homept.set_color (brown);
                        homept.opacity = 200;
                        homept.x = 30;
                        homept.y = 10;
                        homep.add_child(homept);
                    }
                }
                return false;
            });

        homep.leave_event.connect((ce) => {
                if(homept != null) {
                    homep.remove_child(homept);
                    homept = null;
                }
                return false;
            });

        homep.drag_motion.connect((dx,dy,evt) => {
                if(homept != null) {
                    homep.remove_child(homept);
                    homept = null;
                }
                xlat = homep.get_latitude();
                xlon = homep.get_longitude();
                fake_move(xlat, xlon);
            });

        view.add_layer (hmlayer);
    }

    public void create_dialog(Gtk.Builder b, Gtk.Window? w) {
        fhd = new FakeHomeDialog(b, w);
        read_defaults();
    }

    private void parse_delim(string fn, ref PlotElevDefs p) {
        var file = File.new_for_path(fn);
        try {
            var dis = new DataInputStream(file.read());
            string line;
            while ((line = dis.read_line (null)) != null) {
                if(line.strip().length > 0 &&
                   !line.has_prefix("#") &&
                   !line.has_prefix(";")) {
                    var parts = line.split_set("=");
                    if(parts.length == 2) {
                        var str = parts[1].strip();
                        switch(parts[0].strip()) {
                            case "home":
//                                p.hstr = str;
                                break;
                            case "margin":
                                p.margin = str;
                                break;
                            case "rth-alt":
                                p.rthalt = str;
                                break;
                        }
                    }
                }
            }
        } catch (Error e) {
            error ("%s", e.message);
        }
    }

    public PlotElevDefs read_defaults() {
        PlotElevDefs p = PlotElevDefs();
        string fn;

        if((fn = MWPUtils.find_conf_file("elev-plot")) != null) {
            parse_delim(fn, ref p);
        }
        return p;
    }

	public void freeze_home(bool act) {
		homep.set_draggable(act);
		homep.set_reactive(act);
	}

	public void show_fake_home(bool state) {
        if(state != is_visible) {
            if(state) {
                homep.set_draggable(true);
                homep.set_selectable(true);
                homep.set_flags(ActorFlags.REACTIVE);
                hmlayer.add_marker(homep);
                var pp = hmlayer.get_parent();
                pp.set_child_above_sibling(hmlayer, null);
            }
            else
                hmlayer.remove_marker(homep);
            is_visible = state;
        }
    }

    public void set_fake_home(double lat, double lon) {
        has_loc = true;
        homep.set_location (lat, lon);
        EvCache.update_single_elevation(EvCache.EvConst.HOME, lat, lon);
        xlat = lat;
        xlon = lon;
    }

    public void get_fake_home(out double lat, out double lon) {
        lat = xlat; //homep.get_latitude();
        lon = xlon; //homep.get_longitude();
    }

    public void reset_fake_home() {
        if(!is_visible) {
            has_loc = false;
            xlat = 0.0;
            xlon = 0.0;
        }
    }
}

public class FakeHomeDialog : GLib.Object {
    private Gtk.Window pe_dialog;
    private Gtk.Entry pe_home_text;
    private Gtk.Entry pe_margin;
    private Gtk.Entry pe_rthalt;
    private Gtk.Entry pe_climb;
    private Gtk.Entry pe_dive;
    private Gtk.CheckButton pe_replace;
    private Gtk.CheckButton pe_land;
    private Gtk.ComboBoxText pe_altmode;
    private Gtk.Button pe_close;
    private Gtk.Button pe_ok;
    private bool visible = false;

    public signal void ready(bool state);

    public FakeHomeDialog (Gtk.Builder builder, Gtk.Window? w) {
		pe_dialog = builder.get_object ("pe-dialog") as Gtk.Window;
        pe_home_text = builder.get_object ("pe-home-text") as Gtk.Entry;
        pe_margin = builder.get_object ("pe-clearance") as Gtk.Entry;
        pe_rthalt = builder.get_object ("pe-rthalt") as Gtk.Entry;
        pe_replace = builder.get_object ("pe-replace") as Gtk.CheckButton;
        pe_land = builder.get_object ("pe-land") as Gtk.CheckButton;
        pe_altmode = builder.get_object ("pe-altmode") as Gtk.ComboBoxText;
        pe_close = builder.get_object ("pe-close") as Gtk.Button;
        pe_ok = builder.get_object ("pe-ok") as Gtk.Button;
        pe_climb = builder.get_object ("pe-climb") as Gtk.Entry;
        pe_dive = builder.get_object ("pe-dive") as Gtk.Entry;

        pe_land.sensitive = false;
        pe_altmode.sensitive = false;
        pe_climb.sensitive = pe_dive.sensitive = false;

		pe_dialog.set_transient_for(w);
		pe_dialog.set_keep_above(true);
        pe_dialog.delete_event.connect (() => {
                dismiss();
                ready(false);
                return true;
            });

        pe_close.clicked.connect (() => {
                get_climb_opts();
                dismiss();
                ready(false);
            });

        pe_ok.clicked.connect (() => {
                get_climb_opts();
                ready(true);
            });

        set_climb_opts();
	}

    private void get_climb_opts() {
        MWP.conf.maxclimb = double.parse(pe_climb.text);
        if (MWP.conf.maxclimb < 0.0)
            MWP.conf.maxclimb = -MWP.conf.maxclimb;
        MWP.conf.settings.set_double("max-climb-angle", MWP.conf.maxclimb);

        MWP.conf.maxdive = double.parse(pe_dive.text);
        if (MWP.conf.maxdive > 0.0)
            MWP.conf.maxdive = -MWP.conf.maxdive;
        MWP.conf.settings.set_double("max-dive-angle", MWP.conf.maxdive);
    }

    private void set_climb_opts() {
        if (MWP.conf.maxclimb < 0.0)
            MWP.conf.maxclimb = -MWP.conf.maxclimb;
        if (MWP.conf.maxdive  > 0.0)
            MWP.conf.maxdive = -MWP.conf.maxdive;
        pe_climb.text = "%.1f".printf(MWP.conf.maxclimb);
        pe_dive.text = "%.1f".printf(MWP.conf.maxdive);
    }

    public void set_pos(string s) {
        pe_home_text.text = s;
        pe_ok.sensitive = true;
    }

    public string get_pos() {
        return pe_home_text.text;
    }

    public void set_margin(int d) {
        pe_margin.text = "%d".printf(d);
    }

    public int get_margin() {
        return int.parse(pe_margin.text);
    }

    public void set_rthalt(int d) {
        pe_rthalt.text = "%d".printf(d);
    }

    public int get_rthalt() {
        return int.parse(pe_rthalt.text);
    }

    public bool get_replace() {
        return pe_replace.active;
    }

    public bool get_land() {
        return pe_land.active;
    }

    public void set_land_sensitive(bool sens) {
        pe_land.sensitive = sens;
    }

    public int get_altmode() {
        return int.parse(pe_altmode.active_id);
    }

    public void set_altmode_sensitive(bool sens) {
        pe_altmode.sensitive = pe_climb.sensitive = pe_dive.sensitive = sens;
    }

    public void unhide() {
        visible = true;
        pe_dialog.show_all();
    }

    public void dismiss() {
        visible=false;
        pe_dialog.hide();
    }
}
