private static int baud = 115200;
private static string dev;

const OptionEntry[] options = {
    { "baud", 'b', 0, OptionArg.INT, out baud, "baud rate", "115200"},
    { "device", 'd', 0, OptionArg.STRING, out dev, "device", "/dev/ttyUSB0"},
    {null}
};

int main (string[] args)
{
    var ml = new MainLoop();
    MWSerial s;

    try {
        var opt = new OptionContext(" - MSP_MSG test");
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

    s = new MWSerial();

    uint errs = 0;
    uint msgs = 0;

    if (args.length > 2)
        baud = int.parse(args[2]);

    if (args.length > 1)
        dev = args[1];

    s.serial_event.connect((cmd, raw, len, flags, err) => {
            if(err)
            {
                errs++;
            }
            else
            {
                MWPLog.message("%s %u bytes\n", cmd.to_string(), len);
                msgs++;
            }
        });

    s.serial_lost.connect(() => {
            ml.quit();
            });


    string estr = null;
    if(dev != null && (s.open(dev, baud, out estr) == false))
    {
        MWPLog.message("open failed %s\n", estr);
        return 255;
    }

    Timeout.add_seconds(10, () => {

            MWPLog.message("messages %u, errors %u \n", msgs, errs);
            return true;
        });

    ml.run ();
    s.close();
    return 0;
}