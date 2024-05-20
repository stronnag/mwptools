private const double HLAT = 54.353974;
private const double HLON = -4.52369;
private const int MAXRADAR = 256;

private static int baud = 115200;
private static string dev;
private static int  maxradar;
private static string llstr = null;

const OptionEntry[] options = {
    { "baud", 'b', 0, OptionArg.INT, out baud, "baud rate", "115200"},
    { "device", 'd', 0, OptionArg.STRING, out dev, "device", "name"},
    { "centre", 'c', 0, OptionArg.STRING, out llstr, "Centre position", "lat,long"},
    { "max-radar", 'm', 0, OptionArg.INT, out maxradar, "number of radar slots", "256"},
    {null}
};

static MainLoop ml;

public struct TrafficReport {
    uint32 icao;
    double lat;
    double lon;
    int32 alt;
    uint16 hdr;
    double hv;
    uint16 vv;
    uint16 valid;
    uint16 squawk;
    uint8  atype;
    uint8  callsign[10];
    uint8  emtype;
    uint8 tslc;
}

public class RadarSim : Object {
    private TrafficReport []tr;
    private bool quit;
    private uint tid;
    private Rand rand;
    private MWSerial msp;
    private double hlat = HLAT;
    private double hlon = HLON;
    private const uint16 mask = 1+2+4+8+0x10+0x20+0x100;

    public RadarSim() {
        tr = new TrafficReport[maxradar];
        if(llstr != null) {
            string[] delims =  {" ",","};
            foreach (var delim in delims) {
                var parts = llstr.split(delim);
                if(parts.length == 2) {
                    hlat = DStr.strtod(parts[0],null);
                    hlon = DStr.strtod(parts[1],null);
                    break;
                }
            }
        }

        rand  = new Rand();
        quit = false;
        var lonf = 0.5/Math.cos(hlat*(Math.PI/180.0));

        for (var i = 0; i < maxradar; i++) {
            tr[i].icao = 10000000+ (uint32)((long)(&tr[i]) % 1000000);
            tr[i].lat = hlat + rand.double_range(-0.5, 0.5);
            tr[i].lon = hlon + rand.double_range(-lonf, lonf);
            tr[i].alt = 10000 + rand.int_range (-5000, 5000);
            tr[i].hdr = (uint16)rand.int_range (0, 359);
            tr[i].hv = rand.double_range(120,640);
            tr[i].vv = (uint16)rand.int_range(-30,30);
            tr[i].squawk = 0xffff;
            tr[i].valid = mask;
            tr[i].atype  = 0;
            string t = "TEST%04d".printf(i);
            tr[i].callsign = t.data;
            tr[i].emtype = i % 20;
            tr[i].tslc = i%16;
        }
        open_serial();
    }

    public void run() {
        int to = 25;
        int id  = 0;

        tid = Timeout.add(to, () => {
                double spd = tr[id].hv + rand.double_range(-10.0, 10.0);
                double cse = tr[id].hdr + rand.double_range(-5, 5);
                if(cse < 0)
                    cse = cse + 360;
                cse = cse % 360;
                var  lat = tr[id].lat;
                var lon = tr[id].lon;
                double delta = spd * ((to*maxradar)/1000)/3600 ;
                Geo.posit (lat, lon,
                           cse, delta, out tr[id].lat, out tr[id].lon);

                tr[id].hdr = (uint16)cse;
                tr[id].hv = spd;
                tr[id].alt += rand.int_range(-10, 10);
                tr[id].tslc = (uint8)((to*maxradar)/1000 + rand.int_range(0,3) & 0xff);
                transmit_radar(tr[id]);
                id += 1;
                if (id == maxradar)
                    id = 0;
                return Source.CONTINUE;
            });
    }

    private void open_serial() {
        msp = new MWSerial();
        msp.set_mode(MWSerial.Mode.SIM);
		msp.open_async.begin(dev, baud,  (obj,res) => {
				var ok = msp.open_async.end(res);
				if (ok) {
					msp.setup_reader();
					msp.serial_lost.connect(() => {
							if(tid > 0)
								Source.remove(tid);
							ml.quit();
						});
				} else {
					string estr;
					msp.get_error_message(out estr);
		            MWPLog.message("open failed serial %s %s\n", dev, estr);
					ml.quit();
				}
			});
    }

    private void transmit_radar(TrafficReport r) {
        uint8 buf[128];

        uint8 *p = buf;
        p = SEDE.serialise_u32(p, r.icao);
        p = SEDE.serialise_i32(p, (int32)Math.lround(r.lat * 10000000));
        p = SEDE.serialise_i32(p, (int32)Math.lround(r.lon * 10000000));
        p = SEDE.serialise_i32(p, (r.alt * 1000));
        p = SEDE.serialise_u16(p, (uint16)r.hdr*100);
        p = SEDE.serialise_u16(p, (uint16)(r.hv*0.51444444)*100); // knots => m/s
        p = SEDE.serialise_u16(p, (uint16)r.vv*100);
        p = SEDE.serialise_u16(p, (uint16)r.valid);
        p = SEDE.serialise_u16(p, (uint16)r.squawk);
        *p++ = r.atype;
        for(var j = 0; j < 9; j++)
            *p++ = r.callsign[j];
        *p++ = r.emtype;
        *p++ = r.tslc;
        msp.send_mav(246, buf, (size_t)(p - &buf[0]));
    }
}


public static int main (string[] args) {
    ml = new MainLoop();

    maxradar = MAXRADAR;

    string []devs = {"/dev/ttyUSB0","/dev/ttyACM0"};

    foreach(var d in devs) {
        if(Posix.access(d,(Posix.R_OK|Posix.W_OK)) == 0) {
            dev = d;
            break;
        }
    }

    try {
        var opt = new OptionContext(" - mavlink traffic report simulation tool");
        opt.set_help_enabled(true);
        opt.add_main_entries(options, null);
        opt.parse(ref args);
    } catch (OptionError e) {
        stderr.printf("Error: %s\n", e.message);
        stderr.printf("Run '%s --help' to see a full list of available "+
                      "options\n", args[0]);
        return 1;
    }

    if (args.length > 2)
        baud = int.parse(args[2]);

    if (args.length > 1)
        dev = args[1];

    if(dev == null) {
        stdout.puts("No device found\n");
        return 0;
    }

    var rsim = new RadarSim();
    rsim.run();
    ml.run ();
    return 0;
}
