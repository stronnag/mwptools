public class BleSerial : Object {
	private int gid;

	public BleSerial(int _g = -1) {
		gid = _g;
	}

	public void set_gid(int _g) {
		gid = _g;
	}

	private int get_fd_for_characteristic(ObjectPath path, string callname, out uint16 mtu) {
		int fd = -1;
		mtu = 0;
		UnixFDList fdl;
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
				print("get fdl %s\n", e.message);
			}
		}
		return fd;
	}

	public string? get_chipset() {
		return BLEKnownUUids.get(gid).name;
	}

	public int get_bridge_fds(Bluez bt, out int rxfd, out int txfd) {
		uint16 rxmtu = 0;
		uint16 txmtu = 0;
		var	txpath = bt.find_gatt_characteristic_path(BLEKnownUUids.get(gid).txuuid);
		var rxpath = bt.find_gatt_characteristic_path(BLEKnownUUids.get(gid).rxuuid);
		rxfd = get_fd_for_characteristic(rxpath, "AcquireNotify", out rxmtu);
		if (txpath != rxpath) {
			txfd = get_fd_for_characteristic(txpath, "AcquireWrite",  out txmtu);
		} else {
			txfd = rxfd;
			txmtu = rxmtu;
		}
		return (int) ((txmtu < rxmtu) ? txmtu : rxmtu);
	}

	public bool find_service(Bluez bt, uint id) {
		if(gid != -1) {
			return bt.find_service(id,  BLEKnownUUids.get(gid).svcuuid);
		}
		return false;
	}
}