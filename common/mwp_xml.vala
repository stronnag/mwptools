
/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */
using Xml;

public struct MissionItem
{
    int no;
    MSP.Action action;
    double lat;
    double lon;
    uint alt;
    int param1;
    int param2;
    int param3;
}

public class Mission : GLib.Object
{
    private MissionItem[] waypoints;
    public string? version;
    public double maxy;
    public double miny;
    public double maxx;
    public double minx;
    public double cy;
    public double cx;
    public uint npoints;
    public uint zoom;
    public double nspeed;
    public double dist;
    public int et;
    public int lt;

    public Mission()
    {
        waypoints ={};
        version = null;
        npoints=0;
        maxy=-90;
        maxx=-180;
        miny=90;
        minx=180;
        cx = cy = 0;
        zoom = -1;
    }

    public MissionItem[] get_ways()
    {
        return waypoints;
    }


    public MissionItem get_waypoint(uint n)
    {
        if(n < waypoints.length)
            return waypoints[n];
        else
            return {-1};
    }

    public void set_ways(MissionItem[] m)
    {
        waypoints = m;
    }

    public void dump()
    {
        if(version != null)
            stdout.printf("Version: %s\n",version);
        foreach (MissionItem m in this.waypoints)
        {
            stdout.printf ("%d %s %f %f %u %d %d %d\n",
                           m.no,
                           MSP.get_wpname(m.action),
                           m.lat, m.lon, m.alt,
                           m.param1, m.param2, m.param3);
        }
        stdout.printf("lat min,max %f %f\n", minx, maxx);
        stdout.printf("lon min,max %f %f\n", miny, maxy);
        stdout.printf("cy cx %f %f %d\n", cy, cx, (int)zoom);
    }
    public bool read_xml_file(string path)
    {
       Parser.init ();

       Xml.Doc* doc = Parser.parse_file (path);
        if (doc == null)
        {
            stderr.printf ("File %s not found or permissions missing\n", path);
            return false;
        }

        Xml.Node* root = doc->get_root_element ();
        if (root != null)
        {
            if (root->name.down() == "mission")
            {
                parse_node (root);
            }
        }
        if(npoints != 0)
        {
            if (zoom == -1)
            {
                zoom = 12;
                cy = (maxy + miny) / 2.0;
                cx = (maxx + minx) / 2.0;
            }
        }
        delete doc;
        Parser.cleanup();
        return true;
    }

