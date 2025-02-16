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
	internal Gdk.Pixbuf pix;
	public bool draggable;
	private double _sx;
	private double _sy;
	private int _lastang;
	internal int _size;
	private Gtk.GestureDrag gestd;

	public signal void leave();
	public signal void enter(double x, double y);
	public signal void popup_request(int n, double x, double y);
	public signal void drag_motion(double lat, double lon);
	public signal void drag_begin();
	public signal void drag_end();

	public void set_pixbuf(Gdk.Pixbuf _px) {
		pix = _px;
	}

	public void set_pixsize(int _sz) {
		_size = _sz;
	}

	construct {
        no = 0;
        offset = 0;
		_sx = 0.0;
		_sy = 0.0;
		_lastang  = -1;
		_size = -1;

		var gestc = new Gtk.GestureClick();
		add_controller(gestc);
		gestc.set_button(0);
		gestc.released.connect((n,x,y) => {
				var bn = gestc.get_current_button();
				  if(bn == 3) {
					  popup_request( n, x, y);
				  }
			});

		var gestl = new Gtk.GestureLongPress();
		gestl.touch_only = true;
		gestl.delay_factor *= 1.5;
		add_controller(gestl);
		gestl.pressed.connect((x,y) => {
				popup_request( -1, x, y);
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
					var dev = gestd.get_device();
					if(dev != null && dev.source ==  Gdk.InputSource.TOUCHSCREEN) {
						var tfactor = MwpScreen.get_scale();
						x = x / tfactor;
						y = y / tfactor;
					}
					_sx +=x;
					_sy +=y;
					Gis.map.viewport.widget_coords_to_location (Gis.map, _sx, _sy, out lat, out lon);
					/**
					Gis.map.viewport.location_to_widget_coords(this, this.latitude, this.longitude, out _sx, out _sy);
					_sx += x;
					_sy += y;
					Gis.map.viewport.widget_coords_to_location (this, _sx, _sy, out lat, out lon);
					**/
					this.set_location (lat, lon);
					Mwp.set_pos_label(lat, lon);
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
			gestd.propagation_limit =  Gtk.PropagationLimit.SAME_NATIVE;
		} else {
			gestd.propagation_phase  = Gtk.PropagationPhase.NONE;
		}
	}

	public MWPMarker.from_image_file (string fn) {
		try {
			pix =  Img.load_image_from_file(fn);
			var tex =  Gdk.Texture.for_pixbuf(pix);
			var img = new Gtk.Image.from_paintable(tex);
			var _size = int.max(pix.width, pix.height);
			img.set_pixel_size(_size);
			set_child(img);
		} catch (Error e) {
			MWPLog.message("Image open %s : %s\n", fn, e.message);
		}
    }

	public MWPMarker.from_image (Gdk.Pixbuf pix) {
		this.pix = pix;
		var tex = Gdk.Texture.for_pixbuf(pix);
		_size = int.max(pix.width, pix.height);
		var img = new Gtk.Image.from_paintable(tex);
		img.set_pixel_size(_size);
		set_child(img);
    }

	public MWPMarker.from_widget (Gtk.Widget w) {
		set_child(w);
	}

	public void set_image (Gdk.Pixbuf pix) {
		this.pix = pix;
		var tex = Gdk.Texture.for_pixbuf(pix);
		((Gtk.Image)get_child()).paintable = tex;
		double a = _lastang;
		_lastang = -2;
		rotate(a);
	}

	public bool set_image_file (string fn) {
		bool ok = false;
		try {
			pix = Img.load_image_from_file(fn);
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
				var l = int.max(w,h) * 2;
				var cst = new Cairo.ImageSurface (Cairo.Format.ARGB32, l, l);
				var cr = new Cairo.Context (cst);
				cr.translate (w, h);
				cr.rotate(deg*Math.PI/180);
				cr.translate (-w, -h);
				Gdk.cairo_set_source_pixbuf(cr, pix, w/2, h/2);
				cr.paint();
				var px = Gdk.pixbuf_get_from_surface (cst, 0, 0, l, l);
				var tex = Gdk.Texture.for_pixbuf(px);
				((Gtk.Image)get_child()).paintable = tex;
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
		provider.load_from_string(cssstr);
		this.add_css_class("map-point");
	}
}
