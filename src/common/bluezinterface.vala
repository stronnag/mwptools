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
    [DBus (name = "Get")]
    public abstract Variant get(string iface, string name)
                               throws DBusError, IOError;
    [DBus (name = "GetAll")]
    public abstract HashTable<string, Variant> get_all(string iface)
                                                throws DBusError, IOError;

    public signal void properties_changed(string iface,
                                          HashTable <string, Variant> changed,
                                          string[] invalidated);
}

[DBus (name = "org.bluez.AgentManager1")]
interface BluezAgentManagerBus : GLib.Object {
    [DBus (name = "RegisterAgent")]
    public abstract void register_agent(ObjectPath agent, string capability) throws DBusError, IOError;
    [DBus (name = "RequestDefaultAgent")]
    public abstract void request_default_agent(ObjectPath agent) throws DBusError, IOError;
}

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
    [DBus (name = "CancelPairing")]
    public abstract void cancel_pairing() throws DBusError, IOError;
    [DBus (name = "Connect")]
    public abstract void connect() throws DBusError, IOError;
    [DBus (name = "ConnectProfile")]
    public abstract void connect_profile(string UUID) throws DBusError, IOError;
    [DBus (name = "Disconnect")]
    public abstract void disconnect() throws DBusError, IOError;
    [DBus (name = "DisonnectProfile")]
    public abstract void disconnect_profile(string UUID) throws DBusError, IOError;
    [DBus (name = "Pair")]
    public abstract void pair() throws DBusError, IOError;
}

public abstract class BluezInterface : GLib.Object {
    DBusProperties bus;
    string iface_name;
    HashTable<string, Variant> property_cache;

    public ObjectPath object_path = null;

    internal BluezInterface(string name, ObjectPath path,
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
        } catch (Error e) {
            stderr.printf("%s\n", e.message);
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
                return; /* continue foreach */
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
        set { try { this.set_bus("Alias", value); } catch {}}
    }

    public uint32 class {
        get { return this.get_cache("Class").get_uint32(); }
    }

    public bool powered {
        get { return this.get_cache("Powered").get_boolean(); }
        set { try { this.set_bus("Powered", value); } catch {}}
    }

    public bool discoverable {
        get { return this.get_cache("Discoverable").get_boolean(); }
        set { try { this.set_bus("Discoverable", value); } catch {}}
    }

    public bool pairable {
        get { return this.get_cache("Pairable").get_boolean(); }
        set { try { this.set_bus("Pairable", value); } catch {}}
    }

    public uint32 pairable_timeout {
        get { return this.get_cache("PairableTimeout").get_uint32(); }
        set { try { this.set_bus("PairableTimeout", value); } catch {}}
    }

    public uint32 discoverable_timeout {
        get { return this.get_cache("DiscoverableTimeout").get_uint32(); }
        set { try { this.set_bus("DiscoverableTimeout", value); } catch {}}
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
        } catch (Error e) {
            stderr.printf("%s\n", e.message);
        }
    }

    public void remove_device(ObjectPath path) {
        try {
            adapter_bus.remove_device(path);
        } catch (Error e) {
            stderr.printf("%s\n", e.message);
        }
    }

    public void start_discovery() {
        try {
            adapter_bus.start_discovery();
        } catch (Error e) {
            stderr.printf("%s\n", e.message);
        }
    }

    public void stop_discovery() {
		try {
			adapter_bus.stop_discovery();
		} catch (Error e) {
            stderr.printf("%s\n", e.message);
        }
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

		set { try { this.set_bus("Alias", value); } catch {} }
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
		} catch (Error e) {
            stderr.printf("%s\n", e.message);
		}
    }

    public new bool connect() {
		bool res = true;
		try {
			device_bus.connect();
		} catch (Error e) {
            stderr.printf("%s\n", e.message);
			res = false;
		}
		return res;
    }

    public new void disconnect() {
		try {
			device_bus.disconnect();
		} catch (Error e) {
            stderr.printf("%s\n", e.message);
		}
    }


    public signal void alias_changed();
    public signal void paired_changed();
    public signal void connected_changed(bool v);
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
            connected_changed((bool)val);
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
