
namespace MwpVideo {
	public Adw.Window window;
	public string last_uri;

	[Flags]
	public enum State {
		PLAYER,
		WINDOW,
		PLAYWINDOW;

		public string to_string() {
			string []states = {};
			if ((this & PLAYER) != 0) {
				states += "Player";
			}
			if ((this & WINDOW) != 0) {
				states += "Window";
			}
			if ((this & PLAYWINDOW) != 0) {
				states += "InWindow";
			}
			return "[%x] %s".printf(this, string.joinv(",", states));
		}
	}

	public State state;

	public string? to_uri(string uri) {
		string vuri = null;
		if (!uri.contains("""://""")) {
			try {
				vuri = Gst.filename_to_uri(uri);
			} catch (Error e) {
				MWPLog.message("ERROR FN: %s\n", e.message);
			}
		} else {
			vuri = uri;
		}
		return vuri;
	}

	public string save_file_name() {
		var uc =  Environment.get_user_config_dir();
		return GLib.Path.build_filename(uc,"mwp",".last_fpv-video");
	}

	public void embedded_player(string uri) {
		MwpVideo.Player p = null;
		Gdk.Paintable pt;

		MWPLog.message(":DBG: VPane entry setting %s\n", MwpVideo.state.to_string());
		if (MwpVideo.State.PLAYWINDOW in MwpVideo.state) {
			MWPLog.message(":DBG: VP Pass over extant pt\n");
			pt = ((MwpVideo.Viewer)MwpVideo.window).clear_player();
			((MwpVideo.Viewer)MwpVideo.window).close();
#if !UNSUPPORTED_OS
			MwpVideo.playbin.set_state (Gst.State.PLAYING);
#else
			MwpVideo.mmf.playing = true;
#endif
		} else {
			MWPLog.message(":DBG: VP Create new player\n");
			p = new MwpVideo.Player(uri);
			pt = p.pt;
			p.eos.connect(() => {
					MWPLog.message("Video stream EOS\n");
					p.clear();
					p = null;
				});
			p.set_playing(true);
		}

		if (pt != null) {
			var image = new Gtk.Picture.for_paintable (pt);
			image.hexpand = true;
			image.vexpand = true;
			ulong active_id = 0;
			active_id = pt.invalidate_size.connect (()=>{
					var h = pt.get_intrinsic_height();
					var w = pt.get_intrinsic_width();
					if (Mwp.DebugFlags.VIDEO in Mwp.debug_flags) {
						MWPLog.message(":DBG: Embedded video %dx%d \n", w, h);
					}
					pt.disconnect (active_id);
				});
			image.width_request = 640;
			image.height_request = 480;
			image.content_fit = Gtk.ContentFit.CONTAIN;
			image.can_shrink = true;
			Mwp.window.vpane.set_start_child(image);

			var cfile = save_file_name();
			try {
				FileUtils.set_contents(cfile, uri);
			} catch {}
		}
	}

	public void stop_embedded_player() {
		MWPLog.message(":DBG: stop embedded %s\n", MwpVideo.state.to_string());

		if (MwpVideo.State.PLAYER in MwpVideo.state) {
#if !UNSUPPORTED_OS
			if (MwpVideo.playbin != null) {
				MwpVideo.playbin.set_state (Gst.State.NULL);
			}
			MwpVideo.playbin = null;
#else
			if (MwpVideo.mmf != null) {
				MwpVideo.mmf.close();
			}
			MwpVideo.mmf = null;
#endif
		}
		if (MwpVideo.State.WINDOW in MwpVideo.state) {
			MwpVideo.window.close();
			MwpVideo.window = null;
		}
		MwpVideo.last_uri = null;
	}

#if !UNSUPPORTED_OS
	public Gst.Element playbin;

	public class Player : GLib.Object {
		public Gst.Element playbin;
		public signal void state_change(bool s);
		public signal void eos();
		public signal void error(int e);
		public signal void async_done();
		public Gdk.Paintable pt;

		~Player() {
			MWPLog.message(":DBG: player destructor %s\n", MwpVideo.state.to_string());
			if (MwpVideo.playbin != null) {
				MwpVideo.playbin.set_state (Gst.State.NULL);
				MwpVideo.playbin = null;
			}
			MwpVideo.state &= ~MwpVideo.State.PLAYER;
		}

		public Player(string ouri) {
			var uri = MwpVideo.to_uri(ouri);
			pt = generate_playbin(uri);
			if (pt != null) {
				var bus = playbin.get_bus ();
				bus.add_watch(Priority.DEFAULT, bus_callback);
				MwpVideo.playbin = this.playbin;
				MwpVideo.state = MwpVideo.State.PLAYER;
			}
		}

		private Gdk.Paintable? generate_playbin(string uri) {
			string playbinx;
			MwpVideo.playbin = null;
			if((playbinx = Environment.get_variable("MWP_PLAYBIN")) == null) {
				playbinx = "playbin";
			}

			var videosink = Gst.ElementFactory.make ("gtk4paintablesink" /*, "video-sink"*/);
			if (videosink == null) {
				MWPLog.message("Video Fail: No gtk4 paintable\n");
				return null;
			}
			playbin = Gst.ElementFactory.make (playbinx, playbinx);
			playbin.set_property("uri", uri);
			playbin.set_property("video-sink", videosink);
			if(uri.has_prefix("rtsp:")) {
				playbin.set_property("latency", 10);
				videosink.set_property("sync", false);
			}
			Gdk.Paintable pt;
			videosink.get("paintable", out pt);
			playbin.set_state (Gst.State.READY);
			return pt;
		}

		private bool bus_callback (Gst.Bus bus, Gst.Message message) {
			switch (message.type) {

			case Gst.MessageType.BUFFERING:
				int percent = 0;
				message.parse_buffering (out percent);
				MWPLog.message("Video: buffering (%u percent done)", percent);
				break;

			case Gst.MessageType.ERROR:
				GLib.Error err;
				string debug;
				message.parse_error (out err, out debug);
				MWPLog.message("Video error: %s (%d)\n", err.message, err.code);
				error(err.code);
				break;
			case Gst.MessageType.EOS:
				playbin.set_state (Gst.State.READY);
				eos();
				break;
			case Gst.MessageType.STATE_CHANGED:
				Gst.State oldstate;
				Gst.State newstate;
				Gst.State pending;
				message.parse_state_changed (out oldstate, out newstate, out pending);
				if(newstate == Gst.State.PLAYING) {
					state_change(true);
				} else  {
					state_change(false);
				}
				break;

			case Gst.MessageType.ASYNC_DONE:
				async_done();
				break;
			default:
				break;
			}
			return true;
		}

		public void set_playing(bool play) {
			if (play) {
				playbin.set_state (Gst.State.PLAYING);
			} else {
				playbin.set_state (Gst.State.PAUSED);
			}
		}

		public void clear() {
			playbin.set_state (Gst.State.NULL);
			MwpVideo.state &= ~MwpVideo.State.PLAYER;
		}
	}
#else
	public Gtk.MediaFile mmf;

	public class Player : GLib.Object {
		public Gtk.MediaFile pt;
		public signal void state_change(bool s);
		public signal void eos();
		public signal void error(int e);
		public signal void async_done();

		~Player() {
			MwpVideo.state &= ~MwpVideo.State.PLAYER;
		}

		public Player(string ouri) {
			var uri = MwpVideo.to_uri(ouri);
			pt = generate_playbin(uri);
			if(pt != null) {
				MWPLog.message("BS: MF %p\n", pt);
				MwpVideo.mmf = pt;
			}
			MwpVideo.state = MwpVideo.State.PLAYER;
		}

		private Gtk.MediaFile? generate_playbin(string uri) {
			var f = File.new_for_uri(uri);
			return Gtk.MediaFile.for_file(f);
		}

		public void set_playing(bool play) {
			pt.playing = play;
		}

		public void clear() {
			pt.clear();
			MwpVideo.state &= ~MwpVideo.State.PLAYER;
		}
	}
#endif
}
