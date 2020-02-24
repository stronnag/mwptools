
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

/* Layer usage
   path     : craft movement (grey path, coloured dots)
   layer    : craft icon
   pmlayer  : special points (home, RTH, WP start)
   hmlayer  : home position marker
*/

using Gtk;
using Clutter;
using Champlain;
using GtkChamplain;

public class Craft : GLib.Object
{
    private Champlain.Point ici;
    private Champlain.View view;
    private Champlain.Label icon;
    private Champlain.MarkerLayer layer;
    private bool trail;
    private Champlain.PathLayer path;
    private Champlain.MarkerLayer pmlayer;
    private Champlain.MarkerLayer hmlayer;
    private int npath = 0;
    private int mpath = 0;
    private static Clutter.Color trk_cyan =   { 0x00, 0xff, 0xff, 0xa0 };
    private static Clutter.Color trk_green =  { 0xce, 0xff, 0x9d, 0xa0 };
    private static Clutter.Color trk_yellow = { 0xff, 0xff, 0x00, 0xa0 };
    private static Clutter.Color trk_white =  { 0xff, 0xff, 0xff, 0xa0 };
    private static Clutter.Color trk_altblue = { 0x03, 0xc0, 0xfa, 0xa0 };
    private static Clutter.Color trk_purple = { 0xbf, 0x88, 0xf7, 0xa0 };

    private Clutter.Color path_colour;

    private static Champlain.Label homep ;
    private static Champlain.Label posp ;
    private static Champlain.Label rthp ;
    private static Champlain.Label wpp ;
    private int stack_size = 0;
    private int mod_points = 0;

    public enum Vehicles
    {
        ARROW = 0,
        TRI = 1,
        QUADP = 2,
        QUADX = 3,
        BICOPTER = 4,
        GIMBAL = 5,
        Y6 = 6,
        HEX6 = 7,
        FLYING_WING = 8,
        Y4 = 9,
        HEX6X = 10,
        OCTOX8 = 11,
        OCTOFLATP = 12,
        OCTOFLATX = 13,
        AIRPLANE = 14,
        HELI_120_CCPM = 15,
        HELI_90_DEG = 16,
        VTAIL4 = 17,
        HEX6H = 18,
        PPM_TO_SERVO = 19,
        DUALCOPTER = 20,
        SINGLECOPTER = 21,
        ATAIL4 = 22,
        CUSTOM = 23,
        CUSTOM_AIRPLANE = 24,
        CUSTOM_TRI = 25,
        PREVIEW = 26,
        LAST
    }

    private static string[] icons =
    {
        "arrow.png", //0
        "Tri.png",   //1
        "QuadP.png", // 2
        "QuadX.png", // 3
        "Bi.png", // 4
        "QuadX.png", // 5
        "Y6.png", // 6
        "Hex6P.png", // 7
        "Flying_Wing.png", // 8
        "Y4.png", // 9
        "Hex6X.png", // 10
        "OctoX8.png", //11
        "OctoFlatP.png", // 12
        "OctoFlatX.png", // 13
        "Airplane.png", // 14
        "Heli.png", // 15
        "Heli.png", // 16
        "V-Tail4.png", // 17
        "Hex6P.png", // 18
        "QuadX.png", // 19
        "Heli.png", // 20
        "Heli.png", // 21
        "QuadX.png", // 22
        "QuadX.png", // 23
        "Airplane.png", // 24
        "Tri.png",   //25
        "preview.png" //26
    };

    public enum Special
    {
        HOME = -1,
        PH = -2,
        RTH = -3,
        WP = -4,
        ALTH = -5,
        CRUISE = -6
    }

    public enum RMIcon
    {
        PH = 1,
        RTH = 2,
        WP = 4,
        ALL = 7
    }

/*
  // sadly, clutter appears not to support this
    private string get_icon_resource(uint id)
    {
        StringBuilder sb = new StringBuilder ();
        sb.append("resource://org/mwptools/mwp/pixmaps/");
        sb.append(icons[id]);
        return sb.str;
    }
*/

    public void adjust_z_order(Champlain.Layer l)
    {
         var pp = l.get_parent();
         pp.set_child_above_sibling(l, path);
         pp.set_child_above_sibling(l, pmlayer);
    }

