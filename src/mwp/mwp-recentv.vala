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

public class RecentVideo : Gtk.Box {
	public Gtk.Entry entry;
	private GLib.Menu menu;
	private GLib.SimpleActionGroup dg;

	public RecentVideo(Adw.Window _w) {
		this.orientation = Gtk.Orientation.VERTICAL;
		entry = new Gtk.Entry();
		var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
		var button = new Gtk.MenuButton();

		menu = new GLib.Menu();
		button.menu_model = menu;
		dg = new GLib.SimpleActionGroup();

		if (button.popover != null) {
			button.popover.has_arrow=false;
		}
		entry.activate.connect(() => {
				ent_append(entry.text);
			});

		entry.hexpand = true;
		entry.vexpand = false;
		box.vexpand = false;
		button.vexpand = false;
		this.vexpand = false;
		box.append(entry);
		box.append(button);
		this.append(box);

		box.valign=Gtk.Align.START;
		_w.insert_action_group("vmenu", dg);
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


	private string mkfn() {
		var uc =  Environment.get_user_config_dir();
		var cfile = GLib.Path.build_filename(uc,"mwp","recent.txt");
		return cfile;
	}

	public string[]? get_recent_items() {
		string[] strlist;
		strlist = {};
		var fs = FileStream.open(mkfn(), "r");
		if (fs != null) {
			string line=null;
			while ((line = fs.read_line ()) != null) {
				line = line.strip();
				if(line.length == 0 || line.has_prefix("#") || line.has_prefix(";")) {
					continue;
				}
				strlist += line;
			}
		}
		return strlist;
	}

	public void populate(string[]? strlist) {
		if(strlist.length > 0) {
			set_text(strlist[0]);
			foreach(var a in strlist) {
				ent_append(a);
			}
		}
	}

	public void ent_append(string label) {
		var alabel = "item_%02d".printf(menu.get_n_items());
		var aq = new GLib.SimpleAction(alabel, null);
		aq.activate.connect(() => {
				set_text(label);
			});
		dg.add_action(aq);
		menu.append(label, "vmenu.%s".printf(alabel));
	}

	public void set_text(string t) {
		entry.text = t;
	}

	public string get_text() {
		return entry.text;
	}

	public void save_recent() {
		var fs = FileStream.open(mkfn(), "w");
		if (fs != null) {
			fs.puts(entry.text);
			fs.putc('\n');
			int nwr = int.min(10, menu.get_n_items());
			for(var j = 0; j < nwr; j++) {
				var v = menu.get_item_attribute_value(j, "label", VariantType.STRING);
				var ms =  (v == null) ? "" : (string)v;
				if (ms != null && ms != entry.text) {
					fs.puts(ms);
					fs.putc('\n');
				}
			}
		}
	}
}
