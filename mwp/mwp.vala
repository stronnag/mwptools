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

public class MWPlanner : GLib.Object {
    public Builder builder;
    public Gtk.Window window;
    public  Champlain.View view;
    public MWPMarkers markers;
    private string last_file;
    private ListBox ls;
    private Gtk.SpinButton zoomer;
    private Gtk.Label poslabel;
    public Gtk.Label stslabel;
    private double lx;
    private double ly;
    private int ht_map = 600;
    private int wd_map = 800;
    private Gtk.MenuItem menuup;
    private Gtk.MenuItem menudown;
    private Gtk.MenuItem menunav;
    private Gtk.MenuItem menuncfg;
    public MWPSettings conf;
    private MWSerial msp;
    private Gtk.Button conbutton;
    private Gtk.ComboBoxText dev_entry;
    private Gtk.Label verlab;
    private Gtk.Label validatelab;
    private Gtk.Label typlab;
    private Gtk.Label labelvbat;
    private bool have_vers;
    private bool have_misc;
    private bool have_status;
    private bool have_wp;
    private bool have_nc;
    private uint8 mrtype;
    private uint gpstid;
    private uint cmdtid;
    private uint spktid;
    private Craft craft;
    private bool follow = false;
    private bool centreon = false;
    private bool navcap = false;
    private bool naze32 = false;
    private bool vinit = false;
    private GtkChamplain.Embed embed;
    private PrefsDialog prefs;
    private Gtk.AboutDialog about;
    private NavStatus navstatus;
    private RadioStatus radstatus;
    private NavConfig navconf;
    private GPSInfo gpsinfo;
    private WPMGR wpmgr;
    private MissionItem[] wp_resp;
    private static string mission;
    private static string serial;
    private static bool autocon;
    private int autocount = 0;
    private static bool mkcon;
    private static bool ignore_sz;
    private static bool nopoll = false;
    private static bool rawlog = false;
    private static bool norotate = false; // workaround for Ubuntu & old champlain
    private uint8 vwarn1;
    private uint8 vwarn2;
    private uint8 vcrit;
    private int licol;
    private int bleetat;
    private DockMaster master;
    private DockLayout layout;
    public  DockItem[] dockitem;
    private Gtk.CheckButton audio_cb;
    private Gtk.CheckButton autocon_cb;
    private Gtk.CheckButton logb;
    private bool audio_on;
    private uint8 sflags;
    private uint8 nsats = 0;
    private uint8 _nsats = 0;
    private uint8 larmed = 0;

        /**** FIXME ***/
    private int gfcse = 0;

    private enum MS_Column {
        ID,
        NAME,
        N_COLUMNS
    }

    private enum WPDL {
        IDLE=0,
        VALIDATE,
        REPLACE
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

    private static const string[] failnames =
        {"","WPNO","LAT","LON","ALT","P1","P2","P3","FLAG"};

    const OptionEntry[] options = {
        { "mission", 'm', 0, OptionArg.STRING, out mission, "Mission file", null},
        { "serial-device", 's', 0, OptionArg.STRING, out serial, "Serial device", null},
        { "connect", 'c', 0, OptionArg.NONE, out mkcon, "connect to first device", null},
        { "auto-connect", 'a', 0, OptionArg.NONE, out autocon, "auto-connect to first device", null},
        { "no-poll", 'n', 0, OptionArg.NONE, out nopoll, "don't poll for nav info", null},
        { "raw-log", 'r', 0, OptionArg.NONE, out rawlog, "log raw serial data to file", null},

        { "ignore-sizing", 0, 0, OptionArg.NONE, out ignore_sz, "ignore minimum size constraint", null},
        { "ignore-rotation", 0, 0, OptionArg.NONE, out norotate, "ignore vehicle icon rotation on old libchamplain", null},
        {null}
    };

