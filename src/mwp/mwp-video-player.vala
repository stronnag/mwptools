
namespace MwpVideo {
	public Adw.Window window;
	public string last_uri;
	public Gst.Element playbin;
	public Gtk.MediaFile mmf;
	public bool is_fallback;
	public Player player;

	private Gst.State nstate;

	[Flags]
	public enum State {
		PLAYER,
		WINDOW,
		PLAYWINDOW,
		PASSOVER;

		public string to_string() {
			string []states = {};
			if (is_fallback) {
				states += "Fallback";
			}
			if ((this & PLAYER) != 0) {
				states += "Player";
			}
			if ((this & WINDOW) != 0) {
				states += "Window";
			}
			if ((this & PLAYWINDOW) != 0) {
				states += "InWindow";
			}
			if ((this & PASSOVER) != 0) {
				states += "Passover";
			}
			return "[%x] %s".printf(this, string.joinv(",", states));
		}
	}

	public State state;

	public void check() {
		is_fallback = false;
		if (Mwp.conf.use_fallback_video) {
			is_fallback = true;
		} else {
			var pg = Gst.ElementFactory.make ("gtk4paintablesink");
			is_fallback = (pg == null);
		}
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
		return GLib.Path.build_filename(uc,"mwp",".last-fpv-video");
	}

	public void toggle() {
		MwpVideo.player.toggle();
	}

	public void set_playing(bool play) {
		MwpVideo.player.set_playing(play);
	}

	public void seek(int64 to) {
		if(!MwpVideo.is_fallback) {
			MwpVideo.playbin.seek_simple(Gst.Format.TIME, (Gst.SeekFlags.FLUSH|Gst.SeekFlags.KEY_UNIT), to);
		} else {
			to /= 1000; /** Microseconds FFS */
			MwpVideo.mmf.seek(to);
		}
	}

	public void into_window() {
		var vp = new MwpVideo.Viewer();
		vp.present();
		Idle.add(() => {
				vp.setup_window_player(MwpVideo.player);
				//((Gtk.Picture)Mwp.window.vpane.start_child).paintable = null;
				return false;
			});
	}

	public void embedded_player(string uri) {
		MwpVideo.Player p = null;
		Gdk.Paintable pt = null;

		MWPLog.message(":DBG: VPane entry setting %s\n", MwpVideo.state.to_string());
		if (MwpVideo.State.PLAYWINDOW in MwpVideo.state) {
			MWPLog.message(":DBG: VP Pass over extant pt\n");
			pt = ((MwpVideo.Viewer)MwpVideo.window).clear_player();
			MwpVideo.state |= MwpVideo.State.PASSOVER;
			((MwpVideo.Viewer)MwpVideo.window).close();
		} else {
			MWPLog.message(":DBG: VP Create new player\n");
			p = new MwpVideo.Player(uri);
			pt = p.pt;
			if (pt != null) {
				p.error.connect((e,d) => {
						p.handle_error(e,d,Mwp.window);
					});
				p.eos.connect(() => {
						if (p!=null) {
							p.clear();
							p = null;
						}
					});
			}
		}

		if(pt != null) {
			MWPLog.message("to vpane, pt=%p\n", pt);
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
			MwpVideo.set_playing(true);
		} else {
			var wb = new Utils.Warning_box("Cannot create video player");
			wb.present();
		}
	}

	public void stop_embedded_player() {
		if (MwpVideo.State.PLAYER in MwpVideo.state) {
			MWPLog.message(":DBG: stop embedded %s\n", MwpVideo.state.to_string());
			if(MwpVideo.is_fallback) {
				MwpVideo.mmf.close();
				MwpVideo.mmf = null;
			} else {
				if (MwpVideo.playbin != null) {
					MwpVideo.playbin.set_state (Gst.State.NULL);
				}
				MwpVideo.playbin = null;
			}
			MwpVideo.state &= ~MwpVideo.State.PLAYER;
		}
		if (MwpVideo.State.WINDOW in MwpVideo.state) {
			MwpVideo.window.close();
			MwpVideo.window = null;
			MwpVideo.state &= ~MwpVideo.State.WINDOW;
		}
		MwpVideo.last_uri = null;
	}

	public class Player : GLib.Object {
		public Gst.Element playbin;
		public signal void state_change(bool s);
		public signal void eos();
		public signal void error(GLib.Error e, string debug);
		public signal void set_duration(int64 t);
		public signal void set_current(int64 t);
		private uint tid;
		private Gst.ClockTime duration;
		public Gdk.Paintable pt;
		private Gst.ClockTime current;
		private bool show_error;

