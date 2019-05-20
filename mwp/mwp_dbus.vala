[DBus (name = "org.mwptools.mwp")]
public class MwpServer : Object {
   public enum State {
        DISARMED = 0,
        MANUAL,
        ACRO,
        HORIZON,
        ANGLE,
        CRUISE,
        RTH,
        LAND,
        WP,
        HEADFREE,
        POSHOLD,
        ALTHOLD,
        LAUNCH,
        AUTOTUNE,
        UNDEFINED
    }

   internal State m_state;
   internal double v_lat;
   internal double v_long;
   internal double v_alt;

   internal double h_lat;
   internal double h_long;
   internal double h_alt;

   internal uint8 m_nsats = 0;
   internal uint8 m_fix  = 0;

   internal SourceFunc callback;
   internal string?[] device_names = {};
   internal int nwpts;

   internal signal uint __set_mission(string s);
   internal signal uint __load_mission(string s);
   internal signal void __clear_mission();
   internal signal int __get_devices();
   internal signal void __upload_mission(bool e);
   internal signal bool __connect_device(string s);

    public signal void home_changed (double latitude, double longitude,
                                     double altitude);
    public signal void location_changed (double latitude, double longitude,
                                         double altitude);
    public signal void state_changed(State state);
    public signal void sats_changed(uint8 nsats, uint8 fix);

    public uint dbus_pos_interval { get; set; default = 2;}
    public signal void quit();

    public int get_state_names(out string[]names) throws GLib.Error
    {
        string[] _names = {};
        for (var e = State.DISARMED; e <= State.UNDEFINED; e = e+1)
        {
            var s = e.to_string();
                /* MWP_SERVER_STATE_xxxx (17 byte prefix) */
            _names += s.substring(17);
        }
        names = _names;
        return _names.length;
    }

    public void get_home(out double latitude, out double longitude,
                         out double altitude) throws GLib.Error
    {
        latitude = h_lat;
        longitude = h_long;
        altitude = h_alt;
    }

    public void get_location(out double latitude, out double longitude,
                         out double altitude) throws GLib.Error
    {
        latitude = v_lat;
        longitude = v_long;
        altitude = v_alt;
    }

    public State get_state() throws GLib.Error
    {
        return m_state;
    }

    public void get_sats(out uint8 nsats, out uint8 fix) throws GLib.Error
    {
        nsats = m_nsats;
        fix = m_fix;
    }

    public uint set_mission (string mission) throws GLib.Error
    {
        uint nmpts = __set_mission(mission);
        return nmpts;
    }

    public uint load_mission (string filename) throws GLib.Error {
        uint nmpts = __load_mission(filename);
        return nmpts;
    }

    public void clear_mission () throws GLib.Error {
         __clear_mission();
    }

    public void get_devices (out string[]devices) throws GLib.Error {
        __get_devices();
        devices = device_names;
    }

    public async int upload_mission(bool to_eeprom) throws GLib.Error
    {
        callback = upload_mission.callback;
        __upload_mission(to_eeprom);
        yield;
        return nwpts;
    }

    public bool connection_status (out string device) throws GLib.Error {
        int idx = __get_devices();
        device  = (idx == -1) ? "" : device_names[idx];
        return (idx != -1);
    }

    public bool connect_device (string device) throws GLib.Error {
        return __connect_device(device);
    }

}
