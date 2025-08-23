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
		internal unowned Gtk.Button apply;
		[GtkChild]
		internal unowned Gtk.Grid g;

		private RecentVideo cbox;

		public signal void response(int id);

		public Window(Gtk.DropDown viddev_c) {
			transient_for = Mwp.window;
			urichk.active = true;
#if WINDOWS
			webcam.sensitive = false;
#else
			if(viddev_c != null) {
				g.attach (viddev_c, 1, 0);
				var sl = viddev_c.model as Gtk.StringList;
				if(sl.n_items == 1) {
					webcam.sensitive = false;
				} else {
					viddev_c.selected = 1;
				}
			}
#endif
			cbox = new  RecentVideo(this);
			cbox.entry.set_width_chars(48);

			var rl = cbox.get_recent_items();
			if (rl.length > 0) {
				cbox.populate(rl);
			}
			g.attach(cbox, 1, 1);

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
				uri = cbox.get_text();
				cbox.save_recent();
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
						if (Mwp.window.vpane == null) {
							var vp = new VideoPlayer();
							vp.present();
							vp.add_stream(uri);
						} else {

							var vp = new VideoBox();
							vp.init(uri);
							var image = new Gtk.Picture.for_paintable (vp.media);
							image.hexpand = true;
							image.vexpand = true;
							MWPLog.message("DBG: %p %p\n", vp, image);
							ulong active_id = 0;
							active_id = vp.media.invalidate_size.connect (()=>{
									var w = vp.media.get_intrinsic_height();
									var h = vp.media.get_intrinsic_width();
									MWPLog.message("Media %dx%d\n", (int)w, (int)h);
									vp.media.disconnect (active_id);
								});
							image.width_request = 640;
							image.height_request = 480;
							Mwp.window.vpane.set_start_child(image);
							vp.media.notify["ended"].connect(() => {
									var es = vp.media.ended;
									MWPLog.message("DBG: ended %s\n", es.to_string());
								});
							image.show();
							vp.media.play();

							//var label = new Gtk.Label("VIDEO");
							//Mwp.window.vpane.set_start_child(label);
						}
					}
				}
			});
		vid_dialog.present();
	}
}
