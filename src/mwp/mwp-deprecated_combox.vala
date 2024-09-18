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

namespace Mwp {
	private bool dev_is_bt(DevDef dd) {
		return ((dd.type & (DevMask.BT|DevMask.BTLE)) != 0);
	}

	private string devname_for_dd(DevDef dd) {
		StringBuilder sbd = new StringBuilder();
		sbd.append(dd.name);
		sbd.append_c(' ');
		sbd.append(dd.alias);
		return sbd.str;
	}

	public void build_serial_combo() {
		dev_combox.remove_all ();
		DevManager.serials.foreach((dd) => {
				if (!dev_is_bt(dd)) {
					prepend_combo(dev_combox, devname_for_dd(dd));
				}
			});

		foreach(string a in conf.devices) {
			dev_combox.append_text(a);
		}

		DevManager.serials.foreach((dd) => {
				if (dev_is_bt(dd)) {
					if(!conf.bluez_disco || dd.rssi != 0) {
						append_combo(dev_combox, devname_for_dd(dd));
					}
				}
			});

		var ss = list_combo(dev_combox);
		if (ss.length > 0) {
			dev_entry.text = ss[0];;
		}
	}

	public string?[] list_combo(Gtk.ComboBoxText cbtx, int id=0) {
		string[] items={};
		var m = cbtx.get_model();
		Gtk.TreeIter iter;
		bool next;

		for(next = m.get_iter_first(out iter); next; next = m.iter_next(ref iter)) {
			GLib.Value cell;
			m.get_value (iter, id, out cell);
			items += (string)cell;
		}
		return items;
	}

	private int find_combo(Gtk.ComboBoxText cbtx, string s, int id=0) {
		var m = cbtx.get_model();
		Gtk.TreeIter iter;
		int i,n = -1;
		bool next;

		for(i = 0, next = m.get_iter_first(out iter); next; next = m.iter_next(ref iter), i++) {
			GLib.Value cell;
			m.get_value (iter, id, out cell);
			string cs = (string)cell;

			bool has_s = cs.contains(" ");

			if((has_s && ((string)cell).has_prefix(s)) || ((string)cell == s)) {
				n = i;
				break;
			}
		}
		return n;
	}

	private int append_combo(Gtk.ComboBoxText cbtx, string s) {
		if(Radar.lookup_radar(s))
			return -1;

		if(s == forward_device)
			return -1;

		var n = find_combo(cbtx, s);
		if (n == -1) {
			cbtx.append_text(s);
			n = 0;
		}

		//check_pref_dev();

		if(cbtx.active == -1)
			cbtx.active = 0;

		TelemTracker.ttrk.add(s);
		return n;
	}

	private void prepend_combo(Gtk.ComboBoxText cbtx, string s) {
		if(Radar.lookup_radar(s))
			return;

		if(s == forward_device)
			return;

		var n = find_combo(cbtx, s);
		if (n == -1) {
			cbtx.prepend_text(s);
			cbtx.active = 0;
		} else {
			cbtx.active = n;
		}
		TelemTracker.ttrk.add(s);
	}

	private void remove_combo(Gtk.ComboBoxText cbtx,string s) {
		TelemTracker.ttrk.remove(s);
		foreach(string a in conf.devices) {
			if (a == s)
				return;
		}

		var n = find_combo(cbtx, s);
		if (n != -1) {
			cbtx.remove(n);
			cbtx.active = 0;
		}
	}
}
