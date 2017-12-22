
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

public class MWPMarkers : GLib.Object
{
    public  Champlain.PathLayer path;
    public Champlain.MarkerLayer markers;
    public Champlain.MarkerLayer rlayer;
    public Champlain.Marker homep = null;
    public Champlain.Marker rthp = null;
    public Champlain.Point posring = null;
    public Champlain.PathLayer hpath;
    private Champlain.PathLayer []rings;
    private bool rth_land;

    private Gtk.Menu menu;

    public MWPMarkers(ListBox lb, Champlain.View view, string mkcol ="#ffffff60")
    {
        rth_land = false;
        markers = new Champlain.MarkerLayer();
        rlayer = new Champlain.MarkerLayer();
        path = new Champlain.PathLayer();
        hpath = new Champlain.PathLayer();

        view.add_layer(rlayer);
        view.add_layer(path);
        view.add_layer(hpath);
        view.add_layer(markers);

        List<uint> llist = new List<uint>();
        llist.append(10);
        llist.append(5);
        Clutter.Color orange = {0xff, 0xa0, 0x0, 0x80};
        hpath.set_stroke_color(orange);
        hpath.set_dash(llist);
        hpath.set_stroke_width (8);

        Clutter.Color rcol = {0xff, 0x0, 0x0, 0x80};
        path.set_stroke_color(rcol);
        path.set_stroke_width (8);

        menu =   new Gtk.Menu ();
        var item = new Gtk.MenuItem.with_label ("Delete");
        item.activate.connect (() => {
                lb.menu_delete();
            });
        menu.add (item);

        var sep = new Gtk.SeparatorMenuItem ();
        menu.add (sep);

        item = new Gtk.MenuItem.with_label ("Waypoint");
        item.activate.connect (() => {
                lb.change_marker("WAYPOINT");
            });
        menu.add (item);
        item = new Gtk.MenuItem.with_label ("PH unlimited");
        item.activate.connect (() => {
                lb.change_marker("POSHOLD_UNLIM");
            });
        menu.add (item);
        item = new Gtk.MenuItem.with_label ("PH Timed");
        item.activate.connect (() => {
                lb.change_marker("POSHOLD_TIME");
            });
        menu.add (item);
        item = new Gtk.MenuItem.with_label ("RTH");
        item.activate.connect (() => {
                lb.change_marker("RTH");
            });
        menu.add (item);
        menu.show_all();

        var colour = Color.from_string(mkcol);
        posring = new Champlain.Point.full(80.0, colour);
        rlayer.add_marker(posring);
    }

    public void set_rth_icon(bool iland)
    {
        rth_land = iland;
    }

    private void get_text_for(MSP.Action typ, string no, out string text,
                              out  Clutter.Color colour, bool nrth=false)
    {
        string symb;
        switch (typ)
        {

            case MSP.Action.WAYPOINT:
                if(nrth)
                {
                    colour = { 0, 0xaa, 0xff, 0xc8};
                        // nice to set different icon for land ⛳ or ⏬
//                    symb = (rth_land) ? "⏬WP" : "⏏WP";
                    symb = (rth_land) ? "▼WP" : "⏏WP";
                }
                else
                {
                    symb = "WP";
                    colour = { 0, 0xff, 0xff, 0xc8};
                }
                break;

            case MSP.Action.POSHOLD_TIME:
                symb = "◷";
                colour = { 152, 70, 234, 0xc8};
                break;

            case MSP.Action.POSHOLD_UNLIM:
                symb = "∞";
                colour = { 0x4c, 0xfe, 0, 0xc8};
                break;

            case MSP.Action.RTH:
                symb = (rth_land) ? "▼" : "⏏";
                colour = { 0xff, 0x0, 0x0, 0xc8};
                break;

            case MSP.Action.LAND:
                symb = "♜";
                colour = { 0xff, 0x9a, 0xf0, 0xc8};
                break;

            case MSP.Action.JUMP:
                symb = "⇒";
                colour = { 0xed, 0x51, 0xd7, 0xc8};
                break;

            case MSP.Action.SET_POI:
            case MSP.Action.SET_HEAD:
                symb = "⌘";
                colour = { 0xff, 0xfb, 0x2b, 0xc8};
                break;

            default:
                symb = "??";
                colour = { 0xe0, 0xe0, 0xe0, 0xc8};
                break;
        }
        text = "%s %s".printf(symb, no);
    }

