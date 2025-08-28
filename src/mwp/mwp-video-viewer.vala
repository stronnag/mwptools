namespace MwpVideo {
#if !UNSUPPORTED_OS
	public class Viewer : Adw.Window {
		private Gtk.Box vbox;
		private Gtk.Picture pic;
		private Gtk.Button play_button;
		private Gtk.Scale slider;
		private uint tid;
		private const Gst.SeekFlags SEEK_FLAGS=(Gst.SeekFlags.FLUSH|Gst.SeekFlags.KEY_UNIT);
		private Gst.ClockTime duration;
		private bool seeking = false;
		Gst.State st;
		private Utils.VolumeButton vb;
		private Gtk.Label ptim;
		private Gtk.Label prem;

		public Viewer() {
			set_transient_for(Mwp.window);
			set_size_request(640, 480);
			title = "mwp Video player";
			set_icon_name("mwp_icon");
			vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
			var header_bar = new Adw.HeaderBar();
			vbox.append(header_bar);
			duration =  (int64)0x7ffffffffffffff;
			vb = new Utils.VolumeButton();
			pic = new Gtk.Picture();
			pic.hexpand = true;
			pic.vexpand = true;
			vbox.append(pic);
			play_button = new Gtk.Button.from_icon_name ("media-playback-start-symbolic");
			add_slider();
			set_content(vbox);
			MwpVideo.state |= MwpVideo.State.WINDOW;
		}

		public Gdk.Paintable? clear_player() {
			var p = pic.paintable;
			pic.paintable= null;
			MwpVideo.state &= ~MwpVideo.State.PLAYWINDOW;
			return p;
		}

		public MwpVideo.Player load(string uri, bool start) {
			var p = new Player(uri);
			MwpVideo.window = this;
			MwpVideo.state |= MwpVideo.State.PLAYWINDOW;

			if (p.pt != null) {
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

				p.error.connect((e) => {
						Gst.State state;
						p.playbin.get_state (out state, null, Gst.CLOCK_TIME_NONE);
						MWPLog.message("Error %d %s\n", e, state.to_string());
					});


				p.state_change.connect((sts) => {
						play_button.icon_name = (sts) ? "media-playback-pause-symbolic" : "media-playback-start-symbolic";
					});
				p.async_done.connect(()=> {
						if (seeking) {
							seeking = false;
							p.playbin.set_state (st);
						}
					});

				((Gtk.Picture)pic).paintable = p.pt;

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
						print("Closing viewer with %p\n", ((Gtk.Picture)pic).paintable );
						if(((Gtk.Picture)pic).paintable != null) {
							p.clear();
							p=null;
							MwpVideo.playbin = null;
						}
						MwpVideo.window = null;
						MwpVideo.state &= ~(MwpVideo.State.WINDOW|MwpVideo.State.PLAYWINDOW);
						return false;
					});

				start_timer(p);
				if (start) {
					on_play(p);
				}
				MwpVideo.last_uri = uri;
			}
			return p;
		}

		private void add_slider() {
			if (slider == null) {
				slider = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0, 1, 1);
				slider.visible=false;
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
				hbox.hexpand = true;
				vb.hexpand = true;
				vb.halign = Gtk.Align.END;
				vbox.append(hbox);
			}
		}

		private string format_ct(double t, bool neg) {
			int m = (int)(t/60);
			int s = (int)((t % 60) + 0.5);
			return "%s%02d:%02d".printf((neg) ? "-" : "", m, s);
		}

		public void set_slider_max(Player p, Gst.ClockTime max) {
			format_ct(0, false);
			if (max > 0) {
				duration = max;
				double rt =  max / 1e9;
				slider.set_range(0.0, rt);
				format_ct(rt, true);
				slider.visible = true;
			} else {
				slider.visible = false;
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

		public void set_playing(bool play) {
			if(play) {
				MwpVideo.playbin.set_state (Gst.State.PLAYING);
			} else {
				MwpVideo.playbin.set_state (Gst.State.PAUSED);
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
#else
	public class Viewer : Adw.Window {
		private Gtk.Box vbox;
		private Gtk.Video pic;

		public Viewer() {
			set_transient_for(Mwp.window);
			set_size_request(640, 480);
			title = "mwp video player";
			set_icon_name("mwp_icon");
			vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
			var header_bar = new Adw.HeaderBar();
			vbox.append(header_bar);
			pic = new Gtk.Video();
			pic.vexpand = true;
			vbox.append(pic);
			set_content(vbox);
			MwpVideo.state |= MwpVideo.State.WINDOW;
		}

		public MwpVideo.Player load(string uri, bool start) {
			var p = new Player(uri);
			MwpVideo.window = this;
			if (p.pt != null) {
				pic.set_media_stream(p.pt);
				p.pt.set_playing(true);
				MwpVideo.state |= MwpVideo.State.PLAYWINDOW;
				MwpVideo.last_uri = uri;
			}

			close_request.connect (() => {
					MwpVideo.window = null;
					MwpVideo.state &= ~(MwpVideo.State.WINDOW|MwpVideo.State.PLAYWINDOW);
					return false;
				});
			return p;
		}

		public void set_playing(bool play) {
			MwpVideo.mmf.playing = true;
		}
		
		public Gdk.Paintable? clear_player() {
			var pt = pic.media_stream;
			pic.media_stream = null;
			MwpVideo.state &= ~MwpVideo.State.PLAYWINDOW;
			return pt;
		}
	}
#endif
}