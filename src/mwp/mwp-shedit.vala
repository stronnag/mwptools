namespace Safehome {
[GtkTemplate (ui = "/org/stronnag/mwp/shedit.ui")]
	public class Editor : Adw.Window {
		[GtkChild]
		private unowned Gtk.Label shlat;
		[GtkChild]
		private unowned Gtk.Label shlon;
		[GtkChild]
		private unowned Gtk.Entry shappalt;
		[GtkChild]
		private unowned Gtk.Entry shlandalt;
		[GtkChild]
		private unowned Gtk.Entry shdirn1;
		[GtkChild]
		private unowned Gtk.Entry shdirn2;
		[GtkChild]
		private unowned Gtk.Switch shex1;
		[GtkChild]
		private unowned Gtk.Switch shex2;
		[GtkChild]
		private unowned Gtk.DropDown sharef;
		[GtkChild]
		private unowned Gtk.DropDown shdref;
		[GtkChild]
		private unowned Gtk.Button shapp;
		private SafeHome sh;

		public signal void ready();

		public Editor() {
			sh = new SafeHome();
			shapp.clicked.connect(() => {
					sh.appalt = double.parse(shappalt.text);
					sh.landalt = double.parse(shlandalt.text);
					sh.dirn1 = (int16)int.parse(shdirn1.text);
					sh.dirn2 = (int16)int.parse(shdirn2.text);
					sh.ex1 = shex1.active;
					sh.ex2 = shex2.active;
					sh.aref = (bool)sharef.selected;
					sh.dref = (bool)shdref.selected;
					ready();
				});
			transient_for = Mwp.window;
		}

		public void set_location(double lat, double lon) {
			shlat.label = PosFormat.lat(lat, Mwp.conf.dms);
			shlon.label = PosFormat.lon(lon, Mwp.conf.dms);
		}

		public void setup(int idx, SafeHome s) {
			title = "Edit Safehome #%d".printf(idx);
			s.notify["lat"].connect((s,p) => {
					shlat.label = PosFormat.lat(((SafeHome)s).lat, Mwp.conf.dms);
				});
			s.notify["lon"].connect((s,p) => {
					shlon.label = PosFormat.lon(((SafeHome)s).lon, Mwp.conf.dms);
				});

			set_location(s.lat, s.lon);
			shappalt.set_text("%.2f".printf(s.appalt));
			shlandalt.set_text("%.2f".printf(s.landalt));
			shdirn1.text = s.dirn1.to_string();
			shdirn2.text = s.dirn2.to_string();
			shex1.active = s.ex1;
			shex2.active = s.ex2;
			sharef.selected = (int)s.aref;
			shdref.selected = (int)s.dref;
		}

		public SafeHome get_result() {
			return sh;
		}
	}
}