    public bool calc_rth_leg(out double extra)
    {
        bool res;
        if(res = (homep != null && rthp != null))
        {
            double cse;
            Geo.csedist(homep.latitude, homep.longitude,
                        rthp.latitude, rthp.longitude,
                        out extra, out cse);
        }
        else
        {
            extra = 0.0;
        }
        return res;
    }

    public void add_rth_point(double lat, double lon, ListBox l)
    {
        if(homep == null)
        {
            double extra;
            homep = new  Champlain.Marker();
            homep.set_location (lat,lon);
            hpath.add_node(homep);
            if(calc_rth_leg(out extra))
                l.calc_mission(extra);
        }
        else
        {
            homep.set_location (lat,lon);
        }
    }

    private uint find_rth_pos(out double lat, out double lon, bool ind = false)
    {
        List<weak Champlain.Location> m= path.get_nodes();
        if(m.length() > 0)
        {
            Champlain.Location lp = m.last().data;
            lat = lp.get_latitude();
            lon = lp.get_longitude();
        }
        else
            lat = lon = 0;

        return m.length();
    }

    private void update_rth_base(ListBox l)
    {
        double lat,lon;
        if(rthp == null)
        {
            double extra;
            if(0 != find_rth_pos(out lat, out lon, true))
            {
                rthp = new  Champlain.Marker();
                rthp.set_location (lat,lon);
                hpath.add_node(rthp);
                if(calc_rth_leg(out extra))
                    l.calc_mission(extra);
            }
        }
        else
        {
            if (0 != find_rth_pos(out lat, out lon))
                rthp.set_location (lat,lon);
        }
    }

    public void negate_rth()
    {
        if(homep != null)
        {
            hpath.remove_node(homep);
        }
        homep = null;
    }

    public void remove_rings(Champlain.View view)
    {
        if (rings.length != 0)
        {
            foreach (var r in rings)
            {
                r.remove_all();
                view.remove_layer(r);
            }
            rings = {};
        }
    }

    public void initiate_rings(Champlain.View view, double lat, double lon, int nrings, double ringint, string colstr)
    {
        remove_rings(view);
        var pp = path.get_parent();
        Clutter.Color rcol = Color.from_string(colstr);

        ShapeDialog.ShapePoint []pts;
        for (var i = 1; i <= nrings; i++)
        {
            var rring = new Champlain.PathLayer();
            rring.set_stroke_color(rcol);
            rring.set_stroke_width (2);
            view.add_layer(rring);
            pp.set_child_below_sibling(rring, path);
            double rng = i*ringint;
            pts = ShapeDialog.mkshape(lat, lon, rng, 36);
            foreach(var p in pts)
            {
                var pt = new  Champlain.Marker();
                pt.set_location (p.lat,p.lon);
                rring.add_node(pt);
            }
            rings += rring;
        }
    }

