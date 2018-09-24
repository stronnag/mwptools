
private static int baud = 115200;
private static string dev;

const OptionEntry[] options = {
    { "baud", 'b', 0, OptionArg.INT, out baud, "baud rate", null},
    { "device", 'd', 0, OptionArg.STRING, out dev, "device", null},
    {null}
};

private static MainLoop ml;

public static int main (string[] args)
{

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
        MWPLog.message("opened serial %s %d\n", dev, baud);
        s.use_v2 = true;
        s.serial_event.connect((s,cmd,raw,len,xflags,errs) =>
            {
                MWPLog.message("cmd %x len %d errs %s\n",
                               cmd,len, errs.to_string());
            });

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

    int n = 0;
    Timeout.add_seconds(1, () => {
            switch(n)
            {
                case 0,2:
                s.send_command(MSP.Cmds.STATUS,null,0);
                break;
                case 1:
                uint8 [] payl  = {0xD9, 0xB1, 0x3, 0x16, 0x33, 0xA3, 0xF0, 0xD0};
                s.send_command(0x1F03, payl ,8);
                MWPLog.message("send bogus message 0x1f03\n");
                break;

                default:
                ml.quit();
                break;
            }
            n++;
            return true;
        });
    ml.run ();
    return 0;
}
