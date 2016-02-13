
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
using GLib;
using Clutter;

public class MWPMarkers : GLib.Object
{
    public  Champlain.PathLayer path;
    public Champlain.MarkerLayer markers;
    public Champlain.Marker homep = null;
    public Champlain.Marker rthp = null;
    public  Champlain.PathLayer hpath;
    private Gtk.Menu menu;

    public MWPMarkers(ListBox lb)
    {
        markers = new Champlain.MarkerLayer();
        path = new Champlain.PathLayer();
        hpath = new Champlain.PathLayer();
        List<uint> llist = new List<uint>();
        llist.append(10);
        llist.append(5);
        Clutter.Color orange = {0xff, 0xa0, 0x0, 0xc8};
        hpath.set_stroke_color(orange);
        hpath.set_dash(llist);

        menu =   new Gtk.Menu ();
        var item = new Gtk.MenuItem.with_label ("Delete");
        item.activate.connect (() => {
                lb.menu_delete();
            });
        menu.add (item);

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
    }

    private void get_text_for(MSP.Action typ, string no, out string text, out  Clutter.Color colour)
    {
        switch (typ)
        {
            case MSP.Action.WAYPOINT:
                text = @"WP $no";
                colour = { 0, 0xff, 0xff, 0xc8};
                break;

            case MSP.Action.POSHOLD_TIME:
                text = @"◷ $no"; // text = @"\u25f7 $no";
                colour = { 152, 70, 234, 0xc8};
                break;

            case MSP.Action.POSHOLD_UNLIM:
                text = @"∞ $no"; // text = @"\u221e $no";
                colour = { 0x4c, 0xfe, 0, 0xc8};
                break;

            case MSP.Action.RTH:
                text = @"⏏ $no"; // text = @"\u23cf $no";
                colour = { 0xff, 0x0, 0x0, 0xc8};
                break;

            case MSP.Action.LAND:
                text = @"♜ $no"; // text = @"\u265c $no";
                colour = { 0xff, 0x9a, 0xf0, 0xc8};
                break;

            case MSP.Action.JUMP:
                text = @"⇒ $no"; // text = @"\u21d2 $no";
                colour = { 0xed, 0x51, 0xd7, 0xc8};
                break;

            case MSP.Action.SET_POI:
            case MSP.Action.SET_HEAD:
                 text = @"⌘ $no"; //text = @"\u2318 $no";
                colour = { 0xff, 0xfb, 0x2b, 0xc8};
                break;

            default:
                text = @"?? $no";
                colour = { 0xe0, 0xe0, 0xe0, 0xc8};
                break;
        }
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

    private void find_rth_pos(out double lat, out double lon, bool ind = false)
    {
        List<weak Champlain.Location> m= path.get_nodes();
        Champlain.Location lp = m.last().data;
        lat = lp.get_latitude();
        lon = lp.get_longitude();
    }

    private void update_rth_base(ListBox l)
    {
        double lat,lon;
        if(rthp == null)
        {
            double extra;
            rthp = new  Champlain.Marker();
            find_rth_pos(out lat, out lon, true);
            rthp.set_location (lat,lon);
            hpath.add_node(rthp);
            if(calc_rth_leg(out extra))
                l.calc_mission(extra);
        }
        else
        {
            find_rth_pos(out lat, out lon);
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

        get_text_for(typ, no, out text, out colour);
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
                l.set_selection(iter);
                Timeout.add(10, () => {
                        menu.popup(null, null, null, e.button, e.time);
                        return false;
                    });
                return true;
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

    public void remove_all()
    {
        markers.remove_all();
        path.remove_all();
        hpath.remove_all();
        homep = rthp = null;
    }
}
