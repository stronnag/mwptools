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
		bool used;
}

#if LINUX
public class DevManager : Object {
	public static BluetoothMgr btmgr;
	public static USBMgr usbmgr;
	public static SList<DevDef?> serials;
    public signal void device_added (DevDef dd);
    public signal void device_removed (string s);
	private static bool _init;
    public DevManager() {
		if (!_init) {
			_init = true;
			serials = new SList<DevDef?>();
			btmgr = new BluetoothMgr();
			btmgr.add_device_bt.connect((n,a,t) => {
					if(!extant(n)) {
						var _type = DevMask.BT;
						if (t == 2) {
							_type |= DevMask.BTLE;
						}
						DevDef dd = DevDef(){ name = n, alias = a, type = _type };
						serials.append(dd);
						device_added(dd);
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
