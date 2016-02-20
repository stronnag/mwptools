
/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
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

public class Craft : GLib.Object
{
    private Champlain.Point ici;
    private Champlain.View view;
    private Champlain.Label icon;
    private Champlain.MarkerLayer layer;
    private bool norotate;
    private bool trail;
    private Champlain.PathLayer path;
    private Champlain.MarkerLayer pmlayer;
    private Champlain.MarkerLayer hmlayer;
    private int npath = 0;
    private static Clutter.Color trk_cyan = { 0,0xff,0xff, 0xa0 };
    private static Clutter.Color trk_green = { 0xce,0xff,0x9d, 0xa0 };
    private static Clutter.Color trk_yellow = { 0xff,0xff,0, 0xa0 };
    private static Clutter.Color trk_white = { 0xff,0xff,0xff, 0xa0 };
    private Clutter.Color path_colour;

    private static Champlain.Label homep ;
    private static Champlain.Label posp ;
    private static Champlain.Label rthp ;
    private static Champlain.Label wpp ;

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
        "Hex6P.png" // 18
    };

    public enum Special
    {
        HOME = -1,
        PH = -2,
        RTH = -3,
        WP = -4
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
    public Craft(Champlain.View _view, uint id, bool _norotate = false, bool _trail = true)
    {
        view = _view;
        norotate = _norotate;
        trail = _trail;

        if (id == icons.length)
        {
            id = 0;
        }
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

// Not properly implemented in (13.10 and earlier) Ubuntu
#if NOBB
#else
        icon.set_pivot_point(0.5f, 0.5f);
#endif
        icon.set_draw_background (false);
        park();

        layer.add_marker(ici);
        layer.add_marker (icon);
        icon.animate_in();
    }


    ~Craft()
    {
        layer.remove_marker(icon);
    }


    public void set_icon(uint id)
    {
        layer.remove_marker (icon);
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
// Not properly implemented in (13.10 and earlier) Ubuntu
#if NOBB
#else
        icon.set_pivot_point(0.5f, 0.5f);
#endif
        icon.set_draw_background (false);
        layer.add_marker (icon);
        icon.animate_in();
    }

    public void init_trail()
    {
        if(trail)
        {
            hmlayer.remove_all();
            pmlayer.remove_all();
            path.remove_all();
            npath = 0;
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
        set_pix_pos(40,40);
        if (norotate == false)
            icon.set_rotation_angle(Clutter.RotateAxis.Z_AXIS, 0);
        if(trail)
        {
            init_trail();
        }
    }


    public void get_pos(out double lat, out double lon)
    {
        lat = icon.get_latitude();
        lon = icon.get_longitude();
    }

    public void set_lat_lon (double lat, double lon, double cse)
    {
        if(trail)
        {
            Champlain.Point marker;
            marker = new Champlain.Point.full(5.0, path_colour);
            marker.set_location (lat,lon);
            pmlayer.add_marker(marker);
            path.add_node(marker);
            if(npath == 0)
            {
                path.add_node(marker);
                ici.show();
            }
            npath++;
        }
        ici.set_location (lat, lon);
        icon.set_location (lat, lon);
        if (norotate == false)
            icon.set_rotation_angle(Clutter.RotateAxis.Z_AXIS, cse);
    }

    public void set_pix_pos (int x, int y)
    {
        var lat = view.y_to_latitude(y);
        var lon = view.x_to_longitude(x);
        icon.set_location (lat, lon);
    }

    public void set_normal()
    {
        path_colour = trk_cyan;
    }

    public void special_wp(Special wpno, double lat, double lon)
    {
        Champlain.Label m = null;
        Clutter.Color colour;
        Clutter.Color black = { 0,0,0, 0xff };

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
                path_colour = trk_white;
                break;
            default:
                path_colour = trk_cyan;
                break;
        }
        if(m != null)
            m.set_location (lat, lon);
    }
}
