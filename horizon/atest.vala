
public class Application : Object
{
    private Pid cpid;
    private int fdin;
    private int fdout;
    private Rand rand;
    private Gtk.Socket sk;

    public Application ()
    {
        var w = new Gtk.Window();
        w.title = "Hor Test";
        w.destroy.connect (() => {
                if(cpid != 0)
                    Posix.kill(cpid, Posix.SIGTERM);
                Gtk.main_quit ();
            });

        sk = new Gtk.Socket ();
        w.add (sk);
        start_plugger();
        w.show_all ();
    }

    public void start_plugger()
    {
        rand  = new Rand();
        string [] args = {"mwp_ath", "-p"};
        Process.spawn_async_with_pipes ("/",
                                        args,
                                        null,
                                        SpawnFlags.SEARCH_PATH,
                                        null,
                                        out cpid,
                                        out fdin,
                                        out fdout,
                                        null);


        stderr.printf("pipes %d %d\n", fdin, fdout);
        var fs = FileStream.fdopen(fdout,"r");
        var buf = fs.read_line();
        int sockid = int.parse(buf);
        stdout.printf("%s => sockid = %0x\n", buf, sockid);
        sk.add_id((Gtk.Window *)sockid);

        Timeout.add_seconds(1,() => {
                var d1 = rand.int_range(0, 360);
                var d2 = rand.int_range(-70, 70);
                string s = "%d %d\n".printf(d1,d2);
                Posix.write(fdin, s, s.length);
                return true;
            });
    }

    public static int main (string[] args) {
        Gtk.init (ref args);
        new Application ();
        Gtk.main ();
        return 0;
	}
}
