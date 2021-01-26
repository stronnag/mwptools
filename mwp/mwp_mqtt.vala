using Mosquitto;

const int DEFPORT = 1883;
const int KEEPALIVE = 60;

private static MwpMQTT mqtt;
private static Mosquitto.Client client;

public class MwpMQTT : Object {

    private MSP_WP wps[60];
    private LTM_GFRAME gframe;
    private LTM_OFRAME oframe;
    private LTM_AFRAME aframe;
    private LTM_XFRAME xframe;
    private LTM_SFRAME sframe;
    private MSP_NAV_STATUS nframe;
    private uint16 durat = 0;
    private uint8 xcount = 0;
    private uint8 wpcount = 0;
    private uint8 wpvalid = 0;
    private bool have_orig = false;
    public bool active = false;
    public bool available = false;
    private Thread<int> thr;
    private uint8 send_once = 0;

        //private bool wppub ;

    public void init () {
        gframe = LTM_GFRAME();
        oframe = LTM_OFRAME();
        aframe = LTM_AFRAME();
        xframe = LTM_XFRAME();
        sframe = LTM_SFRAME();
        nframe = MSP_NAV_STATUS();
    }

    public signal void mqtt_mission(MSP_WP[] wps, int nwp);
    public signal void mqtt_frame(MSP.Cmds cmd, uint8[] bx, ulong len);
    public signal void mqtt_craft_name(string name);

