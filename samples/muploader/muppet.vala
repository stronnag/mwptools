
private static int baud = 115200;
private static string dev = null;
private static string mission = null;
private static bool save_eeprom = false;

const OptionEntry[] options = {
    { "baud", 'b', 0, OptionArg.INT, out baud, "baud rate", "115200"},
    { "device", 'd', 0, OptionArg.STRING, out dev, "device", "DEVICE_NAME"},
    { "mission", 'm', 0, OptionArg.STRING, out mission, "mission file", "example.mission"},
    { "save", 's', 0, OptionArg.NONE, out save_eeprom, "save to eeprom", "false"},
    {null}
};

class Muppet :Object
{

    private enum WPDL {
        IDLE=0,
        VALIDATE = (1<<0),
        REPLACE = (1<<1),
        POLL = (1<<2),
        REPLAY = (1<<3),
        SAVE_EEPROM = (1<<4),
        GETINFO = (1<<5),
        CALLBACK = (1<<6),
        CANCEL = (1<<7)
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

    private MWSerial msp;
    private uint tid;
    private MainLoop ml;
    public DevManager dmgr;
    private string estr="";
    private WPMGR wpmgr;
    private bool have_wp;
    public int result;
    private uint8 eolc = '\n';

    private const int SPEED_CONV = 100;
    private const int ALT_CONV = 100;
    private const int POS_CONV = 10000000;
    private const string[] failnames = {"WPNO","ACT","LAT","LON","ALT","P1","P2","P3","FLAG"};

