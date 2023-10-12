using Gtk;
using Clutter;
using Champlain;
using GtkChamplain;

public class KmlOverlay : Object {
    private struct StyleItem {
        bool styled;
        string line_colour;
        string fill_colour;
        string point_colour;
		int line_width;
    }

    private struct Point {
        double latitude;
        double longitude;
    }

    private struct OverlayItem {
        string type;
        string name;
        StyleItem styleinfo;
        Point[] pts;
    }

    private Champlain.View view;
    private OverlayItem[] ovly;
    private Champlain.PathLayer[] players;
    private Champlain.MarkerLayer mlayer;
    private string filename;
    private string name;

    public KmlOverlay(Champlain.View _view) {
        ovly = {};
        view = _view;
        mlayer = new Champlain.MarkerLayer();
        view.add_layer (mlayer);
        at_bottom(mlayer);
        players = {};
    }

    public string get_filename() {
        return filename;
    }

    public string get_name() {
        return name;
    }

    private bool read_kmz(string kname) {
        bool ok = false;
        string td;
        string path = null;
        try {
            td = DirUtils.make_tmp(path);
            string []argv = {"unzip", kname, "-d", td};
            int status;
            Process.spawn_sync ("/",
                                argv,
                                null,
                                SpawnFlags.SEARCH_PATH |
                                SpawnFlags.STDOUT_TO_DEV_NULL|
                                SpawnFlags.STDERR_TO_DEV_NULL,
                                null,
                                null,
                                null,
                                out status);
            if(status == 0) {
                Dir dir = Dir.open (td, 0);
                string? name = null;
                while ((name = dir.read_name ()) != null) {
                    if(name.has_suffix(".kml")) {
                        path = GLib.Path.build_filename (td, name);
                        break;
                    }
                }
                if(path != null) {
                    ok = parse(path);
                } else {
                    MWPLog.message("Failed to find kml in %s\n", kname);
                }
                dir.rewind();
                while ((name = dir.read_name ()) != null) {
                    string p = GLib.Path.build_filename (td, name);
                    FileUtils.unlink(p);
                }
            } else {
                MWPLog.message("unzip failed to decompress %s\n", kname);
            }
            DirUtils.remove(td);
        } catch (Error e) {
            MWPLog.message("KMZ error: %s\n", e.message);
        }
        if(ok)
            filename = kname;
        return ok;
    }


    private void at_bottom(Champlain.Layer layer) {
        var pp = layer.get_parent();
        pp.set_child_at_index(layer,0);
    }