    public Craft(Champlain.View _view, uint id, bool _trail = true, int _ss = 0, int _mp = 0)
    {
        stack_size = _ss;
        mod_points = _mp;
        view = _view;
        trail = _trail;

        if(id >= Craft.Vehicles.LAST)
            id = Craft.Vehicles.QUADX;
        var iconfile = MWPUtils.find_conf_file(icons[id], "pixmaps");
        try {
            icon = new Champlain.Label.from_file (iconfile);
        } catch (GLib.Error e) {
            GLib.warning ("ICON: %s", e.message);
            Clutter.Color colour = {0xff, 0xb7, 0x22, 0xff};
            Clutter.Color black = { 0,0,0, 0xff };
            icon = new Champlain.Label.with_text ("⌖","Sans 24",null,null);
            icon.set_alignment (Pango.Alignment.RIGHT);
            icon.set_color (colour);
            icon.set_text_color(black);
        }

        Clutter.Color red = { 0xff,0,0, 0xff};
        ici = new Champlain.Point.full(15.0, red);
        path = new Champlain.PathLayer();
        path_colour = trk_cyan;

        Clutter.Color ladyjane = { 0xa0,0xa0,0xa0, 0xa0 };
        path.set_stroke_color(ladyjane);
        path.set_stroke_width (4);

        layer = new Champlain.MarkerLayer();
        hmlayer = new Champlain.MarkerLayer();
        pmlayer = new Champlain.MarkerLayer();

        if(trail)
        {
            view.add_layer (path);
            view.add_layer (hmlayer);
            view.add_layer (pmlayer);
        }
        view.add_layer (layer);
        homep = posp = rthp = wpp = null;

        icon.set_pivot_point(0.5f, 0.5f);
        icon.set_draw_background (false);
        park();

        if(id != Vehicles.PREVIEW)
            layer.add_marker(ici);
        layer.add_marker (icon);
    }


    ~Craft()
    {
        layer.remove_marker(icon);
    }

    public static bool is_fw(uint id)
    {
        return !Craft.is_mr(id);
    }

    public static  bool is_mr(uint id)
    {
        return !(id == Vehicles.FLYING_WING ||
                 id ==Vehicles. AIRPLANE ||
                 id == Vehicles.CUSTOM_AIRPLANE);
    }

    public void set_icon(uint id)
    {
        layer.remove_marker (icon);
        if(id >= Craft.Vehicles.LAST)
            id = Craft.Vehicles.QUADX;
        var iconfile = MWPUtils.find_conf_file(icons[id], "pixmaps");
        try {
            icon = new Champlain.Label.from_file (iconfile);
        } catch (GLib.Error e) {
            GLib.warning ("ICON: %s", e.message);
            Clutter.Color colour = {0xff, 0xb7, 0x22, 0xff};
            Clutter.Color black = { 0,0,0, 0xff };
            icon = new Champlain.Label.with_text ("⌖","Sans 24",null,null);
            icon.set_alignment (Pango.Alignment.RIGHT);
            icon.set_color (colour);
            icon.set_text_color(black);
        }
        icon.set_pivot_point(0.5f, 0.5f);
        icon.set_draw_background (false);
        layer.add_marker (icon);
    }

    public void init_trail()
    {
        if(trail)
        {
            hmlayer.remove_all();
            pmlayer.remove_all();
            path.remove_all();
            npath = 0;
            mpath = 0;
            homep = posp = rthp = wpp = null;
            ici.hide();
        }
    }

    public void remove_marker()
    {
        park();
    }

    public void park()
    {
        set_pix_pos(icon, 40,40);
        icon.set_rotation_angle(Clutter.RotateAxis.Z_AXIS, 0);
        init_trail();
    }

    public void get_pos(out double lat, out double lon)
    {
        lat = icon.get_latitude();
        lon = icon.get_longitude();
    }

