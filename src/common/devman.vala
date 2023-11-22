/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * (c) Jonathan Hudson <jh+mwptools@daria.co.uk>
 */

/*
 * Standalone test with:
 * valac -D TEST --pkg gio-2.0 --pkg gudev-1.0 devman-linux.vala
 */

public enum DevMask {
    USB = 1,
    BT = 2,
	BTLE = 4,
}

public struct DevDef {
        string name;
        string alias;
        DevMask type;
		string uuid;
}

#if LINUX
public class DevManager {
    private GUdev.Client uc;
    private DBusObjectManager manager;
    private BluezAdapterProperties adapter;
    private HashTable<ObjectPath, HashTable<string, HashTable<string, Variant>>> objects;
    public signal void device_added (DevDef dd);
    public signal void device_removed (string s);
	public static SList<DevDef?> serials;
    private DevMask mask;

    public DevManager(DevMask _dm=(DevMask.BT|DevMask.BTLE|DevMask.USB)) {
        mask = _dm;
		serials = new SList<DevDef?>();
        uc = new GUdev.Client({"tty"});
        uc.uevent.connect((action,dev) => {
                if(dev.get_property("ID_BUS") == "usb") {
                    if((mask & DevMask.USB) != 0) {
                        var ds = dev.get_device_file().dup();
                        switch (action) {
                            case "add":
                                print_device(dev);
								var dd = usbdesc(dev);
                                device_added(dd);
                                break;
                            case "remove":
								for( unowned var lp = serials; lp != null; ) {
									unowned var xlp = lp;
									lp = lp.next;
									if(((DevDef)xlp.data).name == ds) {
                                        serials.remove_link(xlp);
									}
								}
                                device_removed(ds);
                                break;
                        }
                    }
                }
            });
        evince_bt_devices.begin();
    }

    private void print_device(GUdev.Device d) {
        StringBuilder sb = new StringBuilder();
        if(d.get_property("ID_BUS") == "usb") {
            sb.append_printf("Registered serial device: %s ", d.get_device_file());
            sb.append_printf("[%s:%s], ", d.get_property("ID_VENDOR_ID"),
                             d.get_property("ID_MODEL_ID"));
            sb.append_printf("Vendor: %s, Model: %s, ",
                             d.get_property("ID_VENDOR"),
                             d.get_property("ID_MODEL"));
            sb.append_printf("Serial: %s, Driver: %s\n",
                             d.get_property("ID_SERIAL_SHORT"),
                             d.get_property("ID_USB_DRIVER"));
            MWPLog.message (sb.str);
        }
    }

    private async void evince_bt_devices() {
        try {
            manager = yield Bus.get_proxy (BusType.SYSTEM, "org.bluez", "/");
            objects = manager.get_managed_objects();
            find_adapter();
            find_devices();
        } catch (Error e) {
            stderr.printf ("%s\n", e.message);
        }
    }

    private void find_adapter() {
		objects.foreach((path, ifaces) => {
				HashTable<string, Variant>? props;
				props = ifaces.get("org.bluez.Adapter1");
				if (props == null)
					return;
				adapter = new BluezAdapterProperties(path, props);
				adapter.powered = true;
				adapter.start_discovery();
				Timeout.add_seconds(15, () => {
						adapter.stop_discovery();
						return false;
					});
			});
    }

	private bool extant (string name) {
		bool found = false;
		for(unowned var lp = serials; lp != null; lp = lp.next) {
			if (((DevDef)lp.data).name == name) {
				found = true;
				break;
			}
		}
		return found;
	}

    private void add_device(ObjectPath path, HashTable<string, Variant> props) {
		var name = props.get("Address").get_string();
		if (!extant(name)) {
			var uuids = props.get("UUIDs");
			var uus = uuids.get_strv();
			string idu = null;
			foreach(var u in uus) {
				if(u.has_prefix("00001101-0000-1000-8000") ||
				   u == "0000abf0-0000-1000-8000-00805f9b34fb" ||
				   u == "0000ffe0-0000-1000-8000-00805f9b34fb" ||
				   u == "6e400001-b5a3-f393-e0a9-e50e24dcca9e" ||
				   u == "00001000-0000-1000-8000-00805f9b34fb") {
					idu = u;
					break;
				}
			}
			if(idu != null) {
				var alias = props.get("Alias").get_string();
				if (!alias.contains("Keyboard")) { // yes, I have one (not SB t1)
					DevDef dd = {};
					dd.name = name;
					dd.alias = alias;
					dd.uuid = idu;
					dd.type = idu.contains("00001101") ? DevMask.BT : DevMask.BTLE;
					serials.append(dd);
					device_added(dd);
				}
			}
		}
    }

