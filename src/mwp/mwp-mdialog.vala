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

using Gtk;

namespace MissionManager {

	void mm_manager() {
		new MDialog(msx).run();
	}

	public class MDialog : Adw.Window {
		public signal void remitems (uint mstat);
		private Gtk.CheckButton[] cbs;

		public MDialog (Mission []_msx, string _title="Mission Manager") {
			this.title = _title;
			create_widgets (_msx);
		}

		private void create_widgets (Mission []_msx) {
			cbs = new Gtk.CheckButton[msx.length];
			var vbox = new Box (Orientation.VERTICAL, 2);
			vbox.append(new Adw.HeaderBar());
			int k = 0;
			if (_msx.length > 0) {
				foreach (var m in _msx) {
					var s = "Id: %d Points: %u, Dist: %.0fm".printf(k+1, m.npoints, m.dist);
					cbs[k] = new Gtk.CheckButton.with_label(s);
					vbox.append(cbs[k]);
					k++;
				}
			}

			var button = new Gtk.Button();
			if(k > 0) {
				button.label = "Remove";
			} else {
				vbox.append (new Gtk.Label("No multi-mission to manage"));
				button.label = "Close";
			}

			button.hexpand = false;
			button.vexpand = true;
			button.halign = Gtk.Align.END;
			button.valign = Gtk.Align.END;

			button.clicked.connect(() => {
					if (k > 0) {
						get_rem_items();
					}
					close();
				});

			vbox.append(button);
			set_content(vbox);
		}

		private void get_rem_items() {
			bool needed = false;
			uint mstat = 0;
			for(var j = 0; j < cbs.length; j++) {
				if (cbs[j].active) {
					needed = true;
					if (j == mdx) {
						MsnTools.clear(msx[j]);
					}
					mstat |= (1<<j);
				}
			}
			if (needed) {
				mm_regenerate(mstat);
			}
		}
		public void run() {
			present ();
		}
	}

	private void mm_regenerate(uint mitem) {
		Mission [] mmsx = {};
		for(var j = 0; j < msx.length; j++) {
			if ((mitem & (1 << j)) == 0) {
				mmsx += msx[j];
			} else {
				for(var k = j+8; k < msx.length+8; k++) {
					var l = FWApproach.get(k+1);
					FWApproach.set(k,l);
				}
			}
		}
		msx = mmsx;
		mdx = (msx.length > 0) ? 0 : -1;
		for(var j = msx.length; j < 9; j++) {
			FWApproach.clear(j+8);
		}
		update_mission_combo();
		if(msx.length == 0 && !Mwp.window.wpeditbutton.active) {
			HomePoint.try_hide();
		}
	}
}
