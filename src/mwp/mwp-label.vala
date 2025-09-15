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

public interface MWPLabel : MWPMarker {
	public abstract string bcol{get;set;}
	public abstract string fcol{get;set;}
	public abstract void set_text(string txt);
	public abstract string get_text();
	public abstract void set_font_scale(double ps);
	public abstract void set_text_colour(Value v);
	public abstract void set_colour(Value v);

	public virtual string val_to_colour(Value v) {
		var vt = v.type();
		if(vt == typeof(string)) {
			return (v as string);
		} else if (vt== typeof(Gdk.RGBA)) {
			return ((Gdk.RGBA)v).to_string();
		}
		return "rgb(0,0,0)";
	}
}

public class MWPPointyLabel : MWPMarker, MWPLabel {
	const int RADIUS = 10;
	const int PADDING = RADIUS/2;
	const double FONTSIZE = 10.0;

	public string bcol{get;set;}
	public string fcol{get;set;}

	private string label;
	private double fontsize;
	private string wpstyle;

	public MWPPointyLabel(string txt="")  {
#if WINDOWS
		wpstyle = "Segoe UI";
#else
		wpstyle = "Sans";
#endif
		var fs = MwpScreen.rescale(1);
		bcol = "white";
		fcol = "#000000ff";
		fontsize = FONTSIZE*fs;
		label = txt;
		generate_label();
    }

	public void set_text(string txt) {
		label = txt;
		generate_label();
	}

	public string get_text() {
		return label;
	}

	public void set_font_scale(double ps = Pango.Scale.MEDIUM) {
		fontsize = FONTSIZE*ps;
		generate_label();
	}

	public void set_text_colour(Value v) {
		fcol = val_to_colour(v);
		generate_label();
	}

	public void set_colour(Value v) {
		bcol = val_to_colour(v);
		generate_label();
	}

	// should use Gtk.get_locale_direction()  for reverse (Gtk.TextDirection.RTL)
	private void draw_box(Cairo.Context cr, int width, int height, int point, bool rev) {
		cr.move_to (RADIUS, 0);
		cr.line_to (width - RADIUS, 0);
		cr.arc (width - RADIUS, RADIUS, RADIUS - 1, 3 * Math.PI / 2.0, 0);
		if(rev) {
			cr.line_to (width, height - RADIUS);
			cr.arc (width - RADIUS, height - RADIUS, RADIUS - 1, 0, Math.PI / 2.0);
			cr.line_to (point, height);
			cr.line_to (0, height + point);
			cr.arc (RADIUS, RADIUS, RADIUS - 1, Math.PI, 3 * Math.PI / 2.0);
		} else {
			cr.line_to (width, height + point);
			cr.line_to (width - point, height);
			cr.line_to (RADIUS, height);
			cr.arc (RADIUS, height - RADIUS, RADIUS - 1, Math.PI / 2.0, Math.PI);
			cr.line_to (0, RADIUS);
			cr.arc (RADIUS, RADIUS, RADIUS - 1, Math.PI, 3 * Math.PI / 2.0);
		}
		cr.close_path ();
	}

	private Pango.Layout text_get_size(Cairo.Context cr, string s, out int w, out int h) {
		Pango.FontDescription font;
        var fsize = fontsize * Pango.SCALE;
		font = new Pango.FontDescription();
        font.set_family(wpstyle);
		font.set_size((int)fsize);
		font.set_gravity(Pango.Gravity.AUTO);
		font.set_style(Pango.Style.NORMAL);
		font.set_weight(Pango.Weight.NORMAL);

		var layout = Pango.cairo_create_layout(cr);
        layout.set_font_description(font);
		layout.set_markup(s, -1);
		layout.get_pixel_size(out w, out h);
		return layout;
	}

	private void show_text(Cairo.Context cr, Pango.Layout l) {
		Pango.cairo_show_layout(cr, l);
	}