		private void start_timer() {
			tid = Timeout.add(100, () => {
					if(MwpVideo.is_fallback) {
						current = ((Gtk.MediaStream)pt).timestamp;
						set_current(((int64)current+500)*1000);
					} else {
						if(duration == Gst.CLOCK_TIME_NONE) {
							if(playbin.query_duration( Gst.Format.TIME, out duration)) {
								if (duration !=  Gst.CLOCK_TIME_NONE) {
									set_duration((int64)duration);
								}
							}
						}
						if(playbin.query_position( Gst.Format.TIME, out current)) {
							set_current((int64)current);
						}
					}
					return true;
				});
		}

		~Player() {
			if(!MwpVideo.is_fallback) {
				MWPLog.message(":DBG: player destructor %s\n", MwpVideo.state.to_string());
				if (MwpVideo.playbin != null) {
					MwpVideo.playbin.set_state (Gst.State.NULL);
					MwpVideo.playbin = null;
				}
			} else {
				MWPLog.message("Legacy Player destructor\n");
			}
			if (tid > 0) {
				Source.remove(tid);
				tid = 0;
			}
			MwpVideo.state &= ~MwpVideo.State.PLAYER;
			MwpVideo.player = null;
		}

		public Player(string ouri) {
			show_error = false;
			current = Gst.CLOCK_TIME_NONE;
			duration =  Gst.CLOCK_TIME_NONE;
			var uri = MwpVideo.to_uri(ouri);
			pt = generate_playbin(uri);
			if (pt != null) {
				if(MwpVideo.is_fallback) {
					MWPLog.message("BS: MF %p\n", pt);
					MwpVideo.mmf = pt as Gtk.MediaFile;
				} else {
					var bus = playbin.get_bus ();
					bus.add_watch(Priority.DEFAULT, bus_callback);
					MwpVideo.playbin = this.playbin;
				}
				start_timer();
				MwpVideo.state = MwpVideo.State.PLAYER;
				MwpVideo.player = this;
			} else {
				MwpVideo.player = null;
			}
		}

		private Gdk.Paintable? generate_playbin(string uri) {
			File f;
			string furi = uri;
			if(MwpVideo.is_fallback) {
				if(uri.has_prefix("camera://")) {
#if (LINUX || FREEBSD)
					var devname = uri.substring(9);
					MWPLog.message("FB lookup %s\n", devname);
					var ds = MwpCamera.find_camera(devname);
					if (ds != null) {
						furi = "v4l2://".concat(ds.devicename);
						MWPLog.message("FB Device %s %s -> %s \n", ds.devicename, ds.driver, furi);
					} else {
						furi = "v4l2://".concat(devname);
						MWPLog.message("FB Device %s\n", furi);
					}
#else
					return null;
#endif
				}
				f = File.new_for_uri(furi);
				if(f != null) {
					var mmf = Gtk.MediaFile.for_file(f);
					if (mmf != null) {
						MwpVideo.state = MwpVideo.State.PLAYER;
						MwpVideo.mmf = mmf;
						mmf.notify["error"].connect(() => {
								if(mmf.error != null) {
									error(mmf.error,"");
								}
							});
						return mmf;
					}
				}
				return null;
			} else {
				MwpVideo.playbin = null;
				Gdk.Paintable ptx = null;
				Gst.Element videosink = null;
				MwpCamera.VideoDev? ds = null;
				string devname = null;
				bool dbg = (Environment.get_variable("MWP_SHOW_FPS") != null);
				MWPLog.message(":DBG:URI: %s\n", uri);
				if(uri.has_prefix("camera://")) {
					devname = uri.substring(9);
					MWPLog.message(":DBG:CAM: %s\n", devname);
					ds = MwpCamera.find_camera(devname);
					if(ds == null) {
						return null;
					}
					int16 camopt = MwpCamera.lookup_camera_opt(devname);
					var sb = new StringBuilder(ds.driver);
					sb.append_c(' ');
					sb.append(ds.launch_props);
					if(camopt == -1) {
						camopt = 0;
					}
					unowned var caps = 	MwpCamera.get_caps(devname);
					if (camopt < caps.length) {
						sb.append_printf(" ! %s", caps[camopt]);
					}
					if(dbg) {
						sb.append(" ! decodebin ! autovideoconvert ! fpsdisplaysink video-sink=gtk4paintablesink text-overlay=true");
					} else {
						sb.append(" ! decodebin ! autovideoconvert !  gtk4paintablesink sync=false");
					}
					var str = sb.str;
					MWPLog.message("Playbin: %s\n", str);
					try {
						playbin = Gst.parse_launch (str);
					} catch (Error e) {
						MWPLog.message("Video playbin error %s\n", e.message);
						ptx = null;
					}
					if(!dbg) {
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
					} else {
						videosink = find_gtk4_sink((Gst.Bin)playbin);
					}
				} else {
					string playbinx;
					if((playbinx = Environment.get_variable("MWP_PLAYBIN")) == null) {
						playbinx = "playbin";
					}
					playbin = Gst.ElementFactory.make (playbinx, playbinx);
					playbin.set_property("uri", uri);
					if(dbg) {
						var vsrc = "fpsdisplaysink video-sink=gtk4paintablesink text-overlay=true";
						Gst.Element vbin = null;
						try {
							vbin = Gst.parse_launch (vsrc);
						} catch (Error e) {
							MWPLog.message("Failed to parse %s: %s\n", vsrc, e.message);
							return null;
						}
						videosink = find_gtk4_sink((Gst.Bin)vbin);
						playbin.set_property("video-sink", vbin);
					} else {
						videosink = Gst.ElementFactory.make ("gtk4paintablesink" );
						playbin.set_property("video-sink", videosink);
					}
					if (videosink == null) {
						MWPLog.message("Video fail - no gtk4 paintable");
						return null;
					}
					if(uri.has_prefix("rtsp:")) {
						playbin.set_property("latency", 10);
						videosink.set_property("sync", false);
					}
				}
				videosink.get("paintable", out ptx);
				MWPLog.message("Videosink, paintable %p -> %p \n", videosink, ptx);
				playbin.set_state (Gst.State.READY);
				return ptx;
			}
		}

