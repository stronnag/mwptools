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
using Gdl;
using Clutter;
using Champlain;
using GtkChamplain;

extern double get_locale_double(string str);
extern void stupid_ubuntu_atexit(string str);

public struct TelemStats
{
    SerialStats s;
    ulong toc;
    uint tot;
    ulong avg;
}


public struct BatteryLevels
{
    float cell;
    float limit;
    string colour;
    string audio;
    string label;
    bool reached;
    public BatteryLevels(float _cell, string _colour, string? _audio, string? _label)
    {
        cell = _cell;
        limit = 0f;
        colour = _colour;
        audio = _audio;
        label = _label;
        reached = false;
    }
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


public class MWPlanner : Gtk.Application {
    public Builder builder;
    public Gtk.ApplicationWindow window;
    public  Champlain.View view;
    public MWPMarkers markers;
    private string last_file;
    private ListBox ls;
    private Gtk.SpinButton zoomer;
    private Gtk.SpinButton timadj;
    private Gtk.Label poslabel;
    public Gtk.Label stslabel;
    private Gtk.Statusbar statusbar;
    private uint context_id;
    private Gtk.Label elapsedlab;
    private double lx;
    private double ly;
    private int ht_map = 600;
    private int wd_map = 800;
    private Gtk.MenuItem menuup;
    private Gtk.MenuItem menudown;
    private Gtk.MenuItem menureplay;
    private Gtk.MenuItem menunav;
    private Gtk.MenuItem menuncfg;
    private Gtk.MenuItem menumwvar;

    public MWPSettings conf;
    private MWSerial msp;
    private Gtk.Button conbutton;
    private Gtk.ComboBoxText dev_entry;
    private Gtk.Label verlab;
    private Gtk.Label fmodelab;
    private Gtk.Label validatelab;
    private Gtk.Label typlab;
    private Gtk.Label labelvbat;
    private uint8 dmrtype=3; // default to quad
    private uint8 mrtype;
    private uint8 mvers = 230;
    private uint32 capability;
    private uint gpstid;
    private uint cmdtid;
    private uint spktid;
    private Craft craft;
    private bool follow = false;
    private bool centreon = false;
    private bool navcap = false;
    private bool naze32 = false;
    private GtkChamplain.Embed embed;
    private PrefsDialog prefs;
    private SwitchDialog swd;
    private SetPosDialog setpos;
    private Gtk.AboutDialog about;
    private NavStatus navstatus;
    private RadioStatus radstatus;
    private NavConfig navconf;
    private MapSourceDialog msview;
    private MapSeeder mseed;
    private TelemetryStats telstats;
    private GPSInfo gpsinfo;
    private WPMGR wpmgr;
    private MissionItem[] wp_resp;
    private static string mission;
    private static string serial;
    private static bool autocon;
    private int autocount = 0;
    private static bool mkcon = false;
    private static bool ignore_sz = false;
    private static bool nopoll = false;
    private static bool xnopoll;
    private static bool rawlog = false;
    private static bool norotate = false; // workaround for Ubuntu & old champlain
    private static bool gps_trail = false;
    private static bool no_max = false;
    private static bool force_mag = false;
    private static string mwoptstr;
    private uint nrx = 0;

    private MWChooser.MWVAR mwvar=MWChooser.MWVAR.AUTO;
    private uint8 vwarn1;
    private int licol;
    private DockMaster master;
    private DockLayout layout;
    public  DockItem[] dockitem;
    private Gtk.CheckButton audio_cb;
    private Gtk.CheckButton autocon_cb;
    private Gtk.CheckButton logb;
    private bool audio_on;
    private uint8 sflags = 0;
    private uint8 nsats = 0;
    private uint8 _nsats = 0;
    private uint8 larmed = 0;
    private bool wdw_state = false;
    private time_t armtime;
    private time_t duration;
        /**** FIXME ***/
    private int gfcse = 0;
    private double _ilon = 0;
    private double _ilat = 0;
    private uint8 armed = 0;
    private bool npos = false;
    private bool gpsfix;
    private time_t lastrx;
    private int lmin = 0;

    private Thread<int> thr;
    private uint plid = 0;
    private bool xlog;
    private bool xaudio;
    private int[] playfd;
    private IOChannel io_read;
    private ReplayThread robj;

    private MSP.Cmds[] requests = {};
    private int tcycle = 0;
    private bool dopoll;
    private uint8 wpx = 0;
    private bool rxerr = false;
    private int64 lastp;
    private int64 acycle;
    private int64 anvals;
    private ulong toc;
    private uint tot;
    private uint32 xbits = 0;
    private uint8 api_cnt;
    private uint8 icount = 0;
    private bool usemag = false;
    private int16 mhead;
    public static string exstr;

    private bool have_vers;
    private bool have_misc;
    private bool have_api;
    private bool have_status;
    private bool have_wp;
    private bool have_nc;
    private bool have_fcv;
    private bool vinit;
    private string fcv;
    private uint8 gpscnt = 0;
    private time_t last_an = 0;
    private time_t last_wp = 0;

    private enum DOCKLETS
    {
        MISSION=0,
        GPS,
        NAVSTATUS,
        VOLTAGE,
        RADIO,
        TELEMETRY,
        NUMBER
    }

    private enum MS_Column {
        ID,
        NAME,
        N_COLUMNS
    }

    private enum WPDL {
        IDLE=0,
        VALIDATE,
        REPLACE,
        POLL
    }

    private struct WPMGR
    {
        MSP_WP[] wps;
        WPDL wp_flag;
        uint8 npts;
        uint8 wpidx;
    }

    private enum WPFAIL {
        OK=0,
        NO = (1<<0),
        ACT = (1<<1),
        LAT = (1<<2),
        LON = (1<<3),
        ALT = (1<<4),
        P1 = (1<<5),
        P2 = (1<<6),
        P3 = (1<<7),
        FLAG = (1<<8)
    }

    private static BatteryLevels [] vlevels = {
        BatteryLevels(3.7f, "green", null, null),
        BatteryLevels(3.57f, "yellow", null, null),
        BatteryLevels(3.47f, "orange", "sat_alert.ogg",null),
        BatteryLevels(3.0f,  "red", "bleet.ogg",null),
        BatteryLevels(0.0f, "white", null, "n/a")
    };

    private static const string[] failnames = {"","WPNO","LAT","LON","ALT","P1","P2","P3","FLAG"};

    const OptionEntry[] options = {
        { "mission", 'm', 0, OptionArg.STRING, out mission, "Mission file", null},
        { "serial-device", 's', 0, OptionArg.STRING, out serial, "Serial device", null},
        { "flight-controller", 'f', 0, OptionArg.STRING, out mwoptstr, "mw|mwnav|bf|cf", null},
        { "connect", 'c', 0, OptionArg.NONE, out mkcon, "connect to first device", null},
        { "auto-connect", 'a', 0, OptionArg.NONE, out autocon, "auto-connect to first device", null},
        { "no-poll", 'n', 0, OptionArg.NONE, out nopoll, "don't poll for nav info", null},
        { "no-trail", 't', 0, OptionArg.NONE, out gps_trail, "don't display GPS trail", null},
        { "raw-log", 'r', 0, OptionArg.NONE, out rawlog, "log raw serial data to file", null},
        { "ignore-sizing", 0, 0, OptionArg.NONE, out ignore_sz, "ignore minimum size constraint", null},
        { "ignore-rotation", 0, 0, OptionArg.NONE, out norotate, "ignore vehicle icon rotation on old libchamplain", null},
        { "dont-maximise", 0, 0, OptionArg.NONE, out no_max, "don't maximise the window", null},
        { "force-mag", 0, 0, OptionArg.NONE, out force_mag, "force mag for vehicle direction", null},
        {null}
    };

    public MWPlanner ()
    {
        Object(application_id: "mwp.application", flags: ApplicationFlags.FLAGS_NONE);
    }

