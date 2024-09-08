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
	public class SCWindow : Object {
		private Gtk.ShortcutsWindow scview;
		public SCWindow() {
			var builder = new Gtk.Builder.from_resource("/org/stronnag/mwp/mwpsc.ui");
			scview = builder.get_object("scwindow") as Gtk.ShortcutsWindow;
			var scsect = builder.get_object("shortcuts") as Gtk.ShortcutsSection;
			scsect.visible = true;
			scview.transient_for = Mwp.window;
			scview.close_request.connect (() => {
					scview.hide();
					return true;
				});
		}
		public void present() {
			scview.present();
		}
	}
}