		private Gst.Element? find_gtk4_sink(Gst.Bin vbin) {
			for(var j = 0; j < 9; j++) {
				var vname = "gtk4paintablesink%d".printf(j);
				var vsink = vbin.get_by_name(vname);
				if (vsink != null) {
					return vsink;
				}
			}
			return null;
		}

		private bool bus_callback (Gst.Bus bus, Gst.Message message) {
			switch (message.type) {
			case Gst.MessageType.BUFFERING:
				break;

			case Gst.MessageType.ERROR:
				GLib.Error err;
				string debug;
				message.parse_error (out err, out debug);
				error(err, debug);
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
				if (newstate != nstate) {
					if(newstate == Gst.State.PLAYING) {
						state_change(true);
					} else  {
						state_change(false);
					}
					nstate = newstate;
				}
				break;
			default:
				break;
			}
			return true;
		}

		public void set_playing(bool play) {
			if(MwpVideo.is_fallback) {
				((Gtk.MediaStream)pt).playing = play;
			} else {
				if (play) {
					playbin.set_state (Gst.State.PLAYING);
				} else {
					playbin.set_state (Gst.State.PAUSED);
				}
			}
		}

		public void toggle() {
			if(MwpVideo.is_fallback) {
				((Gtk.MediaStream)pt).playing = !((Gtk.MediaStream)pt).playing;
			} else {
				Gst.State sts;
				playbin.get_state (out sts, null, Gst.CLOCK_TIME_NONE);
				if (sts != Gst.State.PLAYING) {
					playbin.set_state (Gst.State.PLAYING);
				} else {
					playbin.set_state (Gst.State.PAUSED);
				}
			}
		}

		public void clear() {
			if(MwpVideo.is_fallback) {
				MwpVideo.state &= ~MwpVideo.State.PLAYER;
			} else {
				playbin.set_state (Gst.State.NULL);
				MwpVideo.state &= ~MwpVideo.State.PLAYER;
			}
		}

		public void handle_error(Error e, string d, Gtk.Window? w) {
			bool showme = true;
			MWPLog.message("Gst Error [%s] [%s] (%s,%d)\n", e.message, d,
						   e.domain.to_string(), e.code);
#if WINDOWS
			if(e.domain.to_string() == "gst-resource-error-quark" && e.code == 3) {
				showme = false;
			}
#endif
			if(!show_error && showme) {
				var wb = new Utils.Warning_box("A Video error has occurred.\nThis may be recoverable\n(Play button / Space Bar to retry)\n\nSee log for details", 0, w);
				wb.present();
			} else {
				set_playing(true);
			}
			show_error = true;
		}
	}
}