    public override void activate ()
    {

        base.startup();
        wpmgr = WPMGR();

        mwvar = MWChooser.fc_from_arg0();

        builder = new Builder ();
        conf = new MWPSettings();
        conf.read_settings();

        stderr.printf("FC type %s\n", conf.fctype);

        if(conf.fctype != null)
            mwvar = MWChooser.fc_from_name(conf.fctype);

        var confdir = GLib.Path.build_filename(Environment.get_user_config_dir(),"mwp");
        try
        {
            var dir = File.new_for_path(confdir);
            dir.make_directory_with_parents ();
        } catch {};

        var layfile = GLib.Path.build_filename(confdir,".layout.xml");
        var fn = MWPUtils.find_conf_file("mwp.ui");
        if (fn == null)
        {
            MSPLog.message ("No UI definition file\n");
            Posix.exit(255);
        }
        else
        {
            try
            {
                builder.add_from_file (fn);
            } catch (Error e) {
                MSPLog.message ("Builder: %s\n", e.message);
                Posix.exit(255);
            }
        }

        gps_trail = !gps_trail; // yet more jh logic

        if(mwoptstr != null)
        {
            mwvar = MWChooser.fc_from_name(mwoptstr);
        }

        if(conf.atstart != null)
        {
            try {
                Process.spawn_command_line_async(conf.atstart);
            } catch {};
        }

        if(conf.atexit != null)
        {
            exstr = conf.atexit;
            stupid_ubuntu_atexit(exstr);
        }

        builder.connect_signals (null);
        window = builder.get_object ("window1") as Gtk.ApplicationWindow;
        this.add_window (window);
        window.set_application (this);

        window.destroy.connect (() =>
            {
                    /*
                     * We only save the layout on clean exit ...
                if (layout.is_dirty())
                {
                    layout.save_layout("mwp");
                    layout.save_to_file(layfile);
                }
                    */
                quit();
            });

        window.window_state_event.connect( (e) => {
                wdw_state = ((e.new_window_state & Gdk.WindowState.FULLSCREEN) != 0);
            return false;
        });

        string icon=null;

        try {
            icon = MWPUtils.find_conf_file("mwp_icon.svg");
            window.set_icon_from_file(icon);
        } catch {};

        zoomer = builder.get_object ("spinbutton1") as Gtk.SpinButton;

        timadj = builder.get_object ("spinbutton2") as Gtk.SpinButton;
        timadj.adjustment.value = conf.updint;

        var menuop = builder.get_object ("file_open") as Gtk.MenuItem;
        menuop.activate.connect (() => {
                on_file_open();
            });

        menuop = builder.get_object ("menu_save") as Gtk.MenuItem;
        menuop.activate.connect (() => {
                on_file_save();
            });

        menuop = builder.get_object ("menu_save_as") as Gtk.MenuItem;
        menuop.activate.connect (() => {
                on_file_save_as();
            });

        menuop = builder.get_object ("menu_prefs") as Gtk.MenuItem;
        menuop.activate.connect(() =>
            {
                prefs.run_prefs(ref conf);
                if(conf.speakint > 0)
                {
                    audio_cb.sensitive = true;
                }
                else
                {
                    audio_cb.sensitive = false;
                    audio_cb.active = false;
                }
            });

        setpos = new SetPosDialog(builder);
        menuop = builder.get_object ("menugoto") as Gtk.MenuItem;
        menuop.activate.connect(() =>
            {
                double glat, glon;
                if(setpos.get_position(out glat, out glon) == true)
                {
                    view.center_on(glat, glon);
                }
            });

        msview = new MapSourceDialog(builder);
        menuop =  builder.get_object ("menu_maps") as Gtk.MenuItem;
        menuop.activate.connect(() => {
                var map_source_factory = Champlain.MapSourceFactory.dup_default();
                var sources =  map_source_factory.get_registered();
                foreach (Champlain.MapSourceDesc sr in sources)
                {
                    if(view.map_source.get_id() == sr.get_id())
                    {
                        msview.show_source(
                            sr.get_name(),
                            sr.get_id(),
                            sr.get_uri_format (),
                            sr.get_min_zoom_level(),
                            sr.get_max_zoom_level());
                        break;
                    }
                }
            });

        mseed = new MapSeeder(builder);
        menuop =  builder.get_object ("menu_seed") as Gtk.MenuItem;
        menuop.activate.connect(() => {
                mseed.run_seeder(view.map_source.get_id(),(int)zoomer.adjustment.value,
                                 view.get_bounding_box());

            });

        menuop = builder.get_object ("menu_quit") as Gtk.MenuItem;
        menuop.activate.connect (() => {
                if(layout.is_dirty())
                {
                    layout.save_layout("mwp");
                    layout.save_to_file(layfile);
                }
                quit();
            });


        menuop= builder.get_object ("menu_about") as Gtk.MenuItem;
        menuop.activate.connect (() => {
                about.show_all();
                about.run();
                about.hide();
            });

        menuup = builder.get_object ("upload_quad") as Gtk.MenuItem;
        menuup.sensitive = false;
        menuup.activate.connect (() => {
                upload_quad();
            });

        menudown = builder.get_object ("download_quad") as Gtk.MenuItem;
        menudown.sensitive =false;
        menudown.activate.connect (() => {
                download_quad();
            });

        menureplay = builder.get_object ("replay_log") as Gtk.MenuItem;
        menureplay.activate.connect (() => {
                replay_log(true);
            });

        menuop = builder.get_object ("load_log") as Gtk.MenuItem;
        menuop.activate.connect (() => {
                replay_log(false);
            });

        navstatus = new NavStatus(builder);
        menunav = builder.get_object ("nav_status_menu") as Gtk.MenuItem;
        menunav.activate.connect (() => {
                    navstatus.show();
            });

        menuncfg = builder.get_object ("nav_config_menu") as Gtk.MenuItem;
        menuncfg.sensitive =false;
        navconf = new NavConfig(window, builder, this);

        menuncfg.activate.connect (() => {
                navconf.show();
            });

        var mi = builder.get_object ("gps_menu_view") as Gtk.MenuItem;
        mi.activate.connect (() => {
                if(dockitem[DOCKLETS.GPS].is_closed() && !dockitem[DOCKLETS.GPS].is_iconified())
                {
                   dockitem[DOCKLETS.GPS].show();
                   dockitem[DOCKLETS.GPS].iconify_item();
                }
            });

        mi = builder.get_object ("tote_menu_view") as Gtk.MenuItem;
        mi.activate.connect (() => {
                if(dockitem[DOCKLETS.MISSION].is_closed() && !dockitem[DOCKLETS.MISSION].is_iconified())
                {
                   dockitem[DOCKLETS.MISSION].show();
                   dockitem[DOCKLETS.MISSION].iconify_item();
                }
            });

        mi = builder.get_object ("voltage_menu_view") as Gtk.MenuItem;
        mi.activate.connect (() => {
                if(dockitem[DOCKLETS.VOLTAGE].is_closed() && !dockitem[DOCKLETS.VOLTAGE].is_iconified())
                {
                   dockitem[DOCKLETS.VOLTAGE].show();
                   dockitem[DOCKLETS.VOLTAGE].iconify_item();
                   }
            });

        radstatus = new RadioStatus(builder);

        mi = builder.get_object ("radio_menu_view") as Gtk.MenuItem;
        mi.activate.connect (() => {
                if(dockitem[DOCKLETS.RADIO].is_closed() && !dockitem[DOCKLETS.RADIO].is_iconified())
                {
                   dockitem[DOCKLETS.RADIO].show();
                   dockitem[DOCKLETS.RADIO].iconify_item();
                   }
            });


        telstats = new TelemetryStats(builder);
        mi =  builder.get_object ("ss_dialog") as Gtk.MenuItem;
        mi.activate.connect(() => {
                if(dockitem[DOCKLETS.TELEMETRY].is_closed() && !dockitem[DOCKLETS.TELEMETRY].is_iconified())
                {
                   dockitem[DOCKLETS.TELEMETRY].show();
                   dockitem[DOCKLETS.TELEMETRY].iconify_item();
                   }
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


        var ent = builder.get_object ("entry1") as Gtk.Entry;
        ent.set_text(conf.altitude.to_string());

        ent = builder.get_object ("entry2") as Gtk.Entry;
        ent.set_text(conf.loiter.to_string());

        var scale = new Champlain.Scale();
        scale.connect_view(view);
        view.add_child(scale);
        var lm = view.get_layout_manager();
        lm.child_set(view,scale,"x-align", Clutter.ActorAlign.START);
        lm.child_set(view,scale,"y-align", Clutter.ActorAlign.END);
        view.set_keep_center_on_resize(true);

        if(ignore_sz == false)
        {
            var s = window.get_screen();
            var m = s.get_monitor_at_window(s.get_active_window());
            Gdk.Rectangle monitor;
            s.get_monitor_geometry(m, out monitor);
            var tmp = monitor.width - 320;
            if (wd_map > tmp)
                wd_map = tmp;
            tmp = monitor.height - 180;
            if (ht_map > tmp)
                ht_map = tmp;
            embed.set_size_request(wd_map, ht_map);
        }

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

                    case Gdk.Key.F11:
                        toggle_full_screen();
                        break;

                    case Gdk.Key.f:
                        if((e.state & Gdk.ModifierType.CONTROL_MASK) != Gdk.ModifierType.CONTROL_MASK)
                            ret = false;
                        else
                            toggle_full_screen();
                        break;

                    case Gdk.Key.c:
                        if((e.state & Gdk.ModifierType.CONTROL_MASK) != Gdk.ModifierType.CONTROL_MASK)
                            ret = false;
                        else
                        {
                            if(craft != null)
                                craft.init_trail();
                        }
                        break;

                    case Gdk.Key.s:
                        if((e.state & Gdk.ModifierType.CONTROL_MASK) != Gdk.ModifierType.CONTROL_MASK)
                            ret = false;
                        else
                        {
                            show_serial_stats();
                        }
                        break;
                    case Gdk.Key.i:
                        if((e.state & Gdk.ModifierType.CONTROL_MASK) != Gdk.ModifierType.CONTROL_MASK)
                            ret = false;
                        else
                        {
                            init_state();
                        }
                        break;

/*
                    case Gdk.Key.question:
                        if((e.state & Gdk.ModifierType.CONTROL_MASK) != Gdk.ModifierType.CONTROL_MASK)
                            ret = false;
                        else
                        {
                            var map_source_factory = Champlain.MapSourceFactory.dup_default();
                            var sources =  map_source_factory.get_registered();
                            foreach (Champlain.MapSourceDesc sr in sources)
                            {
                                if(view.map_source.get_id() == sr.get_id())
                                {
                                    stdout.printf("%s %u %u %s %s\n",
                                                  sr.get_id(),
                                                  sr.get_min_zoom_level(),
                                                  sr.get_max_zoom_level(),
                                                  sr.get_name(),
                                                  sr.get_uri_format ()
                                                  );
                                    break;
                                }
                            }
                        }
                        break;
*/
                    case Gdk.Key.t:
                        if((e.state & Gdk.ModifierType.CONTROL_MASK) != Gdk.ModifierType.CONTROL_MASK)
                            ret = false;
                        else
                        {
                            armtime = 0;
                            duration = 0;
                        }
                        break;

                    default:
                        ret = false;
                        break;
                }
                return ret;
            });


        ls = new ListBox();
        ls.create_view(this);

