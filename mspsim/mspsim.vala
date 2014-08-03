
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

extern double get_locale_double(string str);

public struct LegItem
{
    double slat;
    double slon;
    double elat;
    double elon;
    int alt;
    double dist;
    double tdist;
    double cse;
}

public class MWSim : GLib.Object
{
    private int fd;
    public MWSerial msp;
    private Builder builder;
    private Gtk.Window window;
    private Gtk.Entry slave;
    private Gtk.TextView textlog;
    private Mission ms;
    private LegItem[] legs;
    private time_t gps_start = 0;
    private Gtk.Button startb;
    private Gtk.ProgressBar pbar;
    private uint tid;
    private MSP_WP wps[256];
    private MSP_NAV_STATUS nsts;
    private int nwpts = 0;
    private int gblalt = 0;
    private int gblcse = 0;
    private double volts;
    private Rand rand;
    private double afact;

    private MSP_COMP_GPS cg;
    private Gtk.FileChooserButton chooser;

    private static string mission=null;
    private static string replay = null;
    private static bool exhaustbat=false;
    private static bool ltm=false;
    private static int udport=0;
    private bool armed=false;

    const OptionEntry[] options = {
        { "mission", 'm', 0, OptionArg.STRING, out mission, "Mission file", null},
        { "replay", 'r', 0, OptionArg.STRING, out replay, "Replay file", null},
        { "exhaust-battery", 'x', 0, OptionArg.NONE, out exhaustbat, "exhaust the battery (else warn1)", null},
        { "ltm", 'l', 0, OptionArg.NONE, out ltm, "push tm", null},
        { "udp-port", 'u', 0, OptionArg.INT, ref udport, "udp port for comms", null},
        {null}
    };

    public void append_text(string text)
    {
         Gtk.TextIter ei;
         var tbuffer = textlog.get_buffer();
         tbuffer.get_end_iter(out ei);
         var dt = new DateTime.now_local();
         var secs = dt.get_seconds();
         var ds0 = dt.format("%F %H:%M:");
         var msg = "%s%04.1f : %s".printf(ds0,secs,text);
         tbuffer.insert(ref ei, msg, -1);
    }

    public MWSim()
    {
        cg.range = cg.direction = cg.update = 0;
        rand  = new Rand();
        volts = 12.6;
        afact = (exhaustbat == false) ? 0.1667 :  0.27;

        builder = new Builder ();
        var fn = MWPUtils.find_conf_file("mspsim.ui");
        if (fn == null)
        {
            stderr.printf ("No UI definition file\n");
            Gtk.main_quit();
        }
        else
        {
            try
            {
                builder.add_from_file (fn);
            } catch (Error e) {
                stderr.printf ("Builder: %s\n", e.message);
                Posix.exit(0);
            }
        }

        if(replay != null)
        {
            mission=null;
            ltm=false;
        }

        builder.connect_signals (null);
        window = builder.get_object ("window1") as Gtk.Window;
        window.destroy.connect (Gtk.main_quit);
        window.set_default_size (400, 400);
        try {
            string icon=null;
            icon = MWPUtils.find_conf_file("mspsim_icon.svg");
            window.set_icon_from_file(icon);
        } catch {};

        var quitb = builder.get_object ("button1") as Gtk.Button;
        quitb.clicked.connect(() => {
                Gtk.main_quit();
            });

        pbar = builder.get_object ("progressbar2") as Gtk.ProgressBar;
        startb = builder.get_object ("button2") as Gtk.Button;
        startb.set_sensitive(false);

        startb.clicked.connect(() => {
                if (gps_start == 0)
                {
                    time_t(out gps_start);
                    startb.set_label("gtk-media-stop");
                    var td = legs[legs.length-1].tdist;
                    pbar.set_fraction(0.0);
                    pbar.set_show_text(true);
                    int ftime =(int)Math.round(td * 1852.0 / 2.5);
                    var gps_timer = 0;
                    volts = 12.6;
                    armed = true;
                    tid = Timeout.add(1000, () =>
                        {
                            gps_timer++;
                            double frac = (double)gps_timer/(double)ftime;
                            pbar.set_fraction(frac);
                            volts = 12.6*(1.0 - afact*frac);
                            if (gps_timer == ftime)
                            {
                                stop_sim();
                                return false;
                            }
                            else
                            {
                                if(ltm)
                                {
                                    process_ltm();
                                }
                                return true;
                            }
                        });
                }
                else
                {
                    armed = false;
                    stop_sim();
                }
            });

        slave = builder.get_object ("entry1") as Gtk.Entry;
        textlog = builder.get_object ("textview1") as Gtk.TextView;
        var sw = builder.get_object ("scrolledwindow1") as Gtk.ScrolledWindow;
            // Cunning autoscroll ...
        textlog.size_allocate.connect(() => {
                var adj = sw.get_vadjustment();
                adj.set_value(adj.get_upper() - adj.get_page_size());
            });
        chooser = builder.get_object ("filechooserbutton1") as Gtk.FileChooserButton;

        if(mission != null)
        {
            chooser.set_filename (mission);
            parse_mission(mission);
        }

        chooser.file_set.connect(() => {
                parse_mission(chooser.get_filename ());
            });

        msp = new MWSerial();
        msp.set_mode(MWSerial.Mode.SIM);
        window.show_all();
    }