	private void generate_label() {
		var cst = new Cairo.ImageSurface (Cairo.Format.ARGB32, 256, 256);
		var cr = new Cairo.Context (cst);

		int tw, th, tw0, th0;
		var l = text_get_size(cr, label, out tw0, out th0);

		th = 2*((th0 + 2*PADDING + 1)/2);
		tw = 2*((tw0 + 2*PADDING + 1)/2);
		int point = 2*((1+(th + 2)/3)/2);
		var thp = th + point;
		tw = int.max(tw, thp);

		var r = Gdk.RGBA();
		r.parse(bcol);
		cr.set_source_rgba (r.red, r.green, r.blue, r.alpha);
		draw_box(cr, tw, th, point, false);
		cr.fill_preserve();
		cr.set_line_width(1.0f);
		cr.set_source_rgba (r.red*0.8, r.green*0.8, r.blue*0.8, 1.0f);
		cr.stroke();

		r.parse(fcol);
		cr.set_source_rgba (r.red, r.green, r.blue, r.alpha);

		var ty = PADDING;
		var tx = (tw - tw0+1)/2;

		cr.move_to(tx, ty);
		show_text(cr, l);
		var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, tw, thp);
        var context =  new Cairo.Context (surface);
        context.set_source_surface(cst, 0 ,0);
        context.paint();
		var px = Gdk.pixbuf_get_from_surface(surface, 0, 0, tw, thp);

        set_pixbuf(px);
		var tex = Gdk.Texture.for_pixbuf(pix);
		var sz = int.max(pix.width, pix.height);
		set_pixsize(sz);
		var img = new Gtk.Image.from_paintable(tex);
		img.set_pixel_size(sz);
		set_child(img);
		if(Mwp.shumate_hspot == Mwp.ShumateHotspot.XYALIGN) {
			set_property("xalign", 1.0f);
			set_property("yalign", 1.0f);
		} else {
			halign=Gtk.Align.END;
			valign=Gtk.Align.END;
		}
	}
}

public class MWPTextyLabel : MWPMarker, MWPLabel {
	public string bcol{get;set;}
	public string fcol{get;set;}

	private Gtk.Label label;

	public MWPTextyLabel(string txt="")  {
		label = new Gtk.Label(txt);
		label.use_markup = true;
		var fs = Mwp.conf.symbol_scale;
		if(MwpScreen.has_touch_screen()) {
			fs *= Mwp.conf.touch_scale;
		}
		bcol = "white";
		fcol = "#000000ff";
		var name = get_name_css();
		set_css(name);
		set_font_scale(fs);
		label.vexpand = false;
		label.hexpand = false;
		label.halign = Gtk.Align.START;
		label.margin_top = 2;
		label.margin_bottom = 2;
		label.margin_start = 2;
		label.margin_end = 2;
		set_child(label);
    }

	public void set_text(string txt) {
		label.label = txt;
	}

	public string get_text() {
		return label.label;
	}

	public void set_font_scale(double ps = Pango.Scale.MEDIUM) {
		Pango.AttrList attrs = new Pango.AttrList ();
		attrs.insert (Pango.attr_scale_new (ps));
		label.attributes = attrs;
	}

	private string get_name_css() {
		var name = "mwp_%s%s".printf(bcol, fcol);
		name = name.replace("#", "");
		name = name.replace("(", "");
		name = name.replace(")", "");
		name = name.replace(",", "");
		name = name.replace(".", "");
		return name;
	}

	private void set_css(string name) {
		string cssstr=".%s {  padding: 0 0.6rem 0 0.6rem; background-color: %s; color: %s; border-radius: 5px;}".printf(name, bcol, fcol);
		MwpCss.load_string(cssstr);
	}

	public void set_text_colour(Value v) {
		fcol = val_to_colour(v);
		name = get_name_css();
		add_css_class(name);
		set_css(name);
	}

	public void set_colour(Value v) {
		bcol = val_to_colour(v);
		name = get_name_css();
		add_css_class(name);
		set_css(name);
	}
}

namespace MWPLabelFactory {
	public MWPLabel make_label(string txt = "")	{
		if(Mwp.shumate_hspot == Mwp.ShumateHotspot.NONE) {
			return new MWPTextyLabel(txt);
		} else {
			return new MWPPointyLabel(txt);
		}
	}
}