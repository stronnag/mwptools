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

public class FakeHome : GLib.Object
{
    public FakeHomeDialog fhd;
    private Champlain.MarkerLayer hmlayer;
    private static Champlain.Label homep ;
    public bool is_visible = false;
    public signal void fake_move(double lat, double lon);

    public struct PlotElevDefs
    {
        string hstr;
        string margin;
    }

    public FakeHome(Champlain.View view)
    {
        Clutter.Color colour = {0x8c, 0x43, 0x43, 0xc8};
        Clutter.Color white = { 0xff,0xff,0xff, 0xff};
        hmlayer = new Champlain.MarkerLayer();
        homep = new Champlain.Label.with_text ("⏏", "Sans 10",null,null);
        homep.set_alignment (Pango.Alignment.RIGHT);
        homep.set_color (colour);
        homep.set_text_color(white);
        view.add_layer (hmlayer);
    }

    public void create_dialog(Gtk.Builder b, Gtk.Window? w)
    {
        fhd = new FakeHomeDialog(b, w);
    }

    private void parse_delim(string fn, ref PlotElevDefs p)
    {
        var file = File.new_for_path(fn);
        try {
            var dis = new DataInputStream(file.read());
            string line;
            while ((line = dis.read_line (null)) != null)
            {
                if(line.strip().length > 0 &&
                   !line.has_prefix("#") &&
                   !line.has_prefix(";"))
                {
                    var parts = line.split_set("=");
                    if(parts.length == 2)
                    {
                        switch(parts[0].strip())
                        {
                            case "home":
                                p.hstr = parts[1].strip();
                                break;
                            case "margin":
                                p.margin = parts[1].strip();
                                break;
                        }
                    }
                }
            }
        } catch (Error e) {
            error ("%s", e.message);
        }
    }

    public PlotElevDefs read_defaults()
    {
        PlotElevDefs p = PlotElevDefs(){hstr=null, margin=null};
        string fn;

        if((fn = MWPUtils.find_conf_file("elev-plot")) != null)
        {
            parse_delim(fn, ref p);
        }
        return p;
    }

    public void show_fake_home(bool state)
    {
        is_visible = state;
        if(state)
        {
            homep.set_draggable(true);
            homep.set_selectable(true);
            homep.set_flags(ActorFlags.REACTIVE);
            hmlayer.add_marker(homep);
            homep.drag_motion.connect((dx,dy,evt) => {
                    fake_move(homep.get_latitude(),homep.get_longitude());
                });
        }
        else
            hmlayer.remove_marker(homep);
    }

    public void set_fake_home(double lat, double lon)
    {
        homep.set_location (lat, lon);
    }

    public void get_fake_home(out double lat, out double lon)
    {
        lat = homep.get_latitude();
        lon = homep.get_longitude();
    }
}

public class FakeHomeDialog : GLib.Object
{
    private Gtk.Dialog pe_dialog;
    private Gtk.Entry pe_home_text;
    private Gtk.Entry pe_margin;
    private Gtk.CheckButton pe_replace;
    private Gtk.Button pe_close;
    private Gtk.Button pe_ok;
    private bool visible = false;

    public signal void ready(bool state);

    public FakeHomeDialog (Gtk.Builder builder, Gtk.Window? w)
    {
        pe_dialog = builder.get_object ("pe-dialog") as Gtk.Dialog;
        pe_home_text = builder.get_object ("pe-home-text") as Gtk.Entry;
        pe_margin = builder.get_object ("pe-clearance") as Gtk.Entry;
        pe_replace = builder.get_object ("pe-replace") as Gtk.CheckButton;
        pe_close = builder.get_object ("pe-close") as Gtk.Button;
        pe_ok = builder.get_object ("pe-ok") as Gtk.Button;

        pe_dialog.set_transient_for(w);

        pe_dialog.delete_event.connect (() => {
                dismiss();
                ready(false);
                return true;
            });

        pe_close.clicked.connect (() => {
                dismiss();
                ready(false);
            });

        pe_ok.clicked.connect (() => {
                ready(true);
            });
    }

    public void set_pos(string s)
    {
        pe_home_text.text = s;
        pe_ok.sensitive = true;
    }

    public string get_pos()
    {
        return pe_home_text.text;
    }

    public void set_elev(int d)
    {
        pe_margin.text = "%d".printf(d);
    }

    public int get_elev()
    {
        return int.parse(pe_margin.text);
    }

    public bool get_replace()
    {
        return pe_replace.active;
    }

    public void unhide()
    {
        visible = true;
        pe_dialog.show_all();
    }

    public void dismiss()
    {
        visible=false;
        pe_dialog.hide();
    }
}
