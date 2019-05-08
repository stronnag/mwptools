private const double HLAT = 54.353974;
private const double HLON = -4.52369;
private const int ALT = 50;
private const int SPD = 15;
private const int MAXRANGE = 500;

private static int baud = 115200;
private static string dev;
private static int maxrange;
private static int dspeed;
private static int  dalt;
private static string llstr = null;

const OptionEntry[] options = {
    { "baud", 'b', 0, OptionArg.INT, out baud, "baud rate", "115200"},
    { "device", 'd', 0, OptionArg.STRING, out dev, "device", "name"},
    { "centre", 'c', 0, OptionArg.STRING, out llstr, "Centre position", "lat,long"},
    { "range", 'r', 0, OptionArg.INT, out maxrange, "Max range", "metres"},
    { "speed", 's', 0, OptionArg.INT, out dspeed, "Initial speed", "metres/sec"},
    { "alt", 'a', 0, OptionArg.INT, out dalt, "Initial altitude","metres"},
    {null}
};

static MainLoop ml;

public struct RadarPlot
{
    uint8 state;
    double latitude;
    double longitude;
    double altitude;
    uint16 heading;
    double speed;
    uint8 lq;
    uint lasttick;
}

public class RadarSim : Object
{
    private const uint8 MAXRADAR = 4;

    private RadarPlot radar_plot[4];
    private uint8 id;
    private bool quit;
    private uint tid;
    private Rand rand;
    private MWSerial msp;
    private double hlat = HLAT;
    private double hlon = HLON;

    public RadarSim()
    {
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

        rand  = new Rand();
        id = 0;
        quit = false;
        for (var i = 0; i < MAXRADAR; i++)
        {
            radar_plot[i].state = 0;
            radar_plot[i].latitude = hlat;
            radar_plot[i].longitude = hlon;
            radar_plot[i].altitude = dalt;
            radar_plot[i].speed = dspeed;
            radar_plot[i].heading = 45 + i * (360 / MAXRADAR);
            radar_plot[i].lq = 0;
        }
        open_serial();
    }

    public void run()
    {
        tid = Timeout.add(125, () => {
                double lat, lon;
                double spd = radar_plot[id].speed + rand.double_range(-2.0, 2.0);
                if (spd < dspeed/2)
                    spd = dspeed/2;
                if (spd > dspeed * 2)
                    spd = dspeed *2;

                double cse =  radar_plot[id].heading + rand.int_range(-5, 5);
                if (cse > 360)
                    cse = 45 + id * (360 / MAXRADAR);

                var delta = (spd * 0.5)/1852.0; // nm

                Geo.posit (radar_plot[id].latitude,
                           radar_plot[id].longitude,
                           cse, delta, out lat, out lon, true);

                radar_plot[id].state = 1;
                radar_plot[id].latitude = lat;
                radar_plot[id].longitude = lon;
                radar_plot[id].altitude += rand.double_range(-0.5, 0.5);
                radar_plot[id].speed = spd;
                radar_plot[id].heading = (uint16)cse;
                radar_plot[id].lq += 1;

                transmit_radar(radar_plot[id]);

                double dist;
                Geo.csedist(lat, lon,
                            hlat, hlon,
                            out dist, out cse);
                if(dist*1852.0 > maxrange)
                    radar_plot[id].heading = (uint16)cse;

                id += 1;
                if (id == MAXRADAR)
                    id = 0;
                return Source.CONTINUE;
            });
    }

    private void open_serial()
    {
        bool res;
        string estr;
        msp = new MWSerial();
        msp.set_mode(MWSerial.Mode.SIM);

        if((res = msp.open(dev, baud, out estr)) == true)
        {
            msp.serial_lost.connect(() => {
                    if(tid > 0)
                        Source.remove(tid);
                    msp.close();
                    ml.quit();
                });
        }
        else
        {
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
        msp.send_command(MSP.Cmds.RADAR_POS, buf, (size_t)(p - &buf[0]));
    }
}


public static int main (string[] args)
{
    dalt = ALT;
    dspeed = SPD;
    maxrange = MAXRANGE;

    ml = new MainLoop();

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

    Idle.add(() => {
            var rsim = new RadarSim();
            rsim.run();
            return Source.REMOVE;
        });

    ml.run ();
    return 0;
}
