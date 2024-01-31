namespace KMLWriter {
	private string fixcol(string col) {
		StringBuilder sb = new StringBuilder();
		sb.append(col[7:9]);
		sb.append(col[5:7]);
		sb.append(col[3:5]);
		sb.append(col[1:3]);
		return sb.str;
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
			if(el.desc.has_prefix("geozone")) {
				var gels = el.desc.split(" ");
				if (gels.length >= 7) {
					Xml.Node* xdata = new Xml.Node (ns, "ExtendedData");
					var gns = xdata->new_ns("http://geo.daria.co.uk/zones/1.0", "gzone");
					xdata->new_text_child (gns, "id", gels[1]);
					xdata->new_text_child (gns, "shape", gels[2]);
					xdata->new_text_child (gns, "type", gels[3]);
					xdata->new_text_child (gns, "minalt", gels[4]);
					xdata->new_text_child (gns, "maxalt", gels[5]);
					alt = int.parse(gels[5])/100;
					xdata->new_text_child (gns, "action", gels[6]);
					if(gels.length == 11 && gels[7] == "circle") {
						xdata->new_text_child (gns, "centre-lat", gels[8]);
						xdata->new_text_child (gns, "centre-lon", gels[9]);
						xdata->new_text_child (gns, "radius", gels[10]);
					}
					vfolder->add_child(xdata);
				}
			}
			var pmark = vfolder->new_text_child (ns, "Placemark", "");
			pmark->new_text_child (ns, "name", el.name);
			pmark->new_text_child (ns, "styleUrl", "#%s".printf(sname));
			var polyg = pmark->new_text_child (ns, "Polygon", "");
			polyg->new_text_child (ns, "altitudeMode", "relativeToGround");
			polyg->new_text_child (ns, "extrude", "1");
			polyg->new_text_child (ns, "tessellate", "0");
			var obis = polyg->new_text_child (ns, "outerBoundaryIs", "");
			var lring = obis->new_text_child (ns, "LinearRing", "");
			var sb = new StringBuilder();

			foreach (var p in  el.mks) {
				sb.append_printf("%.7f,%.7f,%d ", p.longitude, p.latitude, alt);
			}
			sb.append_printf("%.7f,%.7f,%d", el.mks.nth_data(0).longitude, el.mks.nth_data(0).latitude, alt);
			lring->new_text_child (ns, "coordinates", sb.str);
			j++;
			});
		doc->dump_memory_enc_format (out s, null, "utf-8", false);
		return s;
	}
}
