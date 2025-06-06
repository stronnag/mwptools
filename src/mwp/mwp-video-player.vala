using Gtk;
using Gst;

public class VideoPlayer : Adw.Window {
	private Element videosink;
	private Element playbin;
	private Gtk.Button play_button;
	private Gtk.Scale slider;
	private bool playing = false;
	private uint tid;
	private Gtk.Box vbox;
	private const SeekFlags SEEK_FLAGS=(SeekFlags.FLUSH|SeekFlags.KEY_UNIT);
	private Gst.ClockTime duration;
	private bool seeking = false;
	private Gst.State st;
	private Gtk.VolumeButton vb;
	private Gtk.Label ptim;
	private Gtk.Label prem;

	private  Gtk.MediaFile mf;
	private Gtk.Video v;

	public signal void video_playing(bool is_playing);
	public signal void video_closed();

	public VideoPlayer() {
		var headerBar = new Adw.HeaderBar();
		vbox = new Box (Gtk.Orientation.VERTICAL, 0);
		vbox.append(headerBar);
		if(Environment.get_variable("USE_GTKV") == null) {
			videosink = ElementFactory.make ("gtk4paintablesink");
		}
		transient_for = Mwp.window;
		if (videosink != null) {
			string playbinx;
			duration =  (int64)0x7ffffffffffffff;

			if((playbinx = Environment.get_variable("MWP_PLAYBIN")) == null) {
				playbinx = "playbin";
			}

			title = "mwp Video player";
			set_icon_name("mwp_icon");

			playbin = ElementFactory.make (playbinx, playbinx);
			playbin.set_property("video-sink", videosink);

			Gdk.Paintable pt;
			videosink.get("paintable", out pt);
			var pic = new Gtk.Picture();
			if(pt != null) {
				pic.paintable = pt;
			} else {
				MWPLog.message("ERROR: *** NO PAINTABLE ***\n");
			}
			pic.hexpand = true;
			pic.vexpand = true;
			vbox.append(pic);
			play_button = new Button.from_icon_name ("gtk-media-play");
			play_button.clicked.connect (on_play);
			pic.set_size_request(640, 480);
			var bus = playbin.get_bus ();
			bus.add_watch(Priority.DEFAULT, bus_callback);

			vb = new Gtk.VolumeButton();
			double vol;
			playbin.get("volume", out vol);
			vb.value = vol;
			vb.value_changed.connect((v) => {
					playbin.set("volume", v);
				});
			//			headerBar.pack_end (vb);
			//headerBar.pack_start (play_button);
		} else {
			title = "mwp (fallback) Video player";
			set_icon_name("mwp_icon");

			default_width = 640;
			default_height = 480;

			v = new Gtk.Video();
			v.vexpand = true;
			vbox.append(v);
		}

		close_request.connect (() => {
				if(videosink == null) {
					mf.playing = false;
				} else {
					if (tid > 0)
						Source.remove(tid);
					playbin.set_state (Gst.State.NULL);
				}
				video_closed();
				return false;
			});
		set_content(vbox);
	}

