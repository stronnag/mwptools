
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
    private int64 gps_start = 0;
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
    private static string relog = null;
    private static bool exhaustbat=false;
    private static bool ltm=false;
    private static bool nowait=false;
    private static int udport=0;
    private bool armed=false;
    private static string model=null;
    private uint8 imodel=3;
    private static string sdev=null;
    private int[] pipe;

    const OptionEntry[] options = {
        { "mission", 'm', 0, OptionArg.STRING, out mission, "Mission file", null},
        { "model", 'M', 0, OptionArg.STRING, out model, "Model", null},
        { "device", 's', 0, OptionArg.STRING, out sdev, "device", null},
        { "raw-replay", 'r', 0, OptionArg.STRING, out replay, "Replay raw file", null},
        { "log-replay", 'l', 0, OptionArg.STRING, out relog, "Replay log file", null},
        { "exhaust-battery", 'x', 0, OptionArg.NONE, out exhaustbat, "exhaust the battery (else warn1)", null},
        { "ltm", 'l', 0, OptionArg.NONE, out ltm, "push tm", null},
        { "now", 'n', 0, OptionArg.NONE, out nowait, "don't wait for input before replay", null},
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

        if(relog != null)
        {
            mission=null;
            ltm=false;
            replay = null;
        }

        if(replay != null)
        {
            mission=null;
            ltm=false;
            relog = null;
        }

        if(model != null)
        {
            imodel = (uint8)MSP.find_model(model);
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
                    gps_start = GLib.get_monotonic_time();
                    startb.set_label("gtk-media-stop");
                    var td = legs[legs.length-1].tdist;
                    pbar.set_fraction(0.0);
                    pbar.set_show_text(true);
                    int ftime =(int)Math.round(td * 1852.0 / 2.5);
                    var gps_timer = 0;
                    volts = 12.6;
                    armed = true;
                    tid = Timeout.add(1000, () => {
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

    private void ui_update(string msg)
    {
        Posix.write(pipe[1],(char[])msg, msg.length);
    }

    private void run_replay()
    {

        IOChannel io_read;
        pipe = new int[2];
        Posix.pipe(pipe);
        io_read  = new IOChannel.unix_new(pipe[0]);
        io_read.add_watch(IOCondition.IN|IOCondition.HUP|IOCondition.NVAL,
                          log_writer);

        new Thread<int> ("replay", () => {
                var rfd = Posix.open (replay, Posix.O_RDONLY);
                uint8 fbuf[10];
                uint8 buf[128];
                double st = 0;
                size_t count;
                bool ok = true;

                ui_update("replay raw %s\n".printf(replay));

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
                                ulong msecs = 0;
                                if(count > 1)
                                {
                                    if (st != 0)
                                    {
                                        var delta = tt - st;
                                        msecs = (ulong)(delta * 1000 * 1000);
                                        Thread.usleep(msecs);
                                    }
                                    ui_update("%cframe %lub\n".printf(buf[2],
                                                                     count));
                                    msp.write(buf,count);
                                }
                                st = tt;
                            }
                        }
                        else
                            ok = false;
                    }
                    else
                        ok = false;
                }
                ui_update("** end **\n");
                Posix.close(pipe[1]);
                return 0;
            });
    }

    private bool log_writer(IOChannel gio, IOCondition condition)
    {
                IOStatus ret;
                string msg;
                size_t len;

                if((condition & IOCondition.IN) != IOCondition.IN)
                {
                    append_text("close replay thread\n");
                    Posix.close(pipe[0]);
                    return false;
                }

                try {
                    ret = gio.read_line(out msg, out len, null);
                    append_text(msg);
                }
                catch(IOChannelError e) {
                    print("Error reading: %s\n", e.message);
                }
                catch(ConvertError e) {
                        print("Error reading: %s\n", e.message);
                }
                return true;
    }



    private void run_relog()
    {
        IOChannel io_read;
        pipe = new int[2];
        Posix.pipe(pipe);
        io_read  = new IOChannel.unix_new(pipe[0]);
        io_read.add_watch(IOCondition.IN|IOCondition.HUP|IOCondition.NVAL,
                          log_writer);

        new Thread<int> ("relog", () => {
                var file = File.new_for_path (relog);
                if (!file.query_exists ()) {
                    stderr.printf ("File '%s' doesn't exist.\n", file.get_path ());
                    return 1;
                }
                ui_update("log %s replay\n".printf(relog));

                try
                {
                    double lt = 0;
                    var dis = new DataInputStream (file.read ());
                    string line;
                    bool armed = false;
                    uint8 tx[64];
                    var parser = new Json.Parser ();
                    while ((line = dis.read_line (null)) != null) {
                        parser.load_from_data (line);
                        var obj = parser.get_root ().get_object ();
                        var utime = obj.get_double_member ("utime");
                        if(lt != 0)
                        {
                            ulong ms = (ulong)((utime - lt) * 1000 * 1000);
                            Thread.usleep(ms);
                        }
                        var typ = obj.get_string_member("type");
                        var str = "Send %s\n".printf(typ);
                        ui_update(str);

                        switch(typ)
                        {
                            case "init":
                                var mrtype = obj.get_int_member ("mrtype");
                                var mwvers = obj.get_int_member ("mwvers");
                                var cap = obj.get_int_member ("capability");
                                if(mwvers == 0)
                                    mwvers = 42;

                                uint8 buf[7];
                                buf[0] = (uint8)mwvers;
                                buf[1] = (uint8)mrtype;
                                buf[2] = 42;
                                serialise_u32(buf+3, (uint32)cap);
                                msp.send_command(MSP.Cmds.IDENT, buf, 7);

                                MSP_MISC a = MSP_MISC();
                                a.conf_minthrottle=1064;
                                a.maxthrottle=1864;
                                a.mincommand=900;
                                a.conf_mag_declination = -15;
                                if ((cap & 0x80000000) == 0x80000000)
                                {
                                    a.conf_vbatscale = 110;
                                    a.conf_vbatlevel_warn1 = 33;
                                    a.conf_vbatlevel_warn2 = 43;
                                }
                                else
                                {
                                    a.conf_vbatscale = 131;
                                    a.conf_vbatlevel_warn1 = 107;
                                    a.conf_vbatlevel_warn2 = 99;
                                    a.conf_vbatlevel_crit = 93;
                                }
                                var nb = serialise_misc(a, tx);
                                msp.send_command(MSP.Cmds.MISC, tx, nb);
                                break;
                            case "armed":
                                var a = MSP_STATUS();
                                armed = obj.get_boolean_member("armed");
                                a.flag = (armed)  ? 1 : 0;
                                a.i2c_errors_count = 0;
                                a.sensor=31;
                                a.cycle_time=0;
                                var nb = serialise_status(a, tx);
                                msp.send_command(MSP.Cmds.STATUS, tx, nb);
                                break;
                            case "analog":
                                var volts = obj.get_double_member("voltage");
                                var amps = obj.get_int_member("amps");
                                var power = obj.get_int_member("power");
                                var rssi = obj.get_int_member("rssi");
                                MSP_ANALOG a = MSP_ANALOG();
                                a.vbat = (uint8)(Math.lround(volts*10));
                                a.amps = (uint16)amps;
                                a.rssi = (uint16)rssi;
                                a.powermetersum = (uint16)power;
                                serialise_analogue(a, tx);
                                msp.send_command(MSP.Cmds.ANALOG, tx, MSize.MSP_ANALOG);
                                break;
                            case "attitude":
                                    //{"type":"attitude","utime":1408382805,"angx":0,"angy":0,"heading"":0}
                                var hdr =  obj.get_int_member("heading");
                                if (hdr > 180)
                                    hdr -= 360;
                                var dangx = obj.get_double_member("angx");
                                var dangy = obj.get_double_member("angy");
                                var a = MSP_ATTITUDE();
                                a.heading=(int16)hdr;
                                a.angx = (int16)Math.lround(dangx*10);
                                a.angy = (int16)Math.lround(dangy*10);
                                serialise_atti(a, tx);
                                msp.send_command(MSP.Cmds.ATTITUDE, tx, MSize.MSP_ATTITUDE);
                                break;
                            case "altitude":
                                    //{"type":"altitude","utime":1404717912,"estalt":4.4199999999999999,"vario":20.399999999999999}
                                var a = MSP_ALTITUDE();
                                a.estalt = (int32)(Math.lround(obj.get_double_member("estalt")*100));
                                a.vario = (int16)(Math.lround(obj.get_double_member("vario")* 10));
                                var nb = serialise_alt(a, tx);
                                msp.send_command(MSP.Cmds.ALTITUDE, tx,nb);
                                break;
                            case "status":
                                    //{"type":"status","utime":1404717912,"gps_mode":0,"nav_mode":0,"action":0,"wp_number":0,"nav_error":10,"target_bearing":0}
                                var a = MSP_NAV_STATUS();
                                a.gps_mode = (uint8)obj.get_int_member("gps_mode");
                                a.nav_mode = (uint8)obj.get_int_member("nav_mode");
                                a.action = (uint8)obj.get_int_member("action");
                                a.wp_number = (uint8)obj.get_int_member("wp_number");
                                a.nav_error = (uint8)obj.get_int_member("nav_error");
                                a.target_bearing = (uint16)obj.get_int_member("target_bearing");
                                serialise_nav_status(a, tx);
                                msp.send_command(MSP.Cmds.NAV_STATUS, tx, MSize.MSP_NAV_STATUS);
                                break;
                            case "raw_gps":
                                    // {"type":"raw_gps","utime":1404717910,"lat":50.805089199999998,"lon":-1.4939248999999999,"cse":50.899999999999999,"spd":0.22,"alt":41,"fix":1,"numsat":8}
                                var a = MSP_RAW_GPS();
                                a.gps_lat = (int32)(Math.lround(obj.get_double_member("lat")*10000000));
                                a.gps_lon = (int32)(Math.lround(obj.get_double_member("lon")*10000000));
                                a.gps_altitude = (int16)obj.get_int_member("alt");
                                a.gps_speed = (int16)(Math.lround(obj.get_double_member("spd")*100));
                                a.gps_ground_course = (int16)(Math.lround(obj.get_double_member("cse")*10));
                                a.gps_fix = (uint8)obj.get_int_member("fix");
                                a.gps_numsat = (uint8)obj.get_int_member("numsat");
                                serialise_raw_gps(a, tx);
                                msp.send_command(MSP.Cmds.RAW_GPS, tx, MSize.MSP_RAW_GPS);
                                break;
                            case "comp_gps":
                                    // {"type":"comp_gps","utime":1408391119,"bearing":180,"range":0,"update":0}

                                var a = MSP_COMP_GPS();
                                a.range = (uint16)obj.get_int_member("range");
                                var hdr =  obj.get_int_member("bearing");
                                if (hdr > 180)
                                    hdr -= 360;
                                a.direction = (int16)hdr;
                                a.update = (uint8)obj.get_int_member("update");
                                serialise_comp_gps(a, tx);
                                msp.send_command(MSP.Cmds.COMP_GPS, tx, MSize.MSP_COMP_GPS);
                                break;
                            case "radio":
                                    //"type":"radio","utime":1404717910,"rxerrors":0,"fixed_errors":0,"localrssi":139,"remrssi":138,"txbuf":100,"noise":93,"remnoise":15}

                                break;
                            default:
                                break;
                        }
                        lt = utime;
                    }
                } catch (Error e) {
                    error ("%s", e.message);
                }
                ui_update("end log replay\n");
                Posix.close(pipe[1]);
                return 0;
            });
    }


    private size_t serialise_gf(LTM_GFRAME b, uint8 []tx)
    {
        uint8 *p;
        p = serialise_i32(tx, b.lat);
        p = serialise_i32(p, b.lon);
        *p++ = (uint8)b.speed;
        p = serialise_i32(p, b.alt);
        *p++ = b.sats;
        return (p - &tx[0]);
    }

    private size_t serialise_af(LTM_AFRAME b, uint8 []tx)
    {
        uint8 *p;
        p = serialise_i16(tx, b.pitch);
        p = serialise_i16(p, b.roll);
        p = serialise_i16(p, b.heading);
        return (p - &tx[0]);
    }

    private size_t serialise_sf(LTM_SFRAME b, uint8 []tx)
    {
        uint8 *p;
        p = serialise_i16(tx, b.vbat);
        p = serialise_i16(p, b.vcurr);
        *p++ = b.rssi;
        *p++ = b.airspeed;
        *p++ = b.flags;
        return (p - &tx[0]);
    }

    private void process_ltm()
    {
        uint8 tx[32];
        size_t nb;

        MSP_RAW_GPS buf = {0};
        get_gps_info(out buf);
        LTM_GFRAME gf = {0};
        gf.lat = buf.gps_lat;
        gf.lon = buf.gps_lon;
        gf.speed = buf.gps_speed/100;
        gf.alt = gblalt*100 + rand.int_range(-50,50);
        gf.sats = 1+(buf.gps_numsat << 2);
        nb = serialise_gf(gf, tx);
        msp.send_ltm('G',tx, nb);
        append_text("Send LTM G Frame %lu\n".printf(MSize.LTM_GFRAME));

        LTM_AFRAME af = {0};
        af.pitch = 4;
        af.roll = -4;
        int16 icse =  (int16)gblcse;
        if (icse > 180)
            icse = icse - 360;
        af.heading = icse;
        nb = serialise_af(af, tx);
        msp.send_ltm('A',tx, nb);
        append_text("Send LTM A Frame %lu\n".printf(sizeof(LTM_AFRAME)));

        LTM_SFRAME sf ={0};
        sf.vbat = (int16)(volts*1000);
        sf.vcurr = 4200;
        sf.rssi = 150 + rand.int_range(-10,10);
        sf.airspeed = gf.speed;
        sf.flags = 1;
        nb = serialise_sf(sf, tx);
        msp.send_ltm('S',tx, nb);
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
            m.lat = w.lat/10000000.0;
            m.lon = w.lon/10000000.0;
            m.alt = w.altitude/100;
            m.param1 = w.p1;
            m.param2 = w.p2;
            m.param3 = w.p3;
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

    private int getpos_at_time(double spd, double t,
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

        if (sdev != null)
        {
            if (msp.open(sdev,115200,out estr) == false)
            {
                stderr.printf("open of %s failed %s\n", sdev, estr);
            }
        }
        else
        {
            if(udport == 0)
            {
                fd = Posix.posix_openpt(Posix.O_RDWR);
                Posix.ttyname_r(fd, buf);
                stderr.printf("%s => fd %d\n", (string)buf, fd);
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
            int64 now = GLib.get_monotonic_time();
            double tdif = (now - gps_start)/1000000;

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

        g.gps_lat = ilat;
        g.gps_lon = ilon;
        g.gps_altitude =ialt;
        g.gps_speed = ispeed;
        g.gps_ground_course = icourse;
    }

    private void stop_sim()
    {
        if(tid > 0)
        {
            Source.remove(tid);
            tid = 0;
        }
        gps_start = 0;
        pbar.set_fraction(0.0);
        volts = 12.6;
        startb.set_label("gtk-media-play");
    }

    private size_t serialise_misc(MSP_MISC misc, uint8 [] tbuf)
    {
        uint8 *rp;
        rp = serialise_u16(tbuf, misc.intPowerTrigger1);
        rp = serialise_u16(rp, misc.conf_minthrottle);
        rp = serialise_u16(rp, misc.maxthrottle);
        rp = serialise_u16(rp, misc.mincommand);
        rp = serialise_u16(rp, misc.failsafe_throttle);
        rp = serialise_u16(rp, misc.plog_arm_counter);
        rp = serialise_u32(rp, misc.plog_lifetime);
        rp = serialise_i16(rp, misc.conf_mag_declination);
        *rp++ = misc.conf_vbatscale;
        *rp++ = misc.conf_vbatlevel_warn1;
        *rp++ = misc.conf_vbatlevel_warn2;
        *rp++ = misc.conf_vbatlevel_crit;
        return (rp - &tbuf[0]);
    }

        /*
    private size_t serialise_rt(MSP_RC_TUNING rt, uint8 [] tbuf)
    {
        uint8 *rp = tbuf;
        *rp++ = rt.rc_rate;
        *rp++ = rt.rc_expo;
        *rp++ = rt.rollpitchrate;
        *rp++ = rt.yawrate;
        *rp++ = rt.dynthrpid;
        *rp++ = rt.throttle_mid;
        *rp++ = rt.throttle_expo;
        return (rp - &tbuf[0]);
    }
        */
    private size_t serialise_nav_status(MSP_NAV_STATUS b, uint8 []tx)
    {
        uint8 *p = tx;
        *p++ = b.gps_mode;
        *p++ = b.nav_mode;
        *p++ = b.action;
        *p++ = b.wp_number;
        *p++ = b.nav_error;
        p = serialise_u16(p, b.target_bearing);
        return (p - &tx[0]);
    }

    private size_t serialise_alt(MSP_ALTITUDE b, uint8 []tx)
    {
        uint8 *p;
        p = serialise_i32(tx, b.estalt);
        p = serialise_i16(p, b.vario);
        return (p - &tx[0]);
    }

    private size_t serialise_raw_gps(MSP_RAW_GPS b, uint8 []tx)
    {
        uint8 *p = tx;
        *p++ = b.gps_fix;
        *p++ = b.gps_numsat;
        p = serialise_i32(p, b.gps_lat);
        p = serialise_i32(p, b.gps_lon);
        p = serialise_i16(p, b.gps_altitude);
        p = serialise_u16(p, b.gps_speed);
        p = serialise_u16(p, b.gps_ground_course);
        return (p - &tx[0]);
    }

    private size_t serialise_status(MSP_STATUS b, uint8 []tx)
    {
        uint8 *p;
        p = serialise_u16(tx, b.cycle_time);
        p = serialise_u16(p, b.i2c_errors_count);
        p = serialise_u16(p, b.sensor);
        p = serialise_u32(p, b.flag);
        *p++ = b.global_conf;
        return (p - &tx[0]);
    }

    private size_t serialise_radio(MSP_RADIO b, uint8 []tx)
    {
        uint8 *p;
        p = serialise_u16(tx, b.rxerrors);
        p = serialise_u16(p, b.fixed_errors);
        *p++ = b.localrssi;
        *p++ = b.remrssi;
        *p++ = b.txbuf;
        *p++ = b.noise;
        *p++ = b.remnoise;
        return (p - &tx[0]);
    }

    private size_t serialise_analogue(MSP_ANALOG b, uint8 []tx)
    {
        uint8 *p = tx;
        *p++ = b.vbat;
        p = serialise_u16(p, b.powermetersum);
        p = serialise_u16(p, b.rssi);
        p = serialise_u16(p, b.amps);
        return (p - &tx[0]);
    }

    private size_t serialise_comp_gps(MSP_COMP_GPS b, uint8 []tx)
    {
        uint8 *p;
        p = serialise_u16(tx, b.range);
        p = serialise_i16(p, b.direction);
        *p++ = b.update;
        return (p - &tx[0]);
    }

    private size_t serialise_atti(MSP_ATTITUDE b, uint8 []tx)
    {
        uint8 *p;
        p = serialise_u16(tx, b.angx);
        p = serialise_u16(p, b.angy);
        p = serialise_u16(p, b.heading);
        return (p - &tx[0]);
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
            fence = 600,
            max_wp_number = 200
        };

        var loop = 0;

        if (nowait)
        {
            Timeout.add_seconds(2,() => {
            if (relog != null)
                run_relog();

            if(replay != null)
                run_replay();

            return false;
                });
        }

        msp.serial_event.connect ((s, cmd, raw, len, errs) =>
        {
            uint8 tx[64];
            size_t nb;

            if(nowait)
                return;

            if(loop == 0)
            {
                if (relog != null)
                    run_relog();

                if(replay != null)
                    run_replay();
            }

            if(replay == null && relog == null)
            {
                if(errs == true)
                {
                    stderr.printf("Error on cmd %c (%d)\n", cmd,cmd);
                    return;
                }
                switch(cmd)
                {
                    case MSP.Cmds.IDENT:
                    uint8[] buf = {230, imodel,42,16,0,0,0};
                    append_text("Send IDENT\n");
                    msp.send_command(MSP.Cmds.IDENT, buf, buf.length);
                    break;

                    case MSP.Cmds.STATUS:
                    MSP_STATUS buf = MSP_STATUS();
                    buf.cycle_time=((uint16)2345);
                    buf.sensor=((uint16)31);
                    buf.flag = (armed) ? 1 : 0;
                    nb = serialise_status(buf, tx);
                    append_text("Send STATUS %lu\n".printf(MSize.MSP_STATUS));
                    msp.send_command(MSP.Cmds.STATUS, tx, nb);
                    break;

                    case MSP.Cmds.MISC:
                    MSP_MISC buf = MSP_MISC();
                    buf.conf_minthrottle=((uint16)1064);
                    buf.maxthrottle=((uint16)1864);
                    buf.mincommand=((uint16)900);
                    buf.conf_mag_declination = -15;
                    buf.conf_vbatscale = 131;
                    buf.conf_vbatlevel_warn1 = 107;
                    buf.conf_vbatlevel_warn2 = 99;
                    buf.conf_vbatlevel_crit = 93;
                    nb = serialise_misc(buf, tx);
                    append_text("Send MISC %lu\n".printf(MSize.MSP_MISC));
                    msp.send_command(MSP.Cmds.MISC, tx, nb);
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
                    MSP_ALTITUDE buf = MSP_ALTITUDE();
                    buf.estalt = (100*((int32)gblalt) + rand.int_range(-50,50));
                    buf.vario = ((int16)3);
                    nb = serialise_alt(buf, tx);
                    append_text("Send ALT %lu\n".printf(MSize.MSP_ALTITUDE));
                    msp.send_command(MSP.Cmds.ALTITUDE, tx,nb);
                    break;

                    case MSP.Cmds.EEPROM_WRITE:
                    append_text("got EE_WRITE\n");
                    break;

                    case MSP.Cmds.SET_NAV_CONFIG:
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
                    append_text("got SET_NC\n");
                    break;

                    case MSP.Cmds.SET_PID:
                    append_text("got SET_PID\n");
                    break;

                    case  MSP.Cmds.RAW_GPS:
                    MSP_RAW_GPS buf = MSP_RAW_GPS();
                    get_gps_info(out buf);
                    nb = serialise_raw_gps(buf, tx);
                    append_text("Send GPS %lu\n".printf(MSize.MSP_RAW_GPS));
                    msp.send_command(MSP.Cmds.RAW_GPS, tx, MSize.MSP_RAW_GPS);
                    break;

                    case MSP.Cmds.SET_WP:
                    MSP_WP w = MSP_WP();
                    uint8* rp = raw;
                    w.wp_no = *rp++;
                    w.action = *rp++;
                    rp = deserialise_i32(rp, out w.lat);
                    rp = deserialise_i32(rp, out w.lon);
                    rp = deserialise_u32(rp, out w.altitude);
                    rp = deserialise_i16(rp, out w.p1);
                    rp = deserialise_u16(rp, out w.p2);
                    rp = deserialise_u16(rp, out w.p3);
                    w.flag = *rp;
                    var n = w.wp_no;
                    wps[n] = w;
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
                        nb = serialise_wp(wps[n], tx);
                        msp.send_command(MSP.Cmds.WP, tx, MSize.MSP_WP);
                        append_text("Send WP %d\n".printf(n));
                    }
                    else
                    {
                        msp.send_error(MSP.Cmds.WP);
                    }
                    break;

                    case MSP.Cmds.NAV_STATUS:
                    nb = serialise_nav_status(nsts, tx);
                    msp.send_command(MSP.Cmds.NAV_STATUS, tx, MSize.MSP_NAV_STATUS);
                    append_text("Send NAV STATUS %lu\n".printf(MSize.MSP_NAV_STATUS));
                    if((loop % 4) == 0)
                    {
                        MSP_RADIO r = {0, 0,152, 152, 100, 57, 38};
                        r.localrssi = (uint8)((int32)r.localrssi + rand.int_range(-10,10));
                        r.remrssi = (uint8)((int32)r.remrssi + rand.int_range(-10,10));
                        r.noise = (uint8)((int32)r.noise + rand.int_range(-5,5));
                        r.remnoise = (uint8)((int32)r.remnoise + rand.int_range(-5,5));
                        nb = serialise_radio(r, tx);
                        msp.send_command(MSP.Cmds.RADIO, tx, MSize.MSP_RADIO);
                        append_text("Send RADIO %lu\n".printf(MSize.MSP_RADIO));
                    }
                    break;

                    case MSP.Cmds.NAV_CONFIG:
                    nb = serialise_nc(nc, tx);
                    msp.send_command(MSP.Cmds.NAV_CONFIG, tx, MSize.MSP_NAV_CONFIG);
                    append_text("Send NAV CONFIG %lu\n".printf(MSize.MSP_NAV_CONFIG));
                    break;

                    case MSP.Cmds.ANALOG:
                    MSP_ANALOG buf = MSP_ANALOG();
                    buf.vbat = (uint8)(volts*10);
                    nb = serialise_analogue(buf, tx);
                    msp.send_command(MSP.Cmds.ANALOG, tx, MSize.MSP_ANALOG);
                    append_text("Send ANALOG %lu\n".printf(MSize.MSP_ANALOG));
                    break;

                    case MSP.Cmds.COMP_GPS:
                    nb = serialise_comp_gps(cg, tx);
                    msp.send_command(MSP.Cmds.COMP_GPS, tx, MSize.MSP_COMP_GPS);
                    append_text("Send NAV COMP GPS %lu\n".printf(MSize.MSP_COMP_GPS));
                    break;

                    case MSP.Cmds.ATTITUDE:
                    MSP_ATTITUDE buf = MSP_ATTITUDE();
                    buf.heading=(int16)gblcse;
                    nb = serialise_atti(buf, tx);
                    msp.send_command(MSP.Cmds.ATTITUDE, tx, MSize.MSP_ATTITUDE);
                    append_text("Send NAV ATTITUDE %lu\n".printf(MSize.MSP_ATTITUDE));
                    break;

                    case MSP.Cmds.BOX:
                    uint8 box[8] = {0};
                    msp.send_command(MSP.Cmds.BOX, box, 8);
                    break;

                    default:
                    stdout.printf("unknown %d\n",cmd);
                    msp.send_error(cmd);
                    break;
                }
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