    private void run_replay()
    {
        var thr = new Thread<int> ("replay", () => {
                var rfd = Posix.open (replay, Posix.O_RDONLY);
                uint8 fbuf[10];
                uint8 buf[128];
                double st = 0;
                size_t count;
                bool ok = true;

                while(ok==true)
                {
                    var n = Posix.read(rfd,fbuf,10);
                    if(n > 0)
                    {
                        count = fbuf[8];
                        n = Posix.read(rfd,buf,(int)fbuf[8]);
                        if (n > 0)
                        {
                            if(fbuf[9] == 'i' && buf[1] == 'T')
                            {
                                double tt;
                                tt = *(double*)fbuf;
                                var delta = tt - st;
                                ulong ms = (ulong)(delta * 1000 * 1000);
                                Thread.usleep(ms);
                                msp.write(buf,count);
                                st = tt;
                                }
                        }
                        else
                            ok = false;
                    }
                    else
                        ok = false;
                }
                return 0;
            });
    }


    private void process_ltm()
    {
        MSP_RAW_GPS buf = {0};
        get_gps_info(out buf);
        LTM_GFRAME gf = {0};
        gf.lat = buf.gps_lat;
        gf.lon = buf.gps_lon;
        gf.speed = buf.gps_speed/100;
        gf.alt = gblalt*100 + rand.int_range(-50,50);
        gf.sats = 1+(buf.gps_numsat << 2);
        msp.send_ltm('G',&gf);
        append_text("Send LTM G Frame %lu\n".printf(sizeof(LTM_GFRAME)));

        LTM_AFRAME af = {0};
        af.pitch = 4;
        af.roll = -4;
        af.heading = (int16)gblcse;
        msp.send_ltm('A',&af);
        append_text("Send LTM A Frame %lu\n".printf(sizeof(LTM_AFRAME)));
        LTM_SFRAME sf ={0};
        sf.vbat = (int16)(volts*1000);
        sf.vcurr = 4200;
        sf.rssi = 150 + rand.int_range(-10,10);
        sf.airspeed = gf.speed;
        sf.flags = 1;
        msp.send_ltm('S',&sf);
        append_text("Send LTM S Frame %lu\n".printf(sizeof(LTM_SFRAME)));
    }

    public void parse_mission(string fn)
    {
        ms = new Mission();
        ms.read_xml_file(fn);
        if(ms.get_ways().length > 0)
        {
            startb.set_sensitive(true);
            make_legs();
        }
    }

    private void parse_wps()
    {
        ms = new Mission();
        MissionItem[] ma = {};
        foreach(var w in wps)
        {
            if(w.action == 0)
                continue;

            MissionItem m = MissionItem();
            m.no= w.wp_no;
            m.action = (MSP.Action)w.action;
            m.lat = (int32.from_little_endian(w.lat))/10000000.0;
            m.lon = (int32.from_little_endian(w.lon))/10000000.0;
            m.alt = (uint32.from_little_endian(w.altitude))/100;
            m.param1 = (uint16.from_little_endian(w.p1));
            m.param2 = (uint16.from_little_endian(w.p2));
            m.param3 = (uint16.from_little_endian(w.p3));
            print("wp %d action %d %f %f %u %02x\n",
                  m.no, m.action, m.lat, m.lon, m.alt, w.flag);
            ma += m;
            if (w.flag == 0xa5)
                break;
        }
        ms.set_ways(ma);
        startb.set_sensitive(true);
        make_legs();
    }

