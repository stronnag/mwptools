using Gtk;
using Clutter;
using Champlain;
using GtkChamplain;
public class Overlay : Object {
    public struct StyleItem {
        bool styled;
		bool line_dotted;
        string line_colour;
        string fill_colour;
        string point_colour;
		int line_width;
    }

    public struct Point {
        double latitude;
        double longitude;
		int altitude;
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

	public struct OverlayItem {
        OLType type;
        string? name;
		string? desc;
        StyleItem? styleinfo;
        Point[] pts;
		CircData circ;
    }

    private Champlain.View view;
    private Champlain.MarkerLayer mlayer;

	private List<Champlain.PathLayer?> players;
	private List<OverlayItem?> elements;

	public unowned List<OverlayItem?> get_elements() {
		return elements;
	}

	public unowned List<Champlain.PathLayer?> get_layers() {
		return players;
	}

    private void at_bottom(Champlain.Layer layer) {
        var pp = layer.get_parent();
        pp.set_child_at_index(layer,0);
    }

	public Overlay(Champlain.View _view) {
		elements= new List<OverlayItem?>();
        view = _view;
        mlayer = new Champlain.MarkerLayer();
        view.add_layer (mlayer);
        at_bottom(mlayer);
        players = new List<Champlain.PathLayer>();
	}

	public void remove_layer(uint j) {
		unowned var li = players.nth(j);
		var p = players.nth_data(j);
		p.remove_all();
		view.remove_layer(p);
		players.remove_link(li);
	}

	public void remove() {
		mlayer.remove_all();
		uint n = players.length();
		for(var j = n-1; ; j--) {
			remove_layer(j);
			if(j == 0)
				break;
		}
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

	public void add_element(Overlay.OverlayItem o) {
		elements.append(o);
	}

	public void display() {
		elements.foreach((o) => {
				stderr.printf("DBG: Add element %s\n", o.name);
				switch(o.type) {
				case OLType.POINT:
				Clutter.Color black = { 0,0,0, 0xff };
				var marker = new Champlain.Label.with_text (o.name,"Sans 10",null,null);
				marker.set_alignment (Pango.Alignment.RIGHT);
				marker.set_color(Clutter.Color.from_string(o.styleinfo.point_colour));
				marker.set_text_color(black);
				marker.set_location (o.pts[0].latitude,o.pts[0].longitude);
				marker.set_draggable(false);
				marker.set_selectable(false);
				mlayer.add_marker (marker);
				break;
				case OLType.LINESTRING:
				var path = new Champlain.PathLayer();
				path.closed=false;
				path.set_stroke_color(Clutter.Color.from_string(o.styleinfo.line_colour));
				path.set_stroke_width (o.styleinfo.line_width);
				foreach (var p in o.pts) {
					var l =  new  Champlain.Point();
					l.set_location(p.latitude, p.longitude);
					path.add_node(l);
				}
				players.append(path);
				view.add_layer (path);
				at_bottom(path);
				break;
				case OLType.POLYGON:
				var path = new Champlain.PathLayer();
				path.closed=true;
				path.set_stroke_color(Clutter.Color.from_string(o.styleinfo.line_colour));
				path.set_stroke_width (o.styleinfo.line_width);
				path.fill = (o.styleinfo.fill_colour != null);
				if (path.fill)
					path.set_fill_color(Clutter.Color.from_string(o.styleinfo.fill_colour));
				if (o.styleinfo.line_dotted) {
					var llist = new List<uint>();
					llist.append(5);
					llist.append(5);
					path.set_dash(llist);
				}
				foreach (var p in o.pts) {
					var l =  new  Champlain.Point();
					l.set_location(p.latitude, p.longitude);
					path.add_node(l);
				}
				players.append(path);
				view.add_layer (path);
				at_bottom(path);
				break;
				case OLType.UNKNOWN:
				break;
				}
			});
	}
}
