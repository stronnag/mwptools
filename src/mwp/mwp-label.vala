public class MWPLabel : MWPMarker {
	private Gtk.CssProvider provider;
	private string bcol;
	private string fcol;
	private Gtk.Label label;

	public MWPLabel(string txt="")  {
		provider = new Gtk.CssProvider ();
		label = new Gtk.Label(txt);
		label.use_markup = true;
        var stylec = label.get_style_context();
		stylec.add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		var fs = Mwp.conf.symbol_scale;
		if(Touch.has_touch_screen()) {
			fs *= Mwp.conf.touch_scale;
		}
		set_font_scale(fs);
		label.add_css_class("mycol");
		label.vexpand = false;
		label.hexpand = false;
		label.halign = Gtk.Align.START;
		label.margin_top = 2;
		label.margin_bottom = 2;
		label.margin_start = 2;
		label.margin_end = 2;
		set_child(label);
		bcol = "white";
		fcol = "black";
		set_css();
    }

	public void set_text(string txt) {
		label.label = txt;
	}

	public void set_font_scale(double ps = Pango.Scale.MEDIUM) {
		Pango.AttrList attrs = new Pango.AttrList ();
		attrs.insert (Pango.attr_scale_new (ps));
		label.attributes = attrs;
	}

	private void set_css() {
		string cssstr=".mycol {  padding: 0 0.6rem 0 0.6rem; background-color: %s; color: %s; border-radius: 5px;}".printf(bcol, fcol);
		provider.load_from_string(cssstr);
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