    public void set_lat_lon (double lat, double lon, double cse)
    {
        if(npath == 0)
        {
            ici.show();
        }
        if(trail)
        {
            Champlain.Point marker;
            marker = new Champlain.Point.full(5.0, path_colour);
            marker.set_location (lat,lon);
            if(mod_points == 0 || (npath % mod_points) == 0)
            {
                pmlayer.add_marker(marker);
                if(stack_size > 0)
                {
                    mpath++;
                    if(mpath > stack_size)
                    {
                        var nds = pmlayer.get_markers();
                        pmlayer.remove_marker(nds.last().data);
                        mpath--;
                    }
                }
                path.add_node(marker);
            }
        }
        ici.set_location (lat, lon);
        icon.set_location (lat, lon);
        icon.set_rotation_angle(Clutter.RotateAxis.Z_AXIS, cse);
        npath++;
    }

    private void set_pix_pos (Champlain.Label l, int x, int y)
    {
        var lat = view.y_to_latitude(y);
        var lon = view.x_to_longitude(x);
        l.set_location (lat, lon);
    }

    public void set_normal()
    {
//        MWPLog.message("craft: set normal\n");
        remove_special(RMIcon.ALL);
    }

    public void remove_special(RMIcon rmflags)
    {
//        MWPLog.message("craft: remove special %x\n", rmflags);
        if(((rmflags & RMIcon.PH) != 0) && posp != null)
        {
            pmlayer.remove_marker(posp);
            posp = null;
        }
        if(((rmflags & RMIcon.RTH) != 0) && rthp != null)
        {
            pmlayer.remove_marker(rthp);
            rthp = null;
        }
        if(((rmflags & RMIcon.WP) != 0) && wpp != null)
        {
            pmlayer.remove_marker(wpp);
            wpp = null;
        }
        if(rmflags == RMIcon.ALL)
            path_colour = trk_cyan;
    }

    public void special_wp(Special wpno, double lat, double lon)
    {
        Champlain.Label m = null;
        Clutter.Color colour;
        Clutter.Color black = { 0,0,0, 0xff };
        RMIcon rmflags = 0;

        switch(wpno)
        {
            case Special.HOME:
                if(homep == null)
                {
                    homep = new Champlain.Label.with_text ("⏏", "Sans 10",null,null);
                    homep.set_alignment (Pango.Alignment.RIGHT);
                    colour = {0xff, 0xa0, 0x0, 0xc8};
                    homep.set_color (colour);
                    homep.set_text_color(black);
                    hmlayer.add_marker(homep);
                }
                m = homep;
                break;
            case Special.PH:
                if(posp == null)
                {
                    posp = new Champlain.Label.with_text ("∞", "Sans 10",null,null);
                    posp.set_alignment (Pango.Alignment.RIGHT);
                    colour = { 0x4c, 0xfe, 0, 0xc8};
                    posp.set_color (colour);
                    posp.set_text_color(black);
                    pmlayer.add_marker(posp);
                }
                m = posp;
                rmflags = RMIcon.RTH|RMIcon.WP;
                path_colour = trk_green;
                break;
            case Special.RTH:
                if(rthp == null)
                {
                    rthp = new Champlain.Label.with_text ("⚑", "Sans 10",null,null);
                    rthp.set_alignment (Pango.Alignment.RIGHT);
                    colour = { 0xfa, 0xfa, 0, 0xc8};
                    rthp.set_color (colour);
                    rthp.set_text_color(black);
                    pmlayer.add_marker(rthp);
                }
                m = rthp;
                rmflags = RMIcon.PH|RMIcon.WP;
                path_colour = trk_yellow;
                break;
            case Special.WP:
                if(wpp == null)
                {
                    wpp = new Champlain.Label.with_text ("☛", "Sans 10",null,null);
                    wpp.set_alignment (Pango.Alignment.RIGHT);
                    colour = { 0xff, 0xff, 0xff, 0xff};
                    wpp.set_color (colour);
                    wpp.set_text_color(black);
                    pmlayer.add_marker(wpp);
                }
                m = wpp;
                rmflags = RMIcon.PH|RMIcon.RTH;
                path_colour = trk_white;
                break;
            case Special.ALTH:
                path_colour = trk_altblue;
                break;
            case Special.CRUISE:
                path_colour = trk_purple;
                break;
            default:
                path_colour = trk_cyan;
                rmflags = RMIcon.ALL;
                break;
        }
        if(rmflags != 0)
            remove_special(rmflags);
        if(m != null)
            m.set_location (lat, lon);
    }
}