    public MWPlanner ()
    {
        wpmgr = WPMGR();
        builder = new Builder ();
        conf = new MWPSettings();
        conf.read_settings();

        var fn = MWPUtils.find_conf_file("mwp.ui");
        if (fn == null)
        {
            stderr.printf ("No UI definition file\n");
            Posix.exit(255);
        }
        else
        {
            try
            {
                builder.add_from_file (fn);
            } catch (Error e) {
                stderr.printf ("Builder: %s\n", e.message);
                Posix.exit(255);
            }
        }

        builder.connect_signals (null);
        window = builder.get_object ("window1") as Gtk.Window;
        window.destroy.connect (Gtk.main_quit);

        string icon=null;

        try {
            icon = MWPUtils.find_conf_file("mwp_icon.svg");
            window.set_icon_from_file(icon);
        } catch {};

        zoomer = builder.get_object ("spinbutton1") as Gtk.SpinButton;

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

        menuop = builder.get_object ("menu_quit") as Gtk.MenuItem;
        menuop.activate.connect (() => {
                Gtk.main_quit();
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
                if(dockitem[1].is_closed() && !dockitem[1].is_iconified())
                {
                   dockitem[1].show();
                   dockitem[1].iconify_item();
                }
            });

        mi = builder.get_object ("tote_menu_view") as Gtk.MenuItem;
        mi.activate.connect (() => {
                if(dockitem[0].is_closed() && !dockitem[0].is_iconified())
                {
                   dockitem[0].show();
                   dockitem[0].iconify_item();
                }
            });

        mi = builder.get_object ("voltage_menu_view") as Gtk.MenuItem;
        mi.activate.connect (() => {
                if(dockitem[3].is_closed() && !dockitem[3].is_iconified())
                {
                   dockitem[3].show();
                   dockitem[3].iconify_item();
                   }
            });

        radstatus = new RadioStatus(builder);

        mi = builder.get_object ("radio_menu_view") as Gtk.MenuItem;
        mi.activate.connect (() => {
                if(dockitem[4].is_closed() && !dockitem[4].is_iconified())
                {
                   dockitem[4].show();
                   dockitem[4].iconify_item();
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

        if(ignore_sz != true)
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

        ls = new ListBox();
        ls.create_view(this);

        var scroll = new Gtk.ScrolledWindow (null, null);
        scroll.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
        scroll.set_min_content_width(400);
        scroll.add (ls.view);

        var grid =  builder.get_object ("grid1") as Gtk.Grid;
        gpsinfo = new GPSInfo(grid);

        var dock = new Dock ();
        this.master = dock.master;
        this.layout = new DockLayout (dock);
        var dockbar = new DockBar (dock);
        dockbar.set_style (DockBarStyle.ICONS);

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL,0);
        pane.add2(box);

        box.pack_start (dockbar, false, false, 0);
        box.pack_end (dock, true, true, 0);

        dockitem = new DockItem[5];

        dockitem[0]= new DockItem.with_stock ("Mission",
                         "Mission Tote", "gtk-properties",
                         DockItemBehavior.NORMAL | DockItemBehavior.CANT_CLOSE);
        dockitem[0].add (scroll);
        dockitem[0].show ();

        dock.add_item (dockitem[0], DockPlacement.TOP);

        dockitem[1]= new DockItem.with_stock ("GPS",
                         "GPS Info", "gtk-refresh",
                         DockItemBehavior.NORMAL | DockItemBehavior.CANT_CLOSE);
        dockitem[1].add (grid);
        dock.add_item (dockitem[1], DockPlacement.BOTTOM);
        dockitem[1].show ();

        dockitem[2]= new DockItem.with_stock ("Status",
                         "NAV Status", "gtk-info",
                         DockItemBehavior.NORMAL | DockItemBehavior.CANT_CLOSE);
        dockitem[2].add (navstatus.grid);
        dock.add_item (dockitem[2], DockPlacement.BOTTOM);
        dockitem[2].show ();

        dockitem[3]= new DockItem.with_stock ("Volts",
                         "Battery Monitor", "gtk-dialog-warning",
                         DockItemBehavior.NORMAL | DockItemBehavior.CANT_CLOSE);
        dockitem[3].add (navstatus.voltbox);
        dock.add_item (dockitem[3], DockPlacement.BOTTOM);

        dockitem[4]= new DockItem.with_stock ("Radio",
                         "Radio Status", "gtk-network",
                         DockItemBehavior.NORMAL | DockItemBehavior.CANT_CLOSE);
        dockitem[4].add (radstatus.grid);
        dock.add_item (dockitem[4], DockPlacement.BOTTOM);

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
        stslabel = builder.get_object ("label5") as Gtk.Label;

        logb = builder.get_object ("logger_cb") as Gtk.CheckButton;
        logb.toggled.connect (() => {
                if (logb.active)
                    Logger.start(last_file);
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

        prefs = new PrefsDialog(builder);
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
        validatelab = builder.get_object ("validated") as Gtk.Label;
        typlab = builder.get_object ("typlab") as Gtk.Label;
        labelvbat = builder.get_object ("labelvbat") as Gtk.Label;
        conbutton.clicked.connect(() => { connect_serial(); });

        msp = new MWSerial();
        msp.serial_lost.connect(() => { serial_doom(conbutton); });

        msp.serial_event.connect((s,cmd,raw,len,errs) => {
                handle_serial(s,cmd,raw,len,errs);
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

        if(autocon)
        {
            autocon_cb.active=true;
            mkcon = true;
        }

        if(mkcon)
        {
            connect_serial();
        }

        Timeout.add_seconds(5, () => { return try_connect(); });
        window.show_all();
        dockitem[1].iconify_item ();
        dockitem[2].iconify_item ();
        dockitem[3].hide ();
        dockitem[4].hide ();
        navstatus.setdock(dockitem[2]);
        radstatus.setdock(dockitem[4]);
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

    private void handle_serial(MWSerial sd,  MSP.Cmds cmd, uint8[] raw, uint len, bool errs)
    {
        if(errs == true)
        {
            stdout.printf("Error on cmd %c (%d)\n", cmd,cmd);
            if(cmd ==  MSP.Cmds.NAV_CONFIG)
                navcap = false;
            remove_tid(ref cmdtid);
            return;
        }
        switch(cmd)
        {
            case MSP.Cmds.IDENT:
                remove_tid(ref cmdtid);
                have_vers = true;
                mrtype = raw[1];
                navcap = ((raw[3] & 0x10) == 0x10);
                if ((raw[3] & 0x20) == 0x20)
                {
                    naze32 = true;
                    navcap = false;
                }
                var vers="v%03d".printf(raw[0]);
                verlab.set_label(vers);
                typlab.set_label(MSP.get_mrtype(mrtype));
                if(navcap == true)
                {
                    menuup.sensitive = menudown.sensitive = menuncfg.sensitive = true;
                }
                add_cmd(MSP.Cmds.MISC,null,0, &have_misc,1000);
                break;

            case MSP.Cmds.MISC:
                remove_tid(ref cmdtid);
                have_misc = true;
                MSP_MISC *m = (MSP_MISC *)raw;
                vwarn1 = m.conf_vbatlevel_warn1;
                vwarn2 = m.conf_vbatlevel_warn2;
                vcrit =  m.conf_vbatlevel_crit;
//                stdout.printf("%d %d %d\n", vwarn1, vwarn2, vcrit);
                add_cmd(MSP.Cmds.STATUS,null,0,&have_status,1000);
                break;

            case MSP.Cmds.STATUS:
                MSP_STATUS *s = (MSP_STATUS *)raw;
                uint16 sensor;
                sensor=uint16.from_little_endian(s.sensor);
                if (nopoll == true)
                {
                    have_status = true;
                    remove_tid(ref cmdtid);
                    if((sensor & MSP.Sensors.GPS) == MSP.Sensors.GPS)
                    {
                        sflags |= NavStatus.SPK.GPS;
                        if(craft == null)
                            craft = new Craft(view, mrtype,norotate);
                        craft.park();
                    }
                }
                else
                {
                    if(have_status == false)
                    {
                        have_status = true;
                        remove_tid(ref cmdtid);
                        if(navcap == true)
                            add_cmd(MSP.Cmds.NAV_CONFIG,null,0,&have_nc,1000);

                        var timadj = builder.get_object ("spinbutton2") as Gtk.SpinButton;
                        var  val = timadj.adjustment.value;
                        MSP.Cmds[] requests = {};
                        ulong reqsize = 0;

                        requests += MSP.Cmds.STATUS;
                        reqsize += sizeof(MSP_STATUS);

                        requests += MSP.Cmds.ANALOG;
                        reqsize += sizeof(MSP_ANALOG);

                        sflags = NavStatus.SPK.Volts;

                        if((sensor & MSP.Sensors.ACC) == MSP.Sensors.ACC)
                        {
                            requests += MSP.Cmds.ATTITUDE;
                            reqsize += sizeof(MSP_ATTITUDE);
                        }

                        if((sensor & MSP.Sensors.BARO) == MSP.Sensors.BARO)
                        {
                            sflags |= NavStatus.SPK.BARO;
                            requests += MSP.Cmds.ALTITUDE;
                            reqsize += sizeof(MSP_ALTITUDE);
                        }

                        if((sensor & MSP.Sensors.GPS) == MSP.Sensors.GPS)
                        {
                            sflags |= NavStatus.SPK.GPS;
                            if(navcap == true)
                            {
                                requests += MSP.Cmds.NAV_STATUS;
                                reqsize += sizeof(MSP_NAV_STATUS);
                            }
                            requests += MSP.Cmds.RAW_GPS;
                            requests += MSP.Cmds.COMP_GPS;
                            reqsize += (sizeof(MSP_RAW_GPS) + sizeof(MSP_COMP_GPS));
                            if(craft == null)
                                craft = new Craft(view, mrtype,norotate);
                            craft.park();
                        }

                        var nreqs = requests.length;
                        int timeout = (int)(val*1000 / nreqs);

                            // data we send, response is structs + this
                        var qsize = nreqs * 6;
                        reqsize += qsize;

                        print("Timer cycle for %d (%dms) items, %lu => %lu bytes\n",
                              nreqs,timeout,qsize,reqsize);

                        int tcycle = 0;
                        gpstid = Timeout.add(timeout, () => {
                                var req=requests[tcycle];
                                send_cmd(req, null, 0);
                                tcycle += 1;
                                tcycle %= nreqs;
                                return true;
                            });
                        start_audio();
                    }
                    Logger.log_time();
                    var swflg = uint32.from_little_endian(s.flag);
                    uint8 armed = (uint8)(swflg & 1);
                    if(Logger.is_logging)
                    {
                        Logger.armed((armed == 1));
                    }
                    if(armed != larmed)
                    {
                        if (armed == 1)
                        {
                            if (conf.audioarmed == true)
                            {
                                audio_cb.active = true;
                            }
                            if(conf.logarmed == true)
                            {
                                logb.active = true;
                                Logger.armed(true);
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
                                Logger.armed(false);
                                logb.active=false;
                            }
                        }
                        larmed = armed;
                    }
                }
                break;

            case MSP.Cmds.NAV_STATUS:
                navstatus.update(*(MSP_NAV_STATUS*)raw);
                break;

            case MSP.Cmds.NAV_CONFIG:
                remove_tid(ref cmdtid);
                have_nc = true;
                navconf.update(*(MSP_NAV_CONFIG*)raw);
                break;

            case MSP.Cmds.SET_NAV_CONFIG:
                send_cmd(MSP.Cmds.EEPROM_WRITE,null, 0);
                break;

            case MSP.Cmds.COMP_GPS:
                navstatus.comp_gps(*(MSP_COMP_GPS*)raw);
                break;

            case MSP.Cmds.ATTITUDE:
                navstatus.set_attitude(*(MSP_ATTITUDE*)raw);
                break;

            case MSP.Cmds.ALTITUDE:
                navstatus.set_altitude(*(MSP_ALTITUDE*)raw);
                break;

            case MSP.Cmds.ANALOG:
                if(Logger.is_logging)
                {
                    Logger.analog(*(MSP_ANALOG*)raw);
                }
                var ivbat = ((MSP_ANALOG*)raw).vbat;
                set_bat_stat(ivbat);
                break;

            case MSP.Cmds.RAW_GPS:
                var fix = gpsinfo.update(*(MSP_RAW_GPS*)raw, conf.dms);
                _nsats =(*(MSP_RAW_GPS*)raw).gps_numsat;

                if (fix != 0)
                {
                    if(craft != null)
                    {
                        if(follow == true)
                            craft.set_lat_lon(gpsinfo.lat,gpsinfo.lon,gpsinfo.cse);
                        if (centreon == true)
                            view.center_on(gpsinfo.lat,gpsinfo.lon);
                    }
                }
                break;
            case MSP.Cmds.SET_WP:
                var no = wpmgr.wps[wpmgr.wpidx].wp_no;
                request_wp(no);
                break;

            case MSP.Cmds.WP:
                MSP_WP *w = (MSP_WP *)raw;
                remove_tid(ref cmdtid);
                have_wp = true;

//                print("Got WP %d\n", w.wp_no);
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
                    else if(w.altitude != wpmgr.wps[wpmgr.wpidx].altitude)
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
                        send_cmd(MSP.Cmds.SET_WP, &wpmgr.wps[wpmgr.wpidx], sizeof(MSP_WP));
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
                    m.lat = (int32.from_little_endian(w.lat))/10000000.0;
                    m.lon = (int32.from_little_endian(w.lon))/10000000.0;
                    m.alt = (uint32.from_little_endian(w.altitude))/100;
                    m.param1 = (int16.from_little_endian(w.p1));
                    if(m.action == MSP.Action.SET_HEAD &&
                       conf.recip_head  == true && m.param1 != -1)
                    {
                        m.param1 = (m.param1 + 180) % 360;
                        stdout.printf("fixup %d %d\n", m.no, m.param1);
                    }
                    m.param2 = (uint16.from_little_endian(w.p2));
                    m.param3 = (uint16.from_little_endian(w.p3));

//                    print("wp %d act %d %.5f %.5f %d %02x\n",
//                          m.no, m.action, m.lat, m.lon, (int)m.alt, w.flag);

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
                        stderr.printf("Error flag on wp #%d\n", w.wp_no);
                    }
                    else
                    {
                        request_wp(w.wp_no+1);
                    }
                }
                else
                {
                    stderr.printf("unsolicited WP #%d\n", w.wp_no);
                }
                break;

            case MSP.Cmds.EEPROM_WRITE:
                break;

            case MSP.Cmds.RADIO:
                radstatus.update(*(MSP_RADIO*)raw);
                break;

            case MSP.Cmds.TG_FRAME:
                nopoll = true;
                LTM_GFRAME *gf = (LTM_GFRAME *)raw;

                if(craft == null)
                    craft = new Craft(view, 3, norotate);
                craft.park();

                var fix = gpsinfo.update_ltm(*gf, conf.dms);
                if(fix != 0)
                {
                    double gflat = gf.lat/10000000.0;
                    double gflon = gf.lon/10000000.0;

                    if(craft != null)
                    {
                        if(follow == true)
                            craft.set_lat_lon(gflat,gflon,gfcse);
                        if (centreon == true)
                            view.center_on(gflat,gflon);
                    }
                }
                break;

            case MSP.Cmds.TA_FRAME:
                nopoll = true;
                LTM_AFRAME *af = (LTM_AFRAME *)raw;
                var h = af.heading;
                if(h < 0)
                    h += 360;
                gfcse = h;
                navstatus.update_ltm_a(*af);
                break;

            case MSP.Cmds.TS_FRAME:
                nopoll = true;
                LTM_SFRAME *sf = (LTM_SFRAME *)raw;
                radstatus.update_ltm(*sf);
                navstatus.update_ltm_s(*sf);
                set_bat_stat((uint8)((sf.vbat + 50) / 100));
                break;

            default:
                stderr.printf ("** Unknown response %d\n", cmd);
                break;
        }
    }


    private int getbatcol(int ivbat)
    {
        int icol;
        if(ivbat < vcrit /2 || ivbat == 0)
        {
            icol = 4;
        }
        else
        {
            if (ivbat <= vcrit)
            {
                icol = 3;
            }
            else if (ivbat <= vwarn2)
                icol = 2;
            else if (ivbat <= vwarn1)
            {
                icol = 1;
            }
            else
            {
                icol= 0;
            }
        }
        return icol;
    }

    private void bleet_sans_merci(string sfn="bleet.ogg")
    {
        var fn = MWPUtils.find_conf_file(sfn);
        if(fn != null)
        {
            try
            {
                string cmd = "%s %s".printf(conf.mediap,fn);
                Process.spawn_command_line_async(cmd);
            } catch (SpawnError e) {
                stderr.printf ("Error: %s\n", e.message);
            }
        }
    }


    private void set_bat_stat(uint8 ivbat)
    {
        string vbatlab;
        string[] bcols = {"green","yellow","orange","red","white" };
        float vf=0f;

        if(vinit == false)
        {
            vinit = true;
            if(naze32)
            {
                var ncell = ivbat / vwarn1;
                var vmin = vwarn1;
                var vmax = vwarn2;
                vcrit = vmin * ncell;
                vwarn1 = vmax * ncell * 84 / 100;
                vwarn2 = vmax * ncell * 80 / 100;
//                stdout.printf("Set warns to %d %d %d\n", vcrit, vwarn1, vwarn2);
            }
        }

        string str;
        var icol = getbatcol(ivbat);
        if (icol == 4)
        {
            str="n/a";
        }
        else
        {
            vf = (float)ivbat/10.0f;
            str = "%.1fv".printf(vf);
        }
        vbatlab="<span background=\"%s\" weight=\"bold\">%s</span>".printf(bcols[icol], str);
        labelvbat.set_markup(vbatlab);
        navstatus.volt_update(str,icol,vf);
        if(icol != 0 && icol != 4 && icol > licol)
        {
            if(bleetat != icol)
            {
                bleet_sans_merci();
                bleetat = icol;
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
        send_cmd(MSP.Cmds.SET_WP, &wpmgr.wps[wpmgr.wpidx], sizeof(MSP_WP));
    }

    public void request_wp(uint8 wp)
    {
        uint8 buf[2];
        have_wp = false;
        buf[0] = wp;
        add_cmd(MSP.Cmds.WP,buf,1,&have_wp,1000);
    }

    public void update_config(MSP_NAV_CONFIG nc)
    {
        have_nc = false;
        send_cmd(MSP.Cmds.SET_NAV_CONFIG, &nc, sizeof(MSP_NAV_CONFIG));
        add_cmd(MSP.Cmds.NAV_CONFIG,null,0,&have_nc,1000);
    }

    private void send_cmd(MSP.Cmds cmd, void* buf, size_t len)
    {
        if(msp.available == true)
        {
            msp.send_command(cmd,buf,len);
        }
    }

    private void add_cmd(MSP.Cmds cmd, void* buf, size_t len,
                         bool *flag, int wait=1000)
    {
        if(flag != null)
        {
            cmdtid = Timeout.add(wait, () => {
                    if (*flag == false)
                    {
                        send_cmd(cmd,buf,len);
                        return true;
                    }
                    else
                    {
                        return false;
                    }
                });
        }
        send_cmd(cmd,buf,len);
    }

    private void start_audio()
    {
        if (spktid == 0)
        {
            if(audio_on && (sflags != 0))
            {
                navstatus.logspeak_init(conf.evoice);
                spktid = Timeout.add_seconds(conf.speakint, () => {
                        if(_nsats != nsats)
                        {
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
            navstatus.logspeak_close();
        remove_tid(ref spktid);
    }

    private void remove_tid(ref uint tid)
    {
        if(tid > 0)
            Source.remove(tid);
        tid = 0;
    }

    private void serial_doom(Gtk.Button c)
    {
        remove_tid(ref cmdtid);
        remove_tid(ref gpstid);
        stop_audio();
        sflags = 0;

        if(rawlog == true)
        {
            msp.raw_logging(false);
        }
        msp.close();
        gpsinfo.annul();
        set_bat_stat(0);
        have_vers = have_misc = have_status = have_wp = have_nc = false;
        nsats = 0;
        _nsats = 0;
        c.set_label("gtk-connect");
        menuncfg.sensitive = menuup.sensitive = menudown.sensitive = false;
        navconf.hide();
        if(craft != null)
        {
            craft.remove_marker();
        }
    }

    private void connect_serial()
    {
        if(msp.available)
        {
            serial_doom(conbutton);
            verlab.set_label("");
            typlab.set_label("");
        }
        else
        {
            var serdev = dev_entry.get_active_text();
            string estr;
            if (msp.open(serdev, conf.baudrate, out estr) == true)
            {
                autocount = 0;
                if(rawlog == true)
                {
                    msp.raw_logging(true);
                }
                conbutton.set_label("gtk-disconnect");
                add_cmd(MSP.Cmds.IDENT,null,0,&have_vers,1000);
            }
            else
            {
                if (autocon == false || autocount == 0)
                {

                    mwp_warning_box("Unable to open serial device: %s\nReason: %s".printf(
                                        serdev, estr));
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

    public void run()
    {
        Gtk.main();
    }

    private void download_quad()
    {
        wp_resp= {};
        wpmgr.wp_flag = WPDL.REPLACE;
        request_wp(1);
    }

    public static int main (string[] args)
    {
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

        MWPlanner app = new MWPlanner();
        app.run ();
        return 0;
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
