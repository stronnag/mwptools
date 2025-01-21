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

using Gtk;

namespace Prefs {
	[GtkTemplate (ui = "/org/stronnag/mwp/prefs.ui")]
	public class Window : Adw.Window {
		[GtkChild]
		internal unowned Gtk.Notebook prefbook;

		[GtkChild]
		internal unowned Gtk.Button pf_cancel;
 		[GtkChild]
		internal unowned Gtk.Button pf_apply;

		[GtkChild]
		internal unowned Gtk.Entry devlist;
 		[GtkChild]
		internal unowned Gtk.Entry baudrate;
 		[GtkChild]
		internal unowned Gtk.Entry deflat;
 		[GtkChild]
		internal unowned Gtk.Entry deflon;
 		[GtkChild]
		internal unowned Gtk.Label altlabel;
 		[GtkChild]
		internal unowned Gtk.Entry defalt;
 		[GtkChild]
		internal unowned Gtk.Entry defloiter;
 		[GtkChild]
		internal unowned Gtk.Label spdlabel;
 		[GtkChild]
		internal unowned Gtk.Entry defspeed;
 		[GtkChild]
		internal unowned Gtk.DropDown defmap;
 		[GtkChild]
		internal unowned Gtk.Entry defzoom;
 		[GtkChild]
		internal unowned Gtk.Entry defspkint;
 		[GtkChild]
		internal unowned Gtk.Switch defland;

 		[GtkChild]
		internal unowned Gtk.CheckButton decd;
 		[GtkChild]
		internal unowned Gtk.CheckButton dms;

		[GtkChild]
		internal unowned Gtk.CheckButton metres;
		[GtkChild]
		internal unowned Gtk.CheckButton feet;
		[GtkChild]
		internal unowned Gtk.CheckButton yards;

		[GtkChild]
		internal unowned Gtk.CheckButton msec;
		[GtkChild]
		internal unowned Gtk.CheckButton kph;
		[GtkChild]
		internal unowned Gtk.CheckButton mph;
		[GtkChild]
		internal unowned Gtk.CheckButton knots;

		private string[]mlist;
		private bool closed;


		public Window() {
			closed = false;
			close_request.connect(() => {
					closed = true;
					return false;
				});


			pf_cancel.clicked.connect (() => {
					close();
				});

			pf_apply.clicked.connect (() => {
					set_defs();
				});

			prefbook.switch_page.connect ((p,n) => {
					if(!closed && n == 0) {
						set_page(0);
					}
				});
		}

		public void run() {
			mlist = Gis.get_map_names();
			defmap.model = new Gtk.StringList(mlist);
			set_page(2);
		}

		private void set_page(int n) {
			if(n == 0 || n == 2) {
				for (var j = 0; j < mlist.length; j++) {
					if(mlist[j] == Mwp.conf.defmap) {
						defmap.selected = j;
						break;
					}
				}
				devlist.text = string.joinv(", ", Mwp.conf.devices);
				baudrate.text = Mwp.conf.baudrate.to_string();
				defland.active = Mwp.conf.rth_autoland;
				deflat.text = PosFormat.lat(Mwp.conf.latitude, Mwp.conf.dms);
				deflon.text = PosFormat.lon(Mwp.conf.longitude, Mwp.conf.dms);
				defloiter.text = "%u".printf(Mwp.conf.loiter);
				altlabel.label = "Default Altitide (%s)".printf(Units.distance_units());
				defalt.text = "%.0f".printf(Units.distance((double)Mwp.conf.altitude));
				spdlabel.label = "Default Speed (%s)".printf(Units.speed_units());
				defspeed.text = "%.2f".printf(Units.speed((double)Mwp.conf.nav_speed));
				defzoom.text = "%u".printf(Mwp.conf.zoom);
				defspkint.text = "%u".printf(Mwp.conf.speakint);
			}

			if(n == 1 || n == 2) {
				if(Mwp.conf.dms) {
					dms.active = true;
				} else {
					decd.active = true;
				}
				switch (Mwp.conf.p_distance) {
				case 1:
					feet.active = true;
					break;
				case 2:
					yards.active = true;
					break;
				default:
					metres.active = true;
					break;
				}
				switch(Mwp.conf.p_speed) {
				case 1:
					kph.active = true;
					break;
				case 2:
					mph.active = true;
					break;
				case 3:
					knots.active = true;
					break;
				default:
					msec.active = true;
					break;
				}
			}
		}

		private void set_defs() {
			var np = prefbook.page;
			if (np == 1) {
				bool dms = dms.active;
				if (dms != Mwp.conf.dms) {
					Mwp.conf.dms = dms;
				}

				uint pd = 0;
				if(kph.active) {
					pd = 1;
				} else if(mph.active) {
					pd = 2;
				} else if(knots.active) {
					pd = 3;
				}
				if (pd != Mwp.conf.p_speed) {
					Mwp.conf.p_speed = pd;
				}
				pd = 0;
				if(feet.active) {
					pd = 1;
				} else if(yards.active) {
					pd = 2;
				}
				if (pd != Mwp.conf.p_distance) {
					Mwp.conf.p_distance = pd;
				}
			} else {
				Mwp.conf.defmap = mlist[defmap.selected];
				if(defmap.selected != Mwp.window.mapdrop.selected) {
					Mwp.window.mapdrop.selected = defmap.selected;
				}
				var strs = devlist.text.split(",");
				for(int i=0; i<strs.length;i++) {
					strs[i] = strs[i].strip();
				}
				Mwp.conf.devices = strs;
				Mwp.conf.settings.set_strv( "device-names", strs);
				Mwp.build_serial_combo();

				var i = int.parse(baudrate.text);
				if(Mwp.conf.baudrate != i) {
					Mwp.conf.baudrate = i;
				}

				double d = InputParser.get_latitude(deflat.text);
				if(Math.fabs(d-Mwp.conf.latitude) > 1e-6) {
					Mwp.conf.latitude = d;
				}

				d = InputParser.get_longitude(deflon.text);
				if(Math.fabs(d-Mwp.conf.longitude) > 1e-6) {
					Mwp.conf.longitude = d;
				}

				int u = (int)InputParser.get_scaled_int(defalt.text);
				if(u != Mwp.conf.altitude) {
					Mwp.conf.altitude = u;
				}

				uint v = uint.parse(defloiter.text);
				if(v != Mwp.conf.loiter) {
					Mwp.conf.loiter = v;
				}

				d = InputParser.get_scaled_real(defspeed.text, "s");
				if(Math.fabs(d-Mwp.conf.nav_speed) > 1e-5) {
					Mwp.conf.nav_speed = d;
				}

				v = uint.parse(defzoom.text);
				if(u != Mwp.conf.zoom) {
					Mwp.conf.zoom = v;
					Mwp.set_zoom_sanely(v);
				}

				i = int.parse(defspkint.text);
				if (Mwp.conf.speakint != i) {
					if(i != 0 && i < 15) {
						i = 15;
					}
					Mwp.conf.speakint = i;
				}
			}
		}
	}
}
