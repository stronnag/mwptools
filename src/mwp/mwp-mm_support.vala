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

namespace MultiM {
	public MSP_WP[] missonx_to_wps(Mission[]mx, int id=-1) {
		MSP_WP[] wps = {};
		var j = 0;
		var k = 1;
		foreach(var ms in mx) {
			if (id == -1 || id == j) {
				var ml = 0;
				foreach(var m in ms.get_ways()) {
					var w = MSP_WP();
					w.wp_no = k;
					w.action = (uint8)m.action;
					w.lat  = (int)(m.lat*1e7);
					w.lon  = (int)(m.lon*1e7);
					w.altitude = (int)(m.alt*100);
					w.p1 = (int16)m.param1;
					w.p2 = (int16)m.param2;
					w.p3 = (int16)m.param3;
					ml++;
					if (ml == ms.npoints) {
						w.flag = 0xa5;
					} else {
						w.flag = m.flag;
					}
					wps += w;
					k++;
				}
			}
			j++;
		}
		return wps;
	}

	public Mission[] wps_to_missonx(MSP_WP[] wps) {
		Mission[] mx = {};
		Mission? ms = null;
		MissionItem[] mi={};
		uint8 wp_no = 1;

		foreach(var w in wps) {
			if (ms == null) {
				ms = new Mission();
			}
			var m = new MissionItem();
			m.no= wp_no;
			m.action = (Msp.Action)w.action;
			m.lat = w.lat/10000000.0;
			m.lon = w.lon/10000000.0;
			m.alt = w.altitude/100;
			m.param1 = w.p1;
			m.param2 = w.p2;
			m.param3 = w.p3;
			m.flag = w.flag;
			if(m.action != Msp.Action.RTH && m.action != Msp.Action.JUMP
			   && m.action != Msp.Action.SET_HEAD) {
				if (m.lat > ms.maxy)
					ms.maxy = m.lat;
				if (m.lon > ms.maxx)
						ms.maxx = m.lon;
				if (m.lat <  ms.miny)
					ms.miny = m.lat;
				if (m.lon <  ms.minx)
					ms.minx = m.lon;
				if (m.alt >  ms.maxalt)
					ms.maxalt = m.alt;
			}
			mi += m;
			if (m.flag == 0xa5) {
				ms.npoints = mi.length;
				if(ms.npoints != 0) {
					ms.points = mi;
					ms.update_meta();
					mx += ms;
					ms.update_meta();
					ms = null;
					wp_no = 1;
					mi={};
				}
			} else {
				wp_no++;
			}
		}
		if (ms != null) { // legacy, no flags
			ms.npoints = mi.length;
			if (ms.npoints > 0) {
				ms.points = mi;
				ms.update_meta();
			}
			mx += ms;
		}
		return mx;
	}
}
