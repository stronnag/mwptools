
namespace MwpVideo {
	public Gst.Element playbin;
	public Adw.Window window;
	public string last_uri;

	public string save_file_name() {
		var uc =  Environment.get_user_config_dir();
		return GLib.Path.build_filename(uc,"mwp",".last_fpv-video");
	}

	public string? to_uri(string uri) {
		string vuri = null;
		if (!uri.contains("""://""")) {
			try {
				vuri = Gst.filename_to_uri(uri);
			} catch (Error e) {
				print("ERROR FN: %s\n", e.message);
			}
		} else {
			vuri = uri;
		}
		MwpVideo.last_uri = uri;
		return vuri;
	}

	public void embedded_player(string uri) {
		var p = new MwpVideo.Player(uri);
		if (p.pt != null) {
			p.eos.connect(() => {
					MWPLog.message("Video stream EOS\n");
					p.playbin.set_state (Gst.State.NULL);
					p = null;
				});

			var image = new Gtk.Picture.for_paintable (p.pt);
			image.hexpand = true;
			image.vexpand = true;
			ulong active_id = 0;
			active_id = p.pt.invalidate_size.connect (()=>{
					var h = p.pt.get_intrinsic_height();
					var w = p.pt.get_intrinsic_width();
					if (Mwp.DebugFlags.VIDEO in Mwp.debug_flags) {
						MWPLog.message(":DBG: Embedded video %dx%d \n", w, h);
					}
					p.pt.disconnect (active_id);
				});
			image.width_request = 640;
			image.height_request = 480;
			image.content_fit = Gtk.ContentFit.CONTAIN;
			image.can_shrink = true;
			Mwp.window.vpane.set_start_child(image);
			p.playbin.set_state (Gst.State.PLAYING);
			var cfile = save_file_name();
			try {
				FileUtils.set_contents(cfile, uri);
			} catch {}
		}
	}

	public static void stop_embedded_player() {
		if (MwpVideo.playbin != null) {
			MwpVideo.playbin.set_state (Gst.State.NULL);
			MwpVideo.playbin = null;
		}
		if (MwpVideo.window != null) {
			MwpVideo.window.close();
			MwpVideo.window = null;
		}
		MwpVideo.last_uri = null;
	}

	public class Player : GLib.Object {
		public Gst.Element playbin;
		public Gdk.Paintable pt;
		public signal void state_change(bool s);
		public signal void eos();
		public signal void async_done();

		~Player() {
			if (MwpVideo.playbin != null) {
				MwpVideo.playbin.set_state (Gst.State.NULL);
				MwpVideo.playbin = null;
				MwpVideo.last_uri = null;
			}
			MWPLog.message("Removing video player\n");
		}

		public Player(string ouri) {
			var uri = MwpVideo.to_uri(ouri);
			pt = generate_playbin(uri);
			if (pt != null) {
				var bus = playbin.get_bus ();
				bus.add_watch(Priority.DEFAULT, bus_callback);
				MwpVideo.playbin = this.playbin;
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
				print("No gtk4 paintable");
				return null;
			}
			playbin = Gst.ElementFactory.make (playbinx, playbinx);
			playbin.set_property("uri", uri);
			playbin.set_property("video-sink", videosink);
			if(uri.has_prefix("rtsp:")) {
				MWPLog.message("Set RTSP low latency\n");
				playbin.set_property("latency", 0);
				videosink.set_property("sync", false);
			}
			Gdk.Paintable pt;
			videosink.get("paintable", out pt);

			playbin.set_state (Gst.State.READY);
			return pt;
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
	}
}