        var scroll = new Gtk.ScrolledWindow (null, null);
        scroll.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
        scroll.set_min_content_width(400);
        scroll.add (ls.view);

        var grid =  builder.get_object ("grid1") as Gtk.Grid;
        gpsinfo = new GPSInfo(grid);

        var dock = new Dock ();
        master = dock.master;
        layout = new DockLayout (master);

        var dockbar = new DockBar (dock);
        dockbar.set_style (DockBarStyle.ICONS);

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL,0);
        pane.add2(box);

        box.pack_start (dockbar, false, false, 0);
        box.pack_end (dock, true, true, 0);

        dockitem = new DockItem[DOCKLETS.NUMBER];

        dockitem[DOCKLETS.MISSION]= new DockItem.with_stock ("Mission",
                         "Mission Tote", "gtk-properties",
                         DockItemBehavior.NORMAL | DockItemBehavior.CANT_CLOSE);
        dockitem[DOCKLETS.MISSION].add (scroll);
        dockitem[DOCKLETS.MISSION].show ();
        dock.add_item (dockitem[DOCKLETS.MISSION], DockPlacement.TOP);

        dockitem[DOCKLETS.GPS]= new DockItem.with_stock ("GPS",
                         "GPS Info", "gtk-refresh",
                         DockItemBehavior.NORMAL | DockItemBehavior.CANT_CLOSE);
        dockitem[DOCKLETS.GPS].add (grid);
        dock.add_item (dockitem[DOCKLETS.GPS], DockPlacement.BOTTOM);
        dockitem[DOCKLETS.GPS].show ();

        dockitem[DOCKLETS.NAVSTATUS]= new DockItem.with_stock ("Status",
                         "NAV Status", "gtk-info",
                         DockItemBehavior.NORMAL | DockItemBehavior.CANT_CLOSE);
        dockitem[DOCKLETS.NAVSTATUS].add (navstatus.grid);
        dock.add_item (dockitem[DOCKLETS.NAVSTATUS], DockPlacement.BOTTOM);
        dockitem[DOCKLETS.NAVSTATUS].show ();

        dockitem[DOCKLETS.VOLTAGE]= new DockItem.with_stock ("Volts",
                         "Battery Monitor", "gtk-dialog-warning",
                         DockItemBehavior.NORMAL | DockItemBehavior.CANT_CLOSE);
        dockitem[DOCKLETS.VOLTAGE].add (navstatus.voltbox);
        dock.add_item (dockitem[DOCKLETS.VOLTAGE], DockPlacement.BOTTOM);

        dockitem[DOCKLETS.RADIO]= new DockItem.with_stock ("Radio",
                         "Radio Status", "gtk-network",
                         DockItemBehavior.NORMAL | DockItemBehavior.CANT_CLOSE);
        dockitem[DOCKLETS.RADIO].add (radstatus.grid);
        dock.add_item (dockitem[DOCKLETS.RADIO], DockPlacement.BOTTOM);

        dockitem[DOCKLETS.TELEMETRY]= new DockItem.with_stock ("Telemetry",
                         "Telemetry", "gtk-disconnect",
                         DockItemBehavior.NORMAL | DockItemBehavior.CANT_CLOSE);
        dockitem[DOCKLETS.TELEMETRY].add (telstats.grid);
        dock.add_item (dockitem[DOCKLETS.TELEMETRY], DockPlacement.BOTTOM);

        view.notify["zoom-level"].connect(() => {
                var val = view.get_zoom_level();
                var zval = (int)zoomer.adjustment.value;
                if (val != zval)
                    zoomer.adjustment.value = (int)val;
            });

        markers = new MWPMarkers();
        view.add_layer (markers.path);
        view.add_layer (markers.markers);
        view.button_release_event.connect((evt) => {
                if(evt.button == 3)
                {
                    var lon = view.x_to_longitude (evt.x);
                    var lat = view.y_to_latitude (evt.y);
                    ls.insert_item(MSP.Action.WAYPOINT, lat,lon);
                    ls.calc_mission();
                    return true;
                }
                else
                    return false;
            });

        poslabel = builder.get_object ("poslabel") as Gtk.Label;
        stslabel = builder.get_object ("missionlab") as Gtk.Label;
        statusbar = builder.get_object ("statusbar1") as Gtk.Statusbar;
        context_id = statusbar.get_context_id ("Starting");
        elapsedlab =  builder.get_object ("elapsedlab") as Gtk.Label;
        logb = builder.get_object ("logger_cb") as Gtk.CheckButton;
        logb.toggled.connect (() => {
                if (logb.active)
                    Logger.start(last_file,mvers,mrtype,capability,mwvar);
                else
                    Logger.stop();
            });


        autocon_cb = builder.get_object ("autocon_cb") as Gtk.CheckButton;

        audio_cb = builder.get_object ("audio_cb") as Gtk.CheckButton;
        audio_cb.sensitive = (conf.speakint > 0);
        audio_cb.toggled.connect (() => {
                audio_on = audio_cb.active;
                if (audio_on)
                    start_audio();
                else
                    stop_audio();
            });
        var centreonb = builder.get_object ("checkbutton1") as Gtk.CheckButton;
        centreonb.toggled.connect (() => {
                centreon = centreonb.active;
            });


        var followb = builder.get_object ("checkbutton2") as Gtk.CheckButton;
        if(conf.autofollow)
        {
            follow = true;
            followb.active = true;
        }

        followb.toggled.connect (() => {
                follow = followb.active;
                if (follow == false && craft != null)
                {
                    craft.park();
                }
            });

        var mwc = new MWChooser(builder);

        menumwvar = builder.get_object ("menuitemmwvar") as Gtk.MenuItem;
        menumwvar.activate.connect (() => {
                var _m = mwc.get_version(mwvar);
                if(_m !=  MWChooser.MWVAR.UNDEF)
                    mwvar = _m;
            });

        prefs = new PrefsDialog(builder);
        swd = new SwitchDialog(builder);

        about = builder.get_object ("aboutdialog1") as Gtk.AboutDialog;
        Gdk.Pixbuf pix = null;
        try  {
            pix = new Gdk.Pixbuf.from_file_at_size (icon, 200,200);
        } catch  {};
        about.logo = pix;
        Timeout.add(500, () => { anim_cb(); return true;});

