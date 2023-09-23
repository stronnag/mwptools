private static int baud = 115200;
private static string dev;
private string infile;

const OptionEntry[] options = {
    { "baud", 'b', 0, OptionArg.INT, out baud, "baud rate", "115200"},
    { "device", 'd', 0, OptionArg.STRING, out dev, "device", "/dev/ttyUSB0"},
    { "infile", 'f', 0, OptionArg.STRING, out infile, "file", null},
    {null}
};

int main (string[] args) {
    var ml = new MainLoop();
    MWSerial s;

    try {
        var opt = new OptionContext(" - MSP_MSG test");
        opt.set_help_enabled(true);
        opt.add_main_entries(options, null);
        opt.parse(ref args);
    } catch (OptionError e) {
        stderr.printf("Error: %s\n", e.message);
        stderr.printf("Run '%s --help' to see a full list of available "+
                      "options\n", args[0]);
        return 1;
    }

    if(infile == null)
        return(1);

    s = new MWSerial.forwarder();
    s.serial_lost.connect(() => {
            ml.quit();
		});

    string estr = null;
    if(dev != null && (s.open(dev, baud, out estr) == false)) {
        MWPLog.message("open failed %s\n", estr);
        return 255;
    }
    int fd = s.get_fd();
    var fs  = FileStream.open (infile, "r");
    Timeout.add(10, () => {
            uint8 buf[8];
            var n = fs.read(buf,1);
            stdout.printf("read %d\n", (int)n);
            if (n <= 0) {
                ml.quit();
                return false;
            } else
                Posix.write(fd,buf,n);
            return true;
        });
    ml.run ();
    s.close();
    return 0;
}