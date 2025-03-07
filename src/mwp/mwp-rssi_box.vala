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

namespace RSSI {
	[Flags]
	public enum Update {
		RSSI
	}

	public enum Title {
		RSSI,
		LQ
	}
	private Title tid=0;

	public void set_title(Title t = Title.RSSI) {
		tid = t;
	}

	[GtkTemplate (ui = "/org/stronnag/mwp/rssi.ui")]
	public class View : Gtk.Box {
		[GtkChild]
		private unowned Gtk.Label title;
		//		[GtkChild]
		//private unowned Gtk.Label rssi;
		[GtkChild]
		private unowned Gtk.Label rssi_pct;
		[GtkChild]
		private unowned Gtk.ProgressBar pbar;

		public View() {	}

		public void update(Update what) {
			if(Update.RSSI in what) {
				update_r(Mwp.msp.td.rssi.rssi);
            }
		}

		private void update_r(int rv) {
			title.label = (tid == Title.RSSI) ? "RSSI" : "LQ";
			int pct = rv*100/1023;
			double f = (double)rv/1023.0;
			pbar.set_fraction(f);
			/*
			if (tid == Title.RSSI) {
				rssi.label="<span size='250%%' font='monospace'>%d</span>".printf(rv);
			} else {
				rssi.label="<span size='250%%' font='monospace'> </span>";
			}
			*/
			rssi_pct.label="<span size='250%%' font='monospace'>%d%%</span>".printf(pct);
		}
	}
}