    public void handle_mqtt(string payload)
    {
        if (payload.has_prefix("wpno:")) {
            parse_wp(payload);
        } else {
            var parts = payload.split(",");
            uint8 gattr = 0;
            uint8 oattr = 0;
            uint8 nattr = 0;
            uint8 sattr = 0;
            uint8 xattr = 0;
            uint8 aattr = 0;
            int ontime = 0;

            double range = 0.0;
            double bearing = 0.0;

            foreach (var p in parts)
            {
                var attrs = p.split(":");
                uint8 tmp;
                switch (attrs[0])
                {
                    case "hds": // home distance
                        range = double.parse(attrs[1]);
                        break;
                    case "hdr": // home direction
                        bearing = double.parse(attrs[1]);
                        break;
// GFRAME data --------------------------------------------------------------
                    case "gla":
                        gframe.lat = (int)(double.parse(attrs[1]) * 1.0e7);
                        gattr |= 1;
                        break;
                    case "glo":
                        gattr |= 2;
                        gframe.lon = (int)(double.parse(attrs[1]) * 1.0e7);
                        break;
                    case "alt":
                        gframe.alt = int.parse(attrs[1]);
                        break;
                    case "gsc":
                        tmp = (gframe.sats & 3);
                        gframe.sats = (uint8)(int.parse(attrs[1])) << 2 | tmp;
                        break;
                    case "3df":
                        tmp = (gframe.sats & ~3);
                        gframe.sats = tmp | ((((uint8)(int.parse(attrs[1]))) != 0) ? 3 : 0);
                        break;
                    case "gsp":
                        gframe.speed = (uint8)(int.parse(attrs[1])/100);
                        break;

// AFRAME data --------------------------------------------------------------
                    case "ran":
                        aframe.roll = (int16)(int.parse(attrs[1]));
                        break;
                    case "pan":
                        aframe.pitch = (int16)(int.parse(attrs[1]));
                        break;
                    case "hea":
                        aframe.heading = (int16)(int.parse(attrs[1]));
                        aattr = 1;
                        break;

// SFRAME data --------------------------------------------------------------
                    case "bpv": // mv
                        sframe.vbat = (uint16)(double.parse(attrs[1])*1000);
                        sattr = 1;
                        break;
                    case "cad": // mah
                        sframe.vcurr = (uint16)(int.parse(attrs[1]));
                        break;
                    case "rsi": // scale to 255
                        tmp = (uint8)(int.parse(attrs[1]));
                        if (tmp > 100)
                            tmp = 100;
                        sframe.rssi = (uint8)(int)((255*tmp)/100);
                        break;
                    case "fs":
                        tmp = sframe.flags & 0xfd;
                        sframe.flags = tmp | ((uint8)(int.parse(attrs[1])) << 1);
                        break;
                    case "arm":
                        var armed = (uint8)(int.parse(attrs[1]));
                        tmp = sframe.flags & 0xfe;
                        sframe.flags = tmp | armed;
                        if (armed == 0)
                        {
                            send_once = 0;
                            durat = 0;
                        }
                        break;
                    case "ftm":
                        tmp =  sframe.flags & 3;
                        var flg = parse_flight_mode(attrs[1]);
                        sframe.flags = tmp | (flg << 2);
                        break;
// OFRAME data --------------------------------------------------------------
                    case "hla":
                        oattr |= 1;
                        oframe.lat = (int)(double.parse(attrs[1]) * 1.0e7);
                        oframe.osd = oframe.fix = 1;
                        oframe.alt = 0;
                        break;
                    case "hlo":
                        oattr |= 2;
                        oframe.lon = (int)(double.parse(attrs[1]) * 1.0e7);
                        break;

// XFRAME data --------------------------------------------------------------
                    case "hdp":
                        xframe.hdop = (uint16)(int.parse(attrs[1]));
                        xframe.ltm_x_count = xcount+1;
                        xframe.disarm_reason = 0;
                        xframe.spare = 0;
                        xattr = 1;
                        break;
                    case "hwh":
                        xframe.sensorok = (int.parse(attrs[1]) == 1) ? 0 : 1;
                        break;
// NFRAME data --------------------------------------------------------------
                    case "nvs": // navstate
                        nframe.nav_mode =  (uint8)(int.parse(attrs[1]));
                        break;
                    case "cwn":
                        nframe.wp_number =  (uint8)(int.parse(attrs[1]));
                        if (nframe.wp_number > 0 && nframe.nav_mode != 0) {
                            uint8 gpsmode = 0;
                            switch (sframe.flags >> 2)
                            {
                                case 10:
                                    gpsmode = 3;
                                    break;
                                case 13:
                                    gpsmode = 2;
                                    break;
                                case 8,9:
                                    gpsmode = 1;
                                    break;
                                default :
                                    gpsmode = 0;
                                    break;
                            }
                            if (gpsmode != 0) {
                                nframe.gps_mode = gpsmode;
                                nattr = 1;
                            }
                        }
                        break;
// Misc ----------------------------------------------------------------------
                    case "wpv":
                        wpvalid = (uint8)int.parse(attrs[1]);
                        if (wpvalid == 1 && wpcount > 0) {
                            if (wps[wpcount -1].flag == 0xa5) {
                                if ((send_once & 2) == 0) {
                                    mqtt_mission(wps, (int)wpcount);
                                    send_once |= 2;
                                }
                            }
                        }
                        break;
                    case "wpc":
                        wpcount = (uint8)int.parse(attrs[1]);
                        break;
                    case "cs":
                        if ((send_once & 1) == 0) {
                            Idle.add(() => { mqtt_craft_name(attrs[1]); return false; });
                            send_once |= 1;
                        }
                        break;
                    case "ont":
                        ontime = int.parse(attrs[1]);
                        break;
                            // QFRAME , mwp extension, duration in seconds (unit16)
                    case "flt":
                        durat = (uint16)(int.parse(attrs[1]));
                        if (durat != 0 && ontime != 0)
                            serialise_qframe(durat);
                        break;
                    default:
                        break;
                }
            }
            if (gattr == 3)
            {
                if (have_orig == false && range != 0.0 && bearing != 0.0) {
                    double la = gframe.lat / 1.0e7;
                    double lo = gframe.lon / 1.0e7;
                    double hla, hlo;
                    Geo.posit (la, lo, bearing, range / 1852.0, out hla, out hlo, true);
                    oframe.lat = (int32)(hla*1e7);
                    oframe.lon = (int32)(hlo*1e7);
                    oframe.fix = 1;
                    have_orig = true;
                    serialise_oframe();
                }
                serialise_gframe();
            }

            if (nattr == 1)
                serialise_nframe();
            if (sattr == 1)
                serialise_sframe();
            if (xattr == 1)
                serialise_xframe();
            if (oattr == 3)
            {
                have_orig = true;
                serialise_oframe();
            }
            if (aattr == 1)
                serialise_aframe();
        }
    }

    private void serialise_qframe(uint16 v)
    {
        uint8 raw[2];
        raw[0] = (uint8)(v & 0xff);
        raw[1] = ((v >> 8) & 0xff);
        Idle.add(() => { mqtt_frame(MSP.Cmds.Tq_FRAME, raw, 2); return false; });
    }

