/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * (c) Jonathan Hudson <jh+mwptools@daria.co.uk>
 */

namespace VideoMan {
	public enum State {
		PLAYING=1,
		ENDED=2,
		PAUSED=3
	}

	public void load_v4l2_video() {
		string uri = null;
		int res = -1;
		var vid_dialog = new V4L2_dialog(GstDev.viddev_c);
		vid_dialog.response.connect((id) => {
				if(id == 0) {
					res = vid_dialog.result(out uri);
					switch(res) {
					case 0:
						 var i = GstDev.viddev_c.get_selected();
						 var dname = ((Gtk.StringList)GstDev.viddev_c.model).get_string(i);
						 if (dname != null) {
							 var devname = GstDev.get_device(dname);
							 uri = "v4l2://%s".printf(devname);
						 } else {
							 res = -1;
						 }
						 break;
					case 1:
						uri = uri.strip();
						if (uri.length > 0) {
							if (uri.has_prefix("~")) {
								var h = Environment.get_home_dir();
								uri = h + uri[1:uri.length];
							}
							if (!uri.contains("://")) {
								try {
									uri = Gst.filename_to_uri(uri);
								} catch {}
							}
						} else {
							res = -1;
						}
						break;
					}
				}
				vid_dialog.close();
				vid_dialog = null;
				if (res != -1) {
					var vp = new VideoPlayer(uri);
					vp.present();
				}
			});
		vid_dialog.present();
	}
}

public class VideoPlayer : Adw.Window {
	private  Gtk.MediaFile mf;

	public signal void play_state(VideoMan.State st);

	public VideoPlayer(string  uri) {
		var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
		title = "mwp Video player";
		set_icon_name("mwp_icon");
		transient_for=Mwp.window;
		default_width = 640;
		default_height = 480;
		var header_bar = new Adw.HeaderBar();
		vbox.append(header_bar);
		File f;
		if(uri.contains("://")) {
			f = File.new_for_uri(uri);
		} else {
			f = File.new_for_path(uri);
		}
		mf = Gtk.MediaFile.for_file(f);
		var v = new Gtk.Video.for_media_stream(mf);
		v.vexpand = true;
		mf.notify["playing"].connect(() => {
				VideoMan.State st;
				if (mf.ended) {
					st = VideoMan.State.ENDED;
				} else if (mf.playing) {
					st = VideoMan.State.PLAYING;
				} else {
					st = VideoMan.State.PAUSED;
				}
				play_state(st);
			});

		vbox.append(v);
		set_content(vbox);
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

	public void set_playing(bool p) {
		mf.set_playing(p);
	}
}

public class V4L2_dialog : Adw.Window {

	private Gtk.Entry e;
	private Gtk.CheckButton rb0;
	private Gtk.CheckButton rb1;

	public signal void response(int id);

	public V4L2_dialog(Gtk.DropDown viddev_c) {
		rb0 = null;
		transient_for = Mwp.window;
		var box = new Gtk.Box(Gtk.Orientation.VERTICAL,2);
		var header_bar = new Adw.HeaderBar();
		box.append(header_bar);
		set_icon_name("mwp_icon");
		title = "Select Video Source";
		rb0  = new Gtk.CheckButton.with_label ("Webcams");
		rb1 = new Gtk.CheckButton.with_label ("URI");
		rb1.active = true;
		rb0.set_group(rb1);
#if WINDOWS
		rb0.sensitive = false;
		viddev_c.sensitive = false;
#endif
		e = new Gtk.Entry();
		e.placeholder_text = "http://daria.co.uk/stream.mp4";
		e.input_purpose = Gtk.InputPurpose.URL;
		var grid = new Gtk.Grid();
		box.append(grid);

		if(rb0 != null) {
			grid.attach(rb0, 0, 0);
		}

		if (viddev_c != null) {
			grid.attach(viddev_c, 1, 0);
		}
		grid.attach(rb1, 0, 1);
		grid.attach(e, 1, 1);

		var bbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);

		var b0 = new Gtk.Button.with_label("Close");
		var b1 = new Gtk.Button.with_label("OK");

		bbox.append (b0);
		bbox.append (b1);
		bbox.hexpand = true;
		bbox.halign = Gtk.Align.FILL;
		b0.hexpand = true;
		b1.hexpand = true;

		b0.clicked.connect(() => {
				response(-1);
			});
		b1.clicked.connect(() => {
				response(0);
			});

		grid.vexpand = true;
		box.append(bbox);
		set_content(box);
	}

	public int result(out string uri) {
		uri=null;
		if (rb0 != null && rb0.active) {
            return 0;
        } else {
            uri = e.text;
			return 1;
        }
	}
}
