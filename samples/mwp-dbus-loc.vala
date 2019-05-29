// valac --pkg gio-2.0 mwp-dbus-loc.vala

[DBus (name = "org.mwptools.mwp")]
interface MwpIF : DBusProxy {
    public signal void home_changed (double latitude, double longitude,
                                     int altitude);
    public signal void location_changed (double latitude, double longitude,
                                         int altitude);
    public signal void polar_changed(uint32 range, uint32 direction, uint32 azimuth);
    public signal void velocity_changed(uint32 speed, uint32 course);

    public signal void state_changed(int state);
    public signal void sats_changed(uint8 nsats, uint8 fix);
    public abstract uint dbus_pos_interval{get; set;}
    public signal void quit();

    public abstract int get_state() throws DBusError,IOError;
    public abstract int get_state_names(out string[]names) throws DBusError,IOError;
    public abstract void get_sats(out uint8 nsats, out uint8 fix) throws DBusError,IOError;
    public abstract void get_home(out double latitude, out double longitude,
                                  out int32 altitude) throws DBusError,IOError;
    public abstract void get_velocity(out uint32 speed,
                                      out uint32 course) throws DBusError,IOError;
    public abstract void get_polar_coordinates(out uint32 range,
                                               out uint32 direction,
                                               out uint32 azimuth) throws DBusError,IOError;
    public abstract void get_location(out double latitude, out double longitude,
                                      out int32 altitude) throws DBusError,IOError;

}

public class App : Object
{
    private MainLoop ml;
    private MwpIF? mwpif = null;
    private int intvl = -1;


    public App(int _i = -1)
    {
        intvl = _i;
    }

    public void acquire()
    {
        Bus.watch_name(BusType.SESSION, "org.mwptools.mwp",
                       BusNameWatcherFlags.NONE,
                       has_bus, lost_bus);
    }

    private void has_bus()
    {
        if (mwpif == null)
            Bus.get_proxy.begin<MwpIF>(BusType.SESSION, "org.mwptools.mwp",
                                       "/org/mwptools/mwp", 0, null, on_bus_get);
    }

    private void on_bus_get(Object? o, AsyncResult? res)
    {
        try {
            mwpif = Bus.get_proxy.end(res);
            string []states;
            uint8 nsats, fix;
            double latitude, longitude;
            int altitude;
            int state;
            uint32 range, bearing, azimuth, course, speed;

            mwpif.quit.connect(() => {
                    ml.quit();
                });

            if(intvl > -1)
            {
                print("Setting new interval %d\n", intvl);
                mwpif.dbus_pos_interval = intvl;
            }
            else
                stdout.printf("Intvl %u\n", mwpif.dbus_pos_interval);
            StringBuilder sb = new StringBuilder("State Names:");
            mwpif.get_state_names (out states);
            foreach(var s in states)
            {
                sb.append_c(' ');
                sb.append(s);
            }
            print ("%s\n", sb.str);

            state = mwpif.get_state();
            stdout.printf("Iniital state: %s\n", states[state]);

            mwpif.get_sats(out nsats, out fix);
            stdout.printf("Initial satellites: %u %u\n", nsats, fix);

            mwpif.get_home(out latitude, out longitude, out altitude);
            stdout.printf("Initial home location: %f %f %dm\n",
                  latitude, longitude, altitude);

            mwpif.get_location(out latitude, out longitude, out altitude);
            stdout.printf("Initial geographic location: %f %f %dm\n",
                  latitude, longitude, altitude);

            mwpif.get_polar_coordinates(out range, out bearing, out azimuth);
            stdout.printf("Initial polar coordinates: %um %u° %u°\n",
                  range, bearing, azimuth);

            mwpif.get_velocity(out speed, out course);
            stdout.printf("Initial velocity: %um/s %u°\n", speed, course);

            mwpif.home_changed.connect((la, lo, alt) => {
                    stdout.printf("Home changed: %f %f %dm\n", la, lo, alt);
                });

            mwpif.location_changed.connect((la, lo, alt) => {
            stdout.printf("Location changed: %f %f %dm\n", la, lo, alt);
                });

            mwpif.polar_changed.connect((r, b, a) => {
            stdout.printf("Polar coordinates changed: %um %u° %u°\n", r, b, a);
                });

            mwpif.state_changed.connect((s) => {
                    stdout.printf("State changed: %s\n", states[s]);
                });

            mwpif.velocity_changed.connect((s,c) => {
                    stdout.printf("Velocity changed: %um/s %u°\n", s, c);
                });

            mwpif.sats_changed.connect((s,f) => {
                    stdout.printf("Satellites changed: %us %u\n", s, f);
                });

        } catch (Error e) {
            stderr.printf ("%s\n", e.message);
            mwpif = null;
        }
    }

    private void lost_bus()
    {
        mwpif = null;
    }

    public void run()
    {
        ml = new MainLoop();
        ml.run();
    }

}

int main (string?[]args) {
    int intvl = -1;
    if(args.length > 1)
        intvl = int.parse(args[1]);
    var a = new App(intvl);
    a.acquire();
    a.run();
    return 0;
}