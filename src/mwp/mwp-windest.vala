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

namespace WindEstimate {
	[Flags]
	public enum Update {
		ANY,
	}

	const string []dirs = {"(N) ", "(NE)", "(E) ", "(SE)", "(S) ", "(SW)", "(W) ", "(NW)"};

	[GtkTemplate (ui = "/org/stronnag/mwp/vas.ui")]
	public class View : Gtk.Box {
		[GtkChild]
		private unowned Gtk.Label vasl;
		[GtkChild]
		private unowned Gtk.Label wdirnl;
		[GtkChild]
		private unowned Gtk.Label wspdl;
		private Gtk.Picture ico;
		private Gdk.Pixbuf pix;

		public View() {
			 try {
				 pix = new Gdk.Pixbuf.from_resource_at_scale ("/org/stronnag/mwp/pixmaps/wind-arrow.svg", 64, 64, true);
				 var tex = Gdk.Texture.for_pixbuf(pix);
				 ico = new Gtk.Picture.for_paintable(tex);
			 } catch (Error e){
				 error(e.message);
			 }

			 ico.can_shrink = false;
			 ico.content_fit = Gtk.ContentFit.COVER;
			 ico.hexpand = true;
			 ico.vexpand = true;
			 ico.halign = Gtk.Align.CENTER;
			 ico.valign = Gtk.Align.CENTER;

			 this.prepend(ico);
			 update(Update.ANY);
		}

		public void update(Update what) {

			TrackData t = Mwp.msp.td;

			double w_x = (double)t.wind.w_x;
			double w_y = (double)t.wind.w_y;
			var w_dirn = Math.atan2(w_y, w_x) * (180.0 / Math.PI);
			if (w_dirn < 0) {
				w_dirn += 360;
			}
			var ndir = (int) ((w_dirn + 22.5) % 360) / 45;
			var w_ms = Math.sqrt(w_x*w_x + w_y*w_y) / 100.0;
			var w_angle = (w_dirn + 180) % 360;
			var w_diff = t.gps.cog - w_angle;
			if (w_diff < 0) {
				w_diff += 360;
			}
			var vas = t.gps.gspeed - w_ms * Math.cos(w_diff*Math.PI/180.0);
			if((Mwp.DEBUG_FLAGS.ADHOC in Mwp.debug_flags)) {
				MWPLog.message(":DBG: Vas %.1f (%.1fm/s %.0f°)\n", vas, w_ms, w_dirn);
			}

			var sp = Units.speed(vas);
			var su = Units.speed_units();

			vasl.label = "<span size='150%%'>%5.1f</span><span size='x-small'>%s</span>".printf(sp, su);
			wdirnl.label = "<span size='150%%'> %03d°%s</span>".printf((int)w_dirn, dirs[ndir]);
			sp = Units.speed(w_ms);
			wspdl.label = "<span size='150%%'>%5.1f</span><span size='x-small'>%s</span>".printf(sp, su);
			rotate(w_dirn);
		}

		public void rotate(double deg) {
			if (pix != null) {
				var w = pix.get_width();
				var h = pix.get_height();
				var cst = new Cairo.ImageSurface (Cairo.Format.ARGB32, w, h);
				var cr = new Cairo.Context (cst);
				cr.translate (w*0.5, h*0.5);
				cr.rotate(deg*Math.PI/180);
				cr.translate (-0.5*w, -0.5*h);
				Gdk.cairo_set_source_pixbuf(cr, pix, 0, 0);
				cr.paint();
				var px = Gdk.pixbuf_get_from_surface (cst, 0, 0, w, h);
				var tex = Gdk.Texture.for_pixbuf(px);
				ico.paintable = tex;
			}
		}
	}
}
