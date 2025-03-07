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

public class  ScrollView : Gtk.ScrolledWindow {
	private Gtk.Label label;
    public ScrollView (string _title = "Text View") {
		var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

		title = _title;
        label = new Gtk.Label (null);
        label.set_use_markup(true);
		has_frame = true;

		scrolled_window.min_content_height = 400;
		scrolled_window.min_content_width = 320;
		scrolled_window.propagate_natural_height = true;
		scrolled_window.propagate_natural_width = true;

		var button = new Gtk.Button.with_label ("OK");
		button.clicked.connect (() => { this.destroy();});

		var grid = new Gtk.Grid ();
		grid.attach (label, 0, 0, 1, 1);
		grid.attach (button, 0, 1, 1, 1);
		box.append(grid);
        scrolled_window.add (box);
	}

	public void generate_climb_dive(string[]lines, double maxclimb, double maxdive) {
		var sb = new StringBuilder();
		sb.append("<tt>");
		foreach (var l in lines) {
			var hilite = false;
			var lparts = l.split("\t");
            if (lparts.length == 3) {
                double angle=double.parse(lparts[1]);
                if((angle > 0.0 && maxclimb > 0.0 && angle > maxclimb) ||
                   (angle < 0.0 && maxdive < 0.0 && angle < maxdive))
                    hilite = true;
            }
            if(hilite)
                sb.append("<span foreground='red'>");
            sb.append(l);
            if(hilite)
                sb.append("</span>");
		}
		sb.append("</tt>");
		label.set_markup(sb.str);
		label.selectable = true;
		present();
	}
}
