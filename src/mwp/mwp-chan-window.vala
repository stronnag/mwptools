using Gtk;

namespace Chans {
	Chans.Window? cwin;

	public void show_window() {
		if(cwin == null) {
			cwin = new Chans.Window(Mwp.window, Mwp.nrc_chan);
			cwin.present();
		} else {
			cwin.close();
			cwin = null;
		}
	}

	public class Window : Gtk.Window {
		private Gtk.Grid g;
		public Window(Gtk.Window? pw, int maxchn) {
			set_bg();
			var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
			box.margin_top = 8;
			box.margin_bottom = 8;
			box.margin_start = 8;
			box.margin_end = 8;
			g = new Gtk.Grid();
			g.column_homogeneous = true;
			g.set_column_spacing (2);
			box.append(g);
			Gtk.Label lbl;
			for(var j = 0; j < maxchn; j++) {
				lbl = new Gtk.Label("Ch%02d".printf(j+1));
				g.attach(lbl, j, 1);
			}
			for(var j = 0; j < maxchn; j++) {
				lbl = new Gtk.Label("----");
				g.attach(lbl, j, 2);
			}
#if !WINDOWS
			set_decorated(false);
			var btn = new Gtk.Button.from_icon_name("window-close");
			g.attach(btn, 15, 0);
			btn.clicked.connect(() => {
					close();
				});
#endif
			close_request.connect(() => {
					cwin = null;
					return false;
				});
			set_child(box);
			if(pw != null) {
				set_transient_for(pw);
			}
		}

		private void set_bg() {
			string css = "window {background: rgba(0, 0, 0, 0.3); border-radius: 16px 16px;}";
			var provider = new CssProvider();
			provider.load_from_data(css.data);
			var stylec = this.get_style_context();
			stylec.add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		}

		public void update(int16 []chans) {
			for(var j = 0; j < chans.length; j++) {
				var lbl =  g.get_child_at(j, 2) as Gtk.Label;
				lbl.label = "%4d".printf(chans[j]);
			}
        }
    }
}

#if TEST
// valac -D TEST  --pkg gtk+-3.0 --pkg cairo  sticks.vala
namespace Mwp {
	Gtk.Window? window = null;
	int nrc_chan = 16;
}

int main (string[] args) {
    Gtk.init ();
	Chans.show_window();
	Timeout.add(150, () => {
			int16 chans[16];
			for(var j = 0; j < 16; j++) {
				chans[j] = (int16)Random.int_range(1000,2000);
			}
			Chans.cwin.update(chans);
			return true;
		});
    var ml = MainContext.@default();
    while(Gtk.Window.get_toplevels().get_n_items() > 0) {
        ml.iteration(true);
    }
    return 0;
}
#endif
