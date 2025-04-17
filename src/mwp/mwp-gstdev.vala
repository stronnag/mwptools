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
	List<GstMonitor.VideoDev?> viddevs;
	Gtk.DropDown viddev_c;
	Gtk.StringList sl;

	public string? get_device(string m) {
		for (unowned List<GstMonitor.VideoDev?>lp = viddevs.first(); lp != null; lp = lp.next)  {
			var dv = lp.data;
			if (dv.displayname == m) {
				return dv.devicename;
			}
		}
		return null;
	}

	public void init() {
		sl = new Gtk.StringList({"(None)"});
		viddevs = new List<GstMonitor.VideoDev?> ();
		CompareFunc<GstMonitor.VideoDev?>  devname_comp = (a,b) =>  {
			return strcmp(a.devicename, b.devicename);
		};
		viddev_c = new Gtk.DropDown(sl, null);
		GstMonitor gstdm;
		gstdm = new GstMonitor();
		gstdm.source_changed.connect((a,d) => {
				bool act = false;
				switch (a) {
				case "add":
				case "init":
					if(viddevs.find_custom(d, devname_comp) == null) {
						viddevs.append(d);
						sl.append(d.displayname);
						act = true;
					}
					break;
				case "remove":
					unowned List<GstMonitor.VideoDev?> da  = viddevs.find_custom(d, devname_comp);					if (da != null) {
						uint pos=-1;
						for(var j = 0; j < sl.get_n_items(); j++) {
							if (sl.get_string(j) == da.data.displayname) {
								pos = j;
								break;
							}
						}
						if(pos != -1) {
							sl.remove(pos);
						}
						act = true;
						viddevs.remove_link(da);
					}
					break;
				}
				if(act) {
					MWPLog.message("GST: \"%s\" <%s> <%s>\n", a, d.displayname, d.devicename);
				}
				if((Mwp.debug_flags & Mwp.DebugFlags.VIDEO) == Mwp.DebugFlags.VIDEO) {
					//					viddevs.@foreach((d) =>
					for (unowned List<GstMonitor.VideoDev?>lp = viddevs.first(); lp != null; lp = lp.next)  {
						var dv = lp.data;
						MWPLog.message("VideoDevs <%s> <%s>\n", dv.devicename, dv.displayname);
					}
				}
			});
		if (Environment.get_variable("MWP_NODEVMON") == null) {
			gstdm.setup_device_monitor();
		}
	}
}
