namespace MwpVideo {
	public class Viewer : Adw.Window {
		private Gtk.Box vbox;
		private Gtk.Video video;
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
		private uint rtid;
		private Gtk.Revealer  rv;
		private Gtk.Overlay ovly;
		private double last_x;
		private double last_y;

		public Viewer() {
			set_transient_for(Mwp.window);
			set_size_request(800, 600);
			set_icon_name("mwp_icon");
			vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
			var header_bar = new Adw.HeaderBar();
			vbox.append(header_bar);
			if(MwpVideo.is_fallback) {
				video = new Gtk.Video();
				title = "mwp Fallack video player";
				video.vexpand = true;
				vbox.append(video);
			} else {
				rtid = 0;
				var evtcm = new Gtk.EventControllerMotion();
				ovly = new Gtk.Overlay();
				title = "mwp Video Player";
				duration =  (int64)0x7ffffffffffffff;
				vb = new Utils.VolumeButton();
				vb.notify["active"].connect(() => {
						if(vb.active) {
							if(rtid != 0) {
								Source.remove(rtid);
							}
						} else {
							rtid = Timeout.add(3000, () => {
									return hide_media_bar();
								});
						}
					});
				pic = new Gtk.Picture();
				pic.add_controller(evtcm);
				evtcm.motion.connect((x,y) => {
						if(x == last_x && y == last_y) {
							return;
						}
						last_x = x;
						last_y = y;
						if(!rv.get_reveal_child()) {
							show_media_bar();
						}
					});
				pic.hexpand = true;
				pic.vexpand = true;
				play_button = new Gtk.Button.from_icon_name ("media-playback-start-symbolic");
				var cbox = add_slider();
				cbox.valign = Gtk.Align.END;
				cbox.add_css_class("osd");
				rv  = new Gtk.Revealer();
				rv.set_child(cbox);
				rv.valign = Gtk.Align.END;
				rv.set_transition_type(Gtk.RevealerTransitionType.CROSSFADE);
				ovly.add_overlay(rv);
				ovly.set_measure_overlay(rv, true);
				ovly.set_child(pic);
				vbox.append(ovly);
				show_media_bar();
			}
			set_content(vbox);
			MwpVideo.state |= MwpVideo.State.WINDOW;
		}

		private bool hide_media_bar() {
			rtid = 0;
			rv.set_reveal_child(false);
			return false;
		}

		private void show_media_bar() {
			rv.set_reveal_child(true);
			if(rtid != 0) {
				Source.remove(rtid);
			}
			rtid = Timeout.add(3000, () => {
					return hide_media_bar();
				});
		}

		public Gdk.Paintable? clear_player() {
			Gdk.Paintable p;
			if (MwpVideo.is_fallback) {
				mmf.playing = false;
				p = mmf;
			} else {
				p = pic.paintable;
				pic.paintable=null;
			}
			MwpVideo.state &= ~MwpVideo.State.PLAYWINDOW;
			return p;
		}

		public MwpVideo.Player load(string uri, bool start) {
			var p = new Player(uri);
			MWPLog.message("v load %s %p %p\n", uri, p, p.pt);
			if (p.pt != null) {
				MwpVideo.window = this;
				MwpVideo.state |= MwpVideo.State.PLAYWINDOW;
				if(MwpVideo.is_fallback) {
					video.set_media_stream((Gtk.MediaStream) p.pt);
					((Gtk.MediaStream)p.pt).set_playing(true);
					close_request.connect (() => {
							if (!(MwpVideo.State.PASSOVER in MwpVideo.state)) {
								MWPLog.message("DBG: Close legacy\n");
								p.clear();
								MwpVideo.mmf.close();
								p = null;
							} else {
								MwpVideo.state &= ~MwpVideo.State.PASSOVER;
							}
							MwpVideo.window = null;
							MwpVideo.state &= ~(MwpVideo.State.WINDOW|MwpVideo.State.PLAYWINDOW);
							return false;
						});
				} else {
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

					p.error.connect((e,d) => {
							Gst.State state;
							p.playbin.get_state (out state, null, Gst.CLOCK_TIME_NONE);
							MWPLog.message("GST Error %s %s (%d)\n%s\n", state.to_string(), e.message, e.code, d);
							var wb = new Utils.Warning_box("Video Error: %s (%d)\n%s\n".printf(e.message, e.code, d), 0, this);
							wb.present();
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

					double vol = 0.0;

					p.discovered.connect((id) => {
							if (id ==  Gst.CLOCK_TIME_NONE) {
								set_slider_max(0);
							} else {
								set_slider_max(id);
							}
						});


					Type type = p.playbin.get_type();
					ObjectClass ocl = (ObjectClass)type.class_ref();
					unowned ParamSpec? spec = ocl.find_property ("volume");
					if (spec != null) {
						p.playbin.get("volume", out vol);
						vb.value_changed.connect((v) => {
								p.playbin.set("volume", v);
							});
					}
					vb.value = vol;

					close_request.connect (() => {
							if (tid > 0) {
								Source.remove(tid);
							}
							if(rtid != 0) {
								Source.remove(rtid);
							}
							MWPLog.message("Closing viewer with %p\n", ((Gtk.Picture)pic).paintable );
							if (!(MwpVideo.State.PASSOVER in MwpVideo.state)) {
								MWPLog.message("DBG: Close gtk4pt window\n");
								p.clear();
								p.playbin.set_state (Gst.State.NULL);
								p=null;
								MwpVideo.playbin = null;
							} else {
								MwpVideo.state &= ~MwpVideo.State.PASSOVER;
							}
							MwpVideo.window = null;
							MwpVideo.state &= ~(MwpVideo.State.WINDOW|MwpVideo.State.PLAYWINDOW);
							MWPLog.message("Close player %p %s\n", 	MwpVideo.playbin, MwpVideo.state.to_string());
							return false;
						});

					MWPLog.message("Start timer\n");
					start_timer(p);
					MWPLog.message("Start play\n");
					p.set_playing(start);
				}
				MwpVideo.last_uri = uri;
			}
			return p;
		}

		private Gtk.Box? add_slider() {
			Gtk.Box? hbox=null;
			if (slider == null) {
				hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
				slider = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0, 1, 1);
				slider.visible=false;
				slider.set_draw_value(false);
				slider.hexpand = true;
				slider.halign = Gtk.Align.FILL;
				ptim = new Gtk.Label("");
				prem = new Gtk.Label("");

				hbox.append(play_button);
				hbox.append(ptim);
				hbox.append (slider);
				hbox.append(prem);
				hbox.append(vb);
				hbox.hexpand = true;
				hbox.vexpand = false;
				vb.halign = Gtk.Align.END;
				vb.visible = false;
			}
			return hbox;
		}

		private string format_ct(double t, bool neg) {
			int m = (int)(t/60);
			int s = (int)((t % 60) + 0.5);
			return "%s%02d:%02d".printf((neg) ? "-" : "", m, s);
		}

		public void set_slider_max(Gst.ClockTime max) {
			if (max > 0) {
				duration = max;
				double rt =  max / 1e9;
				slider.set_range(0.0, rt);
				prem.label = format_ct(rt, true);
				slider.visible = true;
			} else {
				slider.visible = false;
				vb.hexpand = true;
			}
			vb.visible = true;
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
	}
}