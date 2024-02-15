using Gtk;

public class MDialog : Gtk.Window {

	public signal void remitems (uint mstat);
	private Gtk.CheckButton[] cbs;

	public MDialog (Mission []msx, string _title="Remove Segments from Mission") {
        this.title = _title;
        this.border_width = 5;
        create_widgets (msx);
    }

	private void create_widgets (Mission []msx) {
		cbs = new Gtk.CheckButton[msx.length];
        var vbox = new Box (Orientation.VERTICAL, 2);
		int k = 0;
		if (msx.length > 1) {
			foreach (var m in msx) {
				var s = "Id: %d Points: %u, Dist: %.0fm".printf(k+1, m.npoints, m.dist);
				cbs[k] = new Gtk.CheckButton.with_label(s);
				vbox.pack_start (cbs[k], false, false, 2);
				k++;
			}
		}

		var button = new Gtk.Button();

		if(k > 0) {
			button.label = "Remove";
		} else {
			vbox.pack_start (new Gtk.Label("No multi-mission to manage"), false, false, 2);
			button.label = "Close";
		}

		button.hexpand = false;
		button.halign = Gtk.Align.END;
        button.expand = false;

		button.clicked.connect(() => {
				if (k > 0) {
					get_rem_items();
				}
				destroy();
			});

		vbox.pack_end(button, false, false);
        add(vbox);
		show_all ();
    }

	private void get_rem_items() {
		bool needed = false;
		uint mstat = 0;
		for(var j = 0; j < cbs.length; j++) {
			if (cbs[j].active) {
				needed = true;
				mstat |= (1<<j);
			}
		}
		if (needed) {
			remitems(mstat);
		}
	}
}
