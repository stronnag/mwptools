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

	const string MWP_NSHREF="http://www.daria.co.uk/namepaces/mwp";

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
				var px = root->get_ns_prop("xalign", MWP_NSHREF);
				if(px != null) {
					xalign = float.parse(px);
					found += MwpAlign.X;
				}
				px = root->get_ns_prop("yalign", MWP_NSHREF);
				if(px != null) {
					yalign = float.parse(px);
					found += MwpAlign.Y;
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
				var px = root->get_prop("width");
				if(px != null) {
					width= int.parse(px);
				}
				px = root->get_prop("height");
				if(px != null) {
					height = int.parse(px);
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
						string? p;
						p = iter->get_prop("id");
						if (p != null) {
							if (bgfill != null && p  == "mwpbg") {
								var a = iter->has_prop("fill");
								if (a != null) {
									a->children->content = bgfill;
								}
							}
							if (fgfill != null && p  == "mwpfg") {
								var a = iter->has_prop("fill");
								if (a != null) {
									a->children->content = fgfill;
								}
							}
						}
					}
				}
			}
		}
		string os;
		doc->dump_memory_enc_format (out os, null, "utf-8", true);
		return scale(os.data, Mwp.conf.symbol_scale);
	}

	public Gdk.Pixbuf? scale(uint8[] s, double sf) {
		double w=0;
		double h=0;
		int iw = 0;
		int ih = 0;
		try {
			var svg = new Rsvg.Handle.from_data(s);
			var res = svg.get_intrinsic_size_in_pixels(out w, out h);
			if (res) {
				iw = (int)(w*sf+0.5);
				ih = (int)(h*sf+0.5);
				var cst = new Cairo.ImageSurface (Cairo.Format.ARGB32, iw, ih);
				var cr = new Cairo.Context (cst);
				if(sf != 1.0) {
					cr.scale(sf,sf);
				}
				Rsvg.Rectangle r = {0, 0,w, h};
				svg.render_document (cr, r);
				return Gdk.pixbuf_get_from_surface(cr.get_target(), 0, 0, iw, ih);
			} else {
				return null;
			}
		} catch (Error e) {
			MWPLog.message("SVGScaler: %s\n", e.message);
			return null;
		}
	}
}
