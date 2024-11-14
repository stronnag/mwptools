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

using Xml;

namespace XmlIO {
    public static bool uc = false;
    public static bool ugly = false;
    public static bool meta = false;
    public static string generator;
	private static bool set_fwa;

    public Mission[]? read_xml_file(string path, bool _set_fwa = false) {
        string s;
        try  {
            FileUtils.get_contents(path, out s);
        } catch (FileError e) {
            stderr.puts(e.message);
            stderr.putc('\n');
            return null;
        }
        return read_xml_string(s, _set_fwa);
    }

    public Mission[]? read_xml_string(string s, bool _set_fwa = false) {
		set_fwa = _set_fwa;
		Mission [] msx = null;
		Parser.init ();
		Xml.Doc* doc = Parser.parse_memory(s, s.length);
        if (doc == null) {
            return null;
        }

		Xml.Node* root = doc->get_root_element ();
        if (root != null) {
            if (root->name.down() == "mission") {
                msx = parse_node (root);
            }
        }
        delete doc;
        Parser.cleanup();
        return msx;
    }

    private void parse_sub_node(Xml.Node* node, ref Mission ms) {
        for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
            if (iter->type != ElementType.ELEMENT_NODE)
                continue;

            switch(iter->name.down()) {
			case "distance":
				for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next) {
					switch(prop->name) {
					case "value":
						ms.dist = DStr.strtod(prop->children->content,null);
						break;
					}
				}
				break;
			case "nav-speed":
				for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next) {
					switch(prop->name) {
					case "value":
						ms.nspeed = DStr.strtod(prop->children->content,null);
						break;
					}
				}
				break;
			case "fly-time":
				for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next) {
					switch(prop->name) {
					case "value":
						ms.et = int.parse(prop->children->content);
						break;
					}
				}
				break;
			case "loiter-time":
				for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next) {
					switch(prop->name) {
					case "value":
						ms.lt = int.parse(prop->children->content);
						break;
					}
				}
				break;
			case "details":
				parse_sub_node(iter, ref ms);
				break;
            }
        }
    }

    private Mission[] parse_node (Xml.Node* node) {
		Mission[] msx = {};
        MissionItem []mi ={};
		Mission? ms = null;
		uint8 lflag = 0;
		int wpno = 1;
		int idx = 0;

		for (Xml.Node* iter = node->children; iter != null; iter = iter->next) {
            if (iter->type != ElementType.ELEMENT_NODE)
                continue;

			if (ms == null) {
				ms = new Mission();
			}
            switch(iter->name.down()) {
			case  "fwapproach":
				FWApproach.approach l={};
				for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next) {
					string attr_content = prop->children->content;
					switch( prop->name.down()) {
					case "index":
						break;
					case "no":
						idx = int.parse(attr_content);
						break;
					case "approachalt":
						l.appalt = int.parse(attr_content)/100.0;
						break;
					case "landalt":
						l.landalt = int.parse(attr_content)/100.0;
						break;
					case "approachdirection":
						l.dref = (attr_content.down() == "right");
						break;
					case "landheading1":
						l.dirn1 = (int16)int.parse(attr_content);
						if (l.dirn1 < 0) {
							l.ex1 = true;
							l.dirn1 = -l.dirn1;
						}
						break;
					case "landheading2":
						l.dirn2 = (int16)int.parse(attr_content);
						if (l.dirn2 < 0) {
							l.ex2 = true;
							l.dirn2 = -l.dirn2;
						}
						break;
					case "sealevelref":
						l.aref = bool.parse(attr_content.down());
						break;
					}
				}
				if(set_fwa && idx > 7) {
					FWApproach.set(idx, l);
				}
				break;

			case  "missionitem":
				var m = new MissionItem();
				for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next) {
					string attr_content = prop->children->content;
					switch( prop->name) {
					case "no":
						m.no = wpno++; //int.parse(attr_content);
						break;
					case "action":
						var act = attr_content;
						m.action = Msp.lookup_name(act);
						break;
					case "lat":
						m.lat = DStr.strtod(attr_content,null);
						break;
					case "lon":
						m.lon = DStr.strtod(attr_content,null);
						break;
					case "parameter1":
						m.param1 = int.parse(attr_content);
						break;
					case "parameter2":
						m.param2 = int.parse(attr_content);
						break;
					case "parameter3":
						m.param3 = int.parse(attr_content);
						break;
					case "flag":
						lflag = m.flag = (uint8)int.parse(attr_content);
						break;
					case "alt":
						m.alt = int.parse(attr_content);
						if(m.alt > ms.maxalt)
							ms.maxalt = m.alt;
						break;
					}
				}
				ms.check_wp_sanity(ref m);
				mi += m;
				break;
			case "version":
				for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next) {
					if (prop->name == "value")
						ms.version = prop->children->content;
				}
				break;
			case "mwp":
			case "meta":
				for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next) {
					switch(prop->name) {
					case "zoom":
						ms.zoom = (uint)int.parse(prop->children->content);
						break;
					case "cx":
						ms.cx = DStr.strtod(prop->children->content,null);
						break;
					case "cy":
						ms.cy = DStr.strtod(prop->children->content,null);
						break;
					case "home-x":
						ms.homex = DStr.strtod(prop->children->content,null);
						break;
					case "home-y":
						ms.homey = DStr.strtod(prop->children->content,null);
						break;
					}
				}
				parse_sub_node(iter, ref ms);
				break;
			}
			if (lflag == 0xa5) {
				ms.npoints = mi.length;
				if(ms.npoints != 0) {
					ms.points = mi;
					ms.update_meta(false);
					msx += ms;
				}
				ms = null;
				lflag = 0;
				wpno = 1;
				mi = {};
			}
		}

		if (ms != null) { // single mission file, no flags
			ms.npoints = mi.length;
			ms.set_ways(mi);
			if(ms.npoints != 0) {
				ms.update_meta();
				msx += ms;
			}
		}
		return msx;
	}

    public void to_xml_file(string path, Mission[] msx) {
		string s = to_xml_string(msx);
		try {
			FileUtils.set_contents(path, s);
		} catch {}
	}

    public string to_xml_string(Mission [] msx, bool pretty=true) {
        Parser.init ();
        Xml.Doc* doc = new Xml.Doc ("1.0");

        if(generator == null)
            generator="mwp";

        Xml.Ns* ns = null;

        string mstr = "mission";
        if (uc)
            mstr = mstr.ascii_up();
        Xml.Node* root = new Xml.Node (ns, mstr);

        doc->set_root_element (root);

        Xml.Node* comment = new Xml.Node.comment ("mw planner 0.01");
        root->add_child (comment);

        Xml.Node* subnode;

        if (msx[0].version != null) {
            mstr = "version";
            if (uc)
                mstr = mstr.ascii_up();
            subnode = root->new_text_child (ns, mstr, "");
            subnode->new_prop ("value", msx[0].version);
        }
		int wpno = 0;
		int mxno = 0;
		foreach (var ms in msx) {
			if(ms.npoints == 0)
				continue;
			double d;
			int lt;
			if (ms.dist <= 0 && ms.npoints > 1)
				if (ms.calculate_distance(out d, out lt) == true) {
					ms.dist = d;
				}
			string nname;
			nname = (XmlIO.meta) ? "meta" : "mwp";
			subnode = root->new_text_child (ns, nname, "");
			time_t currtime;
			time_t(out currtime);
			char[] dbuf = new char[double.DTOSTR_BUF_SIZE];
			subnode->new_prop ("save-date", Time.local(currtime).format("%FT%T%z"));
			subnode->new_prop ("zoom", ms.zoom.to_string());
			subnode->new_prop ("cx", ms.cx.format(dbuf,"%.7f"));
			subnode->new_prop ("cy", ms.cy.format(dbuf,"%.7f"));
			if(ms.homex != 0 && ms.homey != 0) {
				subnode->new_prop ("home-x", ms.homex.format(dbuf,"%.7f"));
				subnode->new_prop ("home-y", ms.homey.format(dbuf,"%.7f"));
			}
			subnode->new_prop ("generator", "%s (mwptools)".printf(generator));

			if(ms.dist > 0)	{
				Xml.Node* xsubnode;
				Xml.Node* ysubnode;
				xsubnode = subnode->new_text_child (ns, "details", "");

				ysubnode = xsubnode->new_text_child (ns, "distance", "");
				ysubnode->new_prop ("units", "m");
				ysubnode->new_prop ("value", ms.dist.format(dbuf,"%.0f"));
				if (ms.et > 0) {
					ysubnode = xsubnode->new_text_child (ns, "nav-speed", "");
					ysubnode->new_prop ("units", "m/s");
					ysubnode->new_prop ("value", ms.nspeed.to_string());

					ysubnode = xsubnode->new_text_child (ns, "fly-time", "");
					ysubnode->new_prop ("units", "s");
					ysubnode->new_prop ("value", ms.et.to_string());

					ysubnode = xsubnode->new_text_child (ns, "loiter-time", "");
					ysubnode->new_prop ("units", "s");
					ysubnode->new_prop ("value", ms.lt.to_string());
				}
			}

			mstr = "missionitem";
			if (uc)
				mstr = mstr.ascii_up();

			bool has_land = false;
			foreach(var m in ms.get_ways()) {
				wpno++;
				subnode = root->new_text_child (ns, mstr, "");
				subnode->new_prop ("no", wpno.to_string() );
				subnode->new_prop ("action", Msp.get_wpname(m.action));
				subnode->new_prop ("lat", m.lat.format(dbuf,"%.7f"));
				subnode->new_prop ("lon", m.lon.format(dbuf,"%.7f"));
				subnode->new_prop ("alt", m.alt.to_string());
				subnode->new_prop ("parameter1", m.param1.to_string());
				subnode->new_prop ("parameter2", m.param2.to_string());
				subnode->new_prop ("parameter3", m.param3.to_string());
				var flg = m.flag;
				if (m.no == ms.npoints) {
					flg = 0xa5;
				} else if (flg != 0x48) {
					flg = 0;
				}
				subnode->new_prop ("flag", flg.to_string());
				if(m.action == Msp.Action.LAND) {
					has_land = true;
				}
			}

			if(!ugly) {
				wpno = 0;
			}
			var lid = mxno+8;
			if(has_land && FWApproach.is_active(lid)) {
				var l = FWApproach.get(lid);
				subnode = root->new_text_child (ns, "fwapproach", "");
				subnode->new_prop ("no", lid.to_string());
				subnode->new_prop ("index", mxno.to_string());
				subnode->new_prop ("approachalt", ((int)(l.appalt*100)).to_string());
				subnode->new_prop ("landalt", ((int)(l.landalt*100)).to_string());
				var dl = (!l.ex1) ? l.dirn1 : -l.dirn1;
				subnode->new_prop ("landheading1", dl.to_string());
				dl = (!l.ex2) ? l.dirn2 : -l.dirn2;
				subnode->new_prop ("landheading2", dl.to_string());
				subnode->new_prop ("approachdirection", (l.dref) ? "right" : "left");
				subnode->new_prop ("sealevelref", l.aref.to_string());
			}
			mxno += 1;
		}
		string s;
		doc->dump_memory_enc_format (out s, null, "utf-8", pretty);
        delete doc;
        Parser.cleanup ();
        return s;
    }
}


#if XMLTEST_MAIN

int main (string[] args) {
    if (args.length < 2) {
        stderr.printf ("Argument required!\n");
        return 1;
    }

	if (args.length == 4) {
		var iv = int.parse(args[3]);
		if ((iv & 1) == 1)
			XmlIO.ugly = true;
		if ((iv & 2) == 2)
			XmlIO.meta = true;
	}
    var  msx = XmlIO.read_xml_file (args[1]);
	foreach (var ms in msx) {
		ms.dump(120);
/**
		double d = 0.0;
		int lt = 0;
		var res = ms.calculate_distance(out d, out lt);
		if (res == true) {
			var et = (int)(d / 6.0);
			print("dist %.0f %ds (at 6m/s) (%ds)\n",d,et,lt);
		}
		else
			print("Indeterminate\n");

   stdout.puts(XmlIO.to_xml_string(ms, false));
   stdout.putc('\n');
   stdout.putc('\n');
   XmlIO.uc = true;

**/
    }
	stderr.printf("Dump  %d %s\n", args.length, XmlIO.ugly.to_string());
	if (args.length >= 3)
		XmlIO.to_xml_file(args[2], msx);
    return 0;
}
#endif
