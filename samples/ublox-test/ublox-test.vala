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

public class MWPlanner : GLib.Object {
    public Builder builder;
    public Gtk.Window window;
    public  Champlain.View view;
    private Gtk.SpinButton zoomer;
    private int ht_map = 480;
    private int wd_map = 600;
    public MWPSettings conf;
    private MWSerial msp;
    private Gtk.Button conbutton;
    private Gtk.CheckButton autocon_cb;
    private Gtk.ComboBoxText dev_entry;
    private GtkChamplain.Embed embed;
    private int autocount = 0;
    private double lx;
    private double ly;
    private Champlain.PathLayer path;
    private Champlain.MarkerLayer pmlayer;
    private Champlain.MarkerLayer imlayer;
    private int npath =0;
    private static Clutter.Color cyan = { 0,0xff,0xff, 0xa0 };
    private Champlain.Point icon;
    private int baud;
    private bool autocon = false;

    private enum MS_Column {
        ID,
        NAME,
        N_COLUMNS
    }

    public MWPlanner (MWSerial s)
    {
        msp = s;
        {
            builder = new Builder.from_resource("/org/mwptools/ublox/ublox-test.ui");
            if(builder == null)
            {
                stderr.printf ("Builder failed\n");
                Posix.exit(255);
            }

            conf = new MWPSettings();
            conf.read_settings();
            baud = (int)conf.baudrate;
            builder.connect_signals (null);
            window = builder.get_object ("window1") as Gtk.Window;
            window.destroy.connect (Gtk.main_quit);

            try {
                Gdk.Pixbuf icon = new Gdk.Pixbuf.from_resource("/org/mwptools/ublox/ublox.png");
                window.set_icon(icon);
            } catch (Error e) {
                stderr.printf ("icon: %s\n", e.message);
            };

            zoomer = builder.get_object ("spinbutton1") as Gtk.SpinButton;

            var menuop = builder.get_object ("menu_quit") as Gtk.MenuItem;
            menuop.activate.connect (() => {
                    Gtk.main_quit();
                });


            embed = new GtkChamplain.Embed();
            view = embed.get_view();
            view.set_reactive(true);
            view.set_property("kinetic-mode", true);
            zoomer.adjustment.value_changed.connect (() =>
                {
                    int  zval = (int)zoomer.adjustment.value;
                    var val = view.get_zoom_level();
                    if (val != zval)
                    {
                        view.set_property("zoom-level", zval);
                    }
                });

            var ref_fn = MWPUtils.find_conf_file(".ublox_ref.txt");
            double reflat = 0;
            double reflon = 0;
            bool refok = false;
            if(ref_fn != null)
            {
                try
                {
                    var file = File.new_for_path (ref_fn);
                    var dis = new DataInputStream (file.read ());
                    var line = dis.read_line (null);
                    if(line != null)
                        reflat = double.parse(line);
                    line = dis.read_line (null);
                    if(line != null)
                        reflon= double.parse(line);
                    refok = (reflat != 0.0 && reflon != 0.0);
                    dis.close();
                } catch (Error e)
                {
                    stderr.puts(e.message);
                    stderr.putc('\n');
                }
            }

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
                                    view.set_property("zoom-level", val+1);
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
                                    view.set_property("zoom-level", val-1);
                            }
                            break;

                        case Gdk.Key.c:
                            if((e.state & Gdk.ModifierType.CONTROL_MASK) != Gdk.ModifierType.CONTROL_MASK)
                                ret = false;
                            else
                            {
                                init_trail();
                            }
                            break;

                        default:
                            ret = false;
                            break;
                    }
                    return ret;
                });

            var grid =  builder.get_object ("grid1") as Gtk.Grid;

            pane.add2(grid);
            view.notify["zoom-level"].connect(() => {
                    var val = view.get_zoom_level();
                    var zval = (int)zoomer.adjustment.value;
                    if (val != zval)
                        zoomer.adjustment.value = (int)val;
                });

            embed.set_size_request(wd_map, ht_map);

            autocon_cb = builder.get_object ("autocon_cb") as Gtk.CheckButton;

            var poslabel = builder.get_object ("poslabel") as Gtk.Label;
            var elapsedlab =  builder.get_object ("elapsedlab") as Gtk.Label;
            var nsatlab = builder.get_object ("nsatlab") as Gtk.Label;
            var glatlab = builder.get_object ("glatlab") as Gtk.Label;
            var glonlab = builder.get_object ("glonlab") as Gtk.Label;
            var gelevlab = builder.get_object ("gelevlab") as Gtk.Label;
            var hacclab = builder.get_object ("hacclab") as Gtk.Label;
            var vacclab = builder.get_object ("vacclab") as Gtk.Label;
            var gfixlab = builder.get_object ("gfixlab") as Gtk.Label;
            var rangelab = builder.get_object ("rangelab") as Gtk.Label;
            var bearlab = builder.get_object ("bearlab") as Gtk.Label;

            uint32 xtime = 0;

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
            view.set_property("zoom-level", conf.zoom);
            zoomer.adjustment.value = conf.zoom;

            dev_entry = builder.get_object ("comboboxtext1") as Gtk.ComboBoxText;
            foreach(string a in conf.devices)
            {
                dev_entry.append_text(a);
            }
            var te = dev_entry.get_child() as Gtk.Entry;
            te.can_focus = true;
            dev_entry.active = 0;
            conbutton = builder.get_object ("button1") as Gtk.Button;
            te.activate.connect(() => {
                    if(!msp.available)
                    {
                        xtime = 0;
                        connect_serial();
                    }
                });

            conbutton.clicked.connect(() => { xtime = 0; connect_serial(); });

            init_markers();

            bool init_pos = false;

            uint upd = 0;
            msp.gps_update.connect((u) => {
                    nsatlab.set_label("%d".printf(u.numsat));
                    gfixlab.set_label("%d".printf(u.fixt));
                    if(u.fix_ok)
                    {
                        glatlab.set_label("%.6f".printf(u.gpslat));
                        glonlab.set_label("%.6f".printf(u.gpslon));
                        gelevlab.set_label("%.1f".printf(u.gpsalt));
                        hacclab.set_label("%.1f".printf(u.gpshacc));
                        vacclab.set_label("%.1f".printf(u.gpsvacc));
                        if(upd % 5 == 0)
                            gps_set_lat_lon (u.gpslat, u.gpslon);

                        upd++;
                        if(refok)
                        {
                            double c,d;
                            Geo.csedist(reflat,reflon,u.gpslat, u.gpslon, out d, out c);
                            rangelab.set_label("%.1f".printf(1852.0*d));
                            bearlab.set_label("%.0f".printf(c));
                        }

                        if(init_pos == false)
                        {
                            view.center_on(u.gpslat, u.gpslon);
                            init_pos = true;
                        }
                    }
                    else
                    {
                        glatlab.set_label("n/a");
                        glonlab.set_label("n/a");
                        gelevlab.set_label("n/a");
                        hacclab.set_label("n/a");
                        vacclab.set_label("n/a");
                        rangelab.set_label("-");
                        bearlab.set_label("-");
                    }
                    elapsedlab.set_label(u.date);
                });

            if(MWSerial.devname != null)
            {
                dev_entry.prepend_text(MWSerial.devname);
                dev_entry.active = 0;
            }

            autocon_cb.toggled.connect(() => {
                    autocon =  autocon_cb.active;
                    autocount = 0;
                });

            if(autocon)
            {
                autocon_cb.active=true;
                connect_serial();
            }

            Timeout.add_seconds(5, () => { return try_connect(); });
            window.show_all();
        }
    }

    private bool try_connect()
    {
        if(autocon)
        {
            if(!msp.available)
                connect_serial();
            Timeout.add_seconds(5, () => { return try_connect(); });
                return false;
        }
        return true;
    }

    private void serial_doom(Gtk.Button c)
    {
        msp.close();
        c.set_label("gtk-connect");
        init_trail();
    }

    private void connect_serial()
    {
        if(msp.available)
        {
            serial_doom(conbutton);
        }
        else
        {
            var serdev = dev_entry.get_active_text();
            if (msp.ublox_open(serdev, baud) == true)
            {
                autocount = 0;
                conbutton.set_label("gtk-disconnect");
            }
            else
            {
                if (autocon == false || autocount == 0)
                {

                    mwp_warning_box("Unable to open serial device: %s".printf(
                                        serdev));
                }
                autocount = ((autocount + 1) % 4);
            }
        }
    }

    private void add_source_combo(string? defmap)
    {
        var combo  = builder.get_object ("combobox1") as Gtk.ComboBox;
        var map_source_factory = Champlain.MapSourceFactory.dup_default();

        var liststore = new Gtk.ListStore (MS_Column.N_COLUMNS, typeof (string), typeof (string));

        if(conf.map_sources != null)
        {
            var fn = MWPUtils.find_conf_file(conf.map_sources);
            if (fn != null)
            {
                var msources =   JsonMapDef.read_json_sources(fn);
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
                        0, // Champlain.MapProjection.MAP_PROJECTION_MERCATOR,
                        s0.uri_format);
                    map_source_factory.register((Champlain.MapSourceDesc)s0.desc);
                }
            }
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
                view.set_property("map-source", source);

                    /* Stop oob zooms messing up the map */
                var mmax = view.get_max_zoom_level();
                var mmin = view.get_min_zoom_level();
                var chg = false;
                if (zval > mmax)
                {
                    chg = true;
                    view.set_property("zoom-level", mmax);
                }
                if (zval < mmin)
                {
                    chg = true;
                        view.set_property("zoom-level", mmin);
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

    public void init_markers()
    {
        path = new Champlain.PathLayer();
        path.set_stroke_color(cyan);
        pmlayer = new Champlain.MarkerLayer();
        imlayer = new Champlain.MarkerLayer();
        view.add_layer (path);
        view.add_layer (pmlayer);
        view.add_layer (imlayer);
        Clutter.Color red = { 0xff,0,0, 0xff};
        icon = new Champlain.Point.full(8.0, red);
    }

    public void init_trail()
    {
        imlayer.remove_all();
        pmlayer.remove_all();
        path.remove_all();
        npath = 0;
    }

    public void gps_set_lat_lon (double lat, double lon)
    {
        Champlain.Point marker;
        marker = new Champlain.Point.full(5.0, cyan);
        marker.set_location (lat,lon);
        pmlayer.add_marker(marker);
        path.add_node(marker);
        if(npath == 0)
        {
            path.add_node(marker);
            imlayer.add_marker(icon);
        }
        icon.set_location(lat,lon);
        npath++;
    }

    public void run()
    {
        Gtk.main();
    }

    public static int main (string[] args)
    {
        if (GtkClutter.init (ref args) != InitError.SUCCESS)
            return 1;
        var msp = new MWSerial();
        if (msp.parse_option(args) == 0)
        {
            MWPlanner app = new MWPlanner(msp);
            app.run ();
        }
        return 0;
    }
}
