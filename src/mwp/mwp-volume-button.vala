
namespace Utils {
	public class VolumeButton : Gtk.Button {
		private Gtk.Popover p;
		private Gtk.Box v;
		private Gtk.Scale sc;
		private Gtk.Button plus;
		private Gtk.Button minus;

		public double value {get; set; default=0.5;}
		public signal void value_changed(double d);

		~VolumeButton() {
			p.unparent();
		}

		public VolumeButton() {
			sc = new Gtk.Scale.with_range (Gtk.Orientation.VERTICAL, 0.0, 1.0, 0.1);
			this.icon_name = "multimedia-volume-control";
			this.notify["value"].connect((s,p) => {
					sc.set_value(value);
				});

			p = new Gtk.Popover();
			v = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
			sc.value_changed.connect(() => {
					value = sc.get_value();
					value_changed(value);
				});
			sc.inverted = true;
			sc.vexpand = true;
			sc.hexpand = false;
			sc.height_request = 100;
			sc.set_value(value);
			plus = new Gtk.Button.from_icon_name ("value-increase");
			minus = new Gtk.Button.from_icon_name("value-decrease");
			plus.hexpand = false;
			plus.vexpand = false;
			minus.hexpand = false;
			minus.vexpand = false;

			plus.clicked.connect(() => {
					value = sc.get_value();
					if (value < 1.0) {
						value += 0.1;
					}
					sc.set_value(value);
				});
			minus.clicked.connect(() => {
					value = sc.get_value();
					if (value > 0.0) {
						value -= 0.1;
					}
					sc.set_value(value);
				});
			v.append(plus);
			v.append(sc);
			v.append(minus);
			p.set_child(v);
			p.set_parent(this);
			this.clicked.connect(() => {
					p.popup();
				});
		}
	}
}
