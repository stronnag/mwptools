
private static int baud = 115200;
private static string dev;
private static bool spam=false;
private int secs = 0;
private int millis = 20;



const OptionEntry[] options = {
    { "baud", 'b', 0, OptionArg.INT, out baud, "baud rate", null},
    { "device", 'd', 0, OptionArg.STRING, out dev, "device", null},
    { "spam", 's', 0,  OptionArg.NONE, out spam, "spam",null},
    { "time", 't', 0,  OptionArg.INT, out secs, "secs",null},
    { "millis", 'm', 0,  OptionArg.INT, out millis, "secs",null},
    {null}
};

static uint16 lmin = 64000;
static uint16 lmax = 0;
static uint nl = 0;
static uint ns = 0;
static uint ne = 0;
static bool fquit = false;

private static MainLoop ml;

public static int main (string[] args)
{

    Posix.signal (Posix.SIGINT, (s) => {
            fquit = true;
        });

    ml = new MainLoop();
    MWSerial s;

    s = new MWSerial();
    string estr;
    bool res;
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
        var opt = new OptionContext(" - cli tool");
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

    if((res = s.open(dev, baud, out estr)) == true)
    {
        uint tid = 0;
        s.serial_event.connect((s,cmd,raw,len,xflags,errs) =>
            {
                if(errs == false && cmd == MSP.Cmds.STATUS)
                {
                    if(tid != 0)
                    {
                        Source.remove(tid);
                        tid = 0;
                    }
                    nl++;
                    uint16 loopt;
                    deserialise_u16(raw, out loopt);
                    if(secs == 0)
                        print("loop %u\n", loopt);
                    if(loopt > lmax)
                        lmax =  loopt;
                    if(loopt < lmin)
                        lmin =  loopt;
                }
                else
                    ne++;

                if(fquit)
                    ml.quit();

                if(!spam)
                {
                    s.send_command(MSP.Cmds.STATUS,null,0);
                    ns++;
                    tid = Timeout.add_seconds(250, () => {
                            tid =0;
                            s.send_command(MSP.Cmds.STATUS,null,0);
                            ns++;
                            return false;
                        });
                }
            });

        if(spam == false)
        {
            s.send_command(MSP.Cmds.STATUS,null,0);
            ns++;
        }
        else
        {
            Timeout.add(millis, () => {
                    s.send_command(MSP.Cmds.STATUS,null,0);
                    ns++;
                    return true;
                });
        }

        s.serial_lost.connect(() => {
                s.close();
                ml.quit();
            });
    }
    else
    {
        MWPLog.message("open failed serial %s %s\n", dev, estr);
        return 255;
    }

    if(secs > 0)
        Timeout.add_seconds(secs, () => {
                fquit = true;
                return false;
            });

    ml.run ();
    print("\n%s: %d secs,  sent=%u, recv %u, min=%u, max=%u\n",
          (spam) ? "Async" : "Sync",
          secs,ns,nl,lmin,lmax);
    return 0;
}

// 60 secs, interations 1858, min=2000, max=2364
// 60 secs, interations 2860, min=2000, max=21322
