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

namespace KMLWriter {
	private uint8 rgbval(double v) {
		return (uint8)(v*255);
	}

	private string fixcol(string col) {
		string s;
		Gdk.RGBA c = Gdk.RGBA();
		c.parse(col);
		// AABBGGRR
		s = "%02x%02x%02x%02x".printf(rgbval(c.alpha*255), rgbval(c.blue), rgbval(c.green), rgbval(c.red));
		return s;
	}

	public string ovly_to_string(Overlay o) {
		string s;
        Xml.Doc* doc = new Xml.Doc ("1.0");
		Xml.Node* root = new Xml.Node (null, "kml");
        doc->set_root_element (root);
		var ns = new Xml.Ns (root, "http://www.opengis.net/kml/2.2", "gx");
		Xml.Node* comment = new Xml.Node.comment ("created from mwp");
        root->add_child (comment);
		Xml.Node* folder;
		folder = root->new_text_child (ns, "Folder", "");
		folder->new_text_child (ns, "name", "Zones");
		folder->new_text_child (ns, "open", "1");
		int j = 0;
		o.get_elements().foreach((el) => {
				var sname = "StyleItem_%d".printf(j);
				var style = folder->new_text_child (ns, "Style", "");
				style->new_prop ("id", sname);
				Xml.Node* style_item;
				if(el.styleinfo.point_colour != null && el.styleinfo.point_colour != "")  {
					style_item = style->new_text_child (ns, "IconStyle", "");
					style_item->new_text_child (ns, "scale", "1");
					style_item->new_text_child (ns, "color", fixcol(el.styleinfo.point_colour));
				}
				style_item = style->new_text_child (ns, "PolyStyle", "");
				if(el.styleinfo.fill_colour != null && el.styleinfo.fill_colour != "")  {
					style_item->new_text_child (ns, "color", fixcol(el.styleinfo.fill_colour));
				} else {
					style_item->new_text_child (ns, "color", "00000000");
				}
				if(el.styleinfo.line_colour != null && el.styleinfo.line_colour != "")  {
					style_item = style->new_text_child (ns, "LineStyle", "");
					style_item->new_text_child (ns, "color", fixcol(el.styleinfo.line_colour));
					style_item->new_text_child (ns, "width", el.styleinfo.line_width.to_string());
				}
				var vfolder = folder->new_text_child (ns, "Folder", "");
				vfolder->new_text_child (ns, "visibility", "1");
				vfolder->new_text_child (ns, "name", el.name);
				vfolder->new_text_child (ns, "description", el.desc);
				int alt = 0;
				int isAMSL=0;
				if(el.desc.has_prefix("geozone")) {
					var gels = el.desc.split(" ");
					if (gels.length >= 8) {
						Xml.Node* xdata = new Xml.Node (ns, "ExtendedData");
						var gns = xdata->new_ns("http://geo.daria.co.uk/zones/1.0", "gzone");
						xdata->new_text_child (gns, "id", gels[1]);
						xdata->new_text_child (gns, "shape", gels[2]);
						xdata->new_text_child (gns, "type", gels[3]);
						xdata->new_text_child (gns, "minalt", gels[4]);
						xdata->new_text_child (gns, "maxalt", gels[5]);
						alt = int.parse(gels[5])/100;
						isAMSL = (uint8)int.parse(gels[6]);
						xdata->new_text_child (gns, "isAMSL", gels[6]);
						xdata->new_text_child (gns, "action", gels[7]);
						if(gels.length == 12 && gels[8] == "circle") {
							xdata->new_text_child (gns, "centre-lat", gels[9]);
							xdata->new_text_child (gns, "centre-lon", gels[10]);
							xdata->new_text_child (gns, "radius", gels[11]);
						}
						vfolder->add_child(xdata);
					}
				}
				var pmark = vfolder->new_text_child (ns, "Placemark", "");
				pmark->new_text_child (ns, "name", el.name);
				pmark->new_text_child (ns, "styleUrl", "#%s".printf(sname));
				var polyg = pmark->new_text_child (ns, "Polygon", "");
				var altmode = "relativeToGround";
				if (alt == 0) {
					altmode = "clampToGround";
				}
				if (isAMSL == 1) {
					altmode = "absolute";
				}
				polyg->new_text_child (ns, "altitudeMode", altmode);
				polyg->new_text_child (ns, "extrude", "1");
				polyg->new_text_child (ns, "tessellate", "0");
				var obis = polyg->new_text_child (ns, "outerBoundaryIs", "");
				var lring = obis->new_text_child (ns, "LinearRing", "");
				var sb = new StringBuilder();
				if(el.mks.length() > 0) {
					foreach (var p in  el.mks) {
						sb.append_printf("%.7f,%.7f,%d ", p.longitude, p.latitude, alt);
					}
				} else {
					el.pl.get_nodes().foreach ((p) => {
							sb.append_printf("%.7f,%.7f,%d ", p.longitude, p.latitude, alt);
						});
					sb.append_printf("%.7f,%.7f,%d", el.pl.get_nodes().nth_data(0).longitude,
									 el.pl.get_nodes().nth_data(0).latitude, alt);
				}
				lring->new_text_child (ns, "coordinates", sb.str);
				j++;
			});
		doc->dump_memory_enc_format (out s, null, "utf-8", false);
		return s;
	}
}