    private bool parse(string fname) {
        Xml.Doc* doc = Xml.Parser.parse_file (fname);
        if (doc == null) {
            return false;
        }

	Xml.Node* root = doc->get_root_element ();
	if (root == null) {
            MWPLog.message ("malformed kml %s\n", fname);
            delete doc;
            return false;
	}

    filename = fname;
    ovly = {};

    var xpath = "//*[local-name()='Placemark']/*[local-name()='Polygon' or local-name()='LineString'or local-name()='Point']";

    Xml.XPath.Context cntx = new Xml.XPath.Context (doc);
    Xml.XPath.Object* res = cntx.eval_expression (xpath);

    name = look_for(root, "name");

    if (res != null && res->type == Xml.XPath.ObjectType.NODESET &&
        res->nodesetval != null) {
            for (int i = 0; i < res->nodesetval->length (); i++) {
                Xml.Node* node = res->nodesetval->item (i);
                var pname = look_for(node->parent, "name");
                var style = look_for(node->parent, "styleUrl");

                var o = OverlayItem();
                if(style != null)
                    o.styleinfo = populate_style(o, cntx, style);
                else {
                    Xml.Node *n = look_for_node(node->parent, "Style");
                    o.styleinfo = {false, null};
                    if(n != null)
                        extract_style(n, ref o.styleinfo);
                }

                string coords = null;
                var iname = node->name;
                for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
                    coords = look_for(iter, "coordinates");
                    if(coords != null) {
                        coords = coords.strip();
                        break;
                    }
                }
                o.name = pname;
                o.type = iname;

                var cs = Regex.split_simple("\\s+", coords);
                Point[] pts = {};
                foreach(var s in cs) {
                    Point p = Point();
                    var ss = s.split(",");
                    p.latitude = double.parse(ss[1].strip());
                    p.longitude = double.parse(ss[0].strip());
                    pts += p;
                }
                o.pts = pts;
                ovly +=  o;
            }
        }
        delete res;
        delete doc;
        MWPLog.message("Kml loaded %s (%s)\n", filename, name);
        return true;
    }

    private StyleItem populate_style(OverlayItem o,  Xml.XPath.Context cntx, string style) {
        StyleItem si = {false,null};

        string st0;
        st0 = style.substring(1);
        string sm;

        sm = "//*[local-name()='Style'][@id='%s']".printf(st0);
        var res = cntx.eval_expression (sm);
        if (res != null && res->nodesetval != null)
            si = parse_style_nodes(res->nodesetval);
        if (res->nodesetval->length() == 0) {
            sm = "//*[local-name()='StyleMap'][@id='%s']/*[local-name()='Pair']/*[local-name()='key'][text()='normal']".printf(st0);
            res = cntx.eval_expression (sm);
            if (res != null && res->nodesetval != null) {
                Xml.Node* n = res->nodesetval->item(0)->parent;
                var su =  look_for(n, "styleUrl");
                st0 = su.substring(1);
                sm = "//*[local-name()='Style'][@id='%s']".printf(st0);
                res = cntx.eval_expression (sm);
                if (res != null && res->nodesetval != null)
                    si = parse_style_nodes(res->nodesetval);
            }
        }
        return si;
    }

    private void extract_style(Xml.Node *n, ref StyleItem si) {
        for (Xml.Node* iter = n->children; iter != null; iter = iter->next) {
            switch(iter->name) {
                case "IconStyle":
                    if ((si.point_colour = look_for(iter, "color")) != null)
                        si.styled = true;
                    break;
                case "LineStyle":
					string? sw;
					if ((sw = look_for(iter, "width")) != null) {
						si.line_width = int.parse(sw);
					} else {
						si.line_width = 2;
					}
					if((si.line_colour = look_for(iter, "color")) != null)
                        si.styled = true;
                    break;
                case "PolyStyle":
                    if((si.fill_colour = look_for(iter, "color")) != null)
                        si.styled = true;
                    break;
                default:
                    break;
            }
        }
    }

    private StyleItem parse_style_nodes(Xml.XPath.NodeSet* nl) {
        StyleItem si = {false, null};
        for (int i = 0; i < nl->length(); i++) {
            extract_style(nl->item (i), ref si);
        }
        return si;
    }

    private string? look_for(Xml.Node* n, string name) {
        if (n->type == Xml.ElementType.ELEMENT_NODE) {
            if(n->name == name) {
                return n->get_content();
            }
            for (Xml.Node* iter = n->children; iter != null; iter = iter->next) {
                var r = look_for(iter, name);
                if (r != null)
                    return r;
            }
        }
        return null;
    }

    private Xml.Node* look_for_node (Xml.Node* n, string name) {
        if (n->type == Xml.ElementType.ELEMENT_NODE) {
            if(n->name == name) {
                return n;
            }
            for (Xml.Node* iter = n->children; iter != null; iter = iter->next) {
                var r = look_for_node(iter, name);
                if (r != null)
                    return r;
            }
        }
        return null;
    }

    private OverlayItem[] get_overlay() {
        return ovly;
    }

    private Clutter.Color getrgba(string? aabbggrr) {
        string str;
        if(aabbggrr == null || aabbggrr == "")
            str = "#faf976ff";
        else {
            StringBuilder sb = new StringBuilder("#");
            sb.append(aabbggrr[6:8]);
            sb.append(aabbggrr[4:6]);
            sb.append(aabbggrr[2:4]);
            sb.append(aabbggrr[0:2]);
            str = sb.str;
        }
        return Clutter.Color.from_string(str);
    }

    public void remove_overlay() {
        mlayer.remove_all();
        foreach (var p in players) {
            p.remove_all();
            view.remove_layer(p);
        }
        players = {};
    }

    public bool load_overlay(string _fname) {
        bool ok;
        remove_overlay();

        if(_fname.has_suffix(".kmz"))
            ok = read_kmz(_fname);
        else
            ok = parse(_fname);

        if (ok) {
            var ovly = get_overlay();
            foreach(var o in ovly) {
                switch(o.type) {
                    case "Point":
                        Clutter.Color black = { 0,0,0, 0xff };
                        var marker = new Champlain.Label.with_text (o.name,"Sans 10",null,null);
                        marker.set_alignment (Pango.Alignment.RIGHT);
                        marker.set_color(getrgba(o.styleinfo.point_colour));
                        marker.set_text_color(black);
                        marker.set_location (o.pts[0].latitude,o.pts[0].longitude);
                        marker.set_draggable(false);
                        marker.set_selectable(false);
                        mlayer.add_marker (marker);
                        break;
                    case "LineString":
                        var path = new Champlain.PathLayer();
                        path.closed=false;
                        path.set_stroke_color(getrgba(o.styleinfo.line_colour));
						path.set_stroke_width (o.styleinfo.line_width);
                        foreach (var p in o.pts) {
                            var l =  new  Champlain.Point();
                            l.set_location(p.latitude, p.longitude);
                            path.add_node(l);
                        }
                        players += path;
                        view.add_layer (path);
                        at_bottom(path);
                        break;
                    case "Polygon":
                        var path = new Champlain.PathLayer();
                        path.closed=true;
                        path.set_stroke_color(getrgba(o.styleinfo.line_colour));
                        path.fill = (o.styleinfo.fill_colour != null);
                        path.set_fill_color(getrgba(o.styleinfo.fill_colour));
                        foreach (var p in o.pts) {
                            var l =  new  Champlain.Point();
                            l.set_location(p.latitude, p.longitude);
                            path.add_node(l);
                        }
                        players += path;
                        view.add_layer (path);
                        at_bottom(path);
                        break;
                }
            }
        }
        return ok;
    }
}
