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

using Gtk;

namespace Chans {
	Chans.Window? cwin;

	public void show_window() {
		if(cwin == null) {
			cwin = new Chans.Window(Mwp.window, Mwp.nrc_chan);
			cwin.present();
		} else {
			cwin.close();
			cwin = null;
		}
	}

	public class Window : Gtk.Window {
		private Gtk.Grid g;
		public Window(Gtk.Window? pw, int maxchn) {
			var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
			box.margin_top = 8;
			box.margin_bottom = 8;
			box.margin_start = 8;
			box.margin_end = 8;
			g = new Gtk.Grid();
			g.column_homogeneous = true;
			g.set_column_spacing (2);
			box.append(g);
			Gtk.Label lbl;
			for(var j = 0; j < maxchn; j++) {
				lbl = new Gtk.Label("Ch%02d".printf(j+1));
				g.attach(lbl, j, 1);
			}
			for(var j = 0; j < maxchn; j++) {
				lbl = new Gtk.Label("----");
				g.attach(lbl, j, 2);
			}
			set_bg(this, "window {background: color-mix(in srgb, @window_bg_color 40%, transparent)  ;  color: @view_fg_color; border-radius: 12px 12px;}");
			set_title("RC Channels");
			var hb = new Gtk.HeaderBar();
			set_titlebar(hb);
			hb.set_decoration_layout("icon:close");
			set_bg(hb, "headerbar {background: rgba(0, 0, 0, 0.0);}");
			close_request.connect(() => {
					cwin = null;
					return false;
				});
			set_child(box);
			if(pw != null) {
				set_transient_for(pw);
			}
		}

		private void set_bg(Gtk.Widget w, string css) {
			var provider = new CssProvider();
			provider.load_from_data(css.data);
			var stylec = w.get_style_context();
			stylec.add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		}

		public void update(int16 []chans) {
			for(var j = 0; j < chans.length; j++) {
				var lbl =  g.get_child_at(j, 2) as Gtk.Label;
				lbl.label = "%4d".printf(chans[j]);
			}
        }
    }
}