    public void make_legs()
    {
        double lx = 0.0,ly=0.0;
        bool ready = false;
        legs = {};
        double d = 0.0;

        foreach (MissionItem w in ms.get_ways())
        {
            var typ = w.action;

            if (typ == MSP.Action.SET_POI || typ == MSP.Action.SET_HEAD)
            {
                continue;
            }

            if (typ == MSP.Action.RTH)
            {
                break;
            }

            if (ready == true)
            {
                double dx,cse;
                Geo.csedist(ly,lx,w.lat,w.lon, out dx, out cse);
                d += dx;
                var l = LegItem() {
                    slat = ly, slon = lx, elat = w.lat, elon = w.lon,
                    dist = dx, tdist = d, cse = cse, alt= (int)w.alt};
                legs += l;
            }
            else
                ready = true;

            ly = w.lat;
            lx = w.lon;
        }
    }

    private int getpos_at_time(double spd, int t,
                               out double lat, out double lon,
                               out int alt, out double cse, int cl=0)
    {
        var lld = 0.0;
        var llat = legs[0].slat;
        var llon = legs[0].slon;
        var lcse = legs[0].cse;
        var maxl = legs.length;
        int nl;
        lat = lon = cse = 0.0;
        alt = 0;

        double d = t * spd / 1852.0;
        for(nl = 0; nl < maxl; nl++)
        {
            alt = legs[nl].alt;
            cse = legs[nl].cse;
            if (d > legs[nl].tdist)
            {
                cl = nl + 1;
                if (cl == maxl)
                {
                    cl = -1;
                    lat = legs[maxl-1].elat;
                    lon = legs[maxl-1].elon;
                    break;
                }
                else
                {
                    lld = legs[nl].tdist;
                    llat = legs[cl].slat;
                    llon = legs[cl].slon;
                    lcse = legs[cl].cse;
                }
            }
            else
                break;
        }

        if (cl != -1)
        {
            double ld = d - lld;
            Geo.posit (llat, llon, lcse, ld, out lat, out lon, true);
            nsts.gps_mode=3;
            nsts.nav_mode=5;
            nsts.action=1;
            nsts.wp_number=(uint8)cl+2;
            nsts.target_bearing=(uint16)lcse;
            double hdist,hcse;
            Geo.csedist(lat, lon, legs[maxl-1].elat,
                        legs[maxl-1].elon, out hdist, out hcse);
            cg.range = (uint16)(hdist*1852.0);
            var icse = (int16) hcse;
            if (icse > 180)
                icse = icse - 360;
            cg.direction = icse;
            cg.update=1;
        }
        else
        {
            nsts.gps_mode=2;
            nsts.nav_mode=10;
            nsts.action=8;
            nsts.wp_number=(uint8)maxl+1;
            nsts.target_bearing=0;
        }
        gblalt = alt;
        gblcse = (int)cse;
        return cl;
    }

    public void open()
    {
        char buf[128];
        string estr;
        if(udport == 0)
        {
            fd = Posix.posix_openpt(Posix.O_RDWR);
            Posix.grantpt(fd);
            Posix.unlockpt(fd);
            Linux.Termios.ptsname_r (fd, buf);
            slave.set_text((string)buf);
            msp.open_fd(fd,115200);
        }
        else
        {
            var sbuf = ":%d".printf(udport);
            if(msp.open(sbuf,0,out estr) == true)
                slave.set_text(sbuf);
            else
                stderr.printf("UDP fail %s : %s\n", sbuf,estr);
        }
    }


    private void get_gps_info(out MSP_RAW_GPS g)
    {
        double lat, lon, cse;
        int alt;
        double spd;
        var spdspin = builder.get_object ("spinbutton1") as Gtk.SpinButton;

        spd = spdspin.get_value();

        g ={0};

        if(gps_start == 0)
        {
            g.gps_fix = 0;
            g.gps_numsat = 1;
            if(legs != null)
            {
                lat = legs[0].slat;
                lon = legs[0].slon;
            }
            else
            {
                lat = lon = 0.0;
            }
            alt  = 0;
            spd = cse  = 0;
        }
        else if (gps_start == -1)
        {
            int llast = legs.length-1;
            gps_start = -1;
            g.gps_fix = 1;
            g.gps_numsat = 5;
            lat = legs[llast].elat;
            lon = legs[llast].elon;
            alt = legs[llast].alt;
            cse = legs[llast].cse;
            spd = 0;
        }
        else
        {
            time_t now;
            time_t(out now);
            int tdif = (int)(now - gps_start);

            var cl = getpos_at_time(spd, tdif, out lat, out lon,
                                    out alt, out cse, 0);

            if (cl == -1)
            {
                gps_start = -1;
            }
            g.gps_fix = 1;
            g.gps_numsat = 7;
        }

        int32 ilat = (int32)Math.lround(lat * 10000000);
        int32 ilon = (int32)Math.lround(lon * 10000000);
        int16 ialt = (int16)alt;
        int16 ispeed = (int16)(spd*100);
        int16 icourse = (int16)Math.lround(cse*10);

        g.gps_lat = ilat.to_little_endian();
        g.gps_lon = ilon.to_little_endian();
        g.gps_altitude =ialt.to_little_endian();
        g.gps_speed = ispeed.to_little_endian();
        g.gps_ground_course = icourse.to_little_endian();

    }

