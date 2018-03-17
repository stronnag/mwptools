[DBus (name = "org.mwptools.mwp")]
public class MwpServer : Object {
    internal SourceFunc callback;
    internal string?[] device_names = {};
    internal int nwpts;

    internal signal uint __set_mission(string s);
    internal signal uint __load_mission(string s);
    internal signal void __clear_mission();
    internal signal int __get_devices();
    internal signal void __upload_mission(bool e);
    internal signal bool __connect_device(string s);

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