    private void find_devices() {
		objects.foreach((path, ifaces) => {
				HashTable<string, Variant>? props;
				props = ifaces.get("org.bluez.Device1");
				if (props != null) {
					add_device(path, props);
				}
			});
	}

    [CCode (instance_pos = -1)]
    public void on_interfaces_added(ObjectPath path,
                                    HashTable<string, HashTable<string, Variant>> interfaces) {
        objects.insert(path, interfaces);
        HashTable<string, Variant>? props;
        props = interfaces.get("org.bluez.Device1");
        if (props != null)
            add_device(path, props);
    }

    public void get_serial_devices() {
        var devs = uc.query_by_subsystem("tty");
        foreach (var d in devs) {
            if(d.get_property("ID_BUS") == "usb") {
                print_device(d);
				var dd = usbdesc(d);
				device_added(dd);
            }
        }
    }
	private DevDef usbdesc(GUdev.Device dev) {
		DevDef dd = {};
		dd.name = dev.get_device_file().dup();
		dd.alias =  dev.get_property("ID_MODEL").dup();
		dd.type = DevMask.USB;
		serials.append(dd);
		return dd;
	}

	public static DevMask get_type_for_name(string name) {
		for( unowned SList<DevDef?> lp = serials; lp != null; lp = lp.next) {
			var dd = (DevDef)lp.data;
			if(dd.name == name) {
				return dd.type;
			}
		}
		return 0;
	}

	public static DevDef? get_dd_for_name(string name) {
		for( unowned SList<DevDef?> lp = serials; lp != null; lp = lp.next) {
			var dd = (DevDef)lp.data;
			if(dd.name == name) {
				return dd;
			}
		}
		return null;
	}
}

/*
  From xfce-bluetooth
  https://github.com/ncopa/xfce-bluetooth
  GPL 2 (or later)
 */

[DBus (name = "org.freedesktop.DBus.ObjectManager")]
interface DBusObjectManager : GLib.Object {
    [DBus (name = "GetManagedObjects")]
    public abstract HashTable<ObjectPath, HashTable<string, HashTable<string, Variant>>> get_managed_objects() throws DBusError, IOError;
    [DBus (name = "InterfacesAdded")]
    public signal void interfaces_added(ObjectPath path,
			   HashTable<string, HashTable<string, Variant>> interfaces);
}

[DBus (name = "org.freedesktop.DBus.Properties")]
interface DBusProperties : GLib.Object {
    [DBus (name = "Set")]
    public abstract void set(string iface, string name, Variant val)
                            throws DBusError, IOError;
///    [DBus (name = "Get")]
///    public abstract Variant get(string iface, string name)
///                               throws DBusError, IOError;
    [DBus (name = "GetAll")]
    public abstract HashTable<string, Variant> get_all(string iface)
                                                throws DBusError, IOError;

    public signal void properties_changed(string iface,
                                          HashTable <string, Variant> changed,
                                          string[] invalidated);
}

///[DBus (name = "org.bluez.AgentManager1")]
///interface BluezAgentManagerBus : GLib.Object {
///    [DBus (name = "RegisterAgent")]
///    public abstract void register_agent(ObjectPath agent, string capability) throws DBusError, IOError;
///    [DBus (name = "RequestDefaultAgent")]
///    public abstract void request_default_agent(ObjectPath agent) throws DBusError, IOError;
///}

[DBus (name = "org.bluez.Adapter1")]
public interface BluezAdapterBus : GLib.Object {
    [DBus (name = "RemoveDevice")]
    public abstract void remove_device(ObjectPath device) throws DBusError, IOError;
    [DBus (name = "StartDiscovery")]
    public abstract void start_discovery() throws DBusError, IOError;
    [DBus (name = "StopDiscovery")]
    public abstract void stop_discovery() throws DBusError, IOError;
}

