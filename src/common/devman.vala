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
		uint id;
		int gid;
		int16 rssi;
}

#if LINUX
public class DevManager : Object {
	public static Bluez  btmgr;
	public static USBMgr usbmgr;
	public static SList<DevDef?> serials;
    public signal void device_added (DevDef dd);
    public signal void device_removed (string s);
	private static bool _init;
	public static bool is_discovering;
	public static bool use_disco;

	~DevManager() {
	}

	public static void stop_disco() {
		if(DevManager.use_disco) {
			btmgr.discovery(false);
		}
	}

	public DevManager(bool _use_disco = false) {
		if (!_init) {
			DevManager.use_disco = _use_disco;
			new BLEKnownUUids();
			_init = true;
			serials = new SList<DevDef?>();
			btmgr = new Bluez();
			btmgr.changed_device.connect((id) => {
					var d = btmgr.get_device(id);
					if(d.device_type == 0) {
						bool upd = false;
						var dd = upsert_bt(d, out upd);
						if(DevManager.use_disco) {
							MWPLog.message("%s\n", d.print());
						}
						if(DevManager.use_disco == false || dd.rssi != 0) {
							device_added(dd);
						}
					}
				});

			btmgr.changed_adapter.connect((op) => {
					if(DevManager.use_disco) {
						Timeout.add(200, () => {
								DevManager.is_discovering = btmgr.discovery(true);
								return false;
							});
					}
				});

			btmgr.init();

			usbmgr = new USBMgr();
			usbmgr.add_device_usb.connect((n,a) => {
					if (!extant(n)) {
						DevDef dd = DevDef(){ name = n, alias = a, type = DevMask.USB };
						serials.append(dd);
						device_added(dd);
					}
				});

			usbmgr.remove_device_usb.connect((n) => {
					remove_name(n);
					device_removed(n);
				});
			usbmgr.init();
		}
	}

	public void checkbts() {
		var btdevs = btmgr.get_devices();
		int mbts = 0;
		foreach(var dv in btdevs) {
			if(dv.device_type == 0) {
				mbts++;
				var dd = get_dd_for_name(dv.address);
				if (dd != null) {
					var uuids =  btmgr.get_device_property(dv.id, "UUIDs").dup_strv();
					if(uuids.length > 3 && dd.type != (DevMask.BTLE|DevMask.BT)) {
						MWPLog.message("BT: unexpected type for %s\n", dd.name);
					}
				} else {
					MWPLog.message("BT: missing %s\n", dv.address);
				}
			}
		}
		int nbts = 0;
		serials.@foreach((b) => {
				if((b.type & DevMask.BT) != 0) {
					nbts++;
				}
			});
		if(mbts != nbts) {
			MWPLog.message("BT: bluez %d, serials %d (should not happen)\n", mbts, nbts);
		}
	}

	public static void remove_name(string ds) {
		for( unowned var lp = serials; lp != null; ) {
			unowned var xlp = lp;
			lp = lp.next;
			if(((DevDef)xlp.data).name == ds) {
				serials.remove_link(xlp);
			}
		}
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

	public static DevMask get_type_for_name(string name) {
		for( unowned SList<DevDef?> lp = serials; lp != null; lp = lp.next) {
			var dd = (DevDef)lp.data;
			if(dd.name == name) {
				return dd.type;
			}
		}
		return 0;
	}

	public static  async bool wait_device_async(string addr) {
		var thr = new Thread<bool> (addr, () => {
				bool res = false;
				int cnt = 0;
				while(true) {
					var dd = get_dd_for_name(addr);
					if(dd != null) {
						res = true;
						break;
					} else {
						cnt += 1;
						if (cnt == 50) {
							break;
						}
						Thread.usleep(100*1000);
					}
				}
				Idle.add (wait_device_async.callback);
				return res;
			});
		yield;
		return thr.join();
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

	private static void update_dd(BluezDev.Device d, ref DevDef dd) {
		dd.id = d.id;
		dd.name = d.address;
		dd.alias = d.name;
		dd.rssi = d.rssi;
		dd.type = DevMask.BT;
		uint sid = 0;
		var uuids =  btmgr.get_device_property(d.id, "UUIDs").dup_strv();
		if (uuids.length > 0) {
			sid = BLEKnownUUids.verify_serial(uuids, out dd.gid);
			if(sid == 2) {
				dd.type |= DevMask.BTLE;
			}
		}
	}

	public static DevDef upsert_bt(BluezDev.Device d, out bool upd) {
		for( unowned SList<DevDef?> lp = serials; lp != null; lp = lp.next) {
			var dd = (DevDef)lp.data;
			if((dd.type & DevMask.USB) == 0) {
				if(dd.id == d.id) {
					upd = true;
					update_dd(d, ref dd);
					lp.data = dd;
					return dd;
				}
			}
		}
		var dd = DevDef();
		update_dd(d, ref dd);
		upd = false;
		serials.append(dd);
		return dd;
	}
}
#else
public class DevManager {
    public signal void device_added (DevDef s);
    public signal void device_removed (string s);
	public static SList<DevDef?> serials;

    public DevManager(bool unused=false) {
		serials = new SList<DevDef?>();
    }

	public void init() {}

    public void get_serial_devices() {}

	public static DevMask get_type_for_name(string name) {
		return 0;
	}

	public void checkbts() {}

	public static DevDef? get_dd_for_name(string name) {
		var dd = DevDef();
		dd.name = name;
		return dd;
	}

	public static async bool wait_device_async(string addr) {
		return true;
	}

	public static void stop_disco() {}
}
#endif
