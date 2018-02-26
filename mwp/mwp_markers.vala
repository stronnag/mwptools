
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
    public Champlain.PathLayer path;
    public Champlain.MarkerLayer markers;
    public Champlain.MarkerLayer rlayer;
    public Champlain.Marker homep = null;
    public Champlain.Marker rthp = null;
    public Champlain.Marker ipos = null;
    public Champlain.Point posring = null;
    public Champlain.PathLayer hpath;
    public Champlain.PathLayer ipath;
    private Champlain.PathLayer []rings;
    private bool rth_land;

    public MWPMarkers(ListBox lb, Champlain.View view, string mkcol ="#ffffff60")
    {
        rth_land = false;
        markers = new Champlain.MarkerLayer();
        rlayer = new Champlain.MarkerLayer();
        path = new Champlain.PathLayer();
        hpath = new Champlain.PathLayer();
        ipath = new Champlain.PathLayer();

        view.add_layer(rlayer);
        view.add_layer(path);
        view.add_layer(hpath);
        view.add_layer(ipath);
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

        ipath.set_stroke_color(rcol);
        ipath.set_dash(llist);
        ipath.set_stroke_width (8);

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

    private double calc_extra_leg(Champlain.PathLayer p)
    {
        List<weak Champlain.Location> m= p.get_nodes();
        double extra = 0.0;
        if(homep != null)
        {
            double cse;
            Champlain.Location lp0 = m.first().data;
            Champlain.Location lp1 = m.last().data;

            Geo.csedist(lp0.get_latitude(), lp0.get_longitude(),
                        lp1.get_latitude(), lp1.get_longitude(),
                        out extra, out cse);
        }
        return extra;
    }

    public void add_home_point(double lat, double lon, ListBox l)
    {
        if(homep == null)
        {
            homep = new  Champlain.Marker();
            homep.set_location (lat,lon);
            hpath.add_node(homep);
        }
        else
        {
            homep.set_location (lat,lon);
        }
        calc_extra_distances(l);
    }

    void calc_extra_distances(ListBox l)
    {
        double extra = 0.0;
        if(homep != null)
        {
            if(ipos != null)
                extra = calc_extra_leg(ipath);

            if(rthp != null)
            {
                extra += calc_extra_leg(hpath);
            }
        }
        l.calc_mission(extra);
    }

    private uint find_rth_pos(out double lat, out double lon)
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

    public void update_ipos(ListBox l, double lat, double lon)
    {
        if(ipos == null)
        {
            List<weak Champlain.Location> m= path.get_nodes();
            if(m.length() > 0)
            {
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

    public void negate_ipos()
    {
        ipath.remove_all();
        ipos = null;
    }

    private void update_rth (ListBox l)
    {
        double lat,lon;
        uint irth = find_rth_pos(out lat, out lon);

        if(irth != 0)
        {
            if(rthp == null)
            {
                rthp = new  Champlain.Marker();
                rthp.set_location (lat,lon);
                hpath.add_node(rthp);
            }
            else
            {
                rthp.set_location (lat,lon);
            }
            calc_extra_distances(l);
        }
    }

    public void negate_home()
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
        Clutter.Color near_black = { 0x40,0x40,0x40, 0xa0 };
        Clutter.Color white = { 0xff,0xff,0xff, 0xff };
        Gtk.TreeIter ni;

        var ino = int.parse(no);

        bool nrth = l.wp_has_rth(iter, out ni);

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

        var txt = new Clutter.Text.full ("Sans 9", "", white);
        txt.set_background_color(near_black);
        txt.line_wrap = true;

        marker.button_press_event.connect((e) => {
//                Idle.add(() => {txt.set_text(null); return false; });
                if(e.button == 3)
                    l.set_popup_needed(iter);
                return false;
            });

        marker.enter_event.connect((ce) => {
                var s = l.get_marker_tip(ino);
                if(s == null)
                    s = "RTH";

                Timeout.add(500, () => {
                        if(marker.get_has_pointer ())
                        {
                            txt.text = s;
                            if(txt.get_parent() == null)
                                marker.add_child(txt);
                        }
                        return false;
                    });
                return false;
            });

        marker.leave_event.connect((ce) => {
                if(txt.get_parent() == marker)
                    marker.remove_child(txt);
                return false;
            });

        uint move_time = 0;
        marker.drag_motion.connect((dx,dy,evt) => {
                if(evt.get_time() - move_time > 20)
                {
                    if(txt.get_parent() == marker)
                    {
                        ls.set_value(iter, ListBox.WY_Columns.LAT, marker.get_latitude());
                        ls.set_value(iter, ListBox.WY_Columns.LON, marker.get_longitude() );
                        calc_extra_distances(l);
                        txt.set_text(l.get_marker_tip(ino));
                    }
                }
            });

        ((Champlain.Marker)marker).drag_finish.connect(() => {
                GLib.Value val;
                ls.get_value (iter, ListBox.WY_Columns.ACTION, out val);
                if(val == MSP.Action.UNASSIGNED)
                {
                    string mtxt;
                    Clutter.Color col;
                    var act = MSP.Action.WAYPOINT;
                    ls.set_value (iter, ListBox.WY_Columns.TYPE, MSP.get_wpname(act));
                    ls.set_value (iter, ListBox.WY_Columns.ACTION, act);
                    get_text_for(act, no, out mtxt, out col);
                    marker.set_color (col);
                    marker.set_text(mtxt);
                }
                ls.set_value(iter, ListBox.WY_Columns.LAT, marker.get_latitude());
                ls.set_value(iter, ListBox.WY_Columns.LON, marker.get_longitude() );
                calc_extra_distances(l);
                if(txt.get_parent() == marker)
                    txt.text = l.get_marker_tip(ino);
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
                    update_rth(l);
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
        calc_extra_distances(l);
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
        ipath.remove_all();
        homep = rthp = ipos = null;
    }
}
