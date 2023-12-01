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

	private bool add_bt_device(BTDevice d, out DevDef dd) {
		dd={};
		if(!extant(d.address)) {
			dd = DevDef();
			dd.type = DevMask.BT;
			uint sid = 0;
			var uuids =  btmgr.get_device_property(d.id, "UUIDs").dup_strv();
			if (uuids.length > 0) {
				sid = BLEKnownUUids.verify_serial(uuids, out dd.gid);
				if(sid == 2) {
					dd.type |= DevMask.BTLE;
				}
			}
			dd.id = d.id;
			dd.name = d.address;
			dd.alias = d.name;
			return true;
		}
		return (false);
	}

    public DevManager() {
		if (!_init) {
			new BLEKnownUUids();
			_init = true;
			serials = new SList<DevDef?>();
			btmgr = new Bluez();
			btmgr.added_device.connect((id) => {
					var d = btmgr.get_device(id);
					if(d.device_type == 0) {
						DevDef dd;
						var dres = add_bt_device(d, out dd);
						if (dres) {
							serials.append(dd);
							device_added(dd);
						}
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
