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

namespace FWPlot {

	private Shumate.PathLayer []lpaths;
	private Shumate.PathLayer []apaths;
	private Gdk.RGBA landcol;
	private Gdk.RGBA appcol;
	public uint32 nav_fw_land_approach_length = 350;
	public uint32 nav_fw_loiter_radius = 50;

	public void init() {
		landcol = {0xfc/255.0f, 0xac/255.0f, 0x64/255.0f, 0xa0/255.0f};
		appcol = {0x63/255.0f, 0xa0/255.0f, 0xfc/255.0f, 0xff/255.0f};
		lpaths = {};
		apaths = {};
		var llist = new List<uint>();
		llist.append(5);
		llist.append(5);
		llist.append(5);
		llist.append(5);

		for(var i = 0; i < 	FWAPPROACH.maxapproach; i++) {
			var l0 = new Shumate.PathLayer(Gis.map.viewport);
			l0.set_stroke_width (4);
			l0.set_stroke_color(landcol);
			var l1 = new Shumate.PathLayer(Gis.map.viewport);
			l1.set_stroke_width (4);
			l1.set_stroke_color(landcol);
			Gis.map.insert_layer_behind(l0, Gis.mp_layer);
			Gis.map.insert_layer_behind(l1, Gis.mp_layer);
			lpaths += l0;
			lpaths += l1;

			var a0 = new Shumate.PathLayer(Gis.map.viewport);
			a0.set_stroke_width (4);
			a0.set_stroke_color(appcol);
			a0.set_dash(llist);
			var a1 = new Shumate.PathLayer(Gis.map.viewport);
			a1.set_stroke_width (4);
			a1.set_stroke_color(appcol);
			a1.set_dash(llist);
			Gis.map.insert_layer_behind(a0, Gis.mp_layer);
			Gis.map.insert_layer_behind(a1, Gis.mp_layer);
			apaths += a0;
			apaths += a1;
		}
	}

	private Shumate.Marker set_laypoint(int dirn, double lat, double lon, double dlen=-1) {
		double dlat, dlon;
		if (dlen == -1) {
			dlen = (nav_fw_land_approach_length/1852.0);
		}
		Geo.posit(lat, lon, dirn, dlen, out dlat, out dlon);
		var ip0 =  new	Shumate.Marker();
		ip0.latitude = dlat;
		ip0.longitude = dlon;
		return ip0;
	}

	public void update_laylines(int idx, Shumate.Marker mk, bool enabled) {
		Shumate.Marker ip0;
		Shumate.Marker ip1;
		int pi = idx*2;
		landcol.alpha = (enabled) ? 0xa0/255.0f : 0x60/255.0f;
		appcol.alpha = (enabled) ? 0xff/255.0f : 0x80/255.0f;
		var lnd = FWApproach.get(idx);
		if(lnd.dirn1 != 0) {
			var pts = lpaths[pi].get_nodes();
			bool upd = (pts != null && pts.length() > 0);
			if(lnd.ex1) {
				ip0 = mk;
			} else {
				ip0 =  set_laypoint(lnd.dirn1, mk.latitude, mk.longitude);
			}
			if (upd) {
				pts.nth_data(0).latitude = ip0.latitude;
				pts.nth_data(0).longitude = ip0.longitude;
			} else {
				lpaths[pi].add_node(ip0);
			}
			var adir = (lnd.dirn1 + 180) % 360;
			ip1 =  set_laypoint(adir, mk.latitude, mk.longitude);
			if (upd) {
				pts.nth_data(1).latitude = ip1.latitude;
				pts.nth_data(1).longitude = ip1.longitude;
			} else {
				lpaths[pi].add_node(ip1);
			}
			add_approach(idx, pi, lnd.dirn1, lnd.ex1, lnd.dref, ip0, ip1, mk);
		} else {
			lpaths[pi].remove_all();
			apaths[pi].remove_all();
		}
		pi++;
		if(lnd.dirn2 != 0) {
			var pts = lpaths[pi].get_nodes();
			bool upd = (pts != null && pts.length() > 0);
			if(lnd.ex2) {
				ip0 = mk;
			} else {
				ip0 =  set_laypoint(lnd.dirn2, mk.latitude, mk.longitude);
			}
			if(upd) {
				pts.nth_data(0).latitude = ip0.latitude;
				pts.nth_data(0).longitude = ip0.longitude;
			} else {
				lpaths[pi].add_node(ip0);
			}
			var adir = (lnd.dirn2 + 180) % 360;
			ip1 =  set_laypoint(adir, mk.latitude, mk.longitude);
			if(upd) {
				pts.nth_data(1).latitude = ip1.latitude;
				pts.nth_data(1).longitude = ip1.longitude;
			} else {
				lpaths[pi].add_node(ip1);
			}
			add_approach(idx, pi, lnd.dirn2, lnd.ex2, lnd.dref, ip0, ip1, mk);
		} else {
			lpaths[pi].remove_all();
			apaths[pi].remove_all();
		}
	}

	private void add_approach(int idx, int pi, int dirn, bool ex, bool dref,
							  Shumate.Marker ip0, Shumate.Marker ip1, Shumate.Marker mk) {
		apaths[pi].remove_all(); // number of nodes will change if exclusive changed ..
		int xdir= dirn;
			if(dref)
				xdir += 90;
			else
				xdir -= 90;
			xdir %= 360;
			var fwax = nav_fw_land_approach_length/1852.0/2.0;
			var fwlr = nav_fw_loiter_radius * 4.0 / 1852.0;
			if (fwax < fwlr) {
				fwax = fwlr;
			}

			var ipx =  set_laypoint(xdir, ip1.latitude, ip1.longitude, fwax);
			apaths[pi].add_node(ip1);
			apaths[pi].add_node(ipx);
			if(ex) {
				apaths[pi].add_node(ip0);
			} else {
				apaths[pi].add_node(mk);
				ipx =  set_laypoint(xdir, ip0.latitude, ip0.longitude, fwax);
				apaths[pi].add_node(ipx);
				apaths[pi].add_node(ip0);
			}
	}

	public void remove_all(int idx) {
		int pi = 2*idx;
		lpaths[pi].remove_all();
		apaths[pi].remove_all();
		pi += 1;
		lpaths[pi].remove_all();
		apaths[pi].remove_all();
	}

	public void set_colours(int idx, bool state) {
		int pi = idx*2;
		landcol.alpha = (state) ? 0xa0/255.0f : 0x60/255.0f;
		appcol.alpha = (state) ? 0xff/255.0f : 0x80/255.0f;
		for(var j = 0; j < 2; j++) {
			lpaths[pi+j].set_stroke_color(landcol);
			apaths[pi+j].set_stroke_color(appcol);
		}
	}
}
