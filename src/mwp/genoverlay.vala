using Gtk;
using Clutter;
using Champlain;
using GtkChamplain;

public class OverlayItem : Object {
    public struct StyleItem {
        bool styled;
		bool line_dotted;
        string line_colour;
        string fill_colour;
        string point_colour;
		int line_width;
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
	public Champlain.PathLayer? pl;
	public List<Champlain.Label?> mks;

	public OverlayItem() {
		pl = new Champlain.PathLayer();
		mks = new List<Champlain.Label?>();
	}

	public void remove_path() {
		pl.remove_all();
	}

	public void set_label(Champlain.Label mk, string text) {
		Clutter.Color black = { 0,0,0, 0xff };
		mk.set_text(text);
		mk.set_font_name("Sans 10");
		mk.set_alignment (Pango.Alignment.RIGHT);
		string? c = (styleinfo.point_colour != null) ? styleinfo.point_colour : styleinfo.line_colour;
		mk.set_color(Clutter.Color.from_string(c));
		mk.set_text_color(black);
		mk.set_draggable(false);
		mk.set_selectable(false);
	}


	public void add_point(double lat, double lon) {
		var mk = new Champlain.Label();
		mk.latitude = lat;
		mk.longitude = lon;
		mks.append(mk);
	}

	public Champlain.Label add_line_point(double lat, double lon, string label) {
		var mk = new Champlain.Label();
		mk.latitude = lat;
		mk.longitude = lon;
		set_label(mk, label);
		mk.visible = true;
		mk.set_draggable(true);
		pl.add_node(mk);
		return mk;
	}

	public Champlain.Label insert_line_position(double lat, double lon, int ipos) {
		var mk = new Champlain.Label();
		mk.latitude = lat;
		mk.longitude = lon;
		set_label(mk, "?");
		mk.visible = true;
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
		pl.set_stroke_color(Clutter.Color.from_string(styleinfo.line_colour));
		pl.set_stroke_width (styleinfo.line_width);
	}

	public void update_style(StyleItem si) {
		styleinfo = si;
		pl.set_stroke_color(Clutter.Color.from_string(styleinfo.line_colour));
		pl.set_stroke_width (styleinfo.line_width);
		pl.fill = (styleinfo.fill_colour != null);
		if (pl.fill)
			pl.set_fill_color(Clutter.Color.from_string(styleinfo.fill_colour));

		var llist = new List<uint>();
		if (styleinfo.line_dotted) {
			llist.append(5);
			llist.append(5);
		}
		pl.set_dash(llist);
		string? c = (styleinfo.point_colour != null) ? styleinfo.point_colour : styleinfo.line_colour;
		pl.get_nodes().foreach ((mk) => {
				((Champlain.Label)mk).set_color(Clutter.Color.from_string(c));
			});
	}

	public void show_polygon() {
		pl.closed=true;
		pl.set_stroke_color(Clutter.Color.from_string(styleinfo.line_colour));
		pl.set_stroke_width (styleinfo.line_width);
		pl.fill = (styleinfo.fill_colour != null);
		if (pl.fill)
			pl.set_fill_color(Clutter.Color.from_string(styleinfo.fill_colour));
		if (styleinfo.line_dotted) {
			var llist = new List<uint>();
			llist.append(5);
			llist.append(5);
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
    private Champlain.View view;
    private Champlain.MarkerLayer mlayer;
	private List<OverlayItem?> elements;

	public unowned List<OverlayItem?> get_elements() {
		return elements;
	}

    private void at_bottom(Champlain.Layer layer) {
        var pp = layer.get_parent();
        pp.set_child_at_index(layer,0);
    }

	public Overlay(Champlain.View _view) {
        view = _view;
		elements= new List<OverlayItem?>();
        mlayer = new Champlain.MarkerLayer();
        view.add_layer (mlayer);
        at_bottom(mlayer);
	}

	public Champlain.View get_view() {
		return view;
	}

	public Champlain.MarkerLayer get_mlayer() {
		return mlayer;
	}

	public void remove() {
		mlayer.remove_all();
		elements.foreach((el) => {
				el.remove_path();
				view.remove_layer(el.pl);
			});
    }

	public void remove_element(uint n) {
		var el = elements.nth_data(n);
		el.remove_path();
		view.remove_layer(el.pl);
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

	public void add_marker(Champlain.Marker m) {
		mlayer.add_marker (m);
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
					view.add_layer (o.pl);
					at_bottom(o.pl);
					break;
				case OverlayItem.OLType.UNKNOWN:
					break;
				}
			});
	}
}
