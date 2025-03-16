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

namespace IChooser {
	public struct Filter {
		string? name;
		string?[] extns;
	}

	Gtk.FileDialog chooser(string? _fn, IChooser.Filter[] filters={}) {
		Gtk.FileDialog fd = new Gtk.FileDialog();
		if (_fn != null) {
			var fl = File.new_for_path (_fn);
			fd.initial_folder = fl;
		}
		fd.title = "mwp";
		var ls = new GLib.ListStore(typeof(Gtk.FileFilter));
		foreach (var s in filters) {
			var filter = new Gtk.FileFilter();
			filter.set_filter_name (s.name);
			foreach (var sn in s.extns) {
				var wf = "*.%s".printf(sn);
				filter.add_pattern (wf);
			}
			ls.append(filter);
		}
		var afilter = new Gtk.FileFilter ();
		afilter.set_filter_name ("All Files");
		afilter.add_pattern ("*");
		ls.append(afilter);
		fd.set_filters(ls);
		return fd;
	}
}
