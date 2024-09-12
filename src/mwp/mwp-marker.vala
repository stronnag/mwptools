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

public class MWPMarker : Shumate.Marker {
    public int no;
    public int offset;
	private Gdk.Pixbuf pix;
	public bool draggable;
	private double _sx;
	private double _sy;
	private int _lastang;
	private int _size;
	public Gtk.Widget extra {get; set;}
	private Gtk.GestureDrag gestd;

	public signal void leave();
	public signal void enter(double x, double y);
	public signal void popup_request(int n, double x, double y);
	public signal void drag_motion(double lat, double lon);
	public signal void drag_begin();
	public signal void drag_end();

	construct {
        no = 0;
        offset = 0;
		_sx = 0.0;
		_sy = 0.0;
		_lastang  = -1;
		_size = -1;
		extra = null;

		var gestc = new Gtk.GestureClick();
		add_controller(gestc);
		gestc.set_button(0);
		gestc.released.connect((n,x,y) => {
				var bn = gestc.get_current_button();
				  if(bn == 3 || n == 2) {
					  popup_request( n, x, y);
				  }
			});

		var gestl = new Gtk.GestureLongPress();
		add_controller(gestl);
		gestl.pressed.connect((x,y) => {
				popup_request( 1, x, y);
			});

		var evtck = new Gtk.EventControllerMotion();
        add_controller(evtck);
        evtck.enter.connect((x,y) => {
				enter(x,y);
			});
		evtck.leave.connect(() => {
				leave();
            });

		gestd = new Gtk.GestureDrag();
		((Gtk.Widget)this).add_controller(gestd);
		gestd.set_exclusive(true);
		gestd.drag_begin.connect((x,y) => {
				gestd.set_state(Gtk.EventSequenceState.CLAIMED); // stops drag being propogated
				Gis.map.viewport.location_to_widget_coords(Gis.map, this.latitude, this.longitude, out _sx, out _sy);
				drag_begin();
			});
		gestd.drag_update.connect((x,y) => {
				var seq = gestd.get_last_updated_sequence();
				if(gestd.get_sequence_state(seq) == Gtk.EventSequenceState.CLAIMED) {
					double lat,lon;
					Gis.map.viewport.widget_coords_to_location (Gis.map, _sx+x, _sy+y, out lat, out lon);
					_sx +=x;
					_sy +=y;
					this.set_location (lat, lon);
					drag_motion(lat, lon);
				}
			});
		gestd.drag_end.connect((x,y) => {
				drag_end();
			});
		gestd.propagation_phase  = Gtk.PropagationPhase.NONE;
	}

	public new void set_draggable (bool onoff) {
		draggable = onoff;
		if(onoff) {
			gestd.propagation_phase  = Gtk.PropagationPhase.BUBBLE;
		} else {
			gestd.propagation_phase  = Gtk.PropagationPhase.NONE;
		}
	}

	public MWPMarker.from_image_file (string fn, int size = -1) {
		try {
			pix =  Img.load_image_from_file(fn, size, size);
			var tex =  Gdk.Texture.for_pixbuf(pix);
			var img = new Gtk.Picture.for_paintable(tex);
			MWPLog.message("Load from file %s %d %d (%d)\n", fn, pix.width, pix.height, size);
			if (size == -1) {
				_size = int.max(pix.width, pix.height);
			} else {
				_size = size;
			}
			//			img.set_pixel_size(_size);
			set_child(img);
		} catch (Error e) {
			MWPLog.message("Image open %s : %s\n", fn, e.message);
		}
    }

	public MWPMarker.from_image (Gdk.Pixbuf pix) {
		this.pix = pix;
		var tex = Gdk.Texture.for_pixbuf(pix);
		_size = int.max(pix.width, pix.height);
		var img = new Gtk.Picture.for_paintable(tex);
		set_child(img);
    }

	public MWPMarker.from_widget (Gtk.Widget w) {
		set_child(w);
	}

	public void set_image (Gdk.Pixbuf pix) {
		this.pix = pix;
		var tex = Gdk.Texture.for_pixbuf(pix);
		((Gtk.Picture)get_child()).paintable = tex;
		double a = _lastang;
		_lastang = -2;
		rotate(a);
	}

	public bool set_image_file (string fn, int size = -1) {
		bool ok = false;
		try {
			pix = Img.load_image_from_file(fn, size, size);
			set_image(pix);
			ok = true;
		} catch (Error e) {
			MWPLog.message("ERR: set_image_file %s %s\n",fn, e.message);
		}
		return ok;
    }

	public void rotate(double deg) {
		if (pix != null) {
			int ang = (int)((deg + 0.5) % 360);
			if (ang != _lastang) {
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
				((Gtk.Picture)get_child()).paintable = tex;
				_lastang =ang;
			}
		}
    }
}

public class MWPPoint: MWPMarker {
	public MWPPoint()  {
		set_css_style(".map-point { min-width: 5px; min-height: 5px; background: @theme_selected_bg_color; border: 2px solid @theme_selected_fg_color; border-radius: 50%; }");
	}

	public MWPPoint.with_colour(string s, int r=1)  {
		var cssstr =  ".map-point { min-width: 5px; min-height: 5px; background: %s; border: %dpx solid @theme_selected_fg_color; border-radius: 50%%; }".printf(s,r);
		set_css_style(cssstr);
	}

	public void set_css_style (string cssstr) {
		var provider = new Gtk.CssProvider ();
		var stylec = this.get_style_context();
		stylec.add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		provider.load_from_data(cssstr.data);
		this.add_css_class("map-point");
	}
}

public class MWPLabel : MWPMarker {
	private Gtk.CssProvider provider;
	private string bcol;
	private string fcol;
	private Gtk.Label label;

	public MWPLabel(string txt="")  {
		provider = new Gtk.CssProvider ();
		label = new Gtk.Label(null);
		label.use_markup = true;
        var stylec = label.get_style_context();
		stylec.add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		set_font_scale(Mwp.conf.symbol_scale);
		label.add_css_class("mycol");
		label.vexpand = false;
		label.hexpand = false;
		label.halign = Gtk.Align.START;
		label.margin_top = 2;
		label.margin_bottom = 2;
		label.margin_start = 2;
		label.margin_end = 2;
		label.label = txt;
		set_child(label);
		bcol = "white";
		fcol = "black";
		set_css();
    }

	public void set_text(string txt) {
		label.set_markup(txt);
	}

	public void set_font_scale(double ps = Pango.Scale.MEDIUM) {
		Pango.AttrList attrs = new Pango.AttrList ();
		attrs.insert (Pango.attr_scale_new (ps));
		label.attributes = attrs;
	}

	private void set_css() {
		string cssstr=".mycol {  padding: 0 0.6rem 0 0.6rem; background-color: %s; color: %s; border-radius: 5px;}".printf(bcol, fcol);
		provider.load_from_data(cssstr.data);
	}

	private string val_to_colour(Value v) {
		var vt = v.type();
		if(vt == typeof(string)) {
			return (v as string);
		} else if (vt== typeof(Gdk.RGBA)) {
			return ((Gdk.RGBA)v).to_string();
		}
		return "rgb(0,0,0)";
	}


	public void set_text_colour(Value v) {
		fcol = val_to_colour(v);
		set_css();
	}

	public void set_colour(Value v) {
		bcol = val_to_colour(v);
		set_css();
	}
}