    private void serialise_oframe()
    {
        uint8 raw[MSize.LTM_OFRAME];
        uint8 *p;
        p = serialise_i32(raw, oframe.lat);
        p = serialise_i32(p, oframe.lon);
        p = serialise_i32(p, oframe.alt);
        *p++ = 1;
        *p++ = 1;
        Idle.add(() => { mqtt_frame(MSP.Cmds.TO_FRAME, raw, (p - &raw[0])); return false; });
    }

    private void serialise_gframe()
    {
        uint8 raw[MSize.LTM_GFRAME];
        uint8 *p;
        p = serialise_i32(raw, gframe.lat);
        p = serialise_i32(p, gframe.lon);
        *p++ = gframe.speed;
        p = serialise_i32(p, gframe.alt);
        *p++ = gframe.sats;
        Idle.add(() => { mqtt_frame(MSP.Cmds.TG_FRAME, raw, (p - &raw[0])); return false; });
    }

    private void serialise_aframe()
    {
        uint8 raw[MSize.LTM_AFRAME];
        uint8 *p;
        p = serialise_u16(raw, aframe.pitch);
        p = serialise_u16(p, aframe.roll);
        p = serialise_u16(p, aframe.heading);
        Idle.add(() => { mqtt_frame(MSP.Cmds.TA_FRAME, raw, (p - &raw[0])); return false; });
    }

    private void serialise_sframe()
    {
        uint8 raw[MSize.LTM_SFRAME];
        uint8 *p;
        p = serialise_u16(raw, sframe.vbat);
        p = serialise_u16(p, sframe.vcurr);
        *p++ = sframe.rssi;
        *p++ = sframe.airspeed;
        *p++ = sframe.flags;
        Idle.add(() => { mqtt_frame(MSP.Cmds.TS_FRAME, raw, (p - &raw[0])); return false; });
    }

    private void serialise_xframe()
    {
        uint8 raw[MSize.LTM_XFRAME];
        uint8 *p;
        p = serialise_u16(raw, xframe.hdop);
        *p++ = 0;
        *p++ = xframe.ltm_x_count;
        *p++ = 0;
        *p++ = 0;
        Idle.add(() => { mqtt_frame(MSP.Cmds.TX_FRAME, raw, (p - &raw[0])); return false; });
    }

    private void serialise_nframe()
    {
        uint8 raw[MSize.LTM_NFRAME];
        uint8 *p = raw;
        *p++ = nframe.gps_mode;
        *p++ = nframe.nav_mode;
        *p++ = nframe.action;
        *p++ = nframe.wp_number;
        *p++ = nframe.nav_error;
        p = serialise_u16(p, 0);
        Idle.add(() => { mqtt_frame(TN_FRAME, raw, (p - &raw[0])); return false; });
    }

    private void parse_wp(string payload)
    {
        int wpno = 0;
        int wpidx = 0;
        MSP_WP wp = MSP_WP();
        var parts = payload.split(",");
        foreach (var p in parts)
        {
            var attrs = p.split(":");
            switch (attrs[0])
            {
                case "wpno":
                    wpno = int.parse(attrs[1]);
                    if (wpno < 1 || wpno > 60)
                        return;
                    wpidx = wpno - 1;
                    wp.wp_no = (uint8)wpno;
                    break;
                case "la":
                    wp.lat = (int)(double.parse(attrs[1]) * 1.0e7);
                    break;
                case "lo":
                    wp.lon =(int)(double.parse(attrs[1]) * 1.0e7);
                    break;
                case "al":
                    wp.altitude = int.parse(attrs[1]);
                    break;
                case "ac":
                    wp.action = (uint8)int.parse(attrs[1]);
                    break;
                case "p1":
                    wp.p1 = (int16)int.parse(attrs[1]);
                    break;
                case "p2":
                    wp.p2 = (uint16)int.parse(attrs[1]);
                    break;
                case "p3":
                    wp.p3 = (uint16)int.parse(attrs[1]);
                    break;
                case "f":
                    wp.flag = (uint8)int.parse(attrs[1]);
                    break;
            }
        }
        wps[wpidx]= wp;
    }

