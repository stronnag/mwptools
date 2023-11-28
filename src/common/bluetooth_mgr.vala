#if LINUX

public class BluetoothMgr : Object {
    DBusObjectManager manager;
    BluezAdapterProperties adapter;
    HashTable<ObjectPath, HashTable<string, HashTable<string, Variant>>> objects;

	public signal void add_device_bt(string name, string alias, int add);

    public BluetoothMgr() {
        try {
            manager = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", "/");
            objects = manager.get_managed_objects();
            find_adapter();
			manager.interfaces_added.connect((path, interfaces) => {
					objects.insert(path, interfaces);
					HashTable<string, Variant>? props;
					props = interfaces.get("org.bluez.Device1");
					if (props != null) {
						add_device(path, props);
					}
				});
        } catch (Error e) {
            MWPLog.message ("%s\n", e.message);
        }
	}

	public void init() {
        find_devices();
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
        });
    }

    private void add_device(ObjectPath path, HashTable<string, Variant> props) {
		var name = props.get("Address").get_string();
		var alias = props.get("Alias").get_string();
		var uuids = props.get("UUIDs");
		var uus = uuids.get_strv();
		var add = 0;
		foreach (var u in uus) {
			if(u.contains("00001101")) {
				add = 1;
				break;
			} else if (u == "0000abf0-0000-1000-8000-00805f9b34fb" ||
					   u == "0000ffe0-0000-1000-8000-00805f9b34fb" ||
					   u == "6e400001-b5a3-f393-e0a9-e50e24dcca9e" ||
					   u == "00001000-0000-1000-8000-00805f9b34fb") {
				add  = 2;
				break;
			}
		}
		if (add != 0) {
			add_device_bt(name, alias, add);
		}
    }

    private void find_devices() {
		List <unowned ObjectPath> lk = objects.get_keys();
		for (unowned var lp = lk.first(); lp != null; lp = lp.next) {
			var path = lp.data;
			var ifaces = objects.get(path);
			HashTable<string, Variant>? props = ifaces.get("org.bluez.Device1");
			if (props != null) {
				add_device(path, props);
			}
		}
    }

	public BluezDevice? get_device(string address, out string? dpath) {
		dpath = null;
		List <unowned ObjectPath> lk = objects.get_keys();
		for (unowned var lp = lk.first(); lp != null; lp = lp.next) {
			var path = lp.data;
			var ifaces = objects.get(path);
			HashTable<string, Variant>? props = ifaces.get("org.bluez.Device1");
			if (props != null) {
				if (props.get("Address").get_string() == address) {
					dpath = (string)path;
					return new  BluezDevice(path, props);
				}
			}
		}
		return null;
	}

	public string? find_gatt_service(string srvuuid, string dpath) {
		List <unowned ObjectPath> lk = objects.get_keys();
		for (unowned var lp = lk.first(); lp != null; lp = lp.next) {
			var path = lp.data;
			var ifaces = objects.get(path);
			HashTable<string, Variant>? props = ifaces.get("org.bluez.GattService1");
			if (props != null) {
				var uuid = props.get("UUID");
				var devp = props.get("Device").get_string();
				if (uuid.get_string() == srvuuid && devp == dpath) {
					return (string)path;
				}
			}
		}
		return null;
	}

	public string? get_gatt_characteristic_path(string chuuid) {
		List <unowned ObjectPath> lk = objects.get_keys();
		for (unowned var lp = lk.first(); lp != null; lp = lp.next) {
			var path = lp.data;
			var ifaces = objects.get(path);
			HashTable<string, Variant>? props = ifaces.get("org.bluez.GattCharacteristic1");
			if (props != null) {
				var uuid = props.get("UUID");
				if (uuid.get_string() == chuuid) {
					// var devp = props.get("Service");
					// message("Service %s for %s\n", chuuid, devp.get_string());
					return path;
				}
			}
		}
		return null;
	}
}
#endif
