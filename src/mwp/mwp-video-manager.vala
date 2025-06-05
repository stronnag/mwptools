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
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace V4L2 {
	[GtkTemplate (ui = "/org/stronnag/mwp/mwp-video-source.ui")]
	public class Window : Adw.Window {
		[GtkChild]
		internal unowned Gtk.CheckButton webcam;
		[GtkChild]
		internal unowned Gtk.CheckButton urichk;
		[GtkChild]
		internal unowned Gtk.Entry uritxt;
		[GtkChild]
		internal unowned Gtk.Button apply;
		[GtkChild]
		internal unowned Gtk.Box v2;
		[GtkChild]
		internal unowned Gtk.Label dummy;

		public signal void response(int id);

		public Window(Gtk.DropDown viddev_c) {
			transient_for = Mwp.window;
			urichk.active = true;

			uritxt.text = Mwp.conf.default_video_uri;
#if WINDOWS
			webcam.sensitive = false;
#else
			if(viddev_c != null) {
				v2.remove(dummy);
				v2.prepend(viddev_c);
				var sl = viddev_c.model as Gtk.StringList;
				if(sl.n_items == 1) {
					webcam.sensitive = false;
				} else {
					viddev_c.selected = 1;
				}
			}
#endif
			close_request.connect(()=> {
					response(-1);
					return false;
				});

			apply.clicked.connect(() => {
					response(0);
				});
		}

		public int result(out string uri) {
			uri=null;
			if (webcam != null && webcam.active) {
				return 0;
			} else {
				uri = uritxt.text;
				if (uri.length > 0) {
					Mwp.conf.default_video_uri = uri;
				}
				return 1;
			}
		}
	}
}

namespace VideoMan {
	public enum State {
		PLAYING=1,
		ENDED=2,
		PAUSED=3
	}

	public void load_v4l2_video() {
		string uri = null;
		int res = -1;
		var vid_dialog = new V4L2.Window(GstDev.viddev_c);
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
					vid_dialog.close();
					vid_dialog = null;
					if (res != -1) {
						var vp = new VideoPlayer();
						vp.present();
						vp.add_stream(uri);
					}
				}
			});
		vid_dialog.present();
	}
}
