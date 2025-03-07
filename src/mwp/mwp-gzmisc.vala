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

public class FlatEarth {
	private const double MLAT=111120.0; // Metres / degree latitude (1852*60)
	public struct Origin {
		double lat;
		double lon;
		double scale;
		bool valid;
	}

	public struct Point {
		double x;
		double y;
	}

	public struct LLA {
		double lat;
		double lon;
	}

	private Origin origin;

	public FlatEarth() {
		origin.valid = false;
	}

	public AreaCalc.Vec lla_to_point(double lat, double lon) {
		AreaCalc.Vec p = {0,0};
		if(origin.valid) {
			p.y = (lat - origin.lat) * MLAT;
			p.x = (lon - origin.lon) * MLAT * origin.scale;
		}
		return p;
	}

	public LLA point_to_geo(AreaCalc.Vec p) {
		LLA lla = {0,0};
		if (origin.valid) {
			lla.lat = origin.lat + p.y / MLAT;
			lla.lon = origin.lon + p.x * origin.scale / MLAT;
		}
		return lla;
	}

	public void set_origin(double lat, double lon) {
		origin.valid = true;
		origin.lat = lat;
		origin.lon = lon;
        origin.scale = Math.cos(Math.fabs(lat) * Math.PI/180.0);
	}
}

namespace GZMisc {
	private const double RAD = 0.017453292;
	private bool is_clockwise(AreaCalc.Vec []v) {
		double sum = 0;
		for (var i = 0; i < v.length; i++) {
			var v0 = v[i];
			var v1 = v[(i + 1) % v.length];
			sum += (v1.x - v0.x) * (v1.y + v0.y);
		}
		return sum > 0.0;
	}

	private bool is_complex(AreaCalc.Vec []v) {
		for (var i = 0; i < v.length; i++) {
			AreaCalc.Vec v0 = v[i];
			AreaCalc.Vec v1 = v[(i + 1) % v.length];
			for(var j = i+1; j < v.length; j++) {
				AreaCalc.Vec t0 = v[j];
				AreaCalc.Vec t1 = v[(j + 1) % v.length];
				if (AreaCalc.linesCross(v0, v1, t0, t1) != null) {
					return true;
				}
			}
		}
		return false;
	}

	public uint8 validate_polygon(AreaCalc.Vec []v) {
		uint8 res = 0;
		if (is_clockwise(v)) {
			res |= 1;
		}
		if (is_complex(v)) {
			res |= 2;
		}
		return res;
	}
}
