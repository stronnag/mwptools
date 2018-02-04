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


using Gtk;
using Clutter;
using Champlain;
using GtkChamplain;

public struct SPos
{
    double lat;
    double lon;
}

public class PosFormat : GLib.Object
{
    public static string lat(double _lat, bool dms)
    {
        if(dms == false)
            return "%.6f".printf(_lat);
        else
            return position(_lat, "%02d:%02d:%04.1f%c", "NS");
    }

    public static string lon(double _lon, bool dms)
    {
        if(dms == false)
            return "%.6f".printf(_lon);
        else
            return position(_lon, "%03d:%02d:%04.1f%c", "EW");
    }

    public static string pos(double _lat, double _lon, bool dms)
    {
        if(dms == false)
            return "%.6f %.6f".printf(_lat,_lon);
        else
        {
            var slat = lat(_lat,dms);
            var slon = lon(_lon,dms);
            StringBuilder sb = new StringBuilder ();
            sb.append(slat);
            sb.append(" ");
            sb.append(slon);
            return sb.str;
        }
    }

    private static string position(double coord, string fmt, string ind)
    {
        var neg = (coord < 0.0);
        var ds = Math.fabs(coord);
        int d = (int)ds;
        var rem = (ds-d)*3600.0;
        int m = (int)rem/60;
        double s = rem - m*60;
        if ((int)s*10 == 600)
        {
            m+=1;
            s = 0;
        }
        if (m == 60)
        {
            m = 0;
            d+=1;
        }
        var q = (neg) ? ind.get_char(1) : ind.get_char(0);
        return fmt.printf((int)d,(int)m,s,q);
    }
}

public class AreaPlanner : GLib.Object {
    public Builder builder;
    public Gtk.ApplicationWindow window;
    public  Champlain.View view;
    private Gtk.SpinButton zoomer;
    private int ht_map = 600;
    private int wd_map = 800;
    public MWPSettings conf;
    private GtkChamplain.Embed embed;
    private double lx;
    private double ly;
    private Champlain.PathLayer path;
    private Champlain.MarkerLayer pmlayer;

    private Champlain.PathLayer msn_path;
    private Champlain.MarkerLayer msn_points;

    private Gtk.Menu marker_menu;
    private List<Champlain.Marker> list = new List<Champlain.Marker> ();
    private Champlain.Marker menu_marker;

    private Gtk.Button s_export;
    private Gtk.Button s_publish;
    private Gtk.TextView mission_data;

    private Gtk.Entry s_angle;
    private Gtk.Entry s_altitude;
    private Gtk.Entry s_rowsep;
    private Gtk.ComboBoxText s_turn;
    private Gtk.Switch s_rth;
    private uint nmpts = 0;
    private Mission ms;
    private uint32 move_time;

    private enum MS_Column {
        ID,
        NAME,
        N_COLUMNS
    }

    private void set_menu_state(string action, bool state)
    {
        var ac = window.lookup_action(action) as SimpleAction;
        ac.set_enabled(state);
    }