    private void stop_sim()
    {
        Source.remove(tid);
        gps_start = 0;
        pbar.set_fraction(0.0);
        volts = 12.6;
        startb.set_label("gtk-media-play");
    }

    public void sim()
    {
        open();
        msp.serial_lost.connect (()=> {
                append_text("endpoint died\n");
                stop_sim();
                open();
            });


        MSP_NAV_CONFIG nc = MSP_NAV_CONFIG() {
            flag1 = 0x51,
            flag2 = 1,
            wp_radius = 100,
            safe_wp_distance = 500,
            nav_max_altitude = 100,
            nav_speed_max = 400,
            nav_speed_min = 100,
            crosstrack_gain= 40,
            nav_bank_max = 3000,
            rth_altitude = 15,
            land_speed = 100,
            fence = 600
        };

        var loop = 0;
        msp.serial_event.connect ((s, cmd, raw, len, errs) =>
        {
            if(loop ==0  && replay != null)
            {
                run_replay();
            }

            if(errs == true)
            {
                stderr.printf("Error on cmd %c (%d)\n", cmd,cmd);
                return;
            }
            switch(cmd)
            {
                case MSP.Cmds.IDENT:
                uint8[] buf = {230, 3,42,16,0,0,0};
                append_text("Send IDENT\n");
                msp.send_command(MSP.Cmds.IDENT, buf, buf.length);
                break;

                case MSP.Cmds.STATUS:
                MSP_STATUS buf = {0};
                buf.cycle_time=((uint16)2345).to_little_endian();
                buf.sensor=((uint16)31).to_little_endian();
                buf.flag = (armed) ? 1 : 0;

                append_text("Send STATUS %lu\n".printf(sizeof(MSP_STATUS)));
                msp.send_command(MSP.Cmds.STATUS, &buf, sizeof(MSP_STATUS));
                break;

                case MSP.Cmds.MISC:
                MSP_MISC buf = {0};
                buf.conf_minthrottle=((uint16)1064).to_little_endian();
                buf.maxthrottle=((uint16)1864).to_little_endian();
                buf.mincommand=((uint16)900).to_little_endian();
                buf.conf_mag_declination = -15;
                buf.conf_vbatscale = 131;
                buf.conf_vbatlevel_warn1 = 107;
                buf.conf_vbatlevel_warn2 = 99;
                buf.conf_vbatlevel_crit = 93;
                append_text("Send MISC %lu\n".printf(sizeof(MSP_MISC)));
                msp.send_command(MSP.Cmds.MISC, &buf, sizeof(MSP_MISC));
                break;

                case MSP.Cmds.PID:
                uint8[] buf = {
                    0x16, 0x1c, 0x11, 0x16, 0x1c, 0x11, 0x44, 0x2d, 0x00,
                    0x40, 0x19, 0x18, 0x0b, 0x00, 0x00, 0x14,
                    0x08, 0x2d, 0x0e, 0x14, 0x50, 0x3c, 0x0a,
                    0x50, 0x00, 0x50, 0x64, 0x00, 0x00, 0x00
                };
                append_text("Send PIDS %d\n".printf(buf.length));
                msp.send_command(MSP.Cmds.PID, buf, buf.length);
                break;

                case MSP.Cmds.ALTITUDE:
                MSP_ALTITUDE buf ={0};
                buf.estalt = (100*((int32)gblalt) + rand.int_range(-50,50)).to_little_endian();
                buf.vario = ((int16)3).to_little_endian();
                append_text("Send ALT %lu\n".printf(sizeof(MSP_ALTITUDE)));
                msp.send_command(MSP.Cmds.ALTITUDE, &buf, sizeof(MSP_ALTITUDE));
                break;

                case MSP.Cmds.EEPROM_WRITE:
                append_text("got EE_WRITE\n");
                break;

                case MSP.Cmds.SET_NAV_CONFIG:
                append_text("got SET_NC\n");
                nc = *((MSP_NAV_CONFIG*)raw);
                break;

                case MSP.Cmds.SET_PID:
                append_text("got SET_PID\n");
                break;

                case  MSP.Cmds.RAW_GPS:
                MSP_RAW_GPS buf;
                get_gps_info(out buf);
                append_text("Send GPS %lu\n".printf(sizeof(MSP_RAW_GPS)));
                msp.send_command(MSP.Cmds.RAW_GPS, &buf, sizeof(MSP_RAW_GPS));
                break;

                case MSP.Cmds.SET_WP:
                MSP_WP *w = (MSP_WP *)raw;
                var n = w.wp_no;
                wps[n] = *w;
                nwpts = n ;
                append_text("SET_WP %d type %d\n".printf(n, w.action));
                msp.send_command(MSP.Cmds.SET_WP, raw, raw.length);
                if (w.flag == 0xa5)
                {
                    print("Setting file");
                    chooser.set_current_name ("__downloaded.mission__");
                    parse_wps();
                }

                break;

                case MSP.Cmds.SET_HEAD:
                break;

                case MSP.Cmds.WP:
                    /* Assume we only need number */
                var n = raw[0];
                if(n <= nwpts)
                {
                    msp.send_command(MSP.Cmds.WP, &wps[n], sizeof(MSP_WP));
                    append_text("Send WP %d\n".printf(n));
                }
                else
                {
                    msp.send_error(MSP.Cmds.WP);
                }
                break;

                case MSP.Cmds.NAV_STATUS:
                msp.send_command(MSP.Cmds.NAV_STATUS, &nsts, sizeof(MSP_NAV_STATUS));
                append_text("Send NAV STATUS %lu\n".printf(sizeof(MSP_NAV_STATUS)));
                if((loop % 4) == 0)
                {
                    MSP_RADIO r = {0, 0,152, 152, 100, 57, 38};
                    r.localrssi = (uint8)((int32)r.localrssi + rand.int_range(-10,10));
                    r.remrssi = (uint8)((int32)r.remrssi + rand.int_range(-10,10));
                    r.noise = (uint8)((int32)r.noise + rand.int_range(-5,5));
                    r.remnoise = (uint8)((int32)r.remnoise + rand.int_range(-5,5));
                    msp.send_command(MSP.Cmds.RADIO, &r, sizeof(MSP_RADIO));
                    append_text("Send RADIO %lu\n".printf(sizeof(MSP_RADIO)));
                }
                break;

                case MSP.Cmds.NAV_CONFIG:
                nc.max_wp_number = (uint8) nwpts;
                msp.send_command(MSP.Cmds.NAV_CONFIG, &nc, sizeof(MSP_NAV_CONFIG));
                append_text("Send NAV CONFIG %lu\n".printf(sizeof(MSP_NAV_CONFIG)));
                break;

                case MSP.Cmds.ANALOG:
                MSP_ANALOG buf = {0};
                buf.vbat = (uint8)(volts*10);
                msp.send_command(MSP.Cmds.ANALOG, &buf, sizeof(MSP_ANALOG));
                append_text("Send ANALOG %lu\n".printf(sizeof(MSP_ANALOG)));
                break;

                case MSP.Cmds.COMP_GPS:
                msp.send_command(MSP.Cmds.COMP_GPS, &cg, sizeof(MSP_COMP_GPS));
                append_text("Send NAV COMP GPS %lu\n".printf(sizeof(MSP_COMP_GPS)));
                break;

                case MSP.Cmds.ATTITUDE:
                MSP_ATTITUDE buf ={0};
                buf.heading=(int16)gblcse;
                msp.send_command(MSP.Cmds.ATTITUDE, &buf, sizeof(MSP_ATTITUDE));
                append_text("Send NAV ATTITUDE %lu\n".printf(sizeof(MSP_ATTITUDE)));
                        break;

                default:
                stdout.printf("unknown %d\n",cmd);
                break;
            }
            loop++;
        });
    }
    public void run()
    {
        sim();
        Gtk.main();
    }
    static int main(string?[] args)
    {
        Gtk.init(ref args);
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
        var d = new MWSim();
        d.run ();
        return 0;
    }
}
