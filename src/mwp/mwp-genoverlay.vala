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

using Gtk;

// FIXME set_color / set_label / Clutter

public class OverlayItem : Object {
    public struct StyleItem {
		uint line_dash;
		uint line_width;
        string line_colour;
        string fill_colour;
        string point_colour;
        bool styled;
    }

	public enum OLType {
		UNKNOWN=0,
		POINT=1,
		LINESTRING=2,
		POLYGON=3,
	}

	public struct CircData {
		double lat;
		double lon;
		double radius_nm;
	}

	public uint8 idx;
	public OLType type;
    public string? name;
	public string? desc;
	public StyleItem? styleinfo;
	public CircData circ;
	public Shumate.PathLayer? pl;
	public List<MWPLabel?> mks;

	private Gdk.RGBA rgba_from_string(string s) {
		var c = Gdk.RGBA();
		c.parse(s);
		return c;
	}

	public OverlayItem() {
		mks = new List<MWPLabel?>();
		pl = new Shumate.PathLayer(Gis.map.viewport);
	}

	public void remove_path() {
		pl.remove_all();
	}

	public void set_label(MWPLabel mk, string text) {
		mk.set_text(text);
		string? c = (styleinfo.point_colour != null) ? styleinfo.point_colour : styleinfo.line_colour;
		mk.set_colour(c);
		mk.set_text_colour("black");
		mk.set_selectable(false);
	}

	public void add_point(double lat, double lon) {
		var mk = new MWPLabel();
		mk.latitude = lat;
		mk.longitude = lon;
		mks.append(mk);
	}

	public MWPLabel add_line_point(double lat, double lon, string label) {
		var mk = new MWPLabel();
		mk.latitude = lat;
		mk.longitude = lon;
		mk.set_text(label);
		mk.set_draggable(true);
		pl.add_node(mk);
		return mk;
	}

	public MWPLabel insert_line_position(double lat, double lon, int ipos) {
		var mk = new MWPLabel("?");
		mk.latitude = lat;
		mk.longitude = lon;
		mk.set_draggable(true);
		// Amazingly broken
		var n = pl.get_nodes().length();
		pl.insert_node(mk, n - ipos);
		//		pl.get_nodes().insert(mk, ipos);
		return mk;
	}

	public void show_point() {
		set_label(mks.nth_data(0), name);
	}

	public void show_linestring() {
		pl.closed=false;
		pl.set_stroke_color(rgba_from_string(styleinfo.line_colour));
		pl.set_stroke_width (styleinfo.line_width);
	}

	public void update_style(StyleItem si) {
		styleinfo = si;
		pl.set_stroke_color(rgba_from_string(styleinfo.line_colour));
		pl.set_stroke_width (styleinfo.line_width);
		pl.fill = (styleinfo.fill_colour != null);
		if (pl.fill)
			pl.set_fill_color(rgba_from_string(styleinfo.fill_colour));

		var llist = new List<uint>();
		if (styleinfo.line_dash != 0) {
			llist.append(styleinfo.line_dash);
			llist.append(styleinfo.line_dash);
		}
		pl.set_dash(llist);
		string? c = (styleinfo.point_colour != null) ? styleinfo.point_colour : styleinfo.line_colour;
		pl.get_nodes().foreach ((mk) => {
				if (c != null) {
					((MWPLabel)mk).set_colour(c);
				}
			});
	}

	public void show_polygon() {
			pl.closed=true;
			pl.set_stroke_color(rgba_from_string(styleinfo.line_colour));
			pl.set_stroke_width (styleinfo.line_width);
			pl.fill = (styleinfo.fill_colour != null);
			if (pl.fill)
				pl.set_fill_color(rgba_from_string(styleinfo.fill_colour));
			if (styleinfo.line_dash != 0) {
				var llist = new List<uint>();
				llist.append(styleinfo.line_dash);
				llist.append(styleinfo.line_dash);
				pl.set_dash(llist);
			}
	}

	public void display() {
		switch(this.type) {
		case OLType.POINT:
			show_point();
			break;
		case OLType.LINESTRING:
			show_linestring();
			break;
		case OLType.POLYGON:
			show_polygon();
			break;
		case OLType.UNKNOWN:
			break;
		}
	}
}

public class Overlay : Object {
    private Shumate.MarkerLayer mlayer;
	private List<OverlayItem?> elements;

	public unowned List<OverlayItem?> get_elements() {
		return elements;
	}

	public Overlay() {
		elements= new List<OverlayItem?>();
        mlayer = new Shumate.MarkerLayer(Gis.map.viewport);
		Gis.map.insert_layer_above(mlayer, Gis.base_layer);
	}

	public Shumate.MarkerLayer get_mlayer() {
		return mlayer;
	}

	public void remove() {
		mlayer.remove_all();
		elements.foreach((el) => {
				el.remove_path();
				if (el.type != OverlayItem.OLType.POINT) {
					Gis.map.remove_layer(el.pl);
				}
			});
    }

	public void remove_element(uint n) {
		var el = elements.nth_data(n);
		el.remove_path();
		Gis.map.remove_layer(el.pl);
		elements.remove(el);
	}

	/*
	public void remove() {
		mlayer.remove_all();
		while(!players.is_empty()) {
			var p = players.data;
			p.remove_all();
			view.remove_layer(p);
			players.remove_link(players);
		}
    }
	*/

	public void add_element(OverlayItem o) {
		elements.append(o);
	}

	public void add_marker(MWPMarker m) {
		mlayer.add_marker (m);
	}

	public void remove_marker(MWPMarker m) {
		mlayer.remove_marker (m);
	}

	public void remove_all_markers() {
		mlayer.remove_all();
	}

	public void display() {
		elements.foreach((o) => {
				o.display();
				switch(o.type) {
				case OverlayItem.OLType.POINT:
					mlayer.add_marker (o.mks.nth_data(0));
					break;
				case OverlayItem.OLType.LINESTRING:
				case OverlayItem.OLType.POLYGON:
					Gis.map.insert_layer_behind(o.pl, mlayer);
					break;
				case OverlayItem.OLType.UNKNOWN:
					break;
				}
			});
	}
}