	private void add_slider() {
		slider = new Scale.with_range(Orientation.HORIZONTAL, 0, 1, 1);
		slider.set_draw_value(false);
		slider.change_value.connect((stype, d) => {
				seeking = true;
				playbin.get_state (out st, null, CLOCK_TIME_NONE);
				playbin.set_state (Gst.State.PAUSED);
				playbin.seek (1.0,
							  Gst.Format.TIME, SEEK_FLAGS,
							  Gst.SeekType.SET, (int64)(d * Gst.SECOND),
							  Gst.SeekType.NONE, (int64)Gst.CLOCK_TIME_NONE);
				return true;
			});
		slider.hexpand = true;

		var hbox = new Box (Gtk.Orientation.HORIZONTAL, 0);
		  hbox.append(play_button);
		  if (ptim != null) {
			  hbox.append(ptim);
		  }
		  hbox.append (slider);
		  if (prem != null) {
			  hbox.append(prem);
		  }
		  hbox.append(vb);
		  vbox.append(hbox);
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
			ptim = new Gtk.Label(format_ct(0, false));
			prem = new Gtk.Label(format_ct(rt, true));
			add_slider();
			slider.set_range(0.0, rt);
		}
	}

	public void set_slider_value(double value) {
		if (slider != null)
			slider.set_value(value);

		ptim.label = format_ct(value, false);
		var rt = duration/1e9 - value;
		prem.label = format_ct(rt, true);
	}

	public void start_at(int64 tstart = 0) {
		if(videosink == null) {
			if(tstart < 0) {
				int msec = (int)(-1*(tstart / 1000000));
				Timeout.add(msec, () => {
						mf.play_now();
						return Source.REMOVE;
					});
			} else {
				mf.play_now();
				if (tstart > 0) {
					mf.seek (tstart);
				}
			}
		} else {
			if(tstart < 0) {
				int msec = (int)(-1*(tstart / 1000000));
				Timeout.add(msec, () => {
						on_play();
						return Source.REMOVE;
				});
			} else {
				on_play();
				if (tstart > 0) {
					playbin.seek_simple (Gst.Format.TIME, SEEK_FLAGS, tstart);
				}
			}
		}
	}

	public void toggle_stream() {
		if(videosink == null) {
			mf.playing = !mf.playing;
		} else {
			switch (playbin.current_state) {
			case Gst.State.PLAYING:
				playbin.set_state (Gst.State.PAUSED);
				break;
			case Gst.State.PAUSED:
				playbin.set_state (Gst.State.PLAYING);
				break;
			default:
				break;
			}
		}
	}

	public void add_stream(string fn, bool force=true) {
		var start = (force || !fn.has_prefix("file://"));
		string vuri;
		if (!fn.contains("""://""")) {
			try {
				vuri = Gst.filename_to_uri(fn);
			} catch (Error e) {
				MWPLog.message("VURI error: %s\n", e.message);
				return;
			}
		} else {
			vuri = fn;
		}
		if(videosink == null) {
			File f = File.new_for_uri(vuri);
			mf = Gtk.MediaFile.for_file(f);
			mf.notify["playing"].connect(() => {
					video_playing(mf.playing);
			});
			v.set_media_stream(mf);
		} else {
			playbin["uri"] = vuri;
			Gst.ClockTime rt = Gst.CLOCK_TIME_NONE;
			rt = VideoPlayer.discover(vuri);
			if (rt !=  Gst.CLOCK_TIME_NONE) {
				set_slider_max(rt);
			}

			if (start) {
				on_play();
			} else {
				playbin.set_state (Gst.State.PAUSED);
			}

			tid = Timeout.add(50, () => {
					Gst.Format fmt = Gst.Format.TIME;
					int64 current = -1;
					if (playbin.query_position (fmt, out current)) {
						double rtm = current/1e9;
						set_slider_value(rtm);
					}
					return true;
				});
		}
	}

	private bool bus_callback (Gst.Bus bus, Gst.Message message) {
		switch (message.type) {
		case Gst.MessageType.ERROR:
			GLib.Error err;
			string debug;
			message.parse_error (out err, out debug);
			MWPLog.message("Video error: %s\n", err.message);
			break;
		case Gst.MessageType.EOS:
			playing = false;
			playbin.set_state (Gst.State.READY);
			break;
		case Gst.MessageType.STATE_CHANGED:
			Gst.State oldstate;
			Gst.State newstate;
			Gst.State pending;
			message.parse_state_changed (out oldstate, out newstate, out pending);
			if(newstate == Gst.State.PLAYING && !playing) {
				play_button.icon_name = "gtk-media-pause";
				playing = true;
			} else if(playing) {
				play_button.icon_name = "gtk-media-play";
				playing = false;
			}
			break;

		case Gst.MessageType.ASYNC_DONE:
			if (seeking) {
				seeking = false;
				playbin.set_state (st);
			}
			break;
		default:
			break;
		}
		return true;
	}

	void on_play() {
		if(videosink != null) {
			if (playing ==  false)  {
				playbin.set_state (Gst.State.PLAYING);
				video_playing(true);
			} else {
				playbin.set_state (Gst.State.PAUSED);
				video_playing(false);
			}
		}
	}

	public static Gst.ClockTime discover(string fn) {
		Gst.ClockTime id = 0;
		try {
			var d = new Gst.PbUtils.Discoverer((Gst.ClockTime) (Gst.SECOND * 5));
			var di = d.discover_uri(fn);
			id = di.get_duration ();
			foreach(var v in di.get_video_streams ()) {
				if (v is Gst.PbUtils.DiscovererVideoInfo) {
					// print("Vid Size: %u %u\n",  ((Gst.PbUtils.DiscovererVideoInfo)v).get_width(), ((Gst.PbUtils.DiscovererVideoInfo)v).get_height());
				}
			}
		} catch {}
		return id;
	}
}
