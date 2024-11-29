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

namespace Odo {
	Window view;
    Odostats stats;

	public void init (uint tm=30) {
		view = new Window(tm);
		stats = {};
	}

	[GtkTemplate (ui = "/org/stronnag/mwp/odoview.ui")]
	public class Window : Adw.Window {
		[GtkChild]
		internal unowned Gtk.Label odotime;
		[GtkChild]
		internal unowned Gtk.Label odospeed;
		[GtkChild]
		internal unowned Gtk.Label odospeed_u;
		[GtkChild]
		internal unowned Gtk.Label ododist;
		[GtkChild]
		internal unowned Gtk.Label ododist_u;
		[GtkChild]
		internal unowned Gtk.Label odorange;
		[GtkChild]
		internal unowned Gtk.Label odorange_u;
		[GtkChild]
		internal unowned Gtk.Label odoalt;
		[GtkChild]
		internal unowned Gtk.Label odoamps;
		[GtkChild]
		internal unowned Gtk.Label odo_ca0;
		[GtkChild]
		internal unowned Gtk.Label odo_ca2;
		[GtkChild]
		internal unowned Gtk.Label odoalt_u;
		[GtkChild]
		internal unowned Gtk.Button odoclose;

		[GtkChild]
		internal unowned Gtk.Label odoalt_tm;
		[GtkChild]
		internal unowned Gtk.Label odospeed_tm;
		[GtkChild]
		internal unowned Gtk.Label odorange_tm;

		[GtkChild]
		internal unowned  Gtk.TextView odotview;
		[GtkChild]
		internal unowned  Gtk.Frame odoframe;

		private uint to = 30;
		private uint tid = 0;
		private bool odo_visible = false;
		private string cname;
		private time_t atime;

		public Window(uint _to) {
			odotview.buffer.changed.connect(() => {
					if(tid != 0)
						Source.remove(tid);
					tid = 0;
				});

			set_transient_for(Mwp.window);
			to = _to;

			close_request.connect (() => {
					dismiss();
					return true;
				});

			odoclose.clicked.connect (() => {
					dismiss();
				});
			cname = "Unknown";
		}

		private void odosens(bool state) {
			odo_ca0.sensitive = odo_ca2.sensitive = odoamps.sensitive = state;
		}

		private string format_when(uint at) {
			string lbl;
			uint m,s;
			if (at == 0) {
				lbl = "";
			} else {
				m = at / 60;
				s = at % 60;
				lbl = "%u:%02u".printf(m,s);
			}
			return lbl;
		}

		public void display_ui (Odostats o, bool autohide=false) {
			odotime.label = " %u:%02u ".printf(o.time / 60, o.time % 60);
			odospeed.label = "  %.1f ".printf(Units.speed(o.speed));
			odospeed_u.label = Units.speed_units();
			odospeed_tm.label = format_when(o.spd_secs);

			ododist.label = "  %.0f ".printf(Units.distance(o.distance));
			ododist_u.label = Units.distance_units();

			odorange.label = "  %.0f ".printf(Units.distance(o.range));
			odorange_u.label = Units.distance_units();
			odorange_tm.label = format_when(o.rng_secs);

			odoalt.label = "  %.0f ".printf(Units.distance(o.alt));
			odoalt_u.label = Units.distance_units();
			odoalt_tm.label = format_when(o.alt_secs);

			if(o.amps > 0) {
				double odoA = o.amps/100.0;
				odoamps.label = "  %.2f ".printf(odoA);
				odosens(true);
			} else {
				odoamps.label = "N/A";
				odosens(false);
			}

			unhide();
			if(autohide) {
				if(to > 0) {
					tid = Timeout.add_seconds(to, () => {
							tid=0;
							dismiss();
							return Source.REMOVE;
						});
				}
			}
		}

		public void unhide() {
			odo_visible = true;
			present();
		}

		public void set_text(string txt) {
			odotview.buffer.text = txt;
		}

		public void set_cname(string v) {
			cname = v;
		}

		public void reset(Odostats o) {
			cname = o.cname;
			atime = o.atime;
			odoframe.sensitive  = odotview.sensitive = o.live;
			to = (o.live) ? 120 : 30;
			dismiss();
		}

		public void dismiss() {
			if(tid != 0)
				Source.remove(tid);
			tid = 0;
			var t = odotview.buffer.text.strip();
			if (t.length > 0) {
				add_summary_log("Note", t);
				t  = t.replace("\n", "\n ");
				MWPLog.message("User comment: %s\n", t);
			}
			odotview.buffer.text="";
			odo_visible=false;
			set_visible(false);
		}

		public void add_summary_event(string ev) {
			add_summary_log(ev, null);
		}

		private void add_summary_log(string reason, string? t) {
			time_t ntime;
			//		ntime = atime;
			//if (ntime == 0) {
			time_t(out ntime);
			//}
			string spath = Mwp.conf.logsavepath;
			var f = File.new_for_path(spath);
			if(f.query_exists() == false) {
				try {
					f.make_directory_with_parents();
				} catch {
					spath = Environment.get_home_dir();
				}
			}
			var fn = GLib.Path.build_filename(spath, "mwp_summary_notes.txt");
			var dt = new DateTime.from_unix_local(ntime);
			var ts = dt.format("%F %T");
			var etm = "";
			if (reason != "Armed" && atime != 0) {
				var edt = new DateTime.from_unix_local(atime);
				etm = edt.format(" (%T)");
			}
			var os = FileStream.open(fn, "a");
			os.printf("## %s for \"%s\" %s%s\n\n", reason, cname, ts, etm);
			if (t != null && t.length > 0) {
				os.printf("%s\n\n", t);
			}
		}
	}
}