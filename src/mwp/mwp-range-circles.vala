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

namespace RangeCircles {
	private Shumate.PathLayer []rings;                 // range rings layers (per radius)

    public void remove_rings() {
		foreach (var r in rings) {
			r.remove_all();
			Gis.map.remove_layer(r);
		}
		rings = {};
	}

    public void initiate_rings(double lat, double lon, int nrings, double ringint) {
        remove_rings();
		var rcol = Gdk.RGBA();
		rcol.parse(Mwp.conf.rcolstr);
        Shape.Point []pts;
		rings = new Shumate.PathLayer[nrings];
        for (var i = 0; i < nrings; i++) {
            rings[i] = new Shumate.PathLayer(Gis.map.viewport);
            rings[i].set_stroke_color(rcol);
            rings[i].set_stroke_width (2);
			Gis.map.insert_layer_behind(rings[i], Gis.hp_layer);
            double rng = (i+1)*ringint;
            pts = Shape.mkshape(lat, lon, rng, 36);
            foreach(var p in pts) {
                var pt = new  Shumate.Marker();
                pt.set_location (p.lat,p.lon);
                rings[i].add_node(pt);
            }
        }
    }
}
