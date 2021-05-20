private const double HLAT = 54.353974;
private const double HLON = -4.52369;
private const int ALT = 50;
private const int SPD = 15;
private const int MAXRANGE = 500;
private const int MAXRADAR = 4;

private static int baud = 115200;
private static string dev;
private static int maxrange;
private static int dspeed;
private static int  dalt;
private static int  maxradar;
private static string llstr = null;
private static string stale = null;
private static bool verbose;

const OptionEntry[] options = {
    { "baud", 'b', 0, OptionArg.INT, out baud, "baud rate", "115200"},
    { "device", 'd', 0, OptionArg.STRING, out dev, "device", "name"},
    { "centre", 'c', 0, OptionArg.STRING, out llstr, "Centre position", "lat,long"},
    { "range", 'r', 0, OptionArg.INT, out maxrange, "Max range", "metres"},
    { "speed", 's', 0, OptionArg.INT, out dspeed, "Initial speed", "metres/sec"},
    { "alt", 'a', 0, OptionArg.INT, out dalt, "Initial altitude","metres"},
    { "max-radar", 'm', 0, OptionArg.INT, out maxradar, "number of radar slots", "4"},
    { "stale", 0 , 0, OptionArg.STRING, out stale, "stale id:start:end", null},
    { "verbose", 'v', 0, OptionArg.NONE, out verbose, "verbose", null},
    {null}
};

static MainLoop ml;

public struct RadarPlot
{
    uint8 state;
    double latitude;
    double longitude;
    double altitude;
    double heading;
    double speed;
    uint8 lq;
    uint lasttick;
}

public class RadarSim : Object
{
    private RadarPlot []radar_plot;
    private uint8 id;
    private bool quit;
    private uint tid;
    private Rand rand;
    public MWSerial msp;
    private double hlat = HLAT;
    private double hlon = HLON;
    private int staleid = -1;
    private uint start_stale;
    private uint end_stale;
    private int rtime = 0;
    private bool init = false;
    private uint8 variant;

    public RadarSim()
    {
        if(stale != null)
        {
            var parts = stale.split(":");
            if(parts.length == 3)
            {
                var si = int.parse(parts[0]);
                if (si >= 0 && si < maxradar)
                {
                    int ss;
                    int se;

                    ss = int.parse(parts[1]);
                    se = int.parse(parts[2]);
                    if(ss > 0)
                    {
                        if(se > si)
                        {
                            staleid = si;
                            start_stale = ss*1000;
                            end_stale = se*1000;
                        }
                    }
                }
            }
        }

        if(maxradar > 255)
            maxradar = 255;

        radar_plot = new RadarPlot[maxradar];

        if(llstr != null)
        {
            string[] delims =  {" ",","};
            foreach (var delim in delims)
            {
                var parts = llstr.split(delim);
                if(parts.length == 2)
                {
                    hlat = DStr.strtod(parts[0],null);
                    hlon = DStr.strtod(parts[1],null);
                    break;
                }
            }
        }
    }

    public void start_sim()
    {
        open_serial();
    }

    private void setup_radar()
    {
        rand  = new Rand();
        id = 0;
        quit = false;
        double  angle = 360.0 / maxradar;
        for (var i = 0; i < maxradar; i++)
        {
            radar_plot[i].state = 0;
            radar_plot[i].latitude = hlat;
            radar_plot[i].longitude = hlon;
            radar_plot[i].altitude = dalt;
            radar_plot[i].speed = dspeed;
            var aoffset = 45 + i * angle % 360;
            radar_plot[i].heading = aoffset;
            radar_plot[i].lq = 0;
        }
    }

    public void run_radar_msgs()
    {
        var to = 500 / maxradar;
        if (to < 100)
            to = 100; // LoRa xmit c. 70ms + buffer

        tid = Timeout.add(to, () => {
                rtime += to;

                double lat, lon;
                double spd = radar_plot[id].speed + rand.double_range(-2.0, 2.0);
                if (spd < dspeed/2)
                    spd = dspeed/2;
                if (spd > dspeed * 2)
                    spd = dspeed *2;

                double cse = radar_plot[id].heading + rand.double_range(-5, 5);
                if(cse < 0)
                    cse = cse + 360;
                cse = cse % 360;

                var delta = (spd * 0.5)/1852.0; // nm

                Geo.posit (radar_plot[id].latitude,
                           radar_plot[id].longitude,
                           cse, delta, out lat, out lon, true);

                radar_plot[id].state = 1;
                radar_plot[id].latitude = lat;
                radar_plot[id].longitude = lon;
                radar_plot[id].altitude += rand.double_range(-0.5, 0.5);
                radar_plot[id].speed = spd;
                radar_plot[id].heading = cse;
                var tmp = radar_plot[id].lq + 1;
                if (tmp > 4)
                    tmp = 0;
                radar_plot[id].lq = tmp;

                if(!(staleid != -1 && id == (uint8)staleid &&
                    rtime > start_stale && rtime < end_stale))
                {
                    transmit_radar(radar_plot[id]);
                }

                double dist;
                Geo.csedist(lat, lon,
                            hlat, hlon,
                            out dist, out cse);

                if(dist*1852.0 > maxrange)
                    radar_plot[id].heading = cse;

                if (id == 0 && variant == 'I')
                    msp.send_command(MSP.Cmds.ANALOG, null, 0);

                id += 1;
                if (id == maxradar)
                {
                    id = 0;
                    if (variant == 'I')
                        msp.send_command(MSP.Cmds.RAW_GPS, null, 0);
                }
                return Source.CONTINUE;
            });
    }

