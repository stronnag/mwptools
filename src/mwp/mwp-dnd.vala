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

namespace DND {
	private Gtk.DropTarget droptgt;
	public void init() {
		droptgt = new Gtk.DropTarget(typeof (Gdk.FileList), Gdk.DragAction.COPY);
		droptgt.drop.connect((tgt, value, x, y) => {
				if(value.type() == typeof (Gdk.FileList)) {
					var flist = ((Gdk.FileList)value).get_files();
					foreach(var u in flist) {
						var ufn =  u.get_path();
						string fn;
						var ftyp = MWPFileType.guess_content_type(ufn, out fn);
						MWPFileType.handle_file_by_type(ftyp, fn);
						Cli.parse_cli_files();
					}
				}
				return true;
			});
		droptgt.accept.connect((d) => {
				return true;
			});
		droptgt.leave.connect((d) => {
			});
		((Gtk.Widget)Gis.map).add_controller((Gtk.EventController)droptgt);
	}
}
