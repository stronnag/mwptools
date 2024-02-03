using Gtk;
using Gst;

public class VideoPlayer : Window {
	private Element playbin;
	private Gtk.Button play_button;
	private Gtk.Scale slider;
	private bool playing = false;
	private uint tid;
	private Gtk.Box vbox;
	private const SeekFlags SEEK_FLAGS=(SeekFlags.FLUSH|SeekFlags.KEY_UNIT);
	private Gst.ClockTime duration;
	private bool seeking = false;
	Gst.State st;

	public signal void video_playing(bool is_playing);
	public signal void video_closed();

	public VideoPlayer() {
		Widget video_area;
		string playbinx;

		duration =  (int64)0x7ffffffffffffff;
        set_icon_name("mwp_icon");

		if((playbinx = Environment.get_variable("MWP_PLAYBIN")) == null) {
			playbinx = "playbin";
		}
		playbin = ElementFactory.make (playbinx, playbinx);
		var gtksink = ElementFactory.make ("gtksink", "sink");
		if (gtksink == null) {
			MWPLog.message("gstreamer1-plugins-gtk appears missing\n");
			this.destroy();
		} else {
			gtksink.get ("widget", out video_area);
			playbin["video-sink"] = gtksink;

			vbox = new Box (Gtk.Orientation.VERTICAL, 0);
			vbox.pack_start (video_area);

			play_button = new Button.from_icon_name ("gtk-media-play", Gtk.IconSize.BUTTON);
			play_button.clicked.connect (on_play);
			set_size_request(480, 400);
			add (vbox);
			var bus = playbin.get_bus ();
			bus.add_watch(Priority.DEFAULT, bus_callback);

			var header_bar = new Gtk.HeaderBar ();
			header_bar.decoration_layout = "icon,menu:minimize,maximize,close";
			header_bar.set_title ("Video Replay");
			header_bar.show_close_button = true;
			var vb = new Gtk.VolumeButton();
			double vol;
			playbin.get("volume", out vol);
			vb.value = vol;
			vb.value_changed.connect((v) => {
					playbin.set("volume", v);
				});

			header_bar.pack_end (vb);
			header_bar.pack_start (play_button);

			header_bar.has_subtitle = false;
			set_titlebar (header_bar);
			destroy.connect (() => {
					if (tid > 0)
						Source.remove(tid);
					playbin.set_state (Gst.State.NULL);
					video_closed();
				});
		}
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

		var hbox = new Box (Gtk.Orientation.HORIZONTAL, 0);
		  var rewind = new Button.from_icon_name ("gtk-media-previous", Gtk.IconSize.BUTTON);
		  rewind.clicked.connect(() => {
				  playbin.get_state (out st, null, CLOCK_TIME_NONE);
				  seeking = true;
				  playbin.set_state (Gst.State.PAUSED);
				  playbin.seek_simple (Gst.Format.TIME, SEEK_FLAGS, (int64)0);
			  });
		  var forward = new Button.from_icon_name ("gtk-media-next", Gtk.IconSize.BUTTON);
		  forward.clicked.connect(() => {
				  seeking = true;
				  playbin.get_state (out st, null, CLOCK_TIME_NONE);
				  playbin.set_state (Gst.State.PAUSED);
				  playbin.seek_simple (Gst.Format.TIME, SEEK_FLAGS, (int64)duration);
			  });
		  hbox.pack_start (rewind, false, false, 0);
		  hbox.pack_start (slider, true, true);
		  hbox.pack_start (forward, false, false, 0);
		  vbox.pack_start(hbox, false);
	}

	public void set_slider_max(Gst.ClockTime max) {
		if (max > 0) {
			duration = max;
			double rt =  max / 1e9;
			add_slider();
			slider.set_range(0.0, rt);
		}
	}

	public void set_slider_value(double value) {
		if (slider != null)
			slider.set_value(value);
	}

