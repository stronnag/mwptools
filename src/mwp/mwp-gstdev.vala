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

namespace GstDev {
	List<GstMonitor.VideoDev?> viddevs;
	Gtk.ComboBoxText viddev_c;

	public void init() {
		viddevs = new List<GstMonitor.VideoDev?> ();
		CompareFunc<GstMonitor.VideoDev?>  devname_comp = (a,b) =>  {
			return strcmp(a.devicename, b.devicename);
		};
		viddev_c = new Gtk.ComboBoxText();
		GstMonitor gstdm;
		gstdm = new GstMonitor();
		gstdm.source_changed.connect((a,d) => {
				bool act = false;
				switch (a) {
				case "add":
				case "init":
					if(viddevs.find_custom(d, devname_comp) == null) {
						viddevs.append(d);
						viddev_c.append(d.devicename, d.displayname);
						viddev_c.active_id = d.devicename;
						act = true;
					}
					break;
				case "remove":
					unowned List<GstMonitor.VideoDev?> da  = viddevs.find_custom(d, devname_comp);
					if (da != null) {
						viddevs.remove_link(da);
						Mwp.remove_combo(viddev_c, d.displayname);
						act = true;
					}
					break;
				}
				if(act)
					MWPLog.message("GST: \"%s\" <%s> <%s>\n", a, d.displayname, d.devicename);
				if((Mwp.debug_flags & Mwp.DEBUG_FLAGS.VIDEO) == Mwp.DEBUG_FLAGS.VIDEO) {
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
