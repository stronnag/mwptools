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

namespace FlightBox {
	[Flags]
	public enum Update {
		LAT,
		LON,
		ALT,
		YAW,
		SPEED,
		RANGE,
		BEARING,
		GPS
	}

	[GtkTemplate (ui = "/org/stronnag/mwp/fb.ui")]
	public class View : Gtk.Box {
		[GtkChild]
		private unowned Gtk.Label latitude;
		[GtkChild]
		private unowned Gtk.Label longitude;
		[GtkChild]
		private unowned Gtk.Label range;
		[GtkChild]
		private unowned Gtk.Label bearing;
		[GtkChild]
		private unowned Gtk.Label altitude;
		[GtkChild]
		private unowned Gtk.Label heading;
		[GtkChild]
		private unowned Gtk.Label speed;
		[GtkChild]
		private unowned Gtk.Label sats;

		public View() {}

		public void update(Update what) {
			if(Update.LAT in what) {
				set_latitude(Mwp.msp.td.gps.lat);
			}
			if(Update.LON in what) {
				set_longitude(Mwp.msp.td.gps.lon);
			}
			if(Update.ALT in what) {
				set_altitude(Mwp.msp.td.alt.alt);
			}

			if(Update.SPEED in what) {
				set_speed(Mwp.msp.td.gps.gspeed);
			}

			if(Update.GPS in what) {
				set_gps(Mwp.msp.td.gps.hdop, Mwp.msp.td.gps.nsats, Mwp.msp.td.gps.fix);
			}

			if(Update.RANGE in what) {
				set_range(Mwp.msp.td.comp.range);
			}
			if(Update.BEARING in what) {
				set_bearing(Mwp.msp.td.comp.bearing);
			}

			if(Update.YAW in what) {
				set_heading(Mwp.msp.td.atti.yaw);
            }
		}

		private void set_latitude (double lat) {
			var s = PosFormat.lat(lat, Mwp.conf.dms);
			latitude.label = "<span size=\"150%%\" font=\"monospace\">%s</span>".printf(s);
		}

		private void set_longitude (double lon) {
			var s = PosFormat.lon(lon, Mwp.conf.dms);
			longitude.label = "<span size=\"150%%\" font=\"monospace\">%s</span>".printf(s);
		}

		private void set_heading (int hdg) {
			heading.label = "<span size='small'>Heading</span><span size=\"300%%\" font=\"monospace\">%03d°</span>".printf(hdg);
		}
		private void set_altitude (double alt) {
			string sd;
			string su;
			Units.scaled_distance(alt, out sd, out su, true);
			altitude.label = "<span size='small'>Alt</span><span size=\"300%%\" font=\"monospace\">%s</span><span size=\"x-small\">%s</span>".printf(sd, su);
		}

		private void set_speed (double spd) {
			var sp = Units.speed(spd);
			var su =  Units.speed_units();
			speed.label = "<span size='small'>Speed</span><span size=\"300%%\" font=\"monospace\">%s</span><span size=\"x-small\">%s</span>".printf(Utils.trimfp(sp), su);
		}

		private void set_gps(double hdop, uint8 nsats, uint8 fix) {
			string hdoptxt="";
			if(hdop != -1.0 && hdop < 100.0) {
				string htxt;
				if(hdop > 9.95)
					htxt = "%.0f".printf(hdop);
				else if(hdop > 0.95)
                   htxt = "%.1f".printf(hdop);
				else
					htxt = "%.2f".printf(hdop);
				hdoptxt = " / <span font='%%u'>%s</span>".printf(htxt);
			}
			sats.label = "<span size='small'>Sats</span><span size='300%%' font='monospace'>%u</span><span size='x-small'>%s</span> %s".printf(nsats, Units.fix(fix),hdoptxt);
		}

		// CompData
		private void set_range (int rng) {
			string sd;
			string su;
			Units.scaled_distance(rng, out sd, out su, false);

			range.label = "<span size=\"small\">Range</span><span size=\"250%%\" font=\"monospace\">%s</span><span size=\"x-small\">%s</span>".printf(sd, su);
		}

		private void set_bearing(int brg) {
			if(brg < 0)
				brg += 360;
			bearing.label = "<span size=\"small\">Bearing</span><span size=\"300%%\" font=\"monospace\">%03d°</span>".printf(brg);
		}

	}
}
