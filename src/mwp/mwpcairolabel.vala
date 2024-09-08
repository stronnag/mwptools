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

public class MWPCairoLabel : MWPMarker {
	public MWPCairoLabel(string txt, Gdk.RGBA? col=null, bool _offset=false) {
		set_label(txt, col, _offset);
	}

	public void set_label(string txt, Gdk.RGBA? col=null, bool _offset=false) {
        var mlbl = new _CairoLabel();
        mlbl.create_cairo_surface(txt,_offset, col);
        var img = mlbl.to_pixbuf(_offset);
        var pic = new Gtk.Picture.for_pixbuf (img as Gdk.Pixbuf);
        set_child(pic);
        if(_offset) {
            int w = 0;
            mlbl.get_size(out w, out offset);
        }
	}
}

internal class _CairoLabel : GLib.Object {
    private Gdk.RGBA basecol = {0, 1, 1, 1};
    const int RADIUS=8;
    const int POINT=10;
    private Cairo.ImageSurface cst;
    private int width;
    private int height;

	/*
    public void set_default_colour(Gdk.RGBA bcol) {
        basecol = bcol;
    }
	*/
    public void create_cairo_surface(string txt, bool offset, Gdk.RGBA? col=null) {
        cst = new Cairo.ImageSurface (Cairo.Format.ARGB32, 512, 256);
        var cr = new Cairo.Context (cst);
        cr.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
        Cairo.TextExtents extents;
        cr.set_font_size (POINT);
        cr.text_extents (txt, out extents);
        var bw  = extents.width+RADIUS*2;
        var bh = extents.height+RADIUS*2;
        width = (int)extents.width+RADIUS*2;
        height = (int)bh;
		if (offset) {
			height += RADIUS;
		}
        var degrees = Math.PI/180.0;
        cst = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height*2);
        cr = new Cairo.Context (cst);
        if(col != null) {
            cr.set_source_rgba (col.red, col.green, col.blue, col.alpha);
        } else {
            cr.set_source_rgba (basecol.red, basecol.green, basecol.blue, basecol.alpha);
        }
        cr.move_to(RADIUS, 0);
        cr.line_to(bw - RADIUS, 0);
        cr.arc(bw - RADIUS, RADIUS, RADIUS, -90 * degrees, 0 * degrees);
        cr.line_to(bw, bh-RADIUS);
        cr.arc(bw - RADIUS, bh - RADIUS, RADIUS, 0 * degrees, 90 * degrees);
		if (offset) {
			var x = bw/2+RADIUS;
			var x1 = bw/2;
			cr.line_to(x, bh);
			cr.line_to(x1, height);
			x= bw/2-RADIUS;
			cr.line_to(x, bh);
		}
        cr.arc(RADIUS, bh - RADIUS, RADIUS, 90 * degrees, 180 * degrees);
        cr.arc(RADIUS, RADIUS, RADIUS, 180 * degrees, 270 * degrees);
        cr.close_path ();
        cr.fill();

        cr.set_source_rgb (0, 0, 0);
        cr.move_to(RADIUS, bh - RADIUS);
        cr.set_font_size (POINT);
        cr.show_text(txt);
        cr.stroke();
    }

    public Gdk.Pixbuf? to_pixbuf(bool double=false) {
        var h = height;
		//        if (double)
        //    h += height;
        var px = Gdk.pixbuf_get_from_surface (cst, 0, 0, width, h);
        return px;
    }

    public void get_size(out int w, out int h) {
        w = width;
        h = height;
    }
}
