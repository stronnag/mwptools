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
		string uuid;
		DevMask type;
		uint id;
		int gid;
		bool used;
}

#if LINUX
public class DevManager : Object {
	public static Bluez  btmgr;
	public static USBMgr usbmgr;
	public static SList<DevDef?> serials;
    public signal void device_added (DevDef dd);
    public signal void device_removed (string s);
	private static bool _init;

	private async bool add_bt_device_async (uint id, out DevDef dd) {
		DevDef _dd = DevDef();
		var thr = new Thread<bool> ("btnew", () => {
				var res = add_bt_device(id, out _dd);
				Idle.add (add_bt_device_async.callback);
				return res;
			});
		yield;
		dd = _dd;
		return thr.join();
	}

	private bool add_bt_device(uint id, out DevDef dd) {
		dd = DevDef();
		uint sid = 0;
		var d = btmgr.get_device(id);
		if(!extant(d.address)) {
			dd.id = id;
			dd.name = d.address;
			dd.alias = d.name;
			dd.type=DevMask.BT;
			Thread.usleep(10000);
			var uuids =  btmgr.get_device_property(id, "UUIDs").dup_strv();
			message("get uuids %u %u", id, uuids.length);
			sid = BLEKnownUUids.verify_serial(uuids, out dd.gid);
			message("get sid, gid %u %d", sid, dd.gid);
			if(dd.gid == 2) {
				dd.type |= DevMask.BTLE;
			}
		}
		return (sid != 0);
	}

    public DevManager() {
		if (!_init) {
			new BLEKnownUUids();
			_init = true;
			serials = new SList<DevDef?>();
			btmgr = new Bluez();
			btmgr.added_device.connect((id) => {
					message("add BT %u", id);
					add_bt_device_async.begin(id, (obj, res) => {
							DevDef dd;
							var dres = add_bt_device_async.end(res, out dd);
							if (dres) {
								serials.append(dd);
								device_added(dd);
							}
						});
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
		foreach(var dv in btmgr.get_devices()) {
			DevDef dd;
			if(add_bt_device(dv.id, out dd)) {
				serials.append(dd);
				device_added(dd);
			}
			message(dv.print());
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

	public static DevDef? get_dd_for_name(string name) {
		for( unowned SList<DevDef?> lp = serials; lp != null; lp = lp.next) {
			var dd = (DevDef)lp.data;
			if(dd.name == name) {
				return dd;
			}
		}
		return null;
	}

    public void get_serial_devices() {
	}

}
#else
public class DevManager {
    public signal void device_added (DevDef s);
    public signal void device_removed (string s);
	public static SList<DevDef?> serials;

    public DevManager() {
		serials = new SList<DevDef?>();
    }

	public void init() {
	}

    public void get_serial_devices() {
	}

	public static DevMask get_type_for_name(string name) {
		return 0;
	}

	public static DevDef? get_dd_for_name(string name) {
		var dd = DevDef();
		dd.name = name;
		return dd;
	}
}
#endif
