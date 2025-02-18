

namespace SVGReader {
	const string MWP_NSHREF="http://www.daria.co.uk/namepaces/mwp";

	string ? update_svg(string fn, string s, string[]args) {
		string? xalign=null;
		string? yalign=null;
		bool gradients=false;

		for(int n = 0; n < args.length; ) {
			string? key = args[n];
			if (key == null)
				break;
			n++;
			if(key == "xalign") {
				xalign = args[n];
				n++;
			} else if(key == "yalign") {
				yalign = args[n];
				n++;
			} else if (key == "gradients") {
				gradients = true;
			}
		}

		Xml.Parser.init();
		Xml.Doc* doc = Xml.Parser.parse_memory(s, s.length);
        if (doc == null) {
            return null;
        }
		unowned Xml.Node* root = doc->get_root_element ();
		string os = null;

        if (root != null) {
            if (root->name == "svg") {
				var pw = root->get_prop("width");
				var ph = root->get_prop("height");
				if( pw == null || ph == null) {
					stderr.printf("%s does not have the 'width' and/or 'height' attribute\n", fn);
				} else {
					Xml.Attr *a;
					a = root->has_ns_prop("xalign", MWP_NSHREF);
					if (a != null) {
						a->children->content = xalign;
						xalign = null;
					}
					a = root->has_ns_prop("yalign", MWP_NSHREF);
					if (a != null) {
						a->children->content = yalign;
						yalign = null;
					}

					if(xalign != null || yalign != null) {
						Xml.Ns *mwpns = new Xml.Ns(root, MWP_NSHREF, "mwp");
						if (xalign != null) {
							root->new_ns_prop(mwpns, "xalign", xalign);
						}
						if (yalign != null) {
							root->new_ns_prop(mwpns, "yalign", yalign);
						}
					}

					if(gradients) {
						for (Xml.Node* iter = root->children; iter != null; iter = iter->next) {
							if (iter->type != Xml.ElementType.ELEMENT_NODE) {
								continue;
							}
							if(iter->name == "path") {
								var id = iter->get_prop("id");
								if (id == null) {
									var fill = iter->get_prop("fill");
									if (fill == "rgb(255,255,255)" || fill == "rgb(100%, 100%, 100%)") {
										iter->new_prop("id", "mwpbg");
									} else if(fill == "rgb(0%, 0%, 0%)") {
										iter->new_prop("id", "mwpfg");
									}
								}
							}
						}
					}
					doc->dump_memory_enc_format (out os, null, "utf-8", true);
				}
			}
        }
		delete doc;
		Xml.Parser.cleanup();
		return os;
    }
}

int main(string?[] args) {
	string xval=null;
	string yval=null;
	bool grads=false;

	var options =  new OptionEntry[] {
		{ "xalign", 'x', 0, OptionArg.STRING, ref xval, "xalign", ""},
		{ "yalign", 'y', 0, OptionArg.STRING, ref yval, "yalign", ""},
		{ "gradients", 'g', 0, OptionArg.NONE, ref grads, "gradients", "false"},
		{null}
	};

	try {
		var opt = new OptionContext(" - fixup-svg [options] files");
		opt.set_help_enabled(true);
		opt.add_main_entries(options, null);
		opt.parse(ref args);
	} catch (Error e) {
		stderr.printf("Opt error: %s\n", e.message);
	}

	string []xargs={};
	if(xval != null) {
		xargs += "xalign";
		xargs += xval;
	}
	if(yval != null) {
		xargs += "yalign";
		xargs += yval;
	}
	if(grads) {
		xargs += "gradients";
	}

	if (xargs.length == 0) {
		return 0;
	}
	xargs += null;

	foreach (var a in args[1:]) {
		try {
			string xml;
			if (FileUtils.get_contents(a, out xml)) {
				var s= SVGReader.update_svg(a, xml, xargs);
				if (s != null) {
					FileUtils.set_contents(a, s);
				}
			}
		} catch (Error e) {
			stderr.printf("Read %s %s\n", a, e.message);
		}
	}
	return 0;
}