    public void handle_radar(MSP.Cmds cmd, uint8[] raw, uint len,
                              uint8 xflags, bool errs)
    {
        if (errs)
            stderr.printf("Error!!!!!!!!! serial\n");

        switch(cmd)
        {
            case MSP.Cmds.NAME:
                init = false;
                raw[len] = 0;
                stderr.printf("Got name %s (%u)\n", (string)raw[0:len], len);
                msp.send_command(MSP.Cmds.FC_VARIANT, null, 0);
                break;
            case MSP.Cmds.FC_VARIANT:
                raw[len] = 0;
                variant = raw[0];
                stderr.printf("Got Variant %s (%u)\n", (string)raw[0:len], len);
                msp.send_command(MSP.Cmds.FC_VERSION, null, 0);
                break;
            case MSP.Cmds.FC_VERSION:
                stderr.printf("Got Version %d.%d.%d (%u)\n", raw[0], raw[1], raw[2], len);
                if (variant == 'I')
                    msp.send_command(MSP.Cmds.BOXIDS, null, 0);
                else // for GCS we do this *once* so we can use the CGS's viewport
                    msp.send_command(MSP.Cmds.RAW_GPS, null, 0);
                break;
            case MSP.Cmds.STATUS:
                stderr.printf("Got Status (%u)\n", len);
                msp.send_command(MSP.Cmds.BOXIDS, null, 0);
                break;
            case MSP.Cmds.BOXIDS:
                stderr.printf("Got BOXIDS (%u)\n", len);
                msp.send_command(MSP.Cmds.RAW_GPS, null, 0);
                break;

            case MSP.Cmds.RAW_GPS:
                int ilat, ilon;
                deserialise_i32(&raw[2], out ilat);
                deserialise_i32(&raw[6], out ilon);
                hlat = ((double)ilat) / 1e7;
                hlon = ((double)ilon) / 1e7;
                stderr.printf("GPS %.6f %.6f, %u sats, %ud fix (%u)\n",
                              hlat, hlon, raw[1], raw[0], len);
                if (init == false) {
                    stderr.printf("Start sim tracks\n");
                    start_sim_msgs();
                }
                break;
            case MSP.Cmds.ANALOG:
                stderr.printf("Got ANALOG (%u)\n", len);
                break;
            default:
                stderr.printf("Unknown %s (%u)\n", cmd.to_string(), len);
                break;
        }
    }

    private void start_sim_msgs()
    {
        setup_radar();
        run_radar_msgs();
        init = true;
    }

    private void open_serial()
    {
        msp = new MWSerial();
        msp.set_mode(MWSerial.Mode.NORMAL);
        stderr.printf("Set up serial %s\n", dev);
        bool res;
        string estr;
        if((res = msp.open(dev, baud, out estr)) == true)
        {
            msp.serial_lost.connect(() => {
                    stderr.printf("Lost connection\n");
                    if(tid > 0) {
                        Source.remove(tid);
                        tid = 0;
                    }
                    Timeout.add_seconds(10, () => {
                            open_serial();
                            return Source.REMOVE;
                        });
                });
            msp.serial_event.connect((s,cmd,raw,len,xflags,errs) => {
                    handle_radar(cmd,raw,len,xflags,errs);
                });
            msp.send_command(MSP.Cmds.NAME, null, 0);
        } else {
            MWPLog.message("open failed serial %s %s\n", dev, estr);
            ml.quit();
        }
    }

    private void transmit_radar(RadarPlot r)
    {
        uint8 buf[128];
        uint8 *p = buf;
        *p++ = id;
        *p++ = r.state;
        p = serialise_i32(p, (int32)Math.lround(r.latitude * 10000000));
        p = serialise_i32(p, (int32)Math.lround(r.longitude * 10000000));
        p = serialise_i32(p, (int32)Math.lround(r.altitude * 100));
        p = serialise_u16(p, (uint16)r.heading);
        p = serialise_u16(p, (uint16)(r.speed*100));
        *p++ = r.lq;
        msp.send_command(MSP.Cmds.COMMON_SET_RADAR_POS, buf, (size_t)(p - &buf[0]));
    }
}

int main (string[] args)
{
    dalt = ALT;
    dspeed = SPD;
    maxrange = MAXRANGE;
    maxradar = MAXRADAR;

    stderr.puts("inav radar  sim .. \n");

    string []devs = {"/dev/ttyUSB0","/dev/ttyACM0"};

    foreach(var d in devs)
    {
        if(Posix.access(d,(Posix.R_OK|Posix.W_OK)) == 0)
        {
            dev = d;
            break;
        }
    }

    try {
        var opt = new OptionContext(" - iNav radar simulation tool");
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

    if (args.length > 2)
        baud = int.parse(args[2]);

    if (args.length > 1)
        dev = args[1];

    if(dev == null)
    {
        stdout.puts("No device found\n");
        return 0;
    }
    ml = new MainLoop();
    stderr.printf("Start sim .. \n");
    var r = new RadarSim();
    r.start_sim();
    ml.run ();
    return 0;
}
