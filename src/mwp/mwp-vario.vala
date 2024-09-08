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


namespace Vario {
	public class View : Gtk.Box {
		private Gtk.Image vimage;
		private Gtk.Label vlabel;
		private Gdk.Texture up;
		private Gdk.Texture down;
		private Gdk.Texture none;
		private Gdk.Texture lastt;

		public View() {
			this.orientation = Gtk.Orientation.VERTICAL;
			this.spacing = 2;
			this.hexpand = true;
			this.vexpand = true;

			string fn="";
			try {
				fn = MWPUtils.find_conf_file("up-arrow.svg", "pixmaps");
				var f = File.new_for_path (fn);
				up = Gdk.Texture.from_file(f);
				fn = MWPUtils.find_conf_file("down-arrow.svg", "pixmaps");
				f = File.new_for_path (fn);
				down = Gdk.Texture.from_file(f);
				fn =  MWPUtils.find_conf_file("double-arrow.svg", "pixmaps");
				f = File.new_for_path (fn);
				none = Gdk.Texture.from_file(f);
			} catch (Error e) {
				MWPLog.message("** Texture %s %s\n", fn, e.message);
			}
			vimage = new Gtk.Image();
			vimage.hexpand = true;
			vimage.vexpand = true;

			vlabel  = new Gtk.Label("Vario");
			vlabel.hexpand = true;

			this.append(vimage);
			this.append(vlabel);
			lastt = null;
			Mwp.msp.td.alt.notify["vario"].connect((s,p) => {
					var v = ((AltData)s).vario;
					update(v);
				});
		}

		public void update(double vs) {
			Gdk.Texture t;
			if (vs > 0) {
				t =up;
			} else if (vs < 0) {
				t = down;
			} else {
				t = none;
			}
			if (t != lastt) {
				vimage.set_from_paintable(t);
				lastt = t;
			}
			/*
			var v = Units.speed(vs/100);
			vlabel.set_markup("<span face='monospace' size='150%%'>%.1f</span>%s".printf(v, Units.speed_units()));
			*/
        }

		public void annul() {
			update(0);
		}
	}
}
