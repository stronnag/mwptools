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
	public Gtk.StringList sl;
	private void clear_lists() {
		for(var j = 1; j < sl.get_n_items(); j++) {
			var dname = sl.get_string(j);
			if (dname != "(None)") {
				sl.remove(j);
			}
		}
	}

	public List<Gst.Device>get_camera_list() {
		var monitor = new Gst.DeviceMonitor ();
		var caps = new Gst.Caps.empty_simple ("video/x-raw");
		var cid= monitor.add_filter ("Video/Source", caps);
		caps = new Gst.Caps.empty_simple ("image/jpeg");
		cid = monitor.add_filter ("Video/Source", caps);
		monitor.start();
		var devs = monitor.get_devices();
		monitor.stop();
		return devs;
	}


	public void find_cameras() {
		clear_lists();
		var devs = get_camera_list();
		if (devs != null) {
			devs.@foreach((dv) => {
					var d = dv.display_name;
					if(d != null) {
						sl.append(d);
					}
				});
		}

	}

	public void init() {
		sl = new Gtk.StringList({"(None)"});
	}
}