    private uint8 parse_flight_mode(string flm)
    {
        var ltmmode = 0;
        switch (flm)
        {
            case "MANU":
                ltmmode = 0;
                break;

            case "ANGL":
                ltmmode = 2;
                break;

            case "HOR":
                ltmmode = 3;
                break;

            case "ACRO":
                ltmmode = 1;
                break;

            case "A H":
                ltmmode = 8;
                break;

            case "P H":
                ltmmode = 9;
                break;

            case "WP":
                ltmmode = 10;
                break;

            case "RTH":
                ltmmode = 13;
                break;

            case "3CRS":
            case "CRS":
                ltmmode = 18;
                break;

            case "LNCH":
                ltmmode = 20;
                break;

            default:
                ltmmode = 1;
                break;
        }
        return ltmmode;
    }

    public bool mosquitto_setup(string s)
    {
        string broker = null;
        string topic = null;
        int port = -1;
        string user = null;
        string passwd = null;
        string query = null;
        string cafile = null;
#if USE_URIPARSE
        try
        {
            var u = Uri.parse(s, UriFlags.HAS_PASSWORD);
            broker = u.get_host();
            port = u.get_port();
            topic = u.get_path();
            user = u.get_user();
            passwd = u.get_password();
            query = u.get_query();
        } catch {
            return false;
        }

        if (query != null) {
            var parts = query.split("=");
            if (parts.length == 2 && parts[0] == "cafile") {
                cafile = parts[1];
            }
        }
#else
    try
    {
        MatchInfo mi;
        var regex = new Regex ("""^([a-z][a-z0-9+.-]+):(\/\/([^@]+@)?([a-z0-9.\-_~]+)(:\d+)?)?((?:[a-z0-9-._~]|%[a-f0-9]|[!$&'()*+,;=:@])+(?:\/(?:[a-z0-9-._~]|%[a-f0-9]|[!$&'()*+,;=:@])*)*|(?:\/(?:[a-z0-9-._~]|%[a-f0-9]|[!$&'()*+,;=:@])+)*)?(\?(?:[a-z0-9-._~]|%[a-f0-9]|[!$&'()*+,;=:@]|[/?])+)?(\#(?:[a-z0-9-._~]|%[a-f0-9]|[!$&'()*+,;=:@]|[/?])+)?$""");
        if(regex.match(s, 0, out mi))
        {
            if (mi.get_match_count() >= 7) {
                broker = mi.fetch(4);
                var aport = mi.fetch(5);
                topic = mi.fetch(6);
                var up = mi.fetch(3);
                if (up.length > 2) {
                    var fup = up.substring(0, up.length-1);
                    var cred = fup.split(":");
                    user = cred[0];
                    if (cred.length  > 1 )
                        passwd = cred[1];
                }
                if (aport.length > 1) {
                    port = int.parse(aport.substring(1));
                }
                if (mi.get_match_count() == 8) {
                    query = mi.fetch(7);
                    var parts = query.substring(1).split("&");
                    foreach (var p in parts) {
                        var q = p.split("=");
                        if (q[0] == "cafile") {
                            cafile = q[1];
                            break;
                        }
                    }
                }
            }
        }
    } catch(GLib.Error e) {
        stderr.printf("regex err: %s", e.message);
    }
#endif
        if (port <= 0)
            port = 1883;

        if (topic.length > 0)
            topic = topic.slice(1,topic.length);

        Mosquitto.init ();
        client = new Mosquitto.Client (null, true, null);
        if (user != null)
            client.username_pw_set(user, passwd);

        if(cafile != null) {
            client.tls_set(cafile, null, null, null, ()=>{return 0;});
        }

        if (client.connect (broker, port, KEEPALIVE) != 0) {
            stderr.printf ("Unable to connect.\n");
            return false;
        }
        client.message_callback_set ((client, userdata, message) => {
                if (message.payloadlen != 0) {
                    mqtt.handle_mqtt(message.payload);
                }
            });

        if (client.subscribe(null, topic, 0) == 0) {
            thr = new Thread<int>("mqtt", () => {
                    for(active = true ; active;) {
                        active = (client.loop(-1,1) == 0);
                    }
                    return 0;
                });
        } else
            return false;
        available = true;
        return true;
    }

    public void mdisconnect()
    {
        available = false;
        client.disconnect ();
        thr.join();
        Mosquitto.cleanup ();
    }
}
MwpMQTT newMwpMQTT()
{
    mqtt = new MwpMQTT();
    mqtt.init();
    return mqtt;
}
