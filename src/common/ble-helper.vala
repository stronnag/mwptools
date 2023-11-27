public class BleSerial : Object {
	private int done = 0;
	private int gid = 0;
	public BluezDevice bdev;
	public signal void completed(int i);

	private struct GattDev {
		string name;
		string svcuuid;
		string txuuid;
		string rxuuid;
	}

	private static GattDev [] gatts = {
		{
			"CC2541",
			"0000ffe0-0000-1000-8000-00805f9b34fb",
			"0000ffe1-0000-1000-8000-00805f9b34fb",
			"0000ffe1-0000-1000-8000-00805f9b34fb"
		}, {
			"Nordic Semi NRF",
			"6e400001-b5a3-f393-e0a9-e50e24dcca9e",
			"6e400003-b5a3-f393-e0a9-e50e24dcca9e",
			"6e400002-b5a3-f393-e0a9-e50e24dcca9e",
		}, {
			"SpeedyBee Type 2",
			"0000abf0-0000-1000-8000-00805f9b34fb",
			"0000abf1-0000-1000-8000-00805f9b34fb",
			"0000abf2-0000-1000-8000-00805f9b34fb"
		}, {
			"SpeedyBee Type 1",
			"00001000-0000-1000-8000-00805f9b34fb",
			"00001001-0000-1000-8000-00805f9b34fb",
			"00001002-0000-1000-8000-00805f9b34fb"
		}
	};

	public BleSerial() {
		done = 0;
	}

	public string? get_chipset(int j) {
		if (j >= 0 && j < gatts.length) {
			return gatts[j].name;
		} else {
			return null;
		}
	}

	public int find_service() {
		gid = -1;
		for (var j = 0; j < gatts.length; j++) {
			if (DevManager.btmgr.find_gatt_service(gatts[j].svcuuid)) {
				gid= j;
				break;
			}
		}
		return gid;
	}

	public int get_bridge_fds(int j, out int rxfd, out int txfd) {
		uint16 rxmtu;
		uint16 txmtu;
		var txuuid = gatts[j].txuuid;
		var rxuuid = gatts[j].rxuuid;
		txfd = get_fd_for_characteristic(txuuid, "AcquireWrite",  out txmtu);
		rxfd = get_fd_for_characteristic(rxuuid, "AcquireNotify", out rxmtu);
		return (txmtu < rxmtu) ? txmtu : rxmtu;
	}

	private int get_fd_for_characteristic(string uuid, string callname, out uint16 mtu) {
		int fd = -1;
		mtu = 0;
		UnixFDList fdl;
		var path =  DevManager.btmgr.get_gatt_characteristic_path(uuid);
		//message("get fd for %d %s %s %s\n", gid, path, callname, uuid);

		if(path != null) {
			try {
				var options = new Variant("a{sv}");
				var v = new Variant.tuple({options});
				var proxy =  new DBusProxy.for_bus_sync (BusType.SYSTEM, DBusProxyFlags.NONE,
														 null, "org.bluez", path,
														 "org.bluez.GattCharacteristic1");
				var res = proxy.call_with_unix_fd_list_sync(callname, v, DBusCallFlags.NONE, -1,
															null, out fdl);
				var v0 = res.get_child_value(0);
				int32 hdl = v0.get_handle();
				v0 = res.get_child_value(1);
				mtu = v0.get_uint16();
				fd = fdl.get(hdl);
			} catch (Error e) {
				MWPLog.message("get fdl %s\n", e.message);
			}
		}
		return fd;
	}
}