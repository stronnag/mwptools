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

namespace GstDev {
	public struct VideoDev {
		string devicename;
		string displayname;
	}
	List<GstDev.VideoDev?> viddevs;
	Gtk.StringList sl;

	public string? get_device(string m) {
		for (unowned List<GstDev.VideoDev?>lp = viddevs.first(); lp != null; lp = lp.next)  {
			var dv = lp.data;
			if (dv.displayname == m) {
				return dv.devicename;
			}
		}
		return null;
	}

	/*
	  Ugly, but fits in extant POSIX APIs
	 */
	private void clear_lists() {
		while(!viddevs.is_empty()) {
			viddevs.remove_link(viddevs);
		}
		for(var j = 1; j < sl.get_n_items(); j++) {
			var dname = sl.get_string(j);
			if (dname != "(None)") {
				sl.remove(j);
			}
		}
	}

	private VideoDev? get_node_info(Gst.Device device) {
		VideoDev ds = {};
		ds.displayname = device.display_name;
		var s = device.get_properties();
		if (s == null) {
			ds.devicename = device.display_name;
		}
		if(s != null) {
			var dn = s.get_string("api.v4l2.path");
			if (dn == null)
				dn = s.get_string("device.path");
			if (dn == null)
				dn = s.get_string("device.name");
			if (dn != null) {
				ds.devicename = dn;
			} else {
				ds.devicename = ds.displayname;
			}
		}
		return ds;
	}

	public void find_cameras() {
		clear_lists();
		var monitor = new Gst.DeviceMonitor ();
		var caps = new Gst.Caps.empty_simple ("video/x-raw");
		var cid= monitor.add_filter ("Video/Source", caps);
		caps = new Gst.Caps.empty_simple ("image/jpeg");
		cid = monitor.add_filter ("Video/Source", caps);
		monitor.start();
		var devs = monitor.get_devices();
		if (devs != null) {
			devs.@foreach((dv) => {
					var d = get_node_info(dv);
					if(d != null) {
						viddevs.append(d);
						sl.append(d.displayname);
					}
				});
		}
		monitor.stop();
	}

	public void init() {
		sl = new Gtk.StringList({"(None)"});
		viddevs = new List<GstDev.VideoDev?> ();
	}
}