	public void start_at(int64 tstart = 0) {
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

	public void add_stream(string fn, bool force=true) {
		bool start = false;
		if (force || !fn.has_prefix("file://")) {
			start = true;
		}
		playbin["uri"] = fn;
		if (start) {
			on_play();
		} else {
			playbin.set_state (Gst.State.PAUSED);
		}
		tid = Timeout.add(50, () => {
				Gst.Format fmt = Gst.Format.TIME;
				int64 current = -1;
				if (playbin.query_position (fmt, out current)) {
					double rt = current/1e9;
					set_slider_value(rt);
				}
				return true;
			});
	}

	private bool bus_callback (Gst.Bus bus, Gst.Message message) {
		switch (message.type) {
		case Gst.MessageType.ERROR:
			GLib.Error err;
			string debug;
			message.parse_error (out err, out debug);
			MWPLog.message("Video error: %s\n", err.message);
			destroy();
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
				var img = new Gtk.Image.from_icon_name("gtk-media-pause", Gtk.IconSize.BUTTON);
					play_button.set_image(img);
					playing = true;
			} else if(playing) {
				var img = new Gtk.Image.from_icon_name("gtk-media-play", Gtk.IconSize.BUTTON);
				play_button.set_image(img);
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
		if (playing ==  false)  {
			playbin.set_state (Gst.State.PLAYING);
			video_playing(true);
		} else {
			playbin.set_state (Gst.State.PAUSED);
			video_playing(false);
		}
	}

	public void toggle_stream() {
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

	public static Gst.ClockTime discover(string fn) {
		Gst.ClockTime id = 0;
		try {
			var d = new Gst.PbUtils.Discoverer((Gst.ClockTime) (Gst.SECOND * 5));
			var di = d.discover_uri(fn);
			id = di.get_duration ();
		} catch {}
		return id;
	}
}

public class V4L2_dialog : Gtk.Window {

	private Gtk.Entry e;
	private Gtk.RadioButton rb0;
	private Gtk.RadioButton rb1;

	public signal void response(int id);

	public V4L2_dialog(Gtk.ComboBoxText viddev_c) {
		title = "Select Video Source";
		border_width = 5;
        delete_event.connect(hide_on_delete);
		rb0  = new Gtk.RadioButton.with_label_from_widget (null, "Webcams");
		rb1 = new Gtk.RadioButton.with_label_from_widget (rb0, "URI");
		e = new Gtk.Entry();
		e.placeholder_text = "http://daria.co.uk/stream.mp4";
		e.input_purpose = Gtk.InputPurpose.URL;

		var grid = new Gtk.Grid();
		grid.attach(rb0, 0, 0);
		grid.attach(viddev_c, 1, 0);
		grid.attach(rb1, 0, 1);
		grid.attach(e, 1, 1);
		var cbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
		cbox.pack_start (grid, false, true, 2);
		var button = new Gtk.Button.with_label("OK");
		button.clicked.connect(() => {
				response(1000);
				hide();
			});
		cbox.pack_end (button, false, true, 2);
		add(cbox);
		show_all();
    }

	public int result(out string uri) {
        int res = -1;
		uri = null;
        if (rb0.active) {
            res = 0;
        } else {
            res = 1;
            uri = e.text;
        }
		return res;
	}
}

#if TEST

namespace MWPLog {
	public static void message(string format, ...) {
		var args = va_list();
        stderr.vprintf(format, args);
        stderr.flush();
    }
}


public static int main (string[] args) {
        Gst.init (ref args);
        Gtk.init (ref args);
        string? fn = null;
        Gst.ClockTime rt = 0;

        if (args.length > 1) {
			fn = args[1];
			if (fn.contains("""://"""))
				rt = 0;
			else {
				try {
					fn = Gst.filename_to_uri(args[1]);
					rt = VideoPlayer.discover(fn);
				} catch {
					return 127;
				}
			}
			var sample = new VideoPlayer();
			sample.set_slider_max(rt);
			sample.show_all ();
			Idle.add(() => {
					sample.add_stream(fn);
					return false;
				});
			sample.destroy.connect(Gtk.main_quit);
			Gtk.main ();
        }
        return 0;
}
#endif
