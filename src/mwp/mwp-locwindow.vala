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

namespace Mwp {
	[GtkTemplate (ui = "/org/stronnag/mwp/goto_dialog.ui")]
	public class GotoDialog : Adw.Window {
		[GtkChild]
		private unowned Gtk.Entry golat;
		[GtkChild]
		private unowned Gtk.Entry golon;
		[GtkChild]
		private unowned Gtk.DropDown places_dd;
		[GtkChild]
		private unowned Gtk.Button place_edit;
		[GtkChild]
		private unowned Gtk.Button gotoapp;
		[GtkChild]
		private unowned Gtk.Button gotocan;

		Places.PosItem[] pls;
		public signal void new_pos(double la, double lo, int zoom);

		public GotoDialog () {
			transient_for = Mwp.window;;
			var p = new PlaceEdit();
			close_request.connect (() => {
					visible=false;
					return true;
				});

			place_edit.clicked.connect(() => {
					p.show();
				});

			places_dd.notify["selected"].connect(() => {
					var n = places_dd.get_selected ();
					golat.set_text(PosFormat.lat(pls[n].lat, Mwp.conf.dms));
					golon.set_text(PosFormat.lon(pls[n].lon, Mwp.conf.dms));
				});

			gotocan.clicked.connect (() => {
					visible=false;
				});

			gotoapp.clicked.connect (() => {
					double glat = 0,  glon = 0;
					var t1 = golat.get_text();
					var t2 = golon.get_text();
					if (t2 == "") {
						string []parts;
						parts = t1.split (" ");
						if(parts.length == 2) {
							t1 = parts[0];
							t2 = parts[1];
						}
					}
					glat = InputParser.get_latitude(t1);
					glon = InputParser.get_longitude(t2);
					var zl = -1.0;
					var n = places_dd.get_selected ();
					if (n > 0) {
						zl = pls[n].zoom;
						MapUtils.centre_on(glat, glon, zl);
					}
					visible=false;
				});
			load_places();
		}

		public void load_places() {
			pls = {};
			pls +=  new Places.PosItem(){name="Default", lat=Mwp.conf.latitude, lon=Mwp.conf.longitude};
			foreach(var pl in Places.points()) {
				pls += pl;
			}

			var ni = ((Gtk.StringList)places_dd.model).get_n_items();
			if(ni > 0) {
				((Gtk.StringList)places_dd.model).splice(0, ni, null);
			}
			foreach(var l in pls) {
				((Gtk.StringList)places_dd.model).append(l.name);
			}
			places_dd.set_selected(0);
			golat.set_text(PosFormat.lat(pls[0].lat, Mwp.conf.dms));
			golon.set_text(PosFormat.lon(pls[0].lon, Mwp.conf.dms));
		}
	}
}