    public Champlain.Marker add_single_element( ListBox l,  Gtk.TreeIter iter, bool rth)
    {
        Gtk.ListStore ls = l.list_model;
        Champlain.Label marker;
        GLib.Value cell;
        ls.get_value (iter, ListBox.WY_Columns.ACTION, out cell);
        var typ = (MSP.Action)cell;
        ls.get_value (iter, ListBox.WY_Columns.IDX, out cell);
        var no = (string)cell;
        string text;
        Clutter.Color colour;
        Clutter.Color black = { 0,0,0, 0xff };
        Gtk.TreeIter ni = iter;
        bool nrth = false;

        if(ls.iter_next(ref ni) == true)
        {
            ls.get_value (ni, ListBox.WY_Columns.ACTION, out cell);
            var ntyp = (MSP.Action)cell;
            if(ntyp == MSP.Action.RTH)
                nrth = true;
        }

        get_text_for(typ, no, out text, out colour, nrth);
        marker = new Champlain.Label.with_text (text,"Sans 10",null,null);
        marker.set_alignment (Pango.Alignment.RIGHT);
        marker.set_color (colour);
        marker.set_text_color(black);
        ls.get_value (iter, 2, out cell);
        var lat = (double)cell;
        ls.get_value (iter, 3, out cell);
        var lon = (double)cell;

        marker.set_location (lat,lon);
        marker.set_draggable(true);
        marker.set_selectable(true);
        marker.set_flags(ActorFlags.REACTIVE);
        markers.add_marker (marker);
        if (rth == false)
        {
            if(typ != MSP.Action.SET_POI)
                path.add_node(marker);
        }

        ls.set_value(iter,ListBox.WY_Columns.MARKER,marker);

        marker.button_press_event.connect((e) => {
                if(e.button == 3)
                {
                    var button = e.button;
                    var time_ = e.time;
                    l.set_selection(iter);
                    Idle.add(() => {
                            menu.popup(null, null, null, button, time_);
                            return false;
                        });
                    return true;
                }
                else
                    return false;
            });

        ((Champlain.Marker)marker).drag_finish.connect(() => {
                GLib.Value val;
                ls.get_value (iter, ListBox.WY_Columns.ACTION, out val);
                if(val == MSP.Action.UNASSIGNED)
                {
                    string txt;
                    Clutter.Color col;
                    var act = MSP.Action.WAYPOINT;
                    ls.set_value (iter, ListBox.WY_Columns.TYPE, MSP.get_wpname(act));
                    ls.set_value (iter, ListBox.WY_Columns.ACTION, act);
                    get_text_for(act, no, out txt, out col);
                    marker.set_color (col);
                    marker.set_text(txt);
                }
                ls.set_value(iter, ListBox.WY_Columns.LAT, marker.get_latitude());
                ls.set_value(iter, ListBox.WY_Columns.LON, marker.get_longitude() );
                double extra;
                calc_rth_leg(out extra);
                l.calc_mission(extra);
            } );

        return (Champlain.Marker)marker;
    }

    public void add_list_store(ListBox l)
    {
        Gtk.TreeIter iter;
        Gtk.ListStore ls = l.list_model;
        bool rth = false;
        Champlain.Marker mk = null;

        remove_all();
        for(bool next=ls.get_iter_first(out iter);next;next=ls.iter_next(ref iter))
        {
            GLib.Value cell;
            ls.get_value (iter, ListBox.WY_Columns.ACTION, out cell);
            var typ = (MSP.Action)cell;
            switch (typ)
            {
                case MSP.Action.RTH:
                    rth = true;
                    update_rth_base(l);
                    if(mk != null)
                    {
                        add_rth_motion(mk);
                    }
                    ls.set_value(iter,ListBox.WY_Columns.MARKER, (Champlain.Label)null);
                    break;

                case MSP.Action.SET_HEAD:
                case MSP.Action.JUMP:
                    ls.set_value(iter,ListBox.WY_Columns.MARKER, (Champlain.Label)null);
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
    }
    private void add_rth_motion(Champlain.Marker lp)
    {
        lp.drag_motion.connect(() => {
                double nlat, nlon;
                nlat = lp.get_latitude();
                nlon = lp.get_longitude();
                rthp.set_location (nlat,nlon);
            });
    }

    public void change_label(Champlain.Label mk, MSP.Action old, MSP.Action typ, string no)
    {
        string text;
        Clutter.Color colour;
        get_text_for(typ, no, out text, out colour);
        mk.set_color (colour);
        mk.set_text(text);
        if (old == MSP.Action.SET_POI &&
            (typ != MSP.Action.RTH && typ != MSP.Action.SET_HEAD
             && typ != MSP.Action.JUMP))
            path.add_node((Champlain.Marker)mk);

        if (typ == MSP.Action.SET_POI || typ == MSP.Action.RTH
            || typ == MSP.Action.SET_HEAD
            || typ == MSP.Action.JUMP)
            path.remove_node((Champlain.Marker)mk);
    }

    public void set_ring(Champlain.Marker lp)
    {
        var nlat = lp.get_latitude();
        var nlon = lp.get_longitude();
        posring.set_location (nlat,nlon);
        posring.show();
    }

    public void set_home_ring()
    {
        if (homep != null)
            set_ring(homep);
        else
            clear_ring();
    }

    public void clear_ring()
    {
        posring.hide();
    }

    public void remove_all()
    {
        markers.remove_all();
        path.remove_all();
        hpath.remove_all();
        homep = rthp = null;
    }
}
