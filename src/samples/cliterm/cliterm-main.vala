
public static int main (string[] args) {
    Gtk.init (ref args);
    CLITerm t = new CLITerm ();

    string dev = "/dev/ttyUSB0";
    int brate = 115200;

    if (args.length > 2)
        brate = int.parse(args[2]);

    if (args.length > 1)
    dev = args[1];

    bool res;

    var ser = new MWSerial();
    string estr;
    if((res = ser.open(dev, brate, out estr)) == true) {
        t.on_exit.connect(() => {
                Gtk.main_quit();
            });
        t.configure_serial(ser);
        t.show_all ();
        Gtk.main ();
    }
    else
        MWPLog.message("open failed serial %s %s\n", dev, estr);
    return 0;
}
