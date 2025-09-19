namespace MwpVideo {
	public class Viewer : Adw.Window {
		private Gtk.Box vbox;
		private Gtk.Video video;
		private Gtk.Picture pic;
		private Gtk.Button play_button;
		private Gtk.Scale slider;
		private Gst.ClockTime duration;
		private Gtk.ScaleButton volbtn;
		private Gtk.Label ptim;
		private Gtk.Label prem;
		private uint rtid;
		private Gtk.Revealer  rv;
		private Gtk.Overlay ovly;
		private double last_x;
		private double last_y;
		private double last_cx;
		private double last_cy;
		private ulong scvsig = 0;

		public Viewer() {
			set_transient_for(Mwp.window);
			duration =  Gst.CLOCK_TIME_NONE;
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
				duration = Gst.CLOCK_TIME_NONE;
				volbtn = new Gtk.ScaleButton(0.0, 1.0, 0.01, {"audio-volume-low-symbolic", "audio-volume-high-symbolic", "audio-volume-medium-symbolic"});
				volbtn.notify["active"].connect(() => {
						if(volbtn.active) {
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

				var cevtcm = new Gtk.EventControllerMotion();
				cbox.add_controller(cevtcm);
				cevtcm.motion.connect((x,y) => {
						if(x == last_cx && y == last_cy) {
							return;
						}
						last_cx = x;
						last_cy = y;
						if(rtid != 0) {
							Source.remove(rtid);
						}
						rtid = Timeout.add(3000, () => {
								return hide_media_bar();
							});
					});
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
			setup_window_player(p,start);
			MwpVideo.last_uri = uri;
			return p;
		}

		public void setup_window_player(Player p, bool start=true) {
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
								MwpVideo.player = null;
							} else {
								MwpVideo.state &= ~MwpVideo.State.PASSOVER;
							}
							MwpVideo.window = null;
							MwpVideo.state &= ~(MwpVideo.State.WINDOW|MwpVideo.State.PLAYWINDOW);
							return false;
						});
				} else {
					scvsig = slider.value_changed.connect(() => {
							Gst.State sts;
							double d = slider.get_value();
							p.playbin.get_state (out sts, null, Gst.CLOCK_TIME_NONE);
							p.playbin.seek_simple(Gst.Format.TIME, (Gst.SeekFlags.FLUSH|Gst.SeekFlags.KEY_UNIT), (int64)(d* Gst.SECOND));
						});

					p.eos.connect(() => {
							Gst.State sts;
							p.playbin.get_state (out sts, null, Gst.CLOCK_TIME_NONE);
							MWPLog.message("EOS %s\n", sts.to_string());
							p.playbin.set_state (Gst.State.PAUSED);
						});

					p.error.connect((e,d) => {
							p.handle_error(e,d,this);
						});

					p.state_change.connect((sts) => {
							play_button.icon_name = (sts) ? "media-playback-pause-symbolic" : "media-playback-start-symbolic";
						});

					p.set_duration.connect((t) => {
							duration = t;
							set_slider_max();
						});

					p.set_current.connect((t) => {
							double rtm = (double)t/Gst.SECOND;
							GLib.SignalHandler.block(slider, scvsig);
							set_slider_value(rtm);
							GLib.SignalHandler.unblock(slider, scvsig);
						});

					((Gtk.Picture)pic).paintable = p.pt;

					var accs = Mwp.window.application.get_accels_for_action("win.modeswitch");
					if(accs.length > 0) {
						var evtc = new Gtk.EventControllerKey ();
						evtc.set_propagation_phase(Gtk.PropagationPhase.CAPTURE);
						((Gtk.Widget)this).add_controller(evtc);
						var actkey = Gdk.keyval_from_name(accs[0]);
						var spckey = Gdk.keyval_from_name("space");
						evtc.key_pressed.connect((kv, kc, mfy) => {
								if (kv == actkey) {
									Mwp.window.switch_panel_mode(true);
									return true;
								} else if (kv == spckey) {
									p.toggle();
									return true;
								}
								return false;
							});
					}

					play_button.clicked.connect(() => {
							p.toggle();
						});

					double vol = 0.0;

					Type type = p.playbin.get_type();
					ObjectClass ocl = (ObjectClass)type.class_ref();
					unowned ParamSpec? spec = ocl.find_property ("volume");
					if (spec != null) {
						p.playbin.get("volume", out vol);
						volbtn.value_changed.connect((v) => {
								p.playbin.set("volume", v);
							});
					}
					volbtn.value = vol;

					close_request.connect (() => {
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

					MWPLog.message("Start play\n");
					p.set_playing(start);
				}
			}
		}

		private Gtk.Box? add_slider() {
			Gtk.Box? hbox=null;
			if (slider == null) {
				hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
				slider = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0, 1, 1);
				slider.set_draw_value(false);
				slider.restrict_to_fill_level=false;
				slider.hexpand = true;
				slider.sensitive=false;
				slider.add_css_class("osd");
				slider.halign = Gtk.Align.FILL;
				ptim = new Gtk.Label("");
				ptim.add_css_class("numeric");
				prem = new Gtk.Label("");
				prem.add_css_class("numeric");
				hbox.append(play_button);
				hbox.append(ptim);
				hbox.append (slider);
				hbox.append(prem);
				hbox.append(volbtn);
				hbox.hexpand = true;
				hbox.vexpand = false;
				volbtn.visible = true;
				volbtn.hexpand = true;
				volbtn.halign = Gtk.Align.END;
				slider.set_range(0.0, 0.0);
				slider.visible = false;
			}
			return hbox;
		}

		private string format_ct(double t, bool neg) {
			int m = (int)(t/60);
			int s = (int)((t % 60) + 0.5);
			return "%s%02d:%02d".printf((neg) ? "-" : "", m, s);
		}

		public void set_slider_max() {
			slider.visible = true;
			if (duration > 0) {
				double rt =  duration / Gst.SECOND;
				slider.set_range(0.0, rt);
				prem.label = format_ct(rt, true);
				prem.halign = Gtk.Align.END;
				slider.sensitive = true;
				slider.visible = true;
				volbtn.hexpand = false;
			}
			volbtn.visible = true;
		}

		public void set_slider_value(double value) {
			if (slider != null && duration != Gst.CLOCK_TIME_NONE) {
				slider.set_value(value);
				var rt = duration/Gst.SECOND - value;
				if (prem.label != "") {
					prem.label = format_ct(rt, true);
				}
			}
			ptim.label = format_ct(value, false);
		}
	}
}