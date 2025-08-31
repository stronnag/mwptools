
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

	public bool check(string gstplugin) {
		var pg = Gst.ElementFactory.make (gstplugin);
		return (pg != null);
	}

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
			MwpVideo.playbin.set_state (Gst.State.PLAYING);
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
			image.width_request = 480;
			image.height_request = 360;
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
			if (MwpVideo.playbin != null) {
				MwpVideo.playbin.set_state (Gst.State.NULL);
			}
			MwpVideo.playbin = null;
		}
		if (MwpVideo.State.WINDOW in MwpVideo.state) {
			MwpVideo.window.close();
			MwpVideo.window = null;
		}
		MwpVideo.last_uri = null;
	}

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
			MwpVideo.playbin = null;
			Gdk.Paintable pt = null;
			Gst.Element videosink = null;
			if(uri.has_prefix("v4l2://")) {
				var device = uri.substring(7);
				string v4l2src;
#if WINDOWS
				v4l2src = "ksvideosrc device-name=";
#elif DARWIN
				v4l2src = "avfvideosrc device-name=";
#else
				v4l2src = "v4l2src device=";
#endif
				var str = "%s\"%s\" ! decodebin ! autovideoconvert !  gtk4paintablesink sync=false".printf(v4l2src, device);
				MWPLog.message("Playbin: %s\n", str);
				try {
					playbin = Gst.parse_launch (str);
					var gi = ((Gst.Bin)playbin).iterate_elements();
					Gst.IteratorResult res;
					Value elm;
					while ((res = gi.next(out elm)) != Gst.IteratorResult.DONE) {
						var o = elm.get_object();
						var e = o as Gst.Element;
						if (e.name.has_prefix("gtk4paintablesink")) {
							videosink = e;
						}
					}
				} catch (Error e) {
					MWPLog.message("Video playbin error %s\n", e.message);
				}
			} else {
				string playbinx;
				if((playbinx = Environment.get_variable("MWP_PLAYBIN")) == null) {
					playbinx = "playbin";
				}
				videosink = Gst.ElementFactory.make ("gtk4paintablesink" /*, "video-sink"*/);
				if (videosink == null) {
					MWPLog.message("Video fail - no gtk4 paintable");
					return null;
				}
				playbin = Gst.ElementFactory.make (playbinx, playbinx);
				playbin.set_property("uri", uri);
				playbin.set_property("video-sink", videosink);
				if(uri.has_prefix("rtsp:")) {
					playbin.set_property("latency", 10);
					videosink.set_property("sync", false);
				}
			}
			videosink.get("paintable", out pt);
			MWPLog.message("Videosink, paintable %p -> %p \n", videosink, pt);
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
}
