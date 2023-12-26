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

public class FollowMePoint : GLib.Object {
    public static double xlat {private set; get;}
    public static double xlon {private set; get;}

    private static Champlain.MarkerLayer fmlayer;
    public static Champlain.Label fmpt;
    public static bool is_visible = false;
    public static bool has_loc = false;
    public signal void fmpt_move(double lat, double lon);

	public static Champlain.MarkerLayer get_fmlayer() {
		return fmlayer;
	}

    public FollowMePoint(Champlain.View view) {
        Clutter.Color green = {0x4c, 0xc0, 0x10, 0xa0};
        Clutter.Color white = { 0xff,0xff,0xff, 0xff};
        fmlayer = new Champlain.MarkerLayer();
        fmpt = new Champlain.Label.with_text ("⨁", "Sans 10",null,null);
        fmpt.set_alignment (Pango.Alignment.RIGHT);
        fmpt.set_color (green);
        fmpt.set_text_color(white);
        fmpt.drag_motion.connect((dx,dy,evt) => {
                xlat = fmpt.get_latitude();
                xlon = fmpt.get_longitude();
                fmpt_move(xlat, xlon);
            });
        view.add_layer (fmlayer);
    }

    public void show_followme(bool state) {
        if(state != is_visible) {
            if(state) {
                fmpt.set_draggable(true);
                fmpt.set_selectable(true);
                fmpt.set_flags(ActorFlags.REACTIVE);
                fmlayer.add_marker(fmpt);
                var pp = fmlayer.get_parent();
                pp.set_child_above_sibling(fmlayer, null);
            } else {
                fmlayer.remove_marker(fmpt);
            }
            is_visible = state;
        }
    }

    public void set_followme(double lat, double lon) {
        has_loc = true;
        fmpt.set_location (lat, lon);
        xlat = lat;
        xlon = lon;
        fmpt_move(xlat, xlon);
    }

    public void get_followme(out double lat, out double lon) {
        lat = xlat;
        lon = xlon;
    }

    public bool has_location() {
        return has_loc;
    }

    public void reset_followmwe() {
        if(!is_visible) {
            has_loc = false;
            xlat = 0.0;
            xlon = 0.0;
        }
    }
}

public class FollowMeDialog : GLib.Object {
    private Gtk.Dialog dialog;
    private Gtk.Label label;
    private Gtk.Button ok;
    private Gtk.Button clear;
    private Gtk.SpinButton altspin;
    private bool visible = false;

    public signal void ready(int state, int alt);

    public FollowMeDialog (Gtk.Builder builder, Gtk.Window? w) {
        dialog = builder.get_object ("fm-dialog") as Gtk.Dialog;
        ok = builder.get_object ("fm-ok") as Gtk.Button;
        clear = builder.get_object ("fm-clear") as Gtk.Button;
        label = builder.get_object ("fm-label") as Gtk.Label;
        altspin = builder.get_object ("fm-spin-alt") as Gtk.SpinButton;

		//        dialog.set_transient_for(w);

        dialog.delete_event.connect (() => {
                dismiss();
                ready(0,0);
                return true;
            });

        clear.clicked.connect (() => {
                dismiss();
                ready(1,0);
            });

        ok.clicked.connect (() => {
                int altval = (int)altspin.adjustment.value;
                dismiss();
                ready(2,altval);
            });
    }


    public void unhide() {
        visible = true;
        dialog.show_all();
    }

    public void dismiss() {
        visible=false;
        dialog.hide();
    }

    public void set_label(string ltext) {
        label.label = ltext;
    }

}
