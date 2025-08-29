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

#if WINDOWS
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
				MWPLog.message(":DBG:WCAM: remove %d %s\n", j, dname);
				sl.remove(j);
			} else {
				MWPLog.message(":DBG:WCAM: keep %d %s\n", j, dname);
			}
		}
	}

	public void wincams() {
		string clist = WinCam.get_cameras();
		if (clist != null) {
			clear_lists();
			MWPLog.message(":DBG:WCAM - [%s]\n", clist);
			var parts = clist.split("\t");
			MWPLog.message(":DBG:WCAM - parts=%u\n", parts.length);
			foreach(var p in parts) {
				MWPLog.message(":DBG:WCAM - Add [%s]\n", p);
				var d =  GstMonitor.VideoDev();
				d.devicename=p;
				d.displayname=p;
				viddevs.append(d);
				sl.append(d.displayname);
			}
		} else {
			MWPLog.message(":DBG:WCAM - no camera\n");
		}
	}
#endif

	public void init() {
		sl = new Gtk.StringList({"(None)"});
		viddevs = new List<GstMonitor.VideoDev?> ();
#if (LINUX || FREEBSD)
		CompareFunc<GstMonitor.VideoDev?>  devname_comp = (a,b) =>  {
			return strcmp(a.devicename, b.devicename);
		};
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
#endif
	}
}
