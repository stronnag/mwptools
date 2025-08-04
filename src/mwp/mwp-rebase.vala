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

public class Rebase  : Object {
	public struct Point {
		public double lat;
		public double lon;
	}
	public Point orig;
	public Point reloc;
	public uint8 status;

	public Rebase() {
		status = 0;
	}

	public void set_reloc(double rlat, double rlon) {
		reloc.lat = rlat;
		reloc.lon = rlon;
		status |= 1;
	}

	public void set_origin(double olat, double olon) {
		status |= 2;
		orig.lat = olat;
		orig.lon = olon;
	}

	public bool has_reloc() {
		return ((status & 1) == 1);
	}

	public bool has_origin() {
		return ((status & 2) == 2);
	}

	public bool is_valid() {
		return ((status & 3) == 3);
	}

	public void set_invalid() {
		status &= ~2;;
	}

	public void relocate(ref double lat, ref double lon) {
		if (is_valid()) {
			double c,d;
			Geo.csedist(orig.lat, orig.lon, lat, lon, out d, out c);
			Geo.posit(reloc.lat, reloc.lon, c, d, out lat, out lon);
		}
	}
}
