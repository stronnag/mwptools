
using Gtk;
using Gst;

public class VideoPlayer : Window {
	private Element playbin;
	private Gtk.Button play_button;
	private Gtk.Scale slider;
	private bool playing = false;
	private uint tid;
	private Gtk.Box vbox;

	public VideoPlayer() {
		Widget video_area;
		string playbinx;

		if((playbinx = Environment.get_variable("MWP_PLAYBIN")) == null) {
			playbinx = "playbin";
		}
		playbin = ElementFactory.make (playbinx, playbinx);
		var gtksink = ElementFactory.make ("gtksink", "sink");
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
		header_bar.decoration_layout = ":minimize,maximize,close";
		header_bar.set_title ("Video Replay");
		header_bar.show_close_button = true;
		header_bar.pack_end (play_button);
		header_bar.has_subtitle = false;
		set_titlebar (header_bar);
			destroy.connect (() => {
					if (tid > 0)
						Source.remove(tid);
					playbin.set_state (Gst.State.NULL);
				});
		}


	private void add_slider() {
		slider = new Scale.with_range(Orientation.HORIZONTAL, 0, 1, 1);
		slider.set_draw_value(false);
		slider.change_value.connect((st, d) => {
				int64 pos = (int64)(1e9*d);
				playbin.seek_simple (Gst.Format.TIME,
									 Gst.SeekFlags.FLUSH | Gst.SeekFlags.KEY_UNIT,
									 pos);
				return true;
			});
		vbox.pack_start (slider, false, false,0);
	}

	public void set_slider_range(double min, double max) {
		if (max > 0) {
			add_slider();
			slider.set_range(min, max);
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
				playbin.seek_simple (Gst.Format.TIME,
									 Gst.SeekFlags.FLUSH | Gst.SeekFlags.KEY_UNIT,
									 tstart);
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
			}
			if (newstate == Gst.State.PAUSED && playing) {
				var img = new Gtk.Image.from_icon_name("gtk-media-play", Gtk.IconSize.BUTTON);
				play_button.set_image(img);
				playing = false;
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
		} else {
			playbin.set_state (Gst.State.PAUSED);
		}
	}
	public static double discover(string fn) {
		double rt = 0;
		try {
			var d = new Gst.PbUtils.Discoverer((Gst.ClockTime) (Gst.SECOND * 5));
			var di = d.discover_uri(fn);
			var id = di.get_duration ();
			rt =  id/1e9;
		} catch {}
		return rt;
	}
}

public class V4L2_dialog : Dialog {

	private Gtk.Entry e;
	private Gtk.RadioButton rb0;
	private Gtk.RadioButton rb1;

	public V4L2_dialog(Gtk.ComboBoxText viddev_c) {
		this.title = "Select Video Source";
		this.border_width = 5;
		rb0  = new Gtk.RadioButton.with_label_from_widget (null, "Webcams");
		rb1 = new Gtk.RadioButton.with_label_from_widget (rb0, "URI");
		e = new Gtk.Entry();
		e.placeholder_text = "http://daria.co.uk/stream.mp4";
		e.input_purpose = Gtk.InputPurpose.URL;
		var content = get_content_area () as Box;
		var grid = new Gtk.Grid();
		grid.attach(rb0, 0, 0);
		grid.attach(viddev_c, 1, 0);
		grid.attach(rb1, 0, 1);
		grid.attach(e, 1, 1);
		content.pack_start (grid, false, true, 2);
		add_button ("Close", 1001);
		add_button ("OK", 1000);
		set_modal(true);
	}

	public int runner(out string uri) {
		uri = null;
		int res = -1;
		show_all();
		var id = run();
		switch (id) {
		case 1000:
				if (rb0.active) {
					res = 0;
				} else {
					res = 1;
					uri = e.text;
				}
				break;
				case 1001:
					break;
				}
		hide();
		return res;
	}
}
