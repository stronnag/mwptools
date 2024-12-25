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

public class MwpCombox : Gtk.Frame {
	public Gtk.Entry entry;
	private GLib.Menu menu;

	public MwpCombox() {
		entry = new Gtk.Entry();
		var button = new Gtk.MenuButton();
		var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
		menu = new GLib.Menu();
		button.menu_model = menu;
		box.append(entry);
		box.append(button);
		set_child(box);
		if (button.popover != null) {
			button.popover.has_arrow=false;
		}
		entry.activate.connect(() => {
				append(entry.text);
			});
	}

	public void append(string label) {
		var mi = new GLib.MenuItem(label, null);
		mi.set_action_and_target("menu.item", "s", label);
		menu.append_item(mi);
		if(menu.get_n_items() == 0) {
			entry.text = label;
		}
	}

	public void set_text(string t) {
		entry.text = t;
	}

	public string get_text() {
		return entry.text;
	}

	public void set_active(int i) {
		var nm = menu.get_n_items();
		if(nm > 0) {
			var v = menu.get_item_attribute_value(i, "target", VariantType.STRING);
			if(v != null) {
				entry.text = (string)v;
			}
		} else {
			entry.text = "";
		}
	}

	public int  get_active() {
		return find_item(entry.text);
	}

	public void prepend(string label) {
		var mi = new GLib.MenuItem(label, null);
		mi.set_action_and_target("menu.item", "s", label);
		menu.prepend_item(mi);
		entry.text = label;
	}

	public int find_item(string t) {
		int n = -1;
		var nm = menu.get_n_items();
		for(int j = 0; j < nm; j++) {
			var v = menu.get_item_attribute_value(j, "target", VariantType.STRING);
			if(v != null &&  (string)v == t) {
				n = j;
				break;
			}
		}
		return n;
	}

	public int find_prefix(string t) {
		int n = -1;
		var nm = menu.get_n_items();
		for(int j = 0; j < nm; j++) {
			var v = menu.get_item_attribute_value(j, "target", VariantType.STRING);
			if (v != null) {
				string cs = (string)v;
				bool has_s = cs.contains(" ");
				if((has_s && cs.has_prefix(t)) || cs == t) {
					n = j;
					break;
				}
			}
		}
		return n;
	}

	public string[] get_list() {
		string[] sl={};
		var nm = menu.get_n_items();
		for(int j = 0; j < nm; j++) {
			var v = menu.get_item_attribute_value(j, "target", VariantType.STRING);
			if (v != null) {
				sl += (string)v;
			}
		}
		return sl;
	}

	public void remove_item(int n) {
		menu.remove(n);
	}

	public void remove_all() {
		menu.remove_all();
	}

	public void remove(string t) {
		var n = find_item(t);
		if (n != -1) {
			if(t == entry.text) {
				var v = menu.get_item_attribute_value(0, "target", VariantType.STRING);
				var ms =  (v == null) ? "" : (string)v;
				entry.text = ms;
			}
			menu.remove(n);
		}
	}
}