    public AreaPlanner (string? afn)
    {
        try
        {
            builder = new Builder();
            builder.add_from_resource("/org/mwptools/survey/survey.ui");
            builder.add_from_resource ("/org/mwptools/survey/menubar.ui");
        } catch (Error e)
        {
            stderr.printf ("UI builder failed %s\n", e.message);
            Posix.exit(255);
        }

        conf = new MWPSettings();
        conf.read_settings();
        builder.connect_signals (null);

        window = builder.get_object ("window1") as Gtk.ApplicationWindow;
        window.destroy.connect (Gtk.main_quit);
        var mm = builder.get_object ("menubar") as MenuModel;
        Gtk.MenuBar  menubar = new MenuBar.from_model(mm);
        var hb = builder.get_object ("hb") as HeaderBar;
        window.set_show_menubar(false);
        hb.pack_start(menubar);

        try {
            Gdk.Pixbuf icon = new Gdk.Pixbuf.from_resource("/org/mwptools/survey/mwp_area_icon.svg");
            window.set_icon(icon);
        } catch (Error e) {
            stderr.printf ("icon: %s\n", e.message);
        };

        zoomer = builder.get_object ("spinbutton1") as Gtk.SpinButton;

        var saq = new GLib.SimpleAction("quit",null);
        saq.activate.connect(() => {
                Gtk.main_quit();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("file-open",null);
        saq.activate.connect(() => {
                on_file_open();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("reset-area",null);
        saq.activate.connect(() => {
                init_area(null);
            });
        window.add_action(saq);
        saq = new GLib.SimpleAction("menu-save",null);
        saq.activate.connect(() => {
                do_file_save("Area");
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("menu-save-msn",null);
        saq.activate.connect(() => {
                do_file_save("Mission");
            });
        window.add_action(saq);

        embed = new GtkChamplain.Embed();
        view = embed.get_view();
        view.reactive = true;
        view.kinetic_mode = true;
        zoomer.adjustment.value_changed.connect (() =>
            {
                int  zval = (int)zoomer.adjustment.value;
                var val = view.get_zoom_level();
                if (val != zval)
                {
                    view.zoom_level = zval;
                }
            });

        var scale = new Champlain.Scale();
        scale.connect_view(view);
        view.add_child(scale);
        var lm = view.get_layout_manager();
        lm.child_set(view,scale,"x-align", Clutter.ActorAlign.START);
        lm.child_set(view,scale,"y-align", Clutter.ActorAlign.END);
        view.set_keep_center_on_resize(true);

        var pane = builder.get_object ("paned1") as Gtk.Paned;

        add_source_combo(conf.defmap);
        pane.pack1 (embed,true,false);

        window.key_press_event.connect( (s,e) =>
            {
                bool ret = true;

                switch(e.keyval)
                {
                    case Gdk.Key.plus:
                        if((e.state & Gdk.ModifierType.CONTROL_MASK) != Gdk.ModifierType.CONTROL_MASK)
                            ret = false;
                        else
                        {
                            var val = view.get_zoom_level();
                            var mmax = view.get_max_zoom_level();
                            if (val != mmax)
                                view.zoom_level = val+1;
                        }
                        break;
                        case Gdk.Key.minus:
                            if((e.state & Gdk.ModifierType.CONTROL_MASK) != Gdk.ModifierType.CONTROL_MASK)
                                ret = false;
                            else
                            {
                                var val = view.get_zoom_level();
                                var mmin = view.get_min_zoom_level();
                                if (val != mmin)
                                    view.zoom_level = val-1;
                            }
                            break;

                    default:
                            ret = false;
                            break;
                }
                return ret;
            });

        var databox =  builder.get_object ("databox") as Gtk.Box;
        var poslabel = builder.get_object ("poslabel") as Gtk.Label;

        var s_apply =  builder.get_object ("s_apply") as Gtk.Button;
        var s_save =  builder.get_object ("s_save") as Gtk.Button;
        s_export =  builder.get_object ("s_export") as Gtk.Button;
        s_publish =  builder.get_object ("s_publish") as Gtk.Button;
        mission_data = builder.get_object ("mission_data") as Gtk.TextView;

        s_export.clicked.connect(() => {
                do_file_save("Mission");
            });

        s_publish.clicked.connect(() => {
                print("Publish\n");
            });

        s_apply.clicked.connect(() => {
                build_mission();
            });

        s_save.clicked.connect(() => {
                do_file_save("Area");
            });

        s_angle =  builder.get_object ("s_angle") as Gtk.Entry;
        s_altitude =  builder.get_object ("s_altitude") as Gtk.Entry;
        s_rowsep =  builder.get_object ("s_rowsep") as Gtk.Entry;
        s_turn =  builder.get_object ("s_turn") as Gtk.ComboBoxText;
        s_rth =  builder.get_object ("s_rth") as Gtk.Switch;



        s_altitude.text = conf.altitude.to_string();

        s_rth.state_set.connect((s) => {
                var msn_mks = msn_points.get_markers();
                uint msnl;
                if((msnl = msn_mks.length()) > 0)
                {
                    // the first shall be last ...
                    var last = msn_mks.nth_data(0);
                    var tlat = last.latitude;
                    var tlon = last.longitude;
                    msn_path.remove_node(last);
                    msn_points.remove_child(last);
                    add_wp_item(tlat, tlon, msnl, s);
                }
                return false;
            });

        pane.add2(databox);
        view.notify["zoom-level"].connect(() => {
                var val = view.zoom_level;
                var zval = (int)zoomer.adjustment.value;
                    if (val != zval)
                        zoomer.adjustment.value = (int)val;
            });

        embed.set_size_request(wd_map, ht_map);

        Timeout.add(500, () => {
                var x = view.get_center_longitude();
                var y = view.get_center_latitude();
                if (lx !=  x && ly != y)
                {
                    poslabel.set_text(PosFormat.pos(y,x,conf.dms));
                    lx = x;
                    ly = y;
                }
                return true;});

        view.center_on(conf.latitude,conf.longitude);
        view.zoom_level = conf.zoom;
        zoomer.adjustment.value = conf.zoom;

        init_markers();
        setup_buttons();
        init_marker_menu();

        Timeout.add(500, () => {
                init_area(afn);
                return false;
            });

        window.show_all();
    }

    private void save_mission_file(string fn)
    {
        XmlIO.to_xml_file(fn, ms);
    }

    private Mission? create_mission()
    {
        int i =0;
        var rth = s_rth.active;
        var alt = int.parse(s_altitude.text);
        ms = new Mission();

        MissionItem [] mi={};

        foreach(var p in msn_points.get_markers())
        {
            var m = MissionItem() {
                no = ++i, action = MSP.Action.WAYPOINT,
                lat = p.latitude, lon = p.longitude, alt = alt,
                param1 = 0, param2 = 0, param3 = 0
            };

            if (m.lat > ms.maxy)
                ms.maxy = m.lat;
            if (m.lon > ms.maxx)
                ms.maxx = m.lon;
            if (m.lat <  ms.miny)
                ms.miny = m.lat;
            if (m.lon <  ms.minx)
                ms.minx = m.lon;
            mi += m;
        }

        if(rth)
        {
            var land = (int)conf.rth_autoland;
            var m = MissionItem() {
                no = ++i, action = MSP.Action.RTH,
                lat = 0, lon = 0, alt = 0,
                param1 = land, param2 = 0, param3 = 0
            };
            mi += m;
        }

        ms.npoints = mi.length;
        ms.set_ways(mi);
        ms.nspeed = conf.nav_speed;
        ms.cy = (ms.maxy + ms.miny) /2.0;
        ms.cx = (ms.maxx + ms.minx) /2.0;
        ms.maxalt = alt;

        if(ms.calculate_distance(out ms.dist, out ms.lt))
        {
            if(conf.nav_speed != 0)
                ms.et = (int)(ms.dist / conf.nav_speed) + (int)ms.npoints * 3;

            StringBuilder sb = new StringBuilder("Mission Data\n");
            sb.append_printf("Points: %u\n", ms.npoints);
            sb.append_printf("Distance: %.1fm\n", ms.dist);
            sb.append_printf("Flight time %02d:%02d\n", ms.et/60, ms.et%60 );
            if(ms.lt != -1)
                sb.append_printf("Loiter time: %ds\n", ms.lt);
            sb.append_printf("Speed: %.1f m/s\n", ms.nspeed);
            if(ms.maxalt != 0x80000000)
                sb.append_printf("Altitude: %dm\n", ms.maxalt);
            mission_data.buffer.text = sb.str;
        }
        ms.version="mwp-area-planner 0.0";
        return ms;
    }

    private void on_file_open()
    {
        Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
            "Select an area file", null, Gtk.FileChooserAction.OPEN,
            "_Cancel",
            Gtk.ResponseType.CANCEL,
            "_Open",
            Gtk.ResponseType.ACCEPT);
        chooser.select_multiple = false;
        if(conf.missionpath != null)
            chooser.set_current_folder (conf.missionpath);

        chooser.set_transient_for(window);
        Gtk.FileFilter filter = new Gtk.FileFilter ();
        filter.set_filter_name ("Area");
        filter.add_pattern ("*.txt");
        chooser.add_filter (filter);
        filter = new Gtk.FileFilter ();
        filter.set_filter_name ("All Files");
        filter.add_pattern ("*");
        chooser.add_filter (filter);
        chooser.response.connect((id) => {
                if (id == Gtk.ResponseType.ACCEPT)
                {
                    var fn = chooser.get_filename ();
                    chooser.close ();
                    init_area(fn);
                }
                else
                    chooser.close ();
            });
        chooser.show_all();
    }

    private void build_mission()
    {
        Vec[] rpts = {};
        list.foreach((m) => {
                var v = Vec(){x = m.longitude, y=m.latitude};
                rpts += v;
            });

        double angle = double.parse(s_angle.text);
        double sep = double.parse(s_rowsep.text);
        int turn = s_turn.active;
        bool rth = s_rth.active;

        var mpts = AreaCalc.generateFlightPath(rpts, angle, (uint8)turn, sep); // pts, angle, turn, sep
        msn_path.remove_all();
        msn_points.remove_all();
        uint i = 0;
        bool use_rth = false;

        nmpts = mpts.length;

        foreach (var m in mpts)
        {
            i++;
            add_wp_item(m.start.y, m.start.x, i, use_rth);
            i++;
            if(i == nmpts*2 && rth)
                use_rth = true;
            add_wp_item(m.end.y, m.end.x, i, use_rth);
        }
        s_export.sensitive = true;
        set_menu_state("menu-save-msn", true);
        create_mission();
    }

    private void add_wp_item(double lat, double lon, uint i, bool use_rth)
    {
        string text;
        Clutter.Color black = { 0,0,0, 0xff };
        Clutter.Color colour;
        string no = i.to_string();
        get_wp_text (no, out text, out colour, use_rth);
        var marker = new Champlain.Label.with_text (text,"Sans 10",null,null);
        marker.set_alignment (Pango.Alignment.RIGHT);
        marker.set_color (colour);
        marker.set_text_color(black);
        marker.set_location (lat,lon);
        marker.set_draggable(false);
        marker.set_selectable(false);
        msn_points.add_marker (marker);
        msn_path.add_node(marker);
    }

    private void init_marker_menu()
    {
        marker_menu =   new Gtk.Menu ();

        var item = new Gtk.MenuItem.with_label ("Insert");
        item.activate.connect (() => {
                pop_menu_after();
            });
        marker_menu.add (item);

        item = new Gtk.MenuItem.with_label ("Delete");
        item.activate.connect (() => {
                pop_menu_delete();
            });
        marker_menu.add (item);
        marker_menu.show_all();
    }

    private bool near(Champlain.Location a, Champlain.Location b)
    {
        return ((Math.fabs(a.latitude - b.latitude) < 1e-6) &&
                (Math.fabs(a.longitude - b.longitude) < 1e-6));
    }

    private void pop_menu_after()
    {
        if(menu_marker!=null)
        {
            var mks = path.get_nodes();
            uint ml = mks.length();
            Champlain.Location l;
            for(var n = 0; n < ml; n++)
            {
                l = mks.nth_data(n);
                if(near(l,menu_marker))
                {
                    Champlain.Location npos;
                    var np = (n+1) % ml;
                    npos = mks.nth_data(np);
                    var snpos = get_mid_pos(npos, l);
                    add_node(snpos.latitude, snpos.longitude, (int)(1+n));
                    menu_marker.selected = false;
                    break;
                }
            }
            menu_marker = null;
        }
    }

    private void pop_menu_delete()
    {
        if(menu_marker!=null)
        {
            menu_marker.selected = false;
            var mks = path.get_nodes();
            uint ml = mks.length();
            if(ml > 3)
            {
                list.foreach((m) => {
                        if(near(m,menu_marker))
                            list.remove(m);
                    });
                path.remove_node(menu_marker);
                pmlayer.remove_marker(menu_marker);
                if(nmpts > 0)
                    build_mission();
            }
            else
                mwp_warning_box("Need 3 or more vertices\n");
            menu_marker = null;
        }
    }

    private void init_markers()
    {
        Clutter.Color pcol = { 0xc5,0xc5, 0xc5, 0xa0};
        Clutter.Color rcol = {0xff, 0x0, 0x0, 0x60};

        msn_path = new Champlain.PathLayer();
        msn_points = new Champlain.MarkerLayer();

        path = new Champlain.PathLayer();
        path.set_stroke_color(pcol);
        pmlayer = new Champlain.MarkerLayer();

        msn_path.set_stroke_color(rcol);
        msn_path.set_stroke_width (8);

        view.add_layer (msn_points);
        view.add_layer (msn_path);
        view.add_layer (path);
        view.add_layer (pmlayer);

        path.closed=true;
    }

    private void clear_mission()
    {
        msn_path.remove_all();
        msn_points.remove_all();
        s_export.sensitive = false;
        set_menu_state("menu-save-msn",false);
    }

    private void clear_markers()
    {
        pmlayer.remove_all();
        path.remove_all();
        list.foreach((m) => {
                list.remove(m);
            });
    }

    private void init_area(string? fn)
    {
        Vec[]pls={};

        clear_markers();
        clear_mission();

        if(fn != null)
        {
            double cxa = 180, cya = 90, cxz=-180, cyz=-90;
            pls = parse_file(fn);
            foreach(var p in pls)
            {
                cxa = Math.fmin(cxa,p.x);
                cxz = Math.fmax(cxz,p.x);
                cya = Math.fmin(cya,p.y);
                cyz = Math.fmax(cyz,p.y);
                add_node(p.y, p.x);
            }
            if(pls.length != 0)
            {
                view.center_on((cya+cyz)/2, (cxa+cxz)/2);
            }

        }

        if(pls.length == 0)
        {
            var bb = view.get_bounding_box();
            double np,sp,ep,wp;

            np = (bb.top*0.9 + bb.bottom*0.1);
            sp = (bb.top*0.1 + bb.bottom*0.9);
            ep = (bb.left*0.9 + bb.right*0.1);
            wp = (bb.left*0.1 + bb.right*0.9);
            add_node(np,ep);
            add_node(np,wp);
            add_node(sp,wp);
            add_node(sp,ep);
        }
    }

    private void add_node(double lat, double lon, int pos = -1)
    {
        Champlain.Point marker;
        Clutter.Color pcol = { 0xff,0xcd, 0x70, 0xa0};
        marker = new Champlain.Point.full(15.0, pcol);
        marker.set_location (lat,lon);
        marker.set_draggable(true);
        marker.set_selectable(true);
        marker.set_flags(ActorFlags.REACTIVE);
        pmlayer.add_marker(marker);
        marker.button_press_event.connect((e) => {
                if(e.button == 1)
                    move_time = e.get_time();
                marker.selected = true;
                return false;
            });

        if(pos == -1)
        {
            path.add_node(marker);
            list.append(marker);
        }
        else
        {
            list.insert(marker, pos);
            path.remove_all();
            list.foreach((s)  => {
                    path.add_node(s);
                });
        }

        marker.drag_finish.connect(() => {
                if(nmpts > 0)
                    build_mission();
            });

        marker.drag_motion.connect((dx,dy,evt) => {
                if(nmpts > 0)
                {
                    if(evt.get_time() - move_time > 20)
                    {
                        build_mission();
                        move_time = evt.get_time();
                    }
                }
            });
    }

    private Champlain.Marker get_mid_pos(Champlain.Location a, Champlain.Location b)
    {
        var m = new Champlain.Marker();
        m.latitude  = (a.latitude+b.latitude)/2;
        m.longitude = (a.longitude+b.longitude)/2;
        return m;
    }

   private void setup_buttons()
    {
        embed.button_release_event.connect((evt) => {
                if(evt.button == 3)
                {
                    var mls = pmlayer.get_selected();
                    if(mls != null)
                    {
                        menu_marker = mls.first().data;
#if OLDGTK||LSRVAL
                        marker_menu.popup(null, null, null, 3, evt.time);
#else
                        marker_menu.popup_at_pointer(evt);
#endif
                    }
                }
                return false;
            });
    }

    private void add_source_combo(string? defmap)
    {
        var combo  = builder.get_object ("combobox1") as Gtk.ComboBox;
        var map_source_factory = Champlain.MapSourceFactory.dup_default();

        var liststore = new Gtk.ListStore (MS_Column.N_COLUMNS, typeof (string), typeof (string));

        var msources =   JsonMapDef.read_json_sources(null);
        foreach (unowned MapSource s0 in msources)
        {
            s0.desc = new  MwpMapSource(
                s0.id,
                s0.name,
                s0.licence,
                s0.licence_uri,
                s0.min_zoom,
                s0.max_zoom,
                s0.tile_size,
                Champlain.MapProjection.MERCATOR,
                s0.uri_format);
            map_source_factory.register((Champlain.MapSourceDesc)s0.desc);
        }
        var sources =  map_source_factory.get_registered();
        int i = 0;
        int defval = 0;
        string? defsource = null;

        foreach (Champlain.MapSourceDesc s in sources)
        {
            TreeIter iter;
            liststore.append(out iter);
            var id = s.get_id();
            liststore.set (iter, MS_Column.ID, id);
            var name = s.get_name();
            liststore.set (iter, MS_Column.NAME, name);
            if (defmap != null && name == defmap)
            {
                defval = i;
                defsource = id;
            }
            i++;
        }
        combo.set_model(liststore);
        if(defsource != null)
        {
            var src = map_source_factory.create_cached_source(defsource);
            view.set_property("map-source", src);
        }

        var cell = new Gtk.CellRendererText();
        combo.pack_start(cell, false);
        combo.add_attribute(cell, "text", 1);
        combo.set_active(defval);
        combo.changed.connect (() => {
                GLib.Value val1;
                TreeIter iter;
                combo.get_active_iter (out iter);
                liststore.get_value (iter, 0, out val1);
                var source = map_source_factory.create_cached_source((string)val1);
                var zval = zoomer.adjustment.value;
                var cx = lx;
                var cy = ly;
                view.map_source = source;

                    /* Stop oob zooms messing up the map */
                var mmax = view.get_max_zoom_level();
                var mmin = view.get_min_zoom_level();
                var chg = false;
                if (zval > mmax)
                {
                    chg = true;
                    view.zoom_level = mmax;
                }
                if (zval < mmin)
                {
                    chg = true;
                        view.zoom_level = mmin;
                }
                if (chg == true)
                {
                    view.center_on(cy, cx);
                }
            });
    }

    private void mwp_warning_box(string warnmsg,
                                 Gtk.MessageType klass=Gtk.MessageType.WARNING,
                                 int timeout = 0)
    {
        Gtk.MessageDialog msg = new Gtk.MessageDialog (window,
                                                       Gtk.DialogFlags.MODAL,
                                                       klass,
                                                       Gtk.ButtonsType.OK,
                                                       warnmsg);

        if(timeout > 0)
        {
            Timeout.add_seconds(timeout, () => { msg.destroy(); return false; });
        }
        msg.run();
        msg.destroy();
    }

    private void get_wp_text(string no, out string text, out Clutter.Color col, bool nrth = false)
    {
        string symb;
        if(nrth)
        {
            col = { 0, 0xaa, 0xff, 0xa0};
            symb = "▼WP";
        }
        else
        {
            symb = "WP";
            col = { 0, 0xff, 0xff, 0xa0};
        }
        text = "%s %s".printf(symb, no);
    }

    private Vec[] parse_file(string fn)
    {
        Vec[] pls = {};
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
                    var parts = line.split_set("\t|;:");
                    if(parts.length == 2)
                    {
                        Vec p = Vec();
                        p.y = double.parse(parts[0]);
                        p.x = double.parse(parts[1]);
                        pls += p;
                    }
                }
            }
        } catch (Error e) {
            print ("%s\n", e.message);
        }
        return pls;
    }

     public void do_file_save (string name)
     {
         Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
             "Save file", null, Gtk.FileChooserAction.SAVE,
            "_Cancel",
            Gtk.ResponseType.CANCEL,
            "_Save",
            Gtk.ResponseType.ACCEPT);
        chooser.set_transient_for(window);
        chooser.select_multiple = false;

        if(conf.missionpath != null)
            chooser.set_current_folder (conf.missionpath);

        Gtk.FileFilter filter = new Gtk.FileFilter ();

        filter.set_filter_name (name);
        if(name == "Mission")
        {
            filter.add_pattern ("*.mission");
            filter.add_pattern ("*.xml");
            filter.add_pattern ("*.json");
            chooser.add_filter (filter);
        }
        else
        {
            filter.add_pattern ("*.txt");
            chooser.add_filter (filter);
        }
        filter = new Gtk.FileFilter ();
        filter.set_filter_name ("All Files");
        filter.add_pattern ("*");
        chooser.add_filter (filter);

        chooser.response.connect((id) => {
                if (id == Gtk.ResponseType.ACCEPT) {
                    var fn = chooser.get_filename ();
                    if(name == "Mission")
                    {
                        save_mission_file(fn);
                    }
                    else
                    {
                        save_area_file(fn);
                    }
                }
                chooser.close ();
            });
        chooser.show_all();
    }

     private void save_area_file(string fn)
    {
        var os = FileStream.open(fn, "w");
        os.puts("# mwp area file\n");
        os.puts("# Valid delimiters are |;: and <TAB>. Note \",\" is not a delimiter
# for reasons of localisation.\n");
        os.puts("#\n");
        list.foreach((m) => {
                os.printf("%f\t%f\n", m.latitude, m.longitude);
            });
    }

    public void run()
    {
        Gtk.main();
    }

    public static int main (string?[] args)
    {
        if (GtkClutter.init (ref args) != InitError.SUCCESS)
            return 1;
        AreaPlanner app = new AreaPlanner(args.length == 1 ? null : args[1]);
        app.run ();
        return 0;
    }
}