    private MSP_WP[] mission_to_wps(Mission ms, out uint8 dg)
    {
        MSP_WP[] wps =  {};
        var n = 0;
        dg = 0;
        foreach(var m in ms.get_ways())
        {
            var w = MSP_WP();
            w.action = m.action;
            w.lat =(int32)Math.lround(m.lat * POS_CONV);
            w.lon = (int32)Math.lround(m.lon * POS_CONV);
            w.altitude = m.alt * ALT_CONV;
            if(w.action == MSP.Action.WAYPOINT)
                w.p1 = (int16)(m.param1*SPEED_CONV);
            else
                w.p1 = (int16)m.param1;
            w.p2 = (uint16)m.param2;
            w.p3 = (uint16)m.param2;
            w.flag = 0;

            switch(m.action)
            {
                case MSP.Action.POSHOLD_TIME:
                case MSP.Action.POSHOLD_UNLIM:
                case MSP.Action.LAND:
                    MWPLog.message("Downgrade %s to WP\n", m.action.to_string());
                    w.action =  MSP.Action.WAYPOINT;
                    w.p1 = 0;
                    w.p2 = w.p3 = 0;
                    dg++;
                    break;
                case MSP.Action.SET_POI:
                case MSP.Action.SET_HEAD:
                case MSP.Action.JUMP:
                    MWPLog.message("Remove WP %s\n", m.action.to_string());
                    continue;
                default:
                    break;
            }
            n++;
            w.wp_no = n;
            wps += w;
        }
        if(wps.length > 0)
            wps[wps.length-1].flag = 0xa5;
        return wps;
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

    private void upload_mission(Mission m, WPDL flag)
    {
        if(!msp.available)
            return;
        uint8 downgrade = 0;
        var wps = mission_to_wps(m, out downgrade);
        if(wps.length > 60)
        {
            MWPLog.message("Number of waypoints (%d) exceeds max (60)", wps.length);
            return;
        }
        if(downgrade != 0)
        {
            MWPLog.message("WARNING\nmwp downgraded %u multiwii specific waypoint(s) to compatible iNav equivalent(s). Once the upload has completed, please check you're happy with the result.\n\nNote that iNav will treat a final bare WAYPOINT as POSHOLD UNLIMITED\n", downgrade);
        }

        if(wps.length == 0)
        {
            {
                MSP_WP w0 = MSP_WP();
                w0.wp_no = 1;
                w0.action =  MSP.Action.RTH;
                w0.lat = 0;
                w0.lon = 0;
                w0.altitude = 25;
                w0.p1 = 0;
                w0.p2 = w0.p3 = 0;
                w0.flag = 0xa5;
                wps += w0;
            }
        }

        wpmgr = WPMGR();
        wpmgr.npts = (uint8)wps.length;
        wpmgr.wpidx = 0;
        wpmgr.wps = wps;
        wpmgr.wp_flag = flag;

        uint8 wtmp[64];
        var nb = serialise_wp(wpmgr.wps[wpmgr.wpidx], wtmp);
        msp.send_command(MSP.Cmds.SET_WP, wtmp, nb);
    }

    public void request_wp(uint8 wp)
    {
        uint8 buf[2];
        have_wp = false;
        buf[0] = wp;
        msp.send_command(MSP.Cmds.WP,buf,1);
    }

    public Mission? open_mission_file(string fn)
    {
        Mission m=null;
        bool is_j = fn.has_suffix(".json");
        m =  (is_j) ? JsonIO.read_json_file(fn) : XmlIO.read_xml_file (fn);
        return (m != null && m.npoints > 0) ? m : null;
    }

    public void init()
    {
        if(Posix.isatty(stderr.fileno()))
            eolc = '\r';
        result = 1;
        msp = new MWSerial();
        dmgr = new DevManager(DevMask.USB);
        var devs = dmgr.get_serial_devices();
        if(devs.length == 1)
            dev = devs[0];

        dmgr.device_added.connect((sdev) => {
                MWPLog.message("Discovered %s\n", sdev);
                if(!msp.available)
                    if(sdev == dev || dev == null)
                        if(msp.open(sdev, baud, out estr) == false)
                            MWPLog.message("Failed to open %s\n", estr);
                        else
                        {
                            if(tid != 0)
                            {
                                Source.remove(tid);
                                tid = 0;
                            }
                            tid = Timeout.add_seconds(1, () => {
                                    try_connect();
                                    return true;
                                });
                        }
            });

        dmgr.device_removed.connect((sdev) => {
                MWPLog.message("%s has been removed\n",sdev);
                msp.close();
            });

        msp.serial_event.connect((cmd, raw, len, flags, err) => {
                if(err == false)
                {
                    switch(cmd)
                    {
                        case MSP.Cmds.API_VERSION:
                        cancel_timers();
                        msp.send_command(MSP.Cmds.FC_VARIANT,null,0);
                        break;

                        case MSP.Cmds.DEBUGMSG:
                        MWPLog.message((string)raw);
                        break;

                        case MSP.Cmds.FC_VARIANT:
                        string fwid = (string)raw[0:4];
                        switch(fwid)
                        {
                            case "INAV":
                                var m =  open_mission_file(mission);
                                if(m != null)
                                    upload_mission(m, WPDL.VALIDATE);
                                break;
                            default:
                                MWPLog.message("Non- iNav FC detected\n");
                                ml.quit();
                                break;
                        }
                        break;

                        case MSP.Cmds.SET_WP:
                        if(wpmgr.wps.length > 0)
                        {
                            var no = wpmgr.wps[wpmgr.wpidx].wp_no;
                            request_wp(no);
                        }
                        break;

                        case MSP.Cmds.WP:
                        have_wp = true;
                        MSP_WP w = MSP_WP();
                        uint8* rp = raw;
                        w.wp_no = *rp++;
                        w.action = *rp++;
                        rp = deserialise_i32(rp, out w.lat);
                        rp = deserialise_i32(rp, out w.lon);
                        rp = deserialise_i32(rp, out w.altitude);
                        rp = deserialise_i16(rp, out w.p1);
                        rp = deserialise_u16(rp, out w.p2);
                        rp = deserialise_u16(rp, out w.p3);
                        w.flag = *rp;

                        if ((wpmgr.wp_flag & WPDL.VALIDATE) != 0  ||
                            (wpmgr.wp_flag & WPDL.SAVE_EEPROM) != 0)
                        {
                            WPFAIL fail = WPFAIL.OK;
                            MWPLog.message("WP:%3d%c", w.wp_no, eolc);
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
                            {
                                fail |= WPFAIL.FLAG;
                            }
                            if (fail != WPFAIL.OK)
                            {
                                StringBuilder sb = new StringBuilder();
                                for(var i = 0; i < failnames.length; i += 1)
                                {
                                    if ((fail & (1 <<i)) == (1 << i))
                                    {
                                        sb.append(failnames[i]);
                                        sb.append_c(' ');
                                    }
                                }
                                MWPLog.message("Validation for wp %d fails for %s\n", w.wp_no, sb.str);
                                ml.quit();
                            }
                            else if(w.flag != 0xa5)
                            {
                                wpmgr.wpidx++;
                                uint8 wtmp[64];
                                var nb = serialise_wp(wpmgr.wps[wpmgr.wpidx], wtmp);
                                msp.send_command(MSP.Cmds.SET_WP, wtmp, nb);
                            }
                            else
                            {
                                if(eolc == '\r')
                                    MWPLog.puts("\n");
                                MWPLog.message("Mission validated\n");
                                msp.send_command(MSP.Cmds.WP_GETINFO, null, 0);
                                result = 0;
                            }
                        }
                        break;

                        case MSP.Cmds.WP_GETINFO:
                        var wpi = MSP_WP_GETINFO();
                        uint8* rp = raw;
                        rp++;
                        wpi.max_wp = *rp++;
                        wpi.wps_valid = *rp++;
                        wpi.wp_count = *rp;
                        MWPLog.message("WP_GETINFO: %u/%u/%u\n",
                                       wpi.wp_count, wpi.max_wp, wpi.wps_valid);
                        stdout.printf("uploaded %u/%u WP, %svalid\n",
                                      wpi.wp_count, wpi.max_wp,
                                      (wpi.wps_valid == 0) ? "in" : "");

                        if(save_eeprom)
                        {
                            uint8 zb=42;
                            MWPLog.message("Saving mission\n");
                            msp.send_command(MSP.Cmds.WP_MISSION_SAVE, &zb, 1);
                        }
                        else
                            ml.quit();
                        break;

                        case MSP.Cmds.WP_MISSION_SAVE:
                        MWPLog.message("Confirmed mission save\n");
                        ml.quit();
                        break;

                        default:
                        break;
                    }
                }
                else
                {
                    MWPLog.message("Error on %s\n", cmd.to_string());
                    ml.quit();
                }
            });

        msp.serial_lost.connect(() => {
                MWPLog.message("Lost serial connection\n");
                ml.quit();
            });

        if(dev != null)
            if(msp.open(dev, baud, out estr) == false)
            {
                MWPLog.message("open failed %s\n", estr);
            }
            else
            {
                MWPLog.message("Opening %s\n", dev);
                tid = Idle.add(() => { try_connect(); return false; });
            }
    }

    public void run()
    {
        ml = new MainLoop();
        ml.run ();
        msp.close();
    }

    private void try_connect()
    {
        cancel_timers();
        if(msp.available)
        {
            msp.send_command(MSP.Cmds.API_VERSION,null,0);
        }
        tid = Timeout.add_seconds(2,() => {try_connect(); return false;});
    }

    private void cancel_timers()
    {
        if(tid != 0)
            Source.remove(tid);
        tid = 0;
    }
}

static int main (string[] args)
{
    int res = 1;
    try {
        var opt = new OptionContext(" - Mission UPloader");
        opt.set_help_enabled(true);
        opt.add_main_entries(options, null);
        opt.parse(ref args);
    }
    catch (OptionError e) {
        stderr.printf("Error: %s\n", e.message);
        stderr.printf("Run '%s --help' to see a full list of available "+
                      "options\n", args[0]);
        return 1;
    }

    if(mission == null)
        MWPLog.message("No mission offered -- bye\n");
    else
    {
        if(dev == null)
            MWPLog.message("No device given ... watching\n");

        var m = new Muppet();
        m.init();
        m.run();
        res = m.result;
    }
    return res;
}