using Gtk;

public class MDialog : Dialog {

	public signal void remitems (uint8[]mstat);
	private Gtk.CheckButton[] cbs;

	public MDialog (Mission []msx) {
        this.title = "Mission Dialog";
        this.border_width = 5;
        create_widgets (msx);

    }

	private void create_widgets (Mission []msx) {
		cbs = new Gtk.CheckButton[msx.length];
        var vbox = new Box (Orientation.VERTICAL, 2);
		int k = 0;
		if (msx.length > 0) {
			foreach (var m in msx) {
				var s = "Id: %d Points: %u, Dist: %.0fm".printf(k+1, m.npoints, m.dist);
				cbs[k] = new Gtk.CheckButton.with_label(s);
				vbox.pack_start (cbs[k], false, false, 2);
				k++;
			}
		}

        var content = get_content_area () as Box;
        content.pack_start (vbox, false, true, 0);

		if(k > 0) {
			add_button ("Remove", 1001);
		} else {
			vbox.pack_start (new Gtk.Label("No missions to manage"), false, false, 2);
			add_button ("Close", 1000);
		}
		response.connect((id) => {
				switch (id) {
				case 1001:
					get_rem_items();
					break;
				}
				destroy();
			});
		show_all ();
    }
	private void get_rem_items() {
		bool needed = false;
		var mstat = new uint8[cbs.length];
		for(var j = 0; j < cbs.length; j++) {
			if (cbs[j].active) {
				needed = true;
				mstat[j] = 1;
			} else {
				mstat[j] = 0;
			}
		}
		if (needed) {
			remitems(mstat);
		}
	}
}
