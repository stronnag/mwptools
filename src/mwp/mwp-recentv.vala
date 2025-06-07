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


namespace Utils {
	public class RecentVideo : Gtk.Box {
		public Gtk.Entry entry;
		private Gtk.DropDown dd;
		private Gtk.Popover pop;

		~RecentVideo() {
			pop.unparent();
		}

		public RecentVideo() {
			this.orientation = Gtk.Orientation.VERTICAL;
			entry = new Gtk.Entry();
			var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
			box.append(entry);
			entry.width_chars = 48;

			dd = new Gtk.DropDown.from_strings({});
			dd.enable_search = true;
			var expression = new Gtk.CClosureExpression (typeof (string), null, {}, (Callback) get_string, null, null);
			dd.expression = expression;
			dd.search_match_mode = Gtk.StringFilterMatchMode.SUBSTRING;
			entry.activate.connect(() => {
					ent_append(entry.text);
				});

			var button = new Gtk.Button.from_icon_name("pan-down");
			var pop = new Gtk.Popover();
			var pbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
			pbox.append(dd);
			pop.set_child(pbox);
			pop.set_parent(button);
			pop.has_arrow = false;
			pop.autohide = true;

			button.clicked.connect(() => {
					pop.popup();
				});

			dd.notify["selected-item"].connect(() =>  {
					var c = (Gtk.StringObject)dd.get_selected_item();
					Idle.add(() => {
							entry.text = c.string;
							pop.popdown();
							return false;
						});
				});

			entry.hexpand = true;
			entry.vexpand = false;
			box.vexpand = false;
			button.vexpand = false;
			this.vexpand = false;
			box.append(button);
			this.append(box);
			box.valign=Gtk.Align.START;
		}

		public void update_recent() {
			var s = entry.text;
			if (entry.text.length > 0) {
				var ls = dd.model as Gtk.StringList;
				string[] sl = {};
				sl += s;
				bool fnd = false;
				for (var j = 0; j < ls.n_items; j++) {
					var l = ((Gtk.StringObject)ls.get_item(j)).string;
					if(l == s) {
						fnd = true;
						continue;
					}
					sl += l;
				}

				if(!fnd) {
					ls.splice(0, 0, {s});
				}
				var fs = FileStream.open(mkfn(), "w");
				if (fs != null) {
					var j = 0;
					foreach (var l in sl) {
						if (l.length > 0) {
							if(j < 10) {
								fs.puts(l);
								fs.putc('\n');
							} else {
								break;
							}
						}
					}
				}
			}
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
			} else {
				if (Mwp.conf.default_video_uri.length > 0) {
					strlist += Mwp.conf.default_video_uri;
				}
			}
			return strlist;
		}

		public void populate(string[]? strlist) {
			var ls = dd.model as Gtk.StringList;
			ls.splice(0, 0, strlist);
			set_active(0);
		}

		public void ent_append(string label) {
			var ls = dd.model as Gtk.StringList;
			ls.append(label);
		}

		public void set_text(string t) {
			entry.text = t;
		}

		public string get_text() {
			return entry.text;
		}

		public void set_active(int n) {
			var mdl = (Gtk.StringList)dd.model;
			var nm = mdl.n_items;
			if(nm > 0) {
				var v = mdl.get_string(n);
				if(v != null) {
				entry.text = (string)v;
				}
			} else {
				entry.text = "";
			}
		}

		static string get_string (Gtk.StringObject item) {
			return item.string;
		}

	}
}