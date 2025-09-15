namespace MwpCss {

	public void init() {
	}

	public void load_file(string file) {
		var provider = new Gtk.CssProvider();
		provider.load_from_file(File.new_for_path(file));
		Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
	}

	public void load_string(string s) {
		var provider = new Gtk.CssProvider();
		provider.load_from_string(s);
		Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
	}
}