    private void parse_node (Xml.Node* node)
    {
        for (Xml.Node* iter = node->children; iter != null; iter = iter->next)
        {
            if (iter->type != ElementType.ELEMENT_NODE)
            {
                continue;
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
                                m.no = int.parse(attr_content);
                                break;
                            case "action":
                                var act = attr_content;
                                m.action = MSP.lookup_name(act);
                                break;
                            case "lat":
                                m.lat = get_locale_double(attr_content);
                                break;
                            case "lon":
                                m.lon = get_locale_double(attr_content);
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
                            case "alt":
                                m.alt = int.parse(attr_content);
                                break;
                        }
                    }

                    if(m.action != MSP.Action.RTH && m.action != MSP.Action.JUMP)
                    {
                        if (m.lat > maxy)
                            maxy = m.lat;
                        if (m.lon > maxx)
                            maxx = m.lon;
                        if (m.lat <  miny)
                            miny = m.lat;
                        if (m.lon <  minx)
                            minx = m.lon;
                    }
                    waypoints  += m;
                    npoints += 1;
                    break;
                case "version":
                    for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next)
                    {
                        if (prop->name == "value")
                            this.version = prop->children->content;
                    }
                    break;
                case "mwp":
                    for (Xml.Attr* prop = iter->properties; prop != null; prop = prop->next)
                    {
                        switch(prop->name)
                        {
                            case "zoom":
                                this.zoom = (uint)int.parse(prop->children->content);
                                break;
                            case "cx":
                                this.cx = get_locale_double(prop->children->content);
                                break;
                            case "cy":
                                this.cy = get_locale_double(prop->children->content);
                                break;

                        }
                    }
                    break;
            }
        }
    }

    public void to_xml_file(string path)
    {
        Parser.init ();
        Xml.Doc* doc = new Xml.Doc ("1.0");

        Xml.Ns* ns = null;
            /*new Xml.Ns (null, "", "");
              ns->type = Xml.ElementType.ELEMENT_NODE;*/

        Xml.Node* root = new Xml.Node (ns, "MISSION");
        doc->set_root_element (root);

        Xml.Node* comment = new Xml.Node.comment ("mw planner 0.01");
        root->add_child (comment);

        Xml.Node* subnode;

        if (version != null)
        {
            subnode = root->new_text_child (ns, "VERSION", "");
            subnode->new_prop ("value", this.version);
        }

        subnode = root->new_text_child (ns, "mwp", "");
        subnode->new_prop ("zoom", zoom.to_string());
        subnode->new_prop ("cx", cx.to_string());
        subnode->new_prop ("cy", cy.to_string());

        if(et > 0)
        {
            Xml.Node* xsubnode;
            Xml.Node* ysubnode;
            xsubnode = subnode->new_text_child (ns, "details", "");

            ysubnode = xsubnode->new_text_child (ns, "distance", "");
            ysubnode->new_prop ("units", "m");
            ysubnode->new_prop ("value", dist.to_string());

            ysubnode = xsubnode->new_text_child (ns, "nav-speed", "");
            ysubnode->new_prop ("units", "m/s");
            ysubnode->new_prop ("value", nspeed.to_string());

            ysubnode = xsubnode->new_text_child (ns, "fly-time", "");
            ysubnode->new_prop ("units", "s");
            ysubnode->new_prop ("value", et.to_string());

            ysubnode = xsubnode->new_text_child (ns, "loiter-time", "");
            ysubnode->new_prop ("units", "s");
            ysubnode->new_prop ("value", lt.to_string());
        }

        foreach (MissionItem m in this.waypoints)
        {
            subnode = root->new_text_child (ns, "MISSIONITEM", "");
            subnode->new_prop ("no", m.no.to_string());
            subnode->new_prop ("action", MSP.get_wpname(m.action));
            subnode->new_prop ("lat", m.lat.to_string());
            subnode->new_prop ("lon", m.lon.to_string());
            subnode->new_prop ("alt", m.alt.to_string());
            subnode->new_prop ("parameter1", m.param1.to_string());
            subnode->new_prop ("parameter2", m.param2.to_string());
            subnode->new_prop ("parameter3", m.param3.to_string());
        }

/*
        string xmlstr;
        doc->dump_memory_enc_format (out xmlstr);
        var dos = FileStream.open(path, "w");
        if(dos != null)
        {
            dos.puts(xmlstr);
            dos.putc('\n');
        }
        else
            stderr.printf ("Error opening %s\n", path);
*/
        doc->save_format_file_enc(path);

        delete doc;
        Parser.cleanup ();
    }

    public bool calculate_distance(out double d, out int lt)
    {
        var n = 0;
        var rpt = 0;
        double lx = 0.0,ly=0.0;
        bool ready = false;
        d = 0.0;
        lt = 0;

        var nsize = waypoints.length;
        do
        {
            var typ = waypoints[n].action;

            if(typ == MSP.Action.JUMP && waypoints[n].param2 == -1)
            {
                d = 0.0;
                lt = 0;
                return false;
            }

            if (typ == MSP.Action.SET_POI)
            {
                n += 1;
                continue;
            }

            if (typ == MSP.Action.RTH)
            {
                break;
            }

            var cy = waypoints[n].lat;
            var cx = waypoints[n].lon;
            if (ready == true)
            {
                double dx,cse;
                Geo.csedist(ly,lx,cy,cx, out dx, out cse);
                if (typ == MSP.Action.POSHOLD_TIME)
                {
                    lt += waypoints[n].param1;
                }

                d += dx;
                if(typ == MSP.Action.JUMP)
                {
                    var r = waypoints[n].param1;
                    rpt += 1;
                    if (rpt > r)
                        n += 1;
                    else
                        n = waypoints[n].param2 - 1;
                }
                else if (typ == MSP.Action.POSHOLD_UNLIM || typ == MSP.Action.LAND)
                {
                    break;
                }
                else
                {
                    n += 1;
                }
            }
            else
	    {
                ready = true;
		n += 1;
            }
            lx = cx;
            ly = cy;
        } while (n < nsize);
        d *= 1852.0;
        return true;
    }
}


#if XMLTEST_MAIN
int main (string[] args) {

    if (args.length < 2) {
        stderr.printf ("Argument required!\n");
        return 1;
    }
    var ms = new Mission ();
    if (ms.read_xml_file (args[1]) == true)
    {
        ms.dump();
        double d;
        int lt;
        var res = ms.calculate_distance(out d, out lt);
        if (res == true)
        {
            var et = (int)(d / 3.0);
            print("dist %f %ds (%ds)\n",d,et,lt);
        }
        else
            print("Indeterminate\n");

        if (args.length == 3)
            ms.to_xml_file(args[2]);
    }
    return 0;
}
#endif