[DBus (name = "org.bluez.Device1")]
interface BluezDeviceBus : GLib.Object {
///    [DBus (name = "CancelPairing")]
///    public abstract void cancel_pairing() throws DBusError, IOError;
///    [DBus (name = "Connect")]
///    public abstract void connect() throws DBusError, IOError;
///    [DBus (name = "ConnectProfile")]
///    public abstract void connect_profile(string UUID) throws DBusError, IOError;
///    [DBus (name = "Disconnect")]
///    public abstract void disconnect() throws DBusError, IOError;
///    [DBus (name = "DisonnectProfile")]
///    public abstract void disconnect_profile(string UUID) throws DBusError, IOError;
///    [DBus (name = "Pair")]
///    public abstract void pair() throws DBusError, IOError;
}

public abstract class BluezInterface : GLib.Object {
    DBusProperties bus;
    string iface_name;
    HashTable<string, Variant> property_cache;

    public ObjectPath object_path = null;

    BluezInterface(string name, ObjectPath path,
                          HashTable<string, Variant>? props = null) {
        iface_name = name;
        object_path = path;
        try {
            bus = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", path);
            if (props == null) {
                property_cache = bus.get_all(iface_name);
            } else
                property_cache = props;
            bus.properties_changed.connect(on_properties_changed);
        } catch  {
			MWPLog.message("Failed to start bluetooth\n");
		}
    }

    public Variant get_cache(string key) {
        return property_cache.get(key);
    }

    public void set_cache(string key, Variant val) {
        property_cache.replace(key, val);
    }

    public void set_bus(string key, Variant val) throws IOError {
        if (val.equal(property_cache.get(key)))
            return;
        try {
            bus.set(iface_name, key, val);
            set_cache(key, val);
        } catch (Error e) {
            stderr.printf("Failed to set %s=%s: %s", key, val.print(false), e.message);
        }
    }

    public abstract void property_changed(string key, Variant val);

    public void on_properties_changed(string iface,
                                      HashTable <string, Variant> changed,
                                      string[] invalidated) {
		changed.foreach((key, val) => {
				if (val.equal(property_cache.get(key)))
					return;
				set_cache(key, val);
				property_changed(key, val);
			});
    }
}

/* http://git.kernel.org/cgit/bluetooth/bluez.git/tree/doc/adapter-api.txt */
public class BluezAdapterProperties : BluezInterface {
    private string[] _uuids;
    private BluezAdapterBus adapter_bus;

    public string address {
        get { return this.get_cache("Address").get_string(); }
    }

    public string name {
        get { return this.get_cache("Name").get_string(); }
    }

    public string alias {
        get { return this.get_cache("Alias").get_string(); }
        set { try { this.set_bus("Alias", value); } catch {} }
    }

    public uint32 class {
        get { return this.get_cache("Class").get_uint32(); }
    }

    public bool powered {
        get { return this.get_cache("Powered").get_boolean(); }
        set { try { this.set_bus("Powered", value); } catch {} }
    }

    public bool discoverable {
        get { return this.get_cache("Discoverable").get_boolean(); }
        set { try { this.set_bus("Discoverable", value); } catch {} }
    }

    public bool pairable {
        get { return this.get_cache("Pairable").get_boolean(); }
        set { try { this.set_bus("Pairable", value); } catch {} }
    }

    public uint32 pairable_timeout {
        get { return this.get_cache("PairableTimeout").get_uint32(); }
        set { try { this.set_bus("PairableTimeout", value); } catch {} }
    }

    public uint32 discoverable_timeout {
        get { return this.get_cache("DiscoverableTimeout").get_uint32(); }
        set { try { this.set_bus("DiscoverableTimeout", value); } catch {} }
    }

    public bool discovering {
        get { return this.get_cache("Discovering").get_boolean(); }
        private set { /* should alreay been set */ }
    }

    public weak string[] uuids {
        get {
            _uuids = this.get_cache("UUIDs").get_strv();
            return _uuids;
        }
    }

    public BluezAdapterProperties(ObjectPath path,
                        HashTable<string, Variant>? props = null) {
        base("org.bluez.Adapter1", path, props);
        try {
            adapter_bus = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", path);
        } catch {}

    }

    public void remove_device(ObjectPath path) {
        try { adapter_bus.remove_device(path); } catch { }
    }

    public void start_discovery() {
        try { adapter_bus.start_discovery(); } catch  {}
    }

    public void stop_discovery() {
        try {  adapter_bus.stop_discovery(); } catch {}
    }

