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

namespace Kml {
	[GtkTemplate (ui = "/org/stronnag/mwp/kmlremover.ui")]
	public class Remover : Adw.Window {
		[GtkChild]
		private unowned Gtk.Box kmlitems;
		[GtkChild]
		private unowned Gtk.Button kmlcan;
		[GtkChild]
		private unowned Gtk.Button kmlok;

		private Gtk.CheckButton[] btns;

		public Remover() {
			transient_for = Mwp.window;
			close_request.connect (() => {
					cleanup();
					return true;
				});

			kmlok.clicked.connect(() => {
					var i = btns.length;
					foreach (var b in btns) {
						i--;
						if(b.get_active()) {
							kmls.index(i).remove_overlay();
							kmls.remove_index(i);
							update_kml_menu();
						}
					}
					cleanup();
				});

			kmlcan.clicked.connect(() => {
					cleanup();
				});
			btns = {};
		}

		private void cleanup() {
			foreach(var b in btns) {
				kmlitems.remove(b);
			}
			btns = {};
			visible=false;
		}

		public void remove() {
			for (int i = 0; i < kmls.length ; i++) {
				var s = kmls.index(i).get_name();
				var fk = kmls.index(i).get_filename();
				var button = new Gtk.CheckButton.with_label(s);
				button.tooltip_text = "%s : %s".printf(s, fk);
				btns += button;
				kmlitems.append(button);
			}
			present();
		}
	}

	public Array<KmlOverlay> kmls = null;
	private Remover rmer = null;

    public void try_load_overlay(string kf) {
        new Kml.KmlOverlay.from_file(kf);
	}

	private void update_kml_menu() {
		MwpMenu.set_menu_state(Mwp.window, "kml-remove", (Kml.kmls.length > 0));
	}

	public void load_file() {
		IChooser.Filter ifl = {"KML Files", {"kml", "kmz"}};
		var fc = IChooser.chooser(Mwp.conf.kmlpath, {ifl});
		fc.title = "KML Files";
        fc.open_multiple.begin (Mwp.window, null, (o,r) => {
				try {
					var files = fc.open_multiple.end(r);
					for(var j = 0; j < files.get_n_items(); j++) {
						var gfile = files.get_item(j) as File;
						if (gfile != null) {
							var fn = gfile.get_path ();
							new KmlOverlay.from_file(fn);
						} else {
							stderr.printf("filedialog returns NULL\n");
						}
					}
				} catch {}
			});
	}

	public void remove_kml() {
		if(rmer == null) {
			rmer = new Remover();
		}
		rmer.remove();
	}

	public void remove_all() {
		for (int i = 0; i < kmls.length ; i++) {
            kmls.index(i).remove_overlay();
        }
        kmls.remove_range(0,kmls.length);
    }

	public class KmlOverlay : Object {
		private string filename;
		private string name;
		private Overlay ovly;

		construct {
			if (kmls == null)
				kmls = new Array<KmlOverlay>();
		}

		public KmlOverlay.from_file(string _fname) {
			bool ok;
			if(_fname.has_suffix(".kmz"))
				ok = read_kmz(_fname);
			else
				ok = parse(_fname);

			if (ok) {
				ovly.display();
				kmls.append_val(this);
				update_kml_menu();
			}
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

		private bool parse(string fname) {
			Xml.Doc* doc = Xml.Parser.parse_file (fname);
			if (doc == null) {
				return false;
			}
			ovly = new Overlay();
			Xml.Node* root = doc->get_root_element ();
			if (root == null) {
				MWPLog.message ("malformed kml %s\n", fname);
				delete doc;
				return false;
			}

			filename = fname;

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

					var o = new OverlayItem();
					if(style != null)
						populate_style(ref o, cntx, style);
					else {
						Xml.Node *n = look_for_node(node->parent, "Style");
						o.styleinfo = {};
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
					switch (iname) {
					case "Point":
						o.type = OverlayItem.OLType.POINT;
						break;
					case "LineString":
						o.type = OverlayItem.OLType.LINESTRING;
						break;
					case "Polygon":
						o.type = OverlayItem.OLType.POLYGON;
						break;
					default:
						o.type = OverlayItem.OLType.UNKNOWN;
						break;
					}
					var cs = Regex.split_simple("\\s+", coords);
					foreach(var s in cs) {
						var ss = s.split(",");
						var p1= double.parse(ss[1].strip());
						var p0 = double.parse(ss[0].strip());
						if(o.type ==  OverlayItem.OLType.POINT) {
							o.add_point(p1, p0);
						} else {
							o.add_line_point(p1, p0, "") ;
						}
					}
					ovly.add_element(o);
				}
			}
			delete res;
			delete doc;
			MWPLog.message("Kml loaded %s (%s)\n", filename, name);
			return true;
		}

		private void populate_style(ref OverlayItem o,  Xml.XPath.Context cntx, string style) {
			OverlayItem.StyleItem si = {};

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
			o.styleinfo = si;
		}

		private void extract_style(Xml.Node *n, ref OverlayItem.StyleItem si) {
			for (Xml.Node* iter = n->children; iter != null; iter = iter->next) {
				switch(iter->name) {
				case "IconStyle":
					if ((si.point_colour = look_for(iter, "color")) != null)
						si.point_colour = getrgba(si.point_colour);
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
						si.line_colour = getrgba(si.line_colour);
					si.styled = true;
					break;
				case "PolyStyle":
					if((si.fill_colour = look_for(iter, "color")) != null)
						si.fill_colour = getrgba(si.fill_colour);
					si.styled = true;
					break;
				default:
					break;
				}
			}
		}

		private string getrgba(string? aabbggrr) {
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
			return str;
		}

		private OverlayItem.StyleItem parse_style_nodes(Xml.XPath.NodeSet* nl) {
			OverlayItem.StyleItem si = {};
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

		public void remove_overlay() {
			ovly.remove();
		}
	}
}
