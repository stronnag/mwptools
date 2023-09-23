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
    public signal void  waypoint_changed(int wp);

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
    public abstract int get_waypoint_number() throws DBusError,IOError;
}

public class App : Object {
    private MainLoop ml;
    private MwpIF? mwpif = null;
    private int intvl = -1;
    private Timer timer;

    public App(int _i = -1) {
        intvl = _i;
    }

    public void acquire() {
        Bus.watch_name(BusType.SESSION, "org.mwptools.mwp",
                       BusNameWatcherFlags.NONE,
                       has_bus, lost_bus);
    }

    private void has_bus() {
        if (mwpif == null)
            Bus.get_proxy.begin<MwpIF>(BusType.SESSION, "org.mwptools.mwp",
                                       "/org/mwptools/mwp", 0, null, on_bus_get);
    }

    private void message(string format, ...) {
        if(timer == null) {
            timer = new Timer();
            timer.start();
        }
	double seconds;
        var args = va_list();
        StringBuilder sb = new StringBuilder();
 	seconds = timer.elapsed ();
	sb.append_printf("%08.1f: ", seconds);
        sb.append_vprintf(format, args);
        stdout.puts (sb.str);
    }

    private void on_bus_get(Object? o, AsyncResult? res) {
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

            if(intvl > -1) {
                message("Setting new interval %d\n", intvl);
                mwpif.dbus_pos_interval = intvl;
            } else
                message("Intvl %u\n", mwpif.dbus_pos_interval);
            StringBuilder sb = new StringBuilder("State Names:");
            mwpif.get_state_names (out states);
            foreach(var s in states) {
                sb.append_c(' ');
                sb.append(s);
            }
            message ("%s\n", sb.str);

            state = mwpif.get_state();
            message("Iniital state: %s\n", states[state]);

            var wpno = mwpif.get_waypoint_number();
            message("Initial WP: %d\n", wpno);

            mwpif.get_sats(out nsats, out fix);
            message("Initial satellites: %u %u\n", nsats, fix);

            mwpif.get_home(out latitude, out longitude, out altitude);
            message("Initial home location: %f %f %dm\n",
                  latitude, longitude, altitude);

            mwpif.get_location(out latitude, out longitude, out altitude);
            message("Initial geographic location: %f %f %dm\n",
                  latitude, longitude, altitude);

            mwpif.get_polar_coordinates(out range, out bearing, out azimuth);
            message("Initial polar coordinates: %um %u° %u°\n",
                  range, bearing, azimuth);

            mwpif.get_velocity(out speed, out course);
            message("Initial velocity: %um/s %u°\n", speed, course);

            mwpif.home_changed.connect((la, lo, alt) => {
                    message("Home changed: %f %f %dm\n", la, lo, alt);
                });

            mwpif.location_changed.connect((la, lo, alt) => {
                    message("Location changed: %f %f %dm\n", la, lo, alt);
                });

            mwpif.polar_changed.connect((r, b, a) => {
                    message("Polar coordinates changed: %um %u° %u°\n", r, b, a);
                });

            mwpif.state_changed.connect((s) => {
                    message("State changed: %s\n", states[s]);
                });

            mwpif.waypoint_changed.connect((wp) => {
                    message("WP changed: %d\n", wp);
                });

            mwpif.velocity_changed.connect((s,c) => {
                    message("Velocity changed: %um/s %u°\n", s, c);
                });

            mwpif.sats_changed.connect((s,f) => {
                    message("Satellites changed: %us %u\n", s, f);
                });

        } catch (Error e) {
            message("%s\n", e.message);
            mwpif = null;
        }
    }

    private void lost_bus() {
        mwpif = null;
    }

    public void run() {
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
