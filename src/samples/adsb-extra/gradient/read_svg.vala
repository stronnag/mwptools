namespace SVGReader {
	string rgb_for_alt(double alt, float s=0.8f, float opacity = 0.8f) {
		float h,v;
		v = 1.0f;
		float r,g,b;
		if (alt > 12000)
			alt = 12000;

		h = (float)(0.05 + 0.75*(alt / 12000.0));
		Gtk.hsv_to_rgb (h, s, v, out r, out g, out b);
		int ir = (int)(r*255);
		int ig = (int)(g*255);
		int ib = (int)(b*255);
		int op = (int)(opacity*255);
		return "#%02x%02x%02x%0x2".printf(ir, ig, ib, op);
	}

	Xml.Doc* parse_svg(string s) {
		Xml.Parser.init();
		Xml.Doc* doc = Xml.Parser.parse_memory(s, s.length);
        if (doc == null) {
            return null;
        }
		return doc;
	}

	string? rewrite_svg(Xml.Doc *doc, string? bgfill) {
		Xml.Node* root = doc->get_root_element ();
        if (root != null) {
            if (root->name == "svg") {
				bool is_mwpbg = false;
				bool done = false;
				for (Xml.Node* iter = root->children; iter != null; iter = iter->next) {
					if (done)
						break;
					if (iter->type != Xml.ElementType.ELEMENT_NODE) {
						continue;
					}
					if(iter->name == "path") {
						for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next) {							string attr_content = prop->children->content;
							if(prop->name == "id" && attr_content == "mwpbg") {
								is_mwpbg = true;
							} else if(prop->name == "fill" && is_mwpbg && bgfill != null) {
								is_mwpbg = false;
								prop->children->content = bgfill;
								done = true;
								break;
							}
						}
					}
				}
            }
        }
		string os;
		doc->dump_memory_enc_format (out os, null, "utf-8", true);
		/*
		var stream = new MemoryInputStream.from_data(os.data);
		var pixbuf = new Gdk.Pixbuf.from_stream(stream, null);
		var svgwidget = new Gtk.Image.from_pixbuf(pixbuf);
		*/
		return os;
    }
}

int main(string?[] args) {
	Gtk.init();
	if (args.length > 1) {
		string fn = args[1];
		string xml;
		try {
			if (FileUtils.get_contents(fn, out xml)) {
				var doc = SVGReader.parse_svg(xml);
				for(int alt = 0; alt < 12001; alt += 500) {
					var bgfill =  SVGReader.rgb_for_alt((double)alt);
					var s = SVGReader.rewrite_svg(doc, bgfill);
					var ofn = "alt_%05d.svg".printf(alt);
					FileUtils.set_contents(ofn, s);
					stdout.printf("alt %5d, id %2d, fill %s\n", alt, alt/500, bgfill);
				}
				var s = SVGReader.rewrite_svg(doc, "#ff0000");
				FileUtils.set_contents("alt_alert.svg", s);
				delete doc;
				Xml.Parser.cleanup();
			}
		} catch (Error e) {
			stderr.printf("Read %s %s\n", fn, e.message);
		}
	}
	return 0;
}