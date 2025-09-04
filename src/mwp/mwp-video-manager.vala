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
        public Gtk.StringList sl;

		private RecentVideo cbox;
		public Gtk.DropDown viddev_c;
		public Gtk.DropDown caps_c;


		public signal void response(int id);

		private void build_list() {
			for(var j = 1; j < sl.get_n_items(); j++) {
				sl.remove(j);
			}
			MwpCameras.list.@foreach((dv) => {
					var d = dv.displayname;
					sl.append(d);
				});
			if(sl.n_items == 1) {
				webcam.sensitive = false;
			} else {
				webcam.sensitive = true;
				viddev_c.selected = 1;
#if WINDOWS
				if(MwpVideo.is_fallback) {
					webcam.sensitive = false;
				}
#endif
			}
		}

		public Window() {
			sl = new Gtk.StringList({"(None)"});
			var cl =new Gtk.StringList({"Default"});
			viddev_c = new Gtk.DropDown(sl, null);
			caps_c = new Gtk.DropDown(cl, null);
			viddev_c.notify["selected-item"].connect(() =>  {
					var c = (Gtk.StringObject)viddev_c.get_selected_item();
					var ds = MwpCameras.VideoDev(){ displayname=c.string};
					unowned List<MwpCameras.VideoDev?> dp = MwpCameras.list.find_custom(ds, (a,b) => {
							return strcmp(a.displayname, b.displayname);
						});
					if(dp != null) {
						for(var j = 1; j < cl.get_n_items(); j++) {
							cl.remove(j);
						}
						MWPLog.message(":DBG: Camera: %s\n", c.string);
						foreach(var cstr in dp.first().data.caps.data) {
							cl.append(cstr);
							MWPLog.message("  :DBG: Caps: %s\n", cstr);
						}

					}
				});

			build_list();

			MwpCameras.cams.updated.connect(() => {
					build_list();
				});

			transient_for = Mwp.window;
			urichk.active = true;

			g.attach (viddev_c, 1, 0);
			g.attach (caps_c, 2, 0);

			cbox = new  RecentVideo(this);
			cbox.entry.set_width_chars(48);

			var rl = cbox.get_recent_items();
			if (rl.length > 0) {
				cbox.populate(rl);
			}
			g.attach(cbox, 1, 1, 2);

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
		if (MwpVideo.window != null) {
			MwpVideo.window.close();
		}
		if (MwpVideo.state != 0) {
			MwpVideo.stop_embedded_player();
		}

		var vid_dialog = new V4L2.Window();
		vid_dialog.response.connect((id) => {
				if(id == 0) {
					res = vid_dialog.result(out uri);
					switch(res) {
					case 0:
						var i = vid_dialog.viddev_c.get_selected();
						if (i > 0) {
							var dname = ((Gtk.StringList)vid_dialog.viddev_c.model).get_string(i);
							uri = "v4l2://%s".printf(dname);
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
 							var vp = new MwpVideo.Viewer();
							vp.present();
							Idle.add(() => {
									vp.load(uri, true);
									return false;
								});
						} else {
							MWPLog.message("Add %s to embedded\n", uri);
							MwpVideo.embedded_player(uri);
						}
					}
				}
			});
		vid_dialog.present();
	}
}