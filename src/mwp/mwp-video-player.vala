using Gtk;
using Gst;

public class VideoBox : GLib.Object {
	public Gtk.MediaFile mf;
	public VideoBox() {	}
	public void init(string fn) {
		File f;

		var cfile = save_file_name();
		if(fn.contains("://")) {
			f = File.new_for_uri(fn);
		} else {
			f = File.new_for_path(fn);
		}
		MWPLog.message(":DBG: Video %s\n", fn);
		mf = Gtk.MediaFile.for_file(f);
		mf.notify["error"].connect(() => {
				FileUtils.unlink(cfile);
			});

		try {
			FileUtils.set_contents(cfile, fn);
		} catch {}

		Mwp.window.close_request.connect(() => {
				mf.set_playing(false);
				return false;
			});
	}

	public static string save_file_name() {
		var uc =  Environment.get_user_config_dir();
		return GLib.Path.build_filename(uc,"mwp",".last_fpv-video");
	}
}

public class VideoPlayer : Adw.Window {
	public Gtk.MediaFile mf;
	private Gtk.Video v;

	public signal void video_playing(bool is_playing);
	public signal void video_closed();

	public VideoPlayer() {
		var headerBar = new Adw.HeaderBar();
		var vbox = new Box (Gtk.Orientation.VERTICAL, 0);
		vbox.append(headerBar);
		transient_for = Mwp.window;
		title = "mwp Video player";
		set_icon_name("mwp_icon");
		v = new Gtk.Video();
		v.vexpand = true;
		v.set_size_request(640, 480);
		vbox.append(v);
		close_request.connect (() => {
				mf.playing = false;
				video_closed();
				return false;

			});
		set_content(vbox);
	}

	public void init(string uri) {
		add_stream(uri);
	}

	public void start_at(int64 tstart = 0) {
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
	}

	public void toggle_stream() {
		mf.playing = !mf.playing;
	}

	public void add_stream(string fn, bool force=true) {
		File f;
		if(fn.contains("://")) {
			f = File.new_for_uri(fn);
		} else {
			f = File.new_for_path(fn);
		}
		mf = Gtk.MediaFile.for_file(f);
		mf.notify["playing"].connect(() => {
				video_playing(mf.playing);
			});
		mf.notify["error"].connect(() => {
				if(mf.error != null) {
					MWPLog.message("GTKVideo: %s\n", mf.error.message);
				}
			});
		v.set_media_stream(mf);
	}
}