    public signal void alias_changed();
    public signal void powered_changed();
    public signal void discoverable_changed();
    public signal void pairable_changed();
    public signal void pairable_timeout_changed();
    public signal void discoverable_timeout_changed();
    public signal void discovering_changed();

    public override void property_changed(string prop, Variant val) {
        switch (prop) {
        case "Alias":
            alias_changed();
            break;
        case "Powered":
            powered_changed();
            break;
        case "Discoverable":
            discoverable_changed();
            break;
        case "Pairable":
            pairable_changed();
            break;
        case "PairableTimeout":
            pairable_timeout_changed();
            break;
        case "DiscoverableTimeout":
            discoverable_timeout_changed();
            break;
        case "Discovering":
            discovering_changed();
            break;
        }
    }
}

/* http://git.kernel.org/cgit/bluetooth/bluez.git/tree/doc/device-api.txt */
public class BluezDevice : BluezInterface {
    private string[] _uuids;
    private BluezDeviceBus device_bus;

    public string address {
        get { return this.get_cache("Address").get_string(); }
    }

    public string name {
        get { return this.get_cache("Name").get_string(); }
    }

    public string icon {
        get { return this.get_cache("Icon").get_string(); }
    }

    public uint32 class {
        get { return this.get_cache("Class").get_uint32(); }
    }

    public uint16 appearance {
        get { return this.get_cache("Appearance").get_uint16(); }
    }

    public weak string[] uuids {
        get {
            _uuids = this.get_cache("UUIDs").get_strv();
            return _uuids;
        }
    }

    public bool paired {
        get { return this.get_cache("Paired").get_boolean(); }
        private set { /* should aready be set, but needed for notify */ }
    }

    public bool connected {
        get { return this.get_cache("Connected").get_boolean(); }
        private set { /* should aready be set, but needed for notify */ }
    }

    public bool trusted {
        get { return this.get_cache("Trusted").get_boolean(); }
        set { try { this.set_bus("Trusted", value); } catch {} }
    }

    public bool blocked {
        get { return this.get_cache("Blocked").get_boolean(); }
        set { try { this.set_bus("Blocked", value); } catch {} }
    }

    public string alias {
        get { return this.get_cache("Alias").get_string(); }
        set { try { this.set_bus("Alias", value); } catch {}}
    }

    public string adapter {
        get { return this.get_cache("Adapter").get_string(); }
    }

    public bool legacy_pairing {
        get { return this.get_cache("LegacyPairing").get_boolean(); }
    }

    public BluezDevice(ObjectPath path,
                        HashTable<string, Variant>? props = null) {
        base("org.bluez.Device1", path, props);
        try {
            device_bus = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", path);
        } catch {}
    }

///    public void connect() {
///        try { device_bus.connect(); } catch {}
///    }

    public signal void alias_changed();
    public signal void paired_changed();
    public signal void connected_changed();
    public signal void trusted_changed();
    public signal void blocked_changed();

    public override void property_changed(string prop, Variant val) {
        switch (prop) {
        case "Alias":
            alias_changed();
            break;
        case "Paired":
            paired_changed();
            break;
        case "Connected":
            connected_changed();
            break;
        case "Trusted":
            trusted_changed();
            break;
        case "Blocked":
            blocked_changed();
            break;
        }
    }

}
#else
public class DevManager {
    public signal void device_added (DevDef s);
    public signal void device_removed (string s);
    private DevMask mask;
	public static SList<DevDef?> serials;

    public DevManager(DevMask _dm=(DevMask.BT|DevMask.USB)) {
        mask = _dm;
		serials = new SList<DevDef?>();
    }
    public void get_serial_devices() {
	}

	public static DevMask get_type_for_name(string name) {
		return 0;
	}
}


#endif

#if TEST

namespace MWPLog {
    void message(string format, ...) {
        var args = va_list();
        var now = new DateTime.now_local ();
        StringBuilder sb = new StringBuilder();
        sb.append(now.format("%T.%f"));
        sb.append_c(' ');
        sb.append_vprintf(format, args);
        stderr.puts(sb.str);
    }
}

public int main(string?[] args) {
    var d =  new DevManager();
    d.device_added.connect((dd) => {
            print("Add %s %s %d\n", dd.name, dd.alias, dd.type);
        });
    d.device_removed.connect((s) => {
            print("Remove %s\n", s);
        });

    var m = new MainLoop();
    m.run();
    return 0;
}
#endif
