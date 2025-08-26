namespace MwpVideo {
		public class Viewer : Adw.Window {
		private Gtk.Button play_button;
		private Gtk.Scale slider;
		private uint tid;
		private Gtk.Box vbox;
		private const Gst.SeekFlags SEEK_FLAGS=(Gst.SeekFlags.FLUSH|Gst.SeekFlags.KEY_UNIT);
		private Gst.ClockTime duration;
		private bool seeking = false;
		Gst.State st;
		private Utils.VolumeButton vb;
		private Gtk.Label ptim;
		private Gtk.Label prem;
		private Gtk.Picture pic;

		~Viewer () {
			MwpVideo.window = null;
		}

		public Viewer() {
			set_size_request(640, 480);
			duration =  (int64)0x7ffffffffffffff;
			vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
			title = "mwp Video player";
			set_icon_name("mwp_icon");
			var header_bar = new Adw.HeaderBar();
			vbox.append(header_bar);
			vb = new Utils.VolumeButton();
			pic = new Gtk.Picture();
			pic.hexpand = true;
			pic.vexpand = true;
			vbox.append(pic);
			play_button = new Gtk.Button.from_icon_name ("gtk-media-play");
			add_slider();
			set_content(vbox);
		}

		public void load(string uri, bool start) {
			var p = new Player(uri);
			if (p.pt != null) {
				MwpVideo.window = this;

				slider.change_value.connect((stype, d) => {
						seeking = true;
						p.playbin.get_state (out st, null, Gst.CLOCK_TIME_NONE);
						p.playbin.set_state (Gst.State.PAUSED);
						p.playbin.seek (1.0,
										Gst.Format.TIME, SEEK_FLAGS,
										Gst.SeekType.SET, (int64)(d * Gst.SECOND),
										Gst.SeekType.NONE, (int64)Gst.CLOCK_TIME_NONE);
						return true;
					});

				p.eos.connect(() => {
						MWPLog.message("EOS\n");
					});

				p.state_change.connect((sts) => {
						play_button.icon_name = (sts) ? "gtk-media-pause" : "gtk-media-play";
					});
				p.async_done.connect(()=> {
						if (seeking) {
							seeking = false;
							p.playbin.set_state (st);
						}
					});

				pic.paintable = p.pt;

				play_button.clicked.connect(() => {
						on_play(p);
					});

				double vol;
				var rt = get_rt(MwpVideo.to_uri(uri));
				if (rt ==  Gst.CLOCK_TIME_NONE) {
					set_slider_max(p,0);
				} else {
					set_slider_max(p,rt);
				}

				p.playbin.get("volume", out vol);
				vb.value = vol;
				vb.value_changed.connect((v) => {
						p.playbin.set("volume", v);
					});

				close_request.connect (() => {
						if (tid > 0) {
							Source.remove(tid);
						}
						p.playbin.set_state (Gst.State.NULL);
						return false;
					});

				start_timer(p);
				if (start) {
					on_play(p);
				}
			}
		}

		private void add_slider() {
			if (slider == null) {
				slider = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0, 1, 1);
				slider.set_draw_value(false);
				slider.hexpand = true;

				ptim = new Gtk.Label("");
				prem = new Gtk.Label("");

				var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
				hbox.append(play_button);
				hbox.append(ptim);
				hbox.append (slider);
				hbox.append(prem);
				hbox.append(vb);
				vbox.append(hbox);
			}
		}

		private string format_ct(double t, bool neg) {
			int m = (int)(t/60);
			int s = (int)((t % 60) + 0.5);
			return "%s%02d:%02d".printf((neg) ? "-" : "", m, s);
		}

		public void set_slider_max(Player p, Gst.ClockTime max) {
			ptim = new Gtk.Label("");
			format_ct(0, false);

			if (max > 0) {
				prem = new Gtk.Label("");
				duration = max;
				double rt =  max / 1e9;
				slider.set_range(0.0, rt);
				format_ct(rt, true);
			}
		}

		public void set_slider_value(double value) {
			if (slider != null) {
				slider.set_value(value);
				var rt = duration/1e9 - value;
				if (prem.label != "") {
					prem.label = format_ct(rt, true);
				}
			}
			ptim.label = format_ct(value, false);
		}

		private Gst.ClockTime get_rt(string uri) {
			Gst.ClockTime rt = Gst.CLOCK_TIME_NONE;
			rt = discover(uri);
			return rt;
		}

		private void start_timer(Player p) {
			tid = Timeout.add(50, () => {
					Gst.Format fmt = Gst.Format.TIME;
					int64 current = -1;
					if (p.playbin.query_position (fmt, out current)) {
						double rtm = current/1e9;
						set_slider_value(rtm);
					}
					return true;
				});
		}

		void on_play(Player p) {
			Gst.State state;
			p.playbin.get_state (out state, null, Gst.CLOCK_TIME_NONE);
			if (state != Gst.State.PLAYING) {
				p.playbin.set_state (Gst.State.PLAYING);
			} else {
				p.playbin.set_state (Gst.State.PAUSED);
			}
		}

		public Gst.ClockTime discover(string fn) {
			Gst.ClockTime id = 0;
			try {
				var d = new Gst.PbUtils.Discoverer((Gst.ClockTime) (Gst.SECOND * 5));
				var di = d.discover_uri(fn);
				id = di.get_duration ();
			} catch {}
			return id;
		}
	}
}