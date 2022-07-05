using Gtk;

class MwpSplash : Gtk.Window {
	Gtk.Label sp_label;
	public MwpSplash() {}

	construct {
		type = Gtk.WindowType.POPUP;
		type_hint = Gdk.WindowTypeHint.SPLASHSCREEN;
		gravity = Gdk.Gravity.CENTER;
		decorated = false;
		window_position = Gtk.WindowPosition.CENTER_ALWAYS;
		set_default_size (480, 256);
		set_keep_above(true);
		var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
		var label = new Gtk.Label("<span font='72' weight='bold'>mwp</span>");
		label.use_markup = true;
		box.pack_start (label, false, false, 0);
		var image = new Gtk.Image.from_icon_name("mwp_icon", IconSize.DIALOG);
		image.set_pixel_size(160);
		box.pack_start (image,false, false, 0);
		sp_label = new Gtk.Label("<i>A mission planner for the rest of us</i>");
		sp_label.use_markup = true;
		box.pack_start (sp_label, false, false, 0);
		add (box);
	}

	public void run() {
		show_all();
		while(Gtk.events_pending())
			Gtk.main_iteration();
	}

	public void update(string? s) {
		if (s != null) {
			sp_label.label = s;
			while(Gtk.events_pending())
				Gtk.main_iteration();
		}
	}
}