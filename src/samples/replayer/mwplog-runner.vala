private static int baud = 115200;
private static string dev;

const OptionEntry[] options = {
    { "baud", 'b', 0, OptionArg.INT, out baud, "baud rate", null},
    { "device", 'd', 0, OptionArg.STRING, out dev, "device", null},
    {null}
};

public static int main (string[] args) {
    var s = new MWSerial.forwarder();

    string file = null;
    string []devs = {"/dev/ttyUSB0","/dev/ttyACM0"};

    foreach(var d in devs) {
        if(Posix.access(d,(Posix.R_OK|Posix.W_OK)) == 0) {
            dev = d;
            break;
        }
    }

    try {
        var opt = new OptionContext("logfile --- replay mwp logs");
        opt.set_help_enabled(true);
        opt.add_main_entries(options, null);
        opt.parse(ref args);
    } catch (OptionError e) {
        stderr.printf("Error: %s\n", e.message);
        stderr.printf("Run '%s --help' to see a full list of available "+
                      "options\n", args[0]);
        return 1;
    }

    if (args.length == 2)
        file = args[1];

    if(file == null) {
        stdout.puts("No file given\n");
        return 0;
    }

    string estr;
    if(s.open(dev, baud, out estr)) {
        var ml = new MainLoop();
        var robj = new ReplayThread();
        robj.replay_done.connect(() => {
                ml.quit();
            });
        var thr = robj.run_msp(s, file, true);
        ml.run();
        thr.join();
    }
    return 0;
}
