using Xml;

namespace XmlIO
{
    public static bool uc = false;
    public static bool ugly = false;
    public static bool meta = false;
    public static string generator;

    public Mission[]? read_xml_file(string path)
    {

        string s;

        try  {
            FileUtils.get_contents(path, out s);
        } catch (FileError e) {
            stderr.puts(e.message);
            stderr.putc('\n');
            return null;
        }

        return read_xml_string(s);
    }

    public Mission[]? read_xml_string(string s)
    {
		Mission [] msx = null;
		Parser.init ();
		Xml.Doc* doc = Parser.parse_memory(s, s.length);
        if (doc == null)
        {
            return null;
        }

		Xml.Node* root = doc->get_root_element ();
        if (root != null)
        {
            if (root->name.down() == "mission")
            {
                msx = parse_node (root);
            }
        }
        delete doc;
        Parser.cleanup();
        return msx;
    }

    private void parse_sub_node(Xml.Node* node, ref Mission ms)
    {
        for (Xml.Node* iter = node->children; iter != null; iter = iter->next)
        {
            if (iter->type != ElementType.ELEMENT_NODE)
                continue;

            switch(iter->name.down())
            {
			case "distance":
				for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next)
				{
					switch(prop->name)
					{
					case "value":
						ms.dist = DStr.strtod(prop->children->content,null);
						break;
					}
				}
				break;
			case "nav-speed":
				for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next)
				{
					switch(prop->name)
					{
					case "value":
						ms.nspeed = DStr.strtod(prop->children->content,null);
						break;
					}
				}
				break;
			case "fly-time":
				for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next)
				{
					switch(prop->name)
					{
					case "value":
						ms.et = int.parse(prop->children->content);
						break;
					}
				}
				break;
			case "loiter-time":
				for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next)
				{
					switch(prop->name)
					{
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

    private Mission[] parse_node (Xml.Node* node)
    {
		Mission[] msx = {};
        MissionItem[] mi={};
		Mission? ms = null;
		uint8 lflag = 0;
		int wpno = 1;

		for (Xml.Node* iter = node->children; iter != null; iter = iter->next)
        {
            if (iter->type != ElementType.ELEMENT_NODE)
                continue;

			if (ms == null) {
				ms = new Mission();
			}

            switch(iter->name.down())
            {
			case  "missionitem":
				var m = MissionItem();
				for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next)
				{
					string attr_content = prop->children->content;
					switch( prop->name)
					{
					case "no":
						m.no = wpno++; //int.parse(attr_content);
						break;
					case "action":
						var act = attr_content;
						m.action = MSP.lookup_name(act);
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

				if(m.action != MSP.Action.RTH && m.action != MSP.Action.JUMP
				   && m.action != MSP.Action.SET_HEAD)
				{
					if (m.lat > ms.maxy)
						ms.maxy = m.lat;
					if (m.lon > ms.maxx)
						ms.maxx = m.lon;
					if (m.lat <  ms.miny)
						ms.miny = m.lat;
					if (m.lon <  ms.minx)
						ms.minx = m.lon;
				}
				mi += m;
				break;
			case "version":
				for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next)
				{
					if (prop->name == "value")
						ms.version = prop->children->content;
				}
				break;
			case "mwp":
			case "meta":
				for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next)
				{
					switch(prop->name)
					{
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
				if(ms.npoints != 0)
					ms.update_meta(mi);
				msx += ms;
				ms = null;
				lflag = 0;
				wpno = 1;
				mi={};
			}
		}

		if (ms != null) { // single mission file, no flags
			ms.npoints = mi.length;
			ms.set_ways(mi);
			if(ms.npoints != 0)
			{
				ms.update_meta(mi);
			}
			msx += ms;
		}
		return msx;
	}

    public void to_xml_file(string path, Mission[] msx)
    {
		string s = to_xml_string(msx);
		try {
			FileUtils.set_contents(path, s);
		} catch {}
	}

    public string to_xml_string(Mission [] msx, bool pretty=true)
    {
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

        if (msx[0].version != null)
        {
            mstr = "version";
            if (uc)
                mstr = mstr.ascii_up();
            subnode = root->new_text_child (ns, mstr, "");
            subnode->new_prop ("value", msx[0].version);
        }
		int wpno = 0;
		foreach (var ms in msx) {
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

			if(ms.dist > -1)
			{
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

			foreach (MissionItem m in ms.get_ways())
			{
				wpno++;
				subnode = root->new_text_child (ns, mstr, "");
//				subnode->new_prop ("no", m.no.to_string());
				subnode->new_prop ("no", wpno.to_string() );
				subnode->new_prop ("action", MSP.get_wpname(m.action));
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
			}
			if(!ugly)
				wpno = 0;
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
		if (res == true)
		{
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
