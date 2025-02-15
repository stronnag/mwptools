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

namespace SVGReader {
	[Flags]
	public enum MwpAlign {
		X,
		Y
	}

	string rgb_for_alt(double alt) {
    float h,s,v;
    s = 0.8f;
    v = 1.0f;
    float r,g,b;
    if (alt > 12000)
      alt = 12000;

	h = (float)(0.05 + 0.8*(alt / 12000.0));
    Gtk.hsv_to_rgb (h, s, v, out r, out g, out b);
    int ir = (int)(r*255);
    int ig = (int)(g*255);
    int ib = (int)(b*255);
    return "#%02x%02x%02x".printf(ir,ig,ib);
  }

	Xml.Doc* parse_svg(string s) {
		Xml.Parser.init();
		Xml.Doc* doc = Xml.Parser.parse_memory(s, s.length);
        if (doc == null) {
            return null;
        }
		return doc;
	}

	public MwpAlign get_mwp_alignment (Xml.Doc *doc, out float xalign, out float yalign) {
		MwpAlign found = 0;
		xalign = 0;
		yalign = 0;
		Xml.Node* root = doc->get_root_element ();
		if (root != null) {
			if (root->name == "svg") {
				for (Xml.Attr* prop = root->properties; prop != null; prop = prop->next) {
					if (prop->ns != null && prop->ns->prefix == "mwp") {
						if(prop->name == "xalign") {
							found += MwpAlign.X;
							xalign = float.parse(prop->children->content);
						} else if(prop->name == "yalign") {
							found += MwpAlign.Y;
						yalign = float.parse(prop->children->content);
						}
					}
				}
			}
		}
		return found;
	}

	public void get_size(Xml.Doc *doc, out int width, out int height) {
		width = 0;
		height = 0;
		Xml.Node* root = doc->get_root_element ();
		if (root != null) {
			if (root->name == "svg") {
				for (Xml.Attr* prop = root->properties; prop != null; prop = prop->next) {
					if(prop->name == "width") {
						width= int.parse(prop->children->content);
					} else if(prop->name == "height") {
						width = int.parse(prop->children->content);
					}
				}
			}
		}
	}

	Gdk.Pixbuf? rewrite_svg(Xml.Doc *doc, string? bgfill, string? fgfill) {
		Xml.Node* root = doc->get_root_element ();
		if (root != null) {
			if (root->name == "svg") {
				bool done = false;
				for (Xml.Node* iter = root->children; iter != null; iter = iter->next) {
					if (done)
						break;
					if (iter->type != Xml.ElementType.ELEMENT_NODE) {
						continue;
					}
					if(iter->name == "path") {
						bool is_mwpbg = false;
						bool is_mwpfg = false;
						for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next) {
							string attr_content = prop->children->content;
							if(prop->name == "id" && attr_content == "mwpbg") {
								is_mwpbg = true;
							} else if(prop->name == "id" && attr_content == "mwpfg") {
								is_mwpfg = true;
							} else if(prop->name == "fill") {
								if (is_mwpbg && bgfill != null) {
									is_mwpbg = false;
									prop->children->content = bgfill;
								} else if (is_mwpfg && fgfill != null) {
									is_mwpfg = false;
									prop->children->content = fgfill;
								}
							}
						}
					}
				}
			}
		}
		string os;
		doc->dump_memory_enc_format (out os, null, "utf-8", true);
		var stream = new MemoryInputStream.from_data(os.data);
		try {
			return new Gdk.Pixbuf.from_stream(stream, null);
		} catch {
			return null;
		}
	}
}
