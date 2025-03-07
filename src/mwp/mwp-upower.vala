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
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

using GLib;

namespace UPower {
    [DBus (name = "org.freedesktop.UPower")]
    public interface Base : Object {
        public abstract string daemon_version {owned get;}
        public abstract bool on_battery {get;}
        public abstract void get_display_device(out ObjectPath display_device) throws Error;
    }

    //     <property type="u" name="WarningLevel" access="read"/>
    [CCode (type_signature = "u")]
    public enum DeviceWarningLevel {
        UNKNOWN = 0,
        NONE = 1,
        DISCHARGING = 2, // UPS ....
        LOW = 3,
        CRITICAL = 4,
        ACTION = 5
    }

    //  Battery Level (battery_level) 'u'
    [CCode (type_signature = "u")]
    public enum BatteryLevel {
        UNKNOWN = 0,
        NONE, // (the battery does not use a coarse level of battery reporting)
        LOW = 3,
        CRITICAL = 4,
        NORMAL = 6,
        HIGH = 7,
        FULL = 8
    }

/*
  'State'  read      'u'
  The battery power state.
  This property is only valid if the property type has the value "battery".
*/
    [CCode (type_signature = "u")]
    public enum BatteryState {
        UNKNOWN = 0,
        CHARGING,
        DISCHARGING,
        EMPTY,
        FULLY_CHARGED,
        PENDING_CHARGE,
        PENDING_DISCHARGE
    }
/*
  The "Type" property
  'Type'  read      'u'
  Type of power source.
  0: Unknown
  1: Line Power
  2: Battery
  3: Ups
  4: Monitor
  5: Mouse
  6: Keyboard
  7: Pda
  8: Phone
*/

    [DBus (name = "org.freedesktop.DBus.Properties")]
    public interface Prop : Object {
        public signal void properties_changed(string iface, HashTable<string,Variant> changed, string[] invalid);
    }
	// Subset of properties needed.
    [DBus (name = "org.freedesktop.UPower.Device")]
    public interface Device : Object {
        public abstract double percentage {get;}
        public abstract uint32 state {get;}
        public abstract DeviceWarningLevel warning_level {get;}
        public abstract int64 time_to_empty {get;}
    }
}

public class PowerState : Object {
    private const string UPOWER_PATH = "/org/freedesktop/UPower";
    private const string UPOWER_NAME = "org.freedesktop.UPower";
    private UPower.Device dev;
    private UPower.Prop prop;
    public signal void host_power_alert(string alert);

    public PowerState() {
    }

    public bool init() {
        bool ok = false;
        try {
            UPower.Base bas = Bus.get_proxy_sync(BusType.SYSTEM,UPOWER_NAME,UPOWER_PATH);
            ObjectPath objp;
            bas.get_display_device(out objp);
            dev = Bus.get_proxy_sync(BusType.SYSTEM, UPOWER_NAME, objp);
            if(dev != null) {
                ok = true;
                prop = Bus.get_proxy_sync(BusType.SYSTEM, UPOWER_NAME, objp);
                prop.properties_changed.connect( (s,c,i) => {
                        if (c.contains("Percentage") || c.contains("State") || c.contains("WarningLevel")) {
                            if (dev.state == UPower.BatteryState.DISCHARGING &&
                                (dev.warning_level == UPower.DeviceWarningLevel.LOW ||
                                 dev.warning_level == UPower.DeviceWarningLevel.CRITICAL ||
                                 dev.warning_level == UPower.DeviceWarningLevel.ACTION)) {
                                StringBuilder sb = new StringBuilder("Host Power ");
                                sb.append(battery_warning());
                                sb.append_printf(", %.0f%%", dev.percentage);
                                if(dev.time_to_empty > 0) {
                                    var mins = dev.time_to_empty / 60;
                                    var secs = dev.time_to_empty % 60;
                                    sb.append_printf(", %d:%02d remaining", (int)mins,(int)secs);
                                }
                                host_power_alert(sb.str);
                            }
                        }
                    });
            }
        } catch (Error e) {
                MWPLog.message("UPower: %s\n",e.message);
        }
        return ok;
    }

    public string show_status() {
        return "Host power: %0.f%%, state: %s (%u), warn: %s (%u)".printf(
            dev.percentage, bstate(), dev.state, battery_warning(), dev.warning_level);
    }

    public string bstate() {
        string bstate="";
        switch(dev.state) {
            case UPower.BatteryState.UNKNOWN:
                bstate = "Unknown";
                break;
            case UPower.BatteryState.CHARGING:
                bstate = "Charging";
                break;
            case UPower.BatteryState.DISCHARGING:
                bstate = "Discharging";
                break;
            case UPower.BatteryState.EMPTY:
                bstate = "Empty";
                break;
            case UPower.BatteryState.FULLY_CHARGED:
                bstate = "Fully Charged";
                break;
            case UPower.BatteryState.PENDING_CHARGE:
                bstate = "Pending Charge";
                break;
            case UPower.BatteryState.PENDING_DISCHARGE:
                bstate = "Pending Discharge";
                break;
        }
        return bstate;
    }

    public string battery_warning() {
        string warn = "";
        switch (dev.warning_level) {
            case UPower.DeviceWarningLevel.UNKNOWN:
            case UPower.DeviceWarningLevel.NONE:
                warn = "None";
                break;
            case UPower.DeviceWarningLevel.DISCHARGING:
                warn = "Discharging";
                break;
            case UPower.DeviceWarningLevel.LOW:
                warn = "Low";
                break;
            case UPower.DeviceWarningLevel.CRITICAL:
                warn = "Very low";
                break;
            case UPower.DeviceWarningLevel.ACTION:
                warn = "Critical!";
                break;
        }
        return warn;
    }
}

#if TESTPOWER
public int main(string[]args) {
    var p = new PowerState();
    if(p.init()) {
        print("%s\n", p.show_status());
        var loop = new MainLoop();
        loop.run(/* */);
    }
    return 0;
}
#endif
