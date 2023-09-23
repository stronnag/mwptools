
/* MSP 'sink' */

public class MWSim : GLib.Object {
    private int fd;
    private MWSerial msp;
    private MainLoop ml;

    public MWSim() {
        msp = new MWSerial();
        msp.set_mode(MWSerial.Mode.SIM);
        ml = new MainLoop();
    }

    public void open() {
        char buf[128];
        string estr;

        unowned string s;
        fd = Posix.posix_openpt(Posix.O_RDWR);
        Posix.ttyname_r(fd, buf);
        Posix.grantpt(fd);
        Posix.unlockpt(fd);
        s = (string)MwpLibC.ptsname (fd);
        stderr.printf("%s => fd %d slave %s\n", (string)buf, fd, s);
        msp.open_fd(fd,115200);
    }

    public void run() {
        open();
        msp.serial_lost.connect (()=> {
                print("endpoint died\n");

            });
        msp.serial_event.connect ((s, cmd, raw, len, xflags, errs) => {
            s.send_command(cmd, null, 0);
        });
        ml.run();
    }

    static int main(string?[] args) {
        var d = new MWSim();
        d.run ();
        return 0;
    }
}