        if (mission == null)
        {
            view.center_on(conf.latitude,conf.longitude);
            view.set_property("zoom-level", conf.zoom);
            zoomer.adjustment.value = conf.zoom;
        }
        else
        {
            load_file(mission);
        }

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
                    connect_serial();
            });

        verlab = builder.get_object ("verlab") as Gtk.Label;
        fmodelab = builder.get_object ("fmode") as Gtk.Label;
        validatelab = builder.get_object ("validated") as Gtk.Label;
        typlab = builder.get_object ("typlab") as Gtk.Label;
        labelvbat = builder.get_object ("labelvbat") as Gtk.Label;
        conbutton.clicked.connect(() => { connect_serial(); });

        msp = new MWSerial();
        msp.serial_lost.connect(() => { serial_doom(conbutton); });

        msp.serial_event.connect((s,cmd,raw,len,errs) => {
                handle_serial(cmd,raw,len,errs);
            });

        if(serial != null)
        {
            dev_entry.prepend_text(serial);
            dev_entry.active = 0;
        }

        autocon_cb.toggled.connect(() => {
                autocon =  autocon_cb.active;
                autocount = 0;
            });

        if(conf.vlevels != null)
        {
            string [] parts;
            parts = conf.vlevels.split(";");
            var i = 0;
            foreach (unowned string str in parts)
            {
                var d = get_locale_double(str);
                vlevels[i].cell = (float)d;
                i++;
            }
        }

        if(autocon)
        {
            autocon_cb.active=true;
            mkcon = true;
        }

        if(mwvar == MWChooser.MWVAR.UNDEF)
        {
            mwvar = mwc.get_version(MWChooser.MWVAR.MWOLD);
        }

        if(mwvar == MWChooser.MWVAR.UNDEF)
        {
            Posix.exit(255);
        }

        if(no_max == false)
            window.maximize();
        window.show_all();

        if(mkcon)
        {
            connect_serial();
        }

        Timeout.add_seconds(5, () => { return try_connect(); });

        navstatus.setdock(dockitem[DOCKLETS.NAVSTATUS]);
        radstatus.setdock(dockitem[DOCKLETS.RADIO]);
        telstats.setdock(dockitem[DOCKLETS.TELEMETRY]);

        if(layout.load_from_file(layfile) && layout.load_layout("mwp"))
            ;
        else
        {
            dockitem[DOCKLETS.GPS].iconify_item ();
            dockitem[DOCKLETS.NAVSTATUS].iconify_item ();
            dockitem[DOCKLETS.VOLTAGE].hide ();
            dockitem[DOCKLETS.RADIO].hide ();
        }

        if(conf.heartbeat != null)
        {
            Timeout.add_seconds(60, () => {
                    try {
                        Process.spawn_command_line_async(conf.heartbeat);
                    } catch {};
                    return true;
                });
        }
    }

    private void toggle_full_screen()
    {
        if(wdw_state == true)
            window.unfullscreen();
        else
            window.fullscreen();
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

    private void set_error_status(string? e)
    {
        if(e != null)
        {
            statusbar.push(context_id, e);
            MSPLog.message("%s\n", e);
            bleet_sans_merci("beep-sound.ogg");
        }
        else
        {
            statusbar.push(context_id, "");
        }
    }

    private void msg_poller()
    {
        if(dopoll)
        {
            send_poll();
            start_poll_timer();
        }
    }

    private void start_poll_timer()
    {
        gpstid = Timeout.add(1000, () => {
                if(dopoll)
                {
                    toc++;
                    var req=requests[tcycle];
                    var s = MSP.to_string(req);
                    MSPLog.message("timeout on %s\n", s);
                    send_poll();
                    return true;
                }
                else
                    return false;
            });
    }

    private void send_poll()
    {
        var req=requests[tcycle];
        if(tcycle == 0)
            lastp = GLib.get_monotonic_time();
        time_t now;
        time_t(out now);
        if(((int)now - (int)lastrx) > 5)
        {
            if(rxerr == false)
            {
                set_error_status("No data for 5 seconds");
                rxerr=true;
            }
            nrx++;
                /* Probably takes a minute to change the LIPO */
            if(nrx > 30)
            {
                MSPLog.message("Restart poll loop\n");
                init_state();
                dopoll = false;
                add_cmd(MSP.Cmds.IDENT,null,0, 2500);
            }
        }
        else
        {
            if(rxerr)
            {
                set_error_status(null);
                rxerr=false;
            }
            nrx = 0;
        }

        switch(req)
        {
            case MSP.Cmds.ANALOG:


                if (now - last_an > 4)
                {
                    send_cmd(req, null, 0);
                    last_an = now;
//                    MSPLog.message("send analog\n");
                }
                else
                {
                    tcycle = (tcycle + 1) % requests.length;
                    send_poll();
                }
                break;
            case MSP.Cmds.WP:
                if( gpsfix == true && armed == 1 && (now - last_wp) > 1)
                {
                    send_cmd(req,&wpx,1);
//                    MSPLog.message("send WP %d\n", wpx);
                    wpx = (wpx + 16) & 16;
                    last_wp = now;
                }
                else
                {
                    tcycle = (tcycle + 1) % requests.length;
                    send_poll();
                }
                break;
            default:
                send_cmd(req, null, 0);
//                MSPLog.message("send %d\n", req);
                break;
        }
    }

    private void handle_serial(MSP.Cmds cmd, uint8[] raw, uint len, bool errs)
    {
        if(errs == true)
        {
            remove_tid(ref cmdtid);
            stdout.printf("Error on cmd %s %d\n", MSP.to_string(cmd), cmd);
            switch(cmd)
            {
                case MSP.Cmds.NAV_CONFIG:
                    navcap = false;
                    break;
                case MSP.Cmds.API_VERSION:
                    have_api = true;
                    add_cmd(MSP.Cmds.IDENT,null,0, 1000);
                    break;
                case MSP.Cmds.FC_VARIANT:
                    have_fcv=true;
                    add_cmd(MSP.Cmds.IDENT,null,0, 1000);
                    break;
                default:
                    break;
            }
            return;
        }
        Logger.log_time();

        if(gpstid > 0 && cmd == requests[tcycle])
        {
            remove_tid(ref gpstid);
        }

        if(cmd != MSP.Cmds.RADIO)
            time_t(out lastrx);

        switch(cmd)
        {
            case MSP.Cmds.API_VERSION:
                remove_tid(ref cmdtid);
                have_api = true;
                if(len > 32)
                {
                    naze32 = true;
                    mwvar = MWChooser.MWVAR.CF;
                    add_cmd(MSP.Cmds.IDENT,null,0,1000);
                }
                else
                {
                    add_cmd(MSP.Cmds.FC_VARIANT,null,0,1000);
                }

                break;

            case MSP.Cmds.FC_VARIANT:
                remove_tid(ref cmdtid);
                have_fcv = true;
                naze32 = true;
                have_fcv = true;
                raw[4] = 0;
                fcv = (string)raw[0:4];
                switch(fcv)
                {
                    case "CLFL":
                        mwvar = MWChooser.MWVAR.CF;
                        add_cmd(MSP.Cmds.FC_VERSION,null,0,1000);
                        break;
                    default:
                        add_cmd(MSP.Cmds.IDENT,null,0,1000);
                        break;
                }
                break;

            case MSP.Cmds.FC_VERSION:
                remove_tid(ref cmdtid);
                fcv = "%s v%d.%d.%d".printf(fcv,raw[0],raw[1],raw[2]);
                add_cmd(MSP.Cmds.IDENT,null,0,1000);
                break;

            case MSP.Cmds.IDENT:
                remove_tid(ref cmdtid);
                remove_tid(ref gpstid); // in case from timeout
                have_vers = true;
                if (icount == 0)
                {
                    mvers = raw[0];
                    mrtype = raw[1];
                    if(dmrtype != mrtype)
                    {
                        dmrtype = mrtype;
                        if(craft != null)
                            craft.set_icon(mrtype);
                    }

                    deserialise_u32(raw+3, out capability);

                    MWChooser.MWVAR _mwvar = mwvar;

                    if(mwvar == MWChooser.MWVAR.AUTO)
                    {
                        naze32 = ((capability & MSPCaps.CAP_PLATFORM_32BIT) != 0);
                    }
                    else
                    {
                        naze32 = (mwvar == MWChooser.MWVAR.CF || mwvar == MWChooser.MWVAR.BF);
                    }

                    if(naze32 == true)
                    {
                        navcap = false;
                    }
                    else
                    {
                        navcap = ((raw[3] & 0x10) == 0x10);
                    }
                    if(mwvar == MWChooser.MWVAR.AUTO)
                    {
                        if(naze32)
                        {
                            _mwvar =  ((capability & MSPCaps.CAP_CLEANFLIGHT_CONFIG) != 0)  ? MWChooser.MWVAR.CF : MWChooser.MWVAR.BF;
                        }
                        else
                        {
                            _mwvar = (navcap) ? MWChooser.MWVAR.MWNEW : MWChooser.MWVAR.MWOLD;
                        }
                    }
                    string vers;

                    if(fcv != null)
                    {
                        vers="%s compat %03d".printf(fcv, mvers);
                    }
                    else
                    {
                        vers="%s v%03d".printf(MWChooser.mwnames[_mwvar], mvers);
                    }

                    verlab.set_label(vers);
                    typlab.set_label(MSP.get_mrtype(mrtype));
                    stdout.printf("IDENT %s %d\n", vers, mrtype);
                    if(navcap == true)
                    {
                        menuup.sensitive = menudown.sensitive = menuncfg.sensitive = true;
                    }
                    add_cmd(MSP.Cmds.MISC,null,0, 1000);
                }
                icount++;
                break;

            case MSP.Cmds.MISC:
                remove_tid(ref cmdtid);
                have_misc = true;
                vwarn1 = raw[19];
                add_cmd(MSP.Cmds.STATUS,null,0, 1000);
                break;

            case MSP.Cmds.STATUS:
                uint16 sensor;
                uint32 flag;
                deserialise_u16(raw+4, out sensor);
                deserialise_u32(raw+6, out flag);

                if (nopoll == true)
                {
                    have_status = true;
                    remove_tid(ref cmdtid);
                    if((sensor & MSP.Sensors.GPS) == MSP.Sensors.GPS)
                    {
                        sflags |= NavStatus.SPK.GPS;
                        if(craft == null)
                        {
                            craft = new Craft(view, mrtype, norotate, gps_trail);
                            craft.park();
                        }
                    }
                }
                else
                {
                    if(have_status == false)
                    {
                        remove_tid(ref cmdtid);
                        have_status = true;
                        if(conf.checkswitches && ((flag & 6) == 0))
                        {
                            swd.run();
                        }

                        if(navcap == true)
                            add_cmd(MSP.Cmds.NAV_CONFIG,null,0,1000);

                        var  val = timadj.adjustment.value;
                        ulong reqsize = 0;
                        requests.resize(0);

                        requests += MSP.Cmds.STATUS;
                        reqsize += MSize.MSP_STATUS;

                        requests += MSP.Cmds.ANALOG;
                        reqsize += MSize.MSP_ANALOG;

                        sflags = NavStatus.SPK.Volts;

                        if((sensor & MSP.Sensors.GPS) == MSP.Sensors.GPS)
                        {
                            if(gpscnt > 0)
                            {
                                set_error_status("");
                                gpscnt = 0;
                            }
                            sflags |= NavStatus.SPK.GPS;
                            if(navcap == true)
                            {
                                requests += MSP.Cmds.NAV_STATUS;
                                reqsize += MSize.MSP_NAV_STATUS;
                            }
                            requests += MSP.Cmds.RAW_GPS;
                            requests += MSP.Cmds.COMP_GPS;
                            reqsize += (MSize.MSP_RAW_GPS + MSize.MSP_COMP_GPS);
                            if(craft == null)
                            {
                                craft = new Craft(view, mrtype,norotate, gps_trail);
                                craft.park();
                            }
                            if(naze32)
                            {
                                wpmgr.wp_flag = WPDL.POLL;
                                requests += MSP.Cmds.WP;
                                reqsize += 18;
                            }
                        }
                        else
                        {
                            set_error_status("No GPS detected");
                            MSPLog.message("no gps, sensor = 0x%x\n", sensor);
                            if(gpscnt < 2)
                            {
                                gpscnt++;
                                have_status = false;
                                add_cmd(MSP.Cmds.STATUS,null,0, 1000);
                            }
                            else
                                gpscnt = 0;
                        }

                        if(force_mag)
                            usemag = true;
                        else
                            usemag = ((sensor & MSP.Sensors.MAG) == MSP.Sensors.MAG);
                        if((sensor & MSP.Sensors.ACC) == MSP.Sensors.ACC)
                        {
                            requests += MSP.Cmds.ATTITUDE;
                            reqsize += MSize.MSP_ATTITUDE;
                        }

                        if((sensor & MSP.Sensors.BARO) == MSP.Sensors.BARO)
                        {
                            sflags |= NavStatus.SPK.BARO;
                            requests += MSP.Cmds.ALTITUDE;
                            reqsize += MSize.MSP_ALTITUDE;
                        }

                        var nreqs = requests.length;
                        int timeout = (int)(val*1000 / nreqs);

                            // data we send, response is structs + this
                        var qsize = nreqs * 6;
                        reqsize += qsize;
                        if(naze32)
                            qsize += 1; // for WP no

                        print("Timer cycle for %d (%dms) items, %lu => %lu bytes\n",
                              nreqs,timeout,qsize,reqsize);

                        if(nopoll == false && nreqs > 0)
                        {
//                            MSPLog.message("Start poller\n");
                            dopoll = true;
                            tcycle = 0;
                            lastp = GLib.get_monotonic_time();
                        }
                        start_audio();
                        report_bits(flag);
                    }

                    armed = (uint8)(flag & 1);

                    if(armed == 0)
                    {
                        armtime = 0;
                        duration = -1;
                    }
                    else
                    {
                        if(armtime == 0)
                            armtime = time_t(out armtime);
                        time_t(out duration);
                        duration -= armtime;
                    }

                    if(Logger.is_logging)
                    {
                        Logger.armed((armed == 1), duration, flag, sensor);
                    }

                    if(armed != larmed)
                    {
                        if(gps_trail)
                        {
                            if(armed == 1 && craft != null)
                            {
                                craft.init_trail();
                            }
                        }

                        if (armed == 1)
                        {
                            if (conf.audioarmed == true)
                            {
                                audio_cb.active = true;
                            }
                            if(conf.logarmed == true)
                            {
                                logb.active = true;
                                Logger.armed(true,duration,flag, sensor);
                            }
                            duration_timer();
                        }
                        else
                        {
                            if (conf.audioarmed == true)
                            {
                                audio_cb.active = false;
                            }
                            if(conf.logarmed == true)
                            {
                                Logger.armed(false,duration,flag, sensor);
                                logb.active=false;
                            }
                        }
                        larmed = armed;
                    }
                        // acro/horizon/angle changed
                    if((flag & 6) != (xbits & 6))
                    {
                        report_bits(flag);
                    }
                    xbits = flag;
                }
                break;

            case MSP.Cmds.INFO_WP:
                uint8* rp = raw;
                var w = MSP_WP();
                w.wp_no = *rp++;
                rp++; // skip action
                rp = deserialise_i32(rp, out w.lat);
                rp = deserialise_i32(rp, out w.lon);
                double rlat = w.lat/10000000.0;
                double rlon = w.lon/10000000.0;
                if(craft != null && rlat != 0.0 && rlon != 0.0)
                {
                    craft.special_wp(w.wp_no, rlat, rlon);
                }
                break;

            case MSP.Cmds.NAV_STATUS:
            {
                MSP_NAV_STATUS ns = MSP_NAV_STATUS();
                uint8* rp = raw;
                ns.gps_mode = *rp++;
                ns.nav_mode = *rp++;
                ns.action = *rp++;
                ns.wp_number = *rp++;
                ns.nav_error = *rp++;
                deserialise_u16(rp, out ns.target_bearing);
                navstatus.update(ns);
            }
            break;

            case MSP.Cmds.NAV_CONFIG:
            {
                remove_tid(ref cmdtid);
                have_nc = true;
                MSP_NAV_CONFIG nc = MSP_NAV_CONFIG();
                uint8* rp = raw;
                nc.flag1 = *rp++;
                nc.flag2 = *rp++;
                rp = deserialise_u16(rp, out nc.wp_radius);
                rp = deserialise_u16(rp, out nc.safe_wp_distance);
                rp = deserialise_u16(rp, out nc.nav_max_altitude);
                rp = deserialise_u16(rp, out nc.nav_speed_max);
                rp = deserialise_u16(rp, out nc.nav_speed_min);
                nc.crosstrack_gain = *rp++;
                rp = deserialise_u16(rp, out nc.nav_bank_max);
                rp = deserialise_u16(rp, out nc.rth_altitude);
                nc.land_speed = *rp++;
                rp = deserialise_u16(rp, out nc.fence);
                nc.max_wp_number = *rp;
                navconf.update(nc);
            }
            break;

            case MSP.Cmds.SET_NAV_CONFIG:
                send_cmd(MSP.Cmds.EEPROM_WRITE,null, 0);
                break;

            case MSP.Cmds.COMP_GPS:
            {
                MSP_COMP_GPS cg = MSP_COMP_GPS();
                uint8* rp;
                rp = deserialise_u16(raw, out cg.range);
                rp = deserialise_i16(rp, out cg.direction);
                cg.update = *rp;
                navstatus.comp_gps(cg);
            }
            break;

            case MSP.Cmds.ATTITUDE:
            {
                MSP_ATTITUDE at = MSP_ATTITUDE();
                uint8* rp;
                rp = deserialise_i16(raw, out at.angx);
                rp = deserialise_i16(rp, out at.angy);
                deserialise_i16(rp, out at.heading);
                if(usemag)
                {
                    mhead = at.heading;
                    if(mhead < 0)
                        mhead += 360;
                }
                navstatus.set_attitude(at);
            }
            break;

            case MSP.Cmds.ALTITUDE:
            {
                MSP_ALTITUDE al = MSP_ALTITUDE();
                uint8* rp;
                rp = deserialise_i32(raw, out al.estalt);
                deserialise_i16(rp, out al.vario);
                navstatus.set_altitude(al);
            }
            break;

            case MSP.Cmds.ANALOG:
            {
                MSP_ANALOG an = MSP_ANALOG();
                an.vbat = raw[0];
                if(Logger.is_logging)
                {
                    Logger.analog(an);
                }
                var ivbat = an.vbat;
                set_bat_stat(ivbat);
            }
            break;

            case MSP.Cmds.RAW_GPS:
            {
                MSP_RAW_GPS rg = MSP_RAW_GPS();
                uint8* rp = raw;
                rg.gps_fix = *rp++;
                rg.gps_numsat = *rp++;
                rp = deserialise_i32(rp, out rg.gps_lat);
                rp = deserialise_i32(rp, out rg.gps_lon);
                rp = deserialise_i16(rp, out rg.gps_altitude);
                rp = deserialise_u16(rp, out rg.gps_speed);
                deserialise_u16(rp, out rg.gps_ground_course);
                gpsfix = (gpsinfo.update(rg, conf.dms) != 0);
                _nsats = rg.gps_numsat;
                if (gpsfix)
                {
                    if(craft != null)
                    {
                        if(follow == true)
                        {
                            double cse = (usemag) ? mhead : gpsinfo.cse;
                            craft.set_lat_lon(gpsinfo.lat,gpsinfo.lon,cse);
                        }
                        if (centreon == true)
                            view.center_on(gpsinfo.lat,gpsinfo.lon);
                    }
                }
            }
            break;

            case MSP.Cmds.SET_WP:
                var no = wpmgr.wps[wpmgr.wpidx].wp_no;
                request_wp(no);
                break;

            case MSP.Cmds.WP:
            {
                remove_tid(ref cmdtid);
                have_wp = true;
                MSP_WP w = MSP_WP();
                uint8* rp = raw;

                if(wpmgr.wp_flag != WPDL.POLL)
                {
                    w.wp_no = *rp++;
                    w.action = *rp++;
                    rp = deserialise_i32(rp, out w.lat);
                    rp = deserialise_i32(rp, out w.lon);
                    rp = deserialise_u32(rp, out w.altitude);
                    rp = deserialise_i16(rp, out w.p1);
                    rp = deserialise_u16(rp, out w.p2);
                    rp = deserialise_u16(rp, out w.p3);
                    w.flag = *rp;
                }

                if (wpmgr.wp_flag == WPDL.VALIDATE)
                {
                    WPFAIL fail = WPFAIL.OK;
                    if(w.wp_no != wpmgr.wps[wpmgr.wpidx].wp_no)
                        fail |= WPFAIL.NO;
                    else if(w.action != wpmgr.wps[wpmgr.wpidx].action)
                        fail |= WPFAIL.ACT;
                    else if (w.lat != wpmgr.wps[wpmgr.wpidx].lat)
                        fail |= WPFAIL.LAT;
                    else if (w.lon != wpmgr.wps[wpmgr.wpidx].lon)
                            fail |= WPFAIL.LON;
                    else if (w.altitude != wpmgr.wps[wpmgr.wpidx].altitude)
                        fail |= WPFAIL.ALT;
                    else if (w.p1 != wpmgr.wps[wpmgr.wpidx].p1)
                        fail |= WPFAIL.P1;
                    else if (w.p2 != wpmgr.wps[wpmgr.wpidx].p2)
                        fail |= WPFAIL.P2;
                    else if (w.p3 != wpmgr.wps[wpmgr.wpidx].p3)
                        fail |= WPFAIL.P3;
                    else if (w.flag != wpmgr.wps[wpmgr.wpidx].flag)
                        fail |= WPFAIL.FLAG;

                    if (fail != WPFAIL.OK)
                    {
                        string[] arry = {};
                        for(var i = WPFAIL.OK; i <= WPFAIL.FLAG; i += 1)
                        {
                            if ((fail & i) == i)
                            {
                                arry += failnames[i];
                            }
                        }
                        var fmsg = string.join("|",arry);
                        var mtxt = "Validation for wp %d fails for %s".printf(w.wp_no, fmsg);
                        bleet_sans_merci("beep-sound.ogg");
                        mwp_warning_box(mtxt, Gtk.MessageType.ERROR);
                    }
                    else if(w.flag != 0xa5)
                    {
                        wpmgr.wpidx++;
                        uint8 wtmp[64];
                        var nb = serialise_wp(wpmgr.wps[wpmgr.wpidx], wtmp);
                        send_cmd(MSP.Cmds.SET_WP, wtmp, nb);
                    }
                    else
                    {
                        bleet_sans_merci("beep-sound.ogg");
                        validatelab.set_text("✔"); // u+2714
                        mwp_warning_box("Mission validated", Gtk.MessageType.INFO,5);
                    }
                }
                else if (wpmgr.wp_flag == WPDL.REPLACE)
                {
                    MissionItem m = MissionItem();
                    m.no= w.wp_no;
                    m.action = (MSP.Action)w.action;
                    m.lat = w.lat/10000000.0;
                    m.lon = w.lon/10000000.0;
                    m.alt = w.altitude/100;
                    m.param1 = w.p1;
                    if(m.action == MSP.Action.SET_HEAD &&
                       conf.recip_head  == true && m.param1 != -1)
                    {
                        m.param1 = (m.param1 + 180) % 360;
                        stdout.printf("fixup %d %d\n", m.no, m.param1);
                    }
                    m.param2 = w.p2;
                    m.param3 = w.p3;

                    wp_resp += m;
                    if(w.flag == 0xa5 || w.wp_no == 255)
                    {
                        var ms = new Mission();
                        if(w.wp_no == 1 && m.action == MSP.Action.RTH
                           && w.lat == 0 && w.lon == 0)
                        {
                            ls.clear_mission();
                        }
                        else
                        {
                            ms.set_ways(wp_resp);
                            ls.import_mission(ms);
                            foreach(MissionItem mi in wp_resp)
                            {
                                if(mi.action != MSP.Action.RTH &&
                                   mi.action != MSP.Action.JUMP &&
                                   mi.action != MSP.Action.SET_HEAD)
                                {
                                    if (mi.lat > ms.maxy)
                                        ms.maxy = mi.lat;
                                    if (mi.lon > ms.maxx)
                                        ms.maxx = mi.lon;
                                    if (mi.lat <  ms.miny)
                                        ms.miny = mi.lat;
                                    if (mi.lon <  ms.minx)
                                        ms.minx = mi.lon;
                                }
                            }
                            ms.zoom = 16;
                            ms.cy = (ms.maxy + ms.miny) / 2.0;
                            ms.cx = (ms.maxx + ms.minx) / 2.0;
                            if (centreon == false)
                            {
                                var mmax = view.get_max_zoom_level();
                                view.center_on(ms.cy, ms.cx);
                                view.set_property("zoom-level", mmax-1);
                            }
                            markers.add_list_store(ls);
                        }
                        wp_resp={};
                    }
                    else if(w.flag == 0xfe)
                    {
                        MSPLog.message("Error flag on wp #%d\n", w.wp_no);
                    }
                    else
                    {
                        request_wp(w.wp_no+1);
                    }
                }
                else if (wpmgr.wp_flag == WPDL.POLL)
                {
                    w = MSP_WP();
                    w.wp_no = *rp++;
                    if(naze32 == false)
                        rp++; // skip action
                    rp = deserialise_i32(rp, out w.lat);
                    rp = deserialise_i32(rp, out w.lon);
                    if (w.lat != 0 && w.lon != 0)
                    {
                        rp = deserialise_u32(rp, out w.altitude);
                        if(Logger.is_logging)
                        {
                            Logger.wp_poll(w);
                        }
                        double rlat = w.lat/10000000.0;
                        double rlon = w.lon/10000000.0;
                        if(craft != null)
                            craft.special_wp(w.wp_no, rlat, rlon);
                    }
                }
                else
                {
                    MSPLog.message("unsolicited WP #%d\n", w.wp_no);
                }
            }
            break;

            case MSP.Cmds.EEPROM_WRITE:
                break;

            case MSP.Cmds.RADIO:
            {
                MSP_RADIO r = MSP_RADIO();
                uint8 *rp;
                rp = deserialise_u16(raw, out r.rxerrors);
                rp = deserialise_u16(rp, out r.fixed_errors);
                r.localrssi = *rp++;
                r.remrssi = *rp++;
                r.txbuf = *rp++;
                r.noise = *rp++;
                r.remnoise = *rp;
                radstatus.update(r);
            }
            break;

            case MSP.Cmds.TG_FRAME:
            {
                if(nopoll == false)
                {
                    dopoll = nopoll = true;
                }
                sflags |=  NavStatus.SPK.ELEV;
                LTM_GFRAME gf = LTM_GFRAME();
                uint8* rp;

                rp = deserialise_i32(raw, out gf.lat);
                rp = deserialise_i32(rp, out gf.lon);
                gf.speed = *rp++;
                rp = deserialise_i32(rp, out gf.alt);
                gf.sats = *rp;
                _nsats = (gf.sats >> 2);

                if(craft == null)
                {
                    craft = new Craft(view, 3, norotate, gps_trail);
                    craft.park();
                }

                var fix = gpsinfo.update_ltm(gf, conf.dms);
                if(fix != 0)
                {
                    double gflat = gf.lat/10000000.0;
                    double gflon = gf.lon/10000000.0;
                    if(armed == 1 && npos == false)
                    {
                        sflags |=  NavStatus.SPK.GPS;
                        _ilat = gflat;
                        _ilon = gflon;
                        npos = true;
                    }
                    if(armed == 1)
                    {
                        double dist,cse;
                        Geo.csedist(gflat, gflon, _ilat, _ilon, out dist, out cse);
                        var cg = MSP_COMP_GPS();
                        cg.range = (uint16)Math.lround(dist*1852);
                        cg.direction = (int16)Math.lround(cse);
                        navstatus.comp_gps(cg);
                    }
                    if(craft != null)
                    {
                        if(follow == true)
                            craft.set_lat_lon(gflat,gflon,gfcse);
                        if (centreon == true)
                            view.center_on(gflat,gflon);
                    }
                }
            }
            break;

            case MSP.Cmds.TA_FRAME:
            {
                if(nopoll == false)
                                    {
                    dopoll = nopoll = true;
                }
                LTM_AFRAME af = LTM_AFRAME();
                uint8* rp;
                rp = deserialise_i16(raw, out af.pitch);
                rp = deserialise_i16(rp, out af.roll);
                rp = deserialise_i16(rp, out af.heading);
                var h = af.heading;
                if(h < 0)
                    h += 360;
                gfcse = h;
                navstatus.update_ltm_a(af);
            }
            break;

            case MSP.Cmds.TS_FRAME:
            {
                if(nopoll == false)
                {
                    dopoll = nopoll = true;
                }
                LTM_SFRAME sf = LTM_SFRAME ();
                uint8* rp;
                rp = deserialise_i16(raw, out sf.vbat);
                rp = deserialise_i16(rp, out sf.vcurr);
                sf.rssi = *rp++;
                sf.airspeed = *rp++;
                sf.flags = *rp++;
                armed = sf.flags & 1;
                uint32 mwflags = 0;
                if((sf.flags & (2 << 2)) != 0)
                    mwflags |= 2;
                if((sf.flags & (2 << 3)) != 0)
                    mwflags |= 4;

                if(armed == 0)
                {
                    armtime = 0;
                    duration = -1;
                    npos = false;
                }
                else
                {
                    if(armtime == 0)
                        armtime = time_t(out armtime);
                    time_t(out duration);
                    duration -= armtime;
                }

                if(Logger.is_logging)
                {
                    Logger.armed((armed == 1), duration,mwflags,0);
                }

                if(armed != larmed)
                {
                    if(armed == 1 && craft == null)
                    {
                        craft = new Craft(view, 3, norotate, gps_trail);
                        craft.park();
                    }

                    if(gps_trail)
                    {
                        if(armed == 1 && craft != null)
                        {
                            craft.init_trail();
                        }
                    }
                    if (armed == 1)
                    {
                        sflags |= NavStatus.SPK.Volts;
                        duration_timer();
                        if (conf.audioarmed == true)
                        {
                            audio_cb.active = true;
                        }
                        if(conf.logarmed == true)
                        {
                            logb.active = true;
                            Logger.armed(true,duration,mwflags,0);
                        }
                    }
                    else
                    {
                        if (conf.audioarmed == true)
                        {
                            audio_cb.active = false;
                        }
                        if(conf.logarmed == true)
                        {
                            Logger.armed(false,duration,mwflags,0);
                            logb.active=false;
                        }
                    }
                    larmed = armed;
                }

                radstatus.update_ltm(sf);
                navstatus.update_ltm_s(sf);
                set_bat_stat((uint8)((sf.vbat + 50) / 100));
            }
            break;

            default:
                MSPLog.message ("** Unknown response %d\n", cmd);
                break;
        }
        if(dopoll && (cmd == requests[tcycle]))
        {
            tcycle = (tcycle + 1) % requests.length;
            if(tcycle == 0)
            {
                var  val = 1000*timadj.adjustment.value;
                var now = GLib.get_monotonic_time();
                var et = (now - lastp)/1000;
                acycle += et;
                anvals++;

                if (et > val)
                {
                   msg_poller();
                }
                else
                {
                    tot = (uint)val-(uint)et;
                    Timeout.add(tot, ()=> {
                            msg_poller();
                           return false;
                       });
                }
//                if(telstats.visible)
                {
                    var t = gen_serial_stats();
                    telstats.update(t);
                }
            }
            else
            {
                msg_poller();
            }
        }
    }

    private void report_bits(uint32 bits)
    {
        string mode;

        if((bits & 2) == 2)
        {
            mode = "Angle";
        }
        else if((bits & 4) == 4)
        {
            mode = "Horizon";
        }
        else
        {
            mode = "Acro";
        }
        fmodelab.set_label(mode);
        navstatus.update_fmode(mode);
    }

    private void duration_timer()
    {
        lmin = 0;
        Timeout.add_seconds(1, () => {
                int mins,secs;
                bool r = true;

                if (duration <  0)
                {
                    mins = secs = 0;
                    r = false;
                }
                else
                {
                    mins = (int)duration / 60;
                    secs = (int)duration % 60;
                    if(mins != lmin)
                    {
                        navstatus.update_duration(mins);
                        lmin = mins;
                    }
                }
                elapsedlab.set_text("%02d:%02d".printf(mins,secs));
                return r;
            });
    }

    private size_t serialise_wp(MSP_WP w, uint8[] tmp)
    {
        uint8* rp = tmp;
        *rp++ = w.wp_no;
        *rp++ = w.action;
        rp = serialise_i32(rp, w.lat);
        rp = serialise_i32(rp, w.lon);
        rp = serialise_u32(rp, w.altitude);
        rp = serialise_u16(rp, w.p1);
        rp = serialise_u16(rp, w.p2);
        rp = serialise_u16(rp, w.p3);
        *rp++ = w.flag;
        return (rp-&tmp[0]);
    }

    private void gps_alert()
    {
        bleet_sans_merci("sat_alert.ogg");
    }

    private void bleet_sans_merci(string sfn="bleet.ogg")
    {
        var fn = MWPUtils.find_conf_file(sfn);
        if(fn != null)
        {
            try
            {
                string cmd = "%s %s".printf(conf.mediap,fn);
                MSPLog.message("%s\n", cmd);
                Process.spawn_command_line_async(cmd);
            } catch (SpawnError e) {
                MSPLog.message ("Error: %s\n", e.message);
            }
        }
    }

    private void init_battery(uint8 ivbat)
    {
        var ncells = ivbat / 37;
        for(var i = 0; i < vlevels.length; i++)
        {
            vlevels[i].limit = vlevels[i].cell*ncells;
            vlevels[i].reached = false;
        }
        vinit = true;
        vwarn1 = 0;
    }

    private void set_bat_stat(uint8 ivbat)
    {
        string vbatlab;
        float  vf = (float)ivbat/10.0f;
        int icol = 0;
        if (ivbat > 0)
        {
            if(vinit == false)
                init_battery(ivbat);

            foreach(var v in vlevels)
            {
                if(vf >= v.limit)
                    break;
                icol += 1;
            }
        }
        else
            icol = vlevels.length-1;

        string str;
        if(vlevels[icol].label == null)
        {
            str = "%.1fv".printf(vf);
        }
        else
            str = vlevels[icol].label;

        vbatlab="<span background=\"%s\" weight=\"bold\">%s</span>".printf(
             vlevels[icol].colour, str);
        labelvbat.set_markup(vbatlab);
        navstatus.volt_update(str,icol,vf);

        if(vlevels[icol].reached == false)
        {
            vlevels[icol].reached = true;
            if(vlevels[icol].audio != null)
            {
                if(robj == null)
                    bleet_sans_merci(vlevels[icol].audio);
                else
                    stderr.printf("audio alarm %s\n", vlevels[icol].audio);
            }
        }
        licol= icol;
    }

    private void upload_quad()
    {
        validatelab.set_text("");
        var wps = ls.to_wps();
        if(wps.length == 0)
        {
            MSP_WP w0 = MSP_WP();
            w0.wp_no = 1;
            w0.action =  MSP.Action.RTH;
            w0.lat = w0.lon = 0;
            w0.altitude = 25;
            w0.p1 = 0;
            w0.p2 = w0.p3 = 0;
            w0.flag = 0xa5;
            wps += w0;
        }

        if(conf.recip_head)
        {
            for(var ix = 0 ; ix < wps.length; ix++)
            {
                if(wps[ix].action == MSP.Action.SET_HEAD && wps[ix].p1 != -1)
                {
                    wps[ix].p1 = (wps[ix].p1 + 180) % 360;
                }
            }
        }

        wpmgr.npts = (uint8)wps.length;
        wpmgr.wpidx = 0;
        wpmgr.wps = wps;
        wpmgr.wp_flag = WPDL.VALIDATE;

        uint8 wtmp[64];
        var nb = serialise_wp(wpmgr.wps[wpmgr.wpidx], wtmp);
        send_cmd(MSP.Cmds.SET_WP, wtmp, nb);
    }

    public void request_wp(uint8 wp)
    {
        uint8 buf[2];
        have_wp = false;
        buf[0] = wp;
        add_cmd(MSP.Cmds.WP,buf,1, 1000);
    }


    private size_t serialise_nc (MSP_NAV_CONFIG nc, uint8[] tmp)
    {
        uint8* rp = tmp;

        *rp++ = nc.flag1;
        *rp++ = nc.flag2;

        rp = serialise_u16(rp, nc.wp_radius);
        rp = serialise_u16(rp, nc.safe_wp_distance);
        rp = serialise_u16(rp, nc.nav_max_altitude);
        rp = serialise_u16(rp, nc.nav_speed_max);
        rp = serialise_u16(rp, nc.nav_speed_min);
        *rp++ = nc.crosstrack_gain;
        rp = serialise_u16(rp, nc.nav_bank_max);
        rp = serialise_u16(rp, nc.rth_altitude);
        *rp++ = nc.land_speed;
        rp = serialise_u16(rp, nc.fence);
        *rp++ = nc.max_wp_number;
        return (rp-&tmp[0]);
    }

    public void update_config(MSP_NAV_CONFIG nc)
    {
        have_nc = false;
        uint8 tmp[64];
        var nb = serialise_nc(nc, tmp);
        send_cmd(MSP.Cmds.SET_NAV_CONFIG, tmp, nb);
        add_cmd(MSP.Cmds.NAV_CONFIG,null,0, 1000);
    }

    private void send_cmd(MSP.Cmds cmd, void* buf, size_t len)
    {
        if(msp.available == true)
        {
            msp.send_command(cmd,buf,len);
        }
    }

    private void add_cmd(MSP.Cmds cmd, void* buf, size_t len, int wait=1000)
    {
        cmdtid = Timeout.add(wait, () => {
                switch(cmd)
                {
                    case MSP.Cmds.API_VERSION:
                    api_cnt++;
                    if(api_cnt == 2)
                    {
                        cmd = MSP.Cmds.IDENT;
                        api_cnt = 255;
                    }
                    break;
                }
                send_cmd(cmd,buf,len);
                return true;
            });
        send_cmd(cmd,buf,len);
    }

    private void start_audio()
    {
        if (spktid == 0)
        {
            if(audio_on /*&& (sflags != 0)*/)
            {
                navstatus.logspeak_init(conf.evoice);
                spktid = Timeout.add_seconds(conf.speakint, () => {
                        if(_nsats != nsats)
                        {
                            if(_nsats == 0)
                                gps_alert();
                            navstatus.sats(_nsats);
                            nsats = _nsats;
                        }
                        navstatus.announce(sflags, conf.recip);
                        return true;
                    });
                navstatus.announce(sflags,conf.recip);
            }
        }
    }

    private void stop_audio()
    {
        if(spktid > 0)
        {
            remove_tid(ref spktid);
            navstatus.logspeak_close();
        }
    }

    private void remove_tid(ref uint tid)
    {
        if(tid > 0)
            Source.remove(tid);
        tid = 0;
    }

    private TelemStats gen_serial_stats()
    {
        TelemStats t = TelemStats();
        if(msp.available)
            t.s = msp.dump_stats();
        else
            t.s = {0};
        t.toc = toc;
        t.tot = tot;
        t.avg = (anvals > 0) ? (ulong)(acycle/anvals) : 0;
        return t;
    }

    private void show_serial_stats()
    {
        var t = gen_serial_stats();
        MSPLog.message("%.0fs, rx %lub, tx %lub, (%.0fb/s, %0.fb/s) to %lu wait %u, avg poll loop %lu ms\n",
                      t.s.elapsed, t.s.rxbytes, t.s.txbytes, t.s.rxrate, t.s.txrate,
                      t.toc, t.tot, t.avg);
    }

    private void serial_doom(Gtk.Button c)
    {
        menumwvar.sensitive =true;
        dopoll = false;
        remove_tid(ref gpstid);
        remove_tid(ref cmdtid);
        sflags = 0;
        stop_audio();
        show_serial_stats();

        if(rawlog == true)
        {
            msp.raw_logging(false);
        }
        gpsinfo.annul();
        navstatus.reset();
        set_bat_stat(0);
        nsats = 0;
        _nsats = 0;
        msp.close();
        c.set_label("gtk-connect");
        menuncfg.sensitive = menuup.sensitive = menudown.sensitive = false;
        navconf.hide();
        duration = -1;
        if(craft != null)
        {
            craft.remove_marker();
        }
    }


    private void init_state()
    {
        have_api = have_vers = have_misc = have_status = have_wp = have_nc =
            have_fcv = false;
        fcv = null;
        xbits = icount = api_cnt = 0;
        autocount = 0;
        nrx = 0;
        nsats = -99;
        if(msp.available)
            msp.clear_counters();
        gpsinfo.annul();
        navstatus.reset();
        telstats.annul();
        vinit = false;
        set_bat_stat(0);
        toc = tot = 0;
        anvals = 0;
        acycle = 0;
        gpscnt = 0;
    }

    private void connect_serial()
    {
        if(msp.available)
        {
            serial_doom(conbutton);
            verlab.set_label("");
            typlab.set_label("");
            statusbar.push(context_id, "");
        }
        else
        {
            remove_tid(ref gpstid);
            var serdev = dev_entry.get_active_text();
            string estr;
            if (msp.open(serdev, conf.baudrate, out estr) == true)
            {
                init_state();
                dopoll = false;
                if(rawlog == true)
                {
                    msp.raw_logging(true);
                }
                conbutton.set_label("gtk-disconnect");
                add_cmd(MSP.Cmds.API_VERSION,null,0, 1500);
                menumwvar.sensitive = false;
            }
            else
            {
                if (autocon == false || autocount == 0)
                {
                    mwp_warning_box("Unable to open serial device: %s\nReason: %s".printf(serdev, estr));
                }
                autocount = ((autocount + 1) % 4);
            }
        }
    }

    private void anim_cb()
    {
        var x = view.get_center_longitude();
        var y = view.get_center_latitude();

        if (lx !=  x && ly != y)
        {
            poslabel.set_text(PosFormat.pos(y,x,conf.dms));
            lx = x;
            ly = y;
            if (follow == false && craft != null)
            {
                double plat,plon;
                craft.get_pos(out plat, out plon);
                    /*
                     * Older Champlain versions don't have full bbox
                     * work around it
                     */
#if NOBB
                double vypix = view.latitude_to_y(plat);
                double vxpix = view.longitude_to_x(plon);
                bool outofview = ((int)vypix < 0 || (int)vxpix < 0);
                if(outofview == false)
                {
                    var ww = embed.get_window();
                    var wd = ww.get_width();
                    var ht = ww.get_height();
                    outofview = ((int)vypix > ht || (int)vxpix > wd);
                }
                if (outofview == true)
                {
                    craft.park();
                }
#else
                var bbox = view.get_bounding_box();
                if (bbox.covers(plat, plon) == false)
                {
                    craft.park();
                }
#endif
            }
        }
    }

    private void add_source_combo(string? defmap)
    {
        var combo  = builder.get_object ("combobox1") as Gtk.ComboBox;
        var map_source_factory = Champlain.MapSourceFactory.dup_default();

        var liststore = new ListStore (MS_Column.N_COLUMNS, typeof (string), typeof (string));

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
                        Champlain.MapProjection.MAP_PROJECTION_MERCATOR,
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

    public void on_file_save()
    {
        if (last_file == null)
        {
            on_file_save_as ();
        }
        else
        {
            Mission m = ls.to_mission();

            if(true == ls.calc_mission_dist(out m.dist, out m.lt))
            {
                m.nspeed = conf.nav_speed;
                m.et = (int)(m.dist / conf.nav_speed);
            }
            else
            {
                m.et = 0;
            }
            if (conf.compat_vers != null)
                m.version = conf.compat_vers;
            m.to_xml_file(last_file);
            update_title_from_file(last_file);
        }
    }

    public void on_file_save_as ()
    {
        Mission m = ls.to_mission();
        Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
            "Select a mission file", null, Gtk.FileChooserAction.SAVE,
            "_Cancel",
            Gtk.ResponseType.CANCEL,
            "_Save",
            Gtk.ResponseType.ACCEPT);
        chooser.select_multiple = false;
        Gtk.FileFilter filter = new Gtk.FileFilter ();
        filter.set_filter_name ("Mission");
        filter.add_pattern ("*.mission");
        filter.add_pattern ("*.xml");
//            filter.add_pattern ("*.json");
        chooser.add_filter (filter);

        filter = new Gtk.FileFilter ();
        filter.set_filter_name ("All Files");
        filter.add_pattern ("*");
        chooser.add_filter (filter);

            // Process response:
        if (chooser.run () == Gtk.ResponseType.ACCEPT) {
            last_file = chooser.get_filename ();
            if (conf.compat_vers != null)
                m.version = conf.compat_vers;
            m.to_xml_file(last_file);
            update_title_from_file(last_file);
        }
        chooser.close ();
    }

    private void update_title_from_file(string fname)
    {
        var basename = GLib.Path.get_basename(fname);
        window.title = @"MW Planner = $basename";
    }

    private void load_file(string fname)
    {
        var ms = new Mission ();
        if(ms.read_xml_file (fname) == true)
        {
            ms.dump();
            ls.import_mission(ms);
            var mmax = view.get_max_zoom_level();
            var mmin = view.get_min_zoom_level();
            view.center_on(ms.cy, ms.cx);

            if (ms.zoom < mmin)
                ms.zoom = mmin;

            if (ms.zoom > mmax)
                ms.zoom = mmax;

            view.set_property("zoom-level", ms.zoom);
            markers.add_list_store(ls);
            last_file = fname;
            update_title_from_file(fname);
        }
        else
        {
            mwp_warning_box("Failed to open file");
        }
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

    public void on_file_open ()
    {
        Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
            "Select a mission file", null, Gtk.FileChooserAction.OPEN,
            "_Cancel",
            Gtk.ResponseType.CANCEL,
            "_Open",
            Gtk.ResponseType.ACCEPT);
        chooser.select_multiple = false;

        Gtk.FileFilter filter = new Gtk.FileFilter ();
	filter.set_filter_name ("Mission");
	filter.add_pattern ("*.mission");
	filter.add_pattern ("*.xml");
//	filter.add_pattern ("*.json");
	chooser.add_filter (filter);

	filter = new Gtk.FileFilter ();
	filter.set_filter_name ("All Files");
	filter.add_pattern ("*");
	chooser.add_filter (filter);

            // Process response:
        if (chooser.run () == Gtk.ResponseType.ACCEPT) {
            ls.clear_mission();
            var fn = chooser.get_filename ();
            load_file(fn);
        }
        chooser.close ();
    }

    private void replay_log(bool delay=true)
    {
        if(thr != null)
        {
            robj.playon = false;
            duration = -1;
        }
        else
        {
            Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
            "Select a log file", null, Gtk.FileChooserAction.OPEN,
            "_Cancel",
            Gtk.ResponseType.CANCEL,
            "_Open",
            Gtk.ResponseType.ACCEPT);
            chooser.select_multiple = false;

            Gtk.FileFilter filter = new Gtk.FileFilter ();
            filter.set_filter_name ("Log");
            filter.add_pattern ("*.log");
            chooser.add_filter (filter);

            filter = new Gtk.FileFilter ();
            filter.set_filter_name ("All Files");
            filter.add_pattern ("*");
            chooser.add_filter (filter);

                // Process response:
            if (chooser.run () == Gtk.ResponseType.ACCEPT) {
                var fn = chooser.get_filename ();
                usemag = force_mag;
                run_replay(fn, delay);
            }
            chooser.close ();
        }
    }

    private bool replay_handler (IOChannel gio, IOCondition condition)
    {
        var done = false;
        if((condition & (IOCondition.HUP|IOCondition.NVAL)) != 0)
        {
            done = true;
        }
        else
        {
            var rec = REPLAY_rec();
            var ret = Posix.read(gio.unix_get_fd(), &rec, sizeof(REPLAY_rec));
            if(ret == 0)
                done = true;
            else
            {
                handle_serial(rec.cmd, rec.raw, rec.len,false);
            }

        }
        if(done)
        {
            cleanup_replay();
            return false;
        }
        return true;
    }

    private void cleanup_replay()
    {
        thr.join();
        thr = null;
        nopoll = xnopoll;
        remove_tid(ref plid);
        remove_tid(ref gpstid);
        try  { io_read.shutdown(false); } catch {}
        Posix.close(playfd[0]);
        Posix.close(playfd[1]);
        stop_audio();
        conf.logarmed = xlog;
        conf.audioarmed = xaudio;
        duration = -1;
        armtime = 0;

        conbutton.sensitive = true;
        menureplay.label = "Replay Log file";
    }

    private void run_replay(string fn, bool delay)
    {
        xlog = conf.logarmed;
        xaudio = conf.audioarmed;
        xnopoll = nopoll;
        nopoll = true;
        playfd = new int[2];
        var sr =  Posix.socketpair (SocketFamily.UNIX,
                          SocketType.DATAGRAM, 0, playfd);

        if(sr == 0)
        {
            if(craft != null)
                craft.park();

            conf.logarmed = false;
            if(delay == false)
                conf.audioarmed = false;

            if(msp.available)
                serial_doom(conbutton);

            init_state();
            conbutton.sensitive = false;

            io_read  = new IOChannel.unix_new(playfd[0]);
            plid = io_read.add_watch(IOCondition.IN|
                                     IOCondition.HUP|
                                     IOCondition.ERR|
                                     IOCondition.NVAL, replay_handler);
            robj = new ReplayThread();
            thr = robj.run(playfd[1], fn, delay);
            if(thr != null)
                menureplay.label = "Stop Replay";
        }
    }

    private void download_quad()
    {
        wp_resp= {};
        wpmgr.wp_flag = WPDL.REPLACE;
        request_wp(1);
    }

    public static int main (string[] args)
    {
        time_t currtime;
        time_t(out currtime);
        stderr.puts(Time.local(currtime).format("mwp @%FT%T%z\n"));
        if (GtkClutter.init (ref args) != InitError.SUCCESS)
            return 1;

        try {
            var opt = new OptionContext("");
            opt.set_help_enabled(true);
            opt.add_main_entries(options, null);
            opt.parse(ref args);
        } catch (OptionError e) {
            stderr.printf("Error: %s\n", e.message);
            stderr.printf("Run '%s --help' to see a full list of available "+
                          "options\n", args[0]);
            return 1;
        }
        if(Posix.isatty(stderr.fileno()) == false)
        {
            stderr = FileStream.open("/tmp/mwp-stderr.txt","a");
        }
        MWPlanner app = new MWPlanner();
        app.run ();
        return 0;
    }
}
