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
	public void load_v4l2_video() {
		string uri = null;
		int res = -1;
		var vid_dialog = new V4L2_dialog(GstDev.viddev_c);
		vid_dialog.response.connect((id) => {
				if(id == 0) {
					res = vid_dialog.result(out uri);
					switch(res) {
					case 0:
						if (GstDev.viddev_c.active_id != null) {
							uri = "v4l2://%s".printf(GstDev.viddev_c.active_id);
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
							if (!uri.contains("""://""")) {
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

	public signal void play_state(bool state);

	public VideoPlayer(string  uri) {
		var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
		title = "mwp Video player";
		set_icon_name("mwp_icon");
		transient_for=Mwp.window;
		default_width = 640;
		default_height = 480;
		var header_bar = new Adw.HeaderBar();
		vbox.append(header_bar);

		var f = File.new_for_uri(uri);
		mf = Gtk.MediaFile.for_file(f);
		var v = new Gtk.Video.for_media_stream(mf);

		mf.notify["playing"].connect(() => {
				play_state(mf.playing);
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

	public V4L2_dialog(Gtk.ComboBoxText viddev_c) {
		transient_for = Mwp.window;
		var box = new Gtk.Box(Gtk.Orientation.VERTICAL,2);
		var header_bar = new Adw.HeaderBar();
		box.append(header_bar);
		set_icon_name("mwp_icon");
		title = "Select Video Source";

		rb0  = new Gtk.CheckButton.with_label ("Webcams");
		rb1 = new Gtk.CheckButton.with_label ("URI");
		rb0.active = true;
		rb0.set_group(rb1);
		e = new Gtk.Entry();
		e.placeholder_text = "http://daria.co.uk/stream.mp4";
		e.input_purpose = Gtk.InputPurpose.URL;
		var grid = new Gtk.Grid();
		grid.attach(rb0, 0, 0);
		grid.attach(viddev_c, 1, 0);
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

		box.append(grid);
		box.append(bbox);
		set_content(box);
	}

	public int result(out string uri) {
		if (rb0.active) {
            return 0;
        } else {
            uri = e.text;
			return 1;
        }
	}
}