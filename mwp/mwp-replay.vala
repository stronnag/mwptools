public struct REPLAY_rec
{
    MSP.Cmds cmd;
    uint len;
    uint8 raw[64];
}

public class ReplayThread : GLib.Object
{
    public bool playon  {get; set;}

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

    private void send_rec(int fd, MSP.Cmds cmd, uint len, uint8 []buf)
    {
        var rl  = REPLAY_rec();
        rl.cmd = cmd;
        for(var i = 0; i < len; i++)
            rl.raw[i] = buf[i];
        rl.len = len;
        Posix.write(fd,&rl,rl.len + sizeof(uint) + sizeof(MSP.Cmds));
    }

    public ReplayThread()
    {
    }

    public Thread<int> run (int fd, string relog, bool delay=true)
    {
        playon = true;
        var thr = new Thread<int> ("relog", () => {
                var file = File.new_for_path (relog);
                if (!file.query_exists ()) {
                    MSPLog.message ("File '%s' doesn't exist.\n", file.get_path ());
                }
                else
                {
                    try
                    {
                        double lt = 0;
                        var dis = FileStream.open(relog,"r");
                        string line=null;
                        bool armed = false;
                        uint8 buf[64];
                        var parser = new Json.Parser ();
                        bool have_data = false;

                        while (playon && (line = dis.read_line ()) != null) {
                            parser.load_from_data (line);
                            var obj = parser.get_root ().get_object ();
                            var utime = obj.get_double_member ("utime");
                            if(lt != 0)
                            {
                                ulong ms;
                                if (delay  && have_data)
                                {
                                    var dly = (utime - lt);
                                    ms = (ulong)(dly * 1000 * 1000);
                                }
                                else
                                    ms = 2*1000;
                                Thread.usleep(ms);
                            }

                            var typ = obj.get_string_member("type");
                            have_data = (typ != "init");
                            switch(typ)
                            {
                                case "init":
                                    var mrtype = obj.get_int_member ("mrtype");
                                    var mwvers = obj.get_int_member ("mwvers");
                                    var cap = obj.get_int_member ("capability");
                                    if(mwvers == 0)
                                        mwvers = 42;

                                    buf[0] = (uint8)mwvers;
                                    buf[1] = (uint8)mrtype;
                                    buf[2] = 42;
                                    serialise_u32(buf+3, (uint32)cap);

                                    send_rec(fd,MSP.Cmds.IDENT, 7, buf);

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
                                    var nb = serialise_misc(a, buf);
                                    send_rec(fd,MSP.Cmds.MISC, (uint)nb, buf);
                                    break;
                                case "armed":
                                    var a = MSP_STATUS();
                                    armed = obj.get_boolean_member("armed");
                                    a.flag = (armed)  ? 1 : 0;
                                    if(obj.has_member("flags"))
                                    {
                                        var flag =  obj.get_int_member("flags");
                                        a.flag = (uint32)flag;
                                    }
                                    else
                                        a.flag = (((armed)  ? 1 : 0) | 4);


                                    if(obj.has_member("sensors"))
                                    {
                                        var s =  obj.get_int_member("sensors");
                                        a.sensor = (uint16)s;
                                    }
                                    else
                                        a.sensor=(MSP.Sensors.ACC+MSP.Sensors.GPS);
                                    a.i2c_errors_count = 0;
                                    a.cycle_time=0;
                                    var nb = serialise_status(a, buf);
                                    send_rec(fd,MSP.Cmds.STATUS, (uint)nb, buf);
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
                                    serialise_analogue(a, buf);
                                    send_rec(fd,MSP.Cmds.ANALOG, MSize.MSP_ANALOG, buf);
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
                                    serialise_atti(a, buf);
                                    send_rec (fd,MSP.Cmds.ATTITUDE, MSize.MSP_ATTITUDE,buf);
                                    break;
                                case "altitude":
                                        //{"type":"altitude","utime":1404717912,"estalt":4.4199999999999999,"vario":20.399999999999999}
                                    var a = MSP_ALTITUDE();
                                    a.estalt = (int32)(Math.lround(obj.get_double_member("estalt")*100));
                                    a.vario = (int16)(Math.lround(obj.get_double_member("vario")* 10));
                                    var nb = serialise_alt(a, buf);
                                    send_rec(fd,MSP.Cmds.ALTITUDE, (uint)nb, buf);
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
                                    serialise_nav_status(a, buf);
                                    send_rec(fd,MSP.Cmds.NAV_STATUS, MSize.MSP_NAV_STATUS,buf);
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
                                    serialise_raw_gps(a, buf);
                                    send_rec(fd,MSP.Cmds.RAW_GPS, MSize.MSP_RAW_GPS,buf);
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
                                    serialise_comp_gps(a, buf);
                                    send_rec(fd,MSP.Cmds.COMP_GPS, MSize.MSP_COMP_GPS,buf);
                                    break;
                                case "radio":
                                        //"type":"radio","utime":1404717910,"rxerrors":0,"fixed_errors":0,"localrssi":139,"remrssi":138,"txbuf":100,"noise":93,"remnoise":15}
                                    var a = MSP_RADIO();
                                    a.localrssi = (uint8)(obj.get_int_member("localrssi"));
                                    a.remrssi = (uint8)(obj.get_int_member("remrssi"));
                                    a.noise = (uint8)(obj.get_int_member("noise"));
                                    a.remnoise = (uint8)(obj.get_int_member("remnoise"));
                                    a.txbuf = (uint8)(obj.get_int_member("txbuf"));

                                    a.rxerrors = (uint16)(obj.get_int_member("rxerrors"));
                                    a.fixed_errors = (uint16)(obj.get_int_member("fixed_errors"));
                                    serialise_radio(a, buf);
                                    send_rec(fd,MSP.Cmds.RADIO, MSize.MSP_RADIO,buf);
                                    break;
                                case "ltm_raw_sframe":
                                    var s = LTM_SFRAME();
                                    s.vbat = (int16)(obj.get_int_member("vbat"));
                                    s.vcurr = (int16)(obj.get_int_member("vcurr"));
                                    s.rssi = (uint8)(obj.get_int_member("rssi"));
                                    s.airspeed = (uint8)(obj.get_int_member("airspeed"));
                                    s.flags = (uint8)(obj.get_int_member("flags"));

                                    serialise_sf(s,buf);
                                    send_rec(fd,MSP.Cmds.TS_FRAME, MSize.LTM_SFRAME,buf);
                                    break;

                                case "wp_poll":
                                    var w = MSP_WP();
                                    w.wp_no = (uint8)(obj.get_int_member("wp_no"));
                                    var lat = obj.get_double_member("wp_lat");
                                    var lon = obj.get_double_member("wp_lon");
                                    w.lat = (int32)(lat*10000000);
                                    w.lon = (int32)(lon*10000000);
                                    w.altitude = (uint32)(obj.get_int_member("wp_alt"));
                                    serialise_wp(w,buf);
                                    send_rec(fd,MSP.Cmds.INFO_WP, MSize.MSP_WP,buf);
                                    break;

                                default:
                                    break;
                            }
                            lt = utime;
                        }
                    } catch (Error e) {
                        error ("%s", e.message);
                    }
                }
                Posix.write(fd,"",0);
                Posix.close(fd);
                return 0;
            });
        return thr;
    }
}
