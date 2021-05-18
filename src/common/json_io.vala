public class JsonIO : Object
{
    public static Mission? read_json_file(string fn)
    {
        try
        {
            string s;
            if(FileUtils.get_contents(fn, out s))
                return from_json(s);
        } catch {}

        return null;
    }
    public static Mission? from_json(string s)
    {
        Mission ms = null;
            try {
                ms = new Mission();
                var parser = new Json.Parser ();
                parser.load_from_data (s);

                Json.Node root = parser.get_root ();
                Json.Object obj = null;
                if(root!= null && !root.is_null())
                    obj = root.get_object ();
                if(obj != null)
                foreach (var name in obj.get_members ())
                {
                    switch (name)
                    {
                        case "mission":
                            MissionItem [] mi={};
                            foreach (var rsnode in
                                     obj.get_array_member ("mission").get_elements())
                            {
                                var rsitem = rsnode.get_object ();
                                var m = MissionItem();
                                m.no = (int) rsitem.get_int_member("no");
                                m.action =  MSP.lookup_name(rsitem.get_string_member("action"));
                                m.lat = rsitem.get_double_member("lat");
                                m.lon = rsitem.get_double_member("lon");
                                m.alt = (int) rsitem.get_int_member("alt");
                                if(m.alt > ms.maxalt)
                                    ms.maxalt = m.alt;
                                m.param1 = (int) rsitem.get_int_member("p1");
                                m.param2 = (int) rsitem.get_int_member("p2");
                                m.param3 = (int) rsitem.get_int_member("p3");
                                if(m.action != MSP.Action.RTH && m.action != MSP.Action.JUMP &&
                                   m.action != MSP.Action.SET_HEAD)
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
                            }
                            ms.set_ways(mi);
                            ms.npoints = mi.length;
                            break;
                        case "meta":
                        var msobj = obj.get_object_member("meta");
                        parse_meta(msobj, ref ms);
                        break;
                    }
                }

            } catch {}
        return ms;
    }

    private static void parse_meta(Json.Object o, ref Mission ms)
    {
        foreach (var name in o.get_members())
        {
            switch (name)
            {
                case "zoom":
                    ms.zoom = (int)o.get_int_member("zoom");
                    break;
                case "cx":
                    ms.cx = o.get_double_member("cx");
                    break;
                case "cy":
                    ms.cy = o.get_double_member("cy");
                    break;
                case "details":
                    var dobj = o.get_object_member("details");
                    parse_details(dobj, ref ms);
                    break;
            }
        }
    }

    private static void parse_details(Json.Object o, ref Mission ms)
    {
        Json.Object dobj;
        foreach (var name in o.get_members())
        {
            switch (name)
            {
                case "distance":
                    dobj = o.get_object_member("distance");
                    if(dobj.has_member("value"))
                        ms.dist = dobj.get_double_member("value");
                    break;
                case "nav-speed":
                    dobj = o.get_object_member("nav-speed");
                    if(dobj.has_member("value"))
                        ms.nspeed = dobj.get_double_member("value");
                    break;
                case "fly-time":
                    dobj = o.get_object_member("fly-time");
                    if(dobj.has_member("value"))
                        ms.et = (int)dobj.get_int_member("value");
                    break;
                case "loiter-time":
                dobj = o.get_object_member("loiter-time");
                if(dobj.has_member("value"))
                    ms.lt = (int)dobj.get_int_member("value");
                break;
            }
        }
    }

    public static string? to_json(Mission ms, bool indent=true)
    {
        var builder = new Json.Builder ();
        builder.begin_object ();
        builder.set_member_name ("meta");
        builder.begin_object ();
        builder.set_member_name ("save-date");
        time_t currtime;
        time_t(out currtime);
        builder.add_string_value(Time.local(currtime).format("%FT%T%z"));
        builder.set_member_name ("zoom");
        builder.add_int_value (ms.zoom);
        builder.set_member_name ("cx");
        builder.add_double_value (ms.cx);
        builder.set_member_name ("cy");
        builder.add_double_value (ms.cy);
        builder.set_member_name ("details");
        builder.begin_object ();

        builder.set_member_name ("distance");
        builder.begin_object (); //dx
        builder.set_member_name ("units");
        builder.add_string_value("m");
        builder.set_member_name ("value");
        builder.add_double_value (ms.dist);
        builder.end_object (); // dx

        builder.set_member_name ("nav-speed");
        builder.begin_object (); //dx
        builder.set_member_name ("units");
        builder.add_string_value("m/s");
        builder.set_member_name ("value");
        builder.add_double_value (ms.nspeed);
        builder.end_object (); // dx

        builder.set_member_name ("fly-time");
        builder.begin_object (); //dx
        builder.set_member_name ("units");
        builder.add_string_value("s");
        builder.set_member_name ("value");
        builder.add_int_value (ms.et);
        builder.end_object (); // dx

        builder.set_member_name ("loiter-time");
        builder.begin_object (); //dx
        builder.set_member_name ("units");
        builder.add_string_value("s");
        builder.set_member_name ("value");
        builder.add_int_value (ms.lt);
        builder.end_object (); // dx

        builder.end_object (); // details
        builder.set_member_name ("generator");
        builder.add_string_value ("mwp");
        builder.end_object (); // meta

        builder.set_member_name ("mission");
        builder.begin_array ();
        foreach (MissionItem m in ms.get_ways())
        {
            builder.begin_object (); //mi
            builder.set_member_name ("no");
            builder.add_int_value (m.no);
            builder.set_member_name ("action");
            builder.add_string_value(MSP.get_wpname(m.action));
            builder.set_member_name ("lat");
            builder.add_double_value( m.lat);
            builder.set_member_name ("lon");
            builder.add_double_value( m.lon);
            builder.set_member_name ("alt");
            builder.add_int_value( m.alt);
            builder.set_member_name ("p1");
            builder.add_int_value( m.param1);
            builder.set_member_name ("p2");
            builder.add_int_value( m.param2);
            builder.set_member_name ("p3");
            builder.add_int_value( m.param3);
            builder.end_object (); // mi
        }
        builder.end_array ();
        builder.end_object (); // root
        var generator = new Json.Generator ();
        if(indent)
        {
            generator.indent = 1;
            generator.indent_char = ' ';
        }
        generator.set_pretty(indent);
        var root = builder.get_root ();
        generator.set_root (root);
        return generator.to_data (null);
    }

    public static void to_json_file(string fn, Mission  ms)
    {
        var s = to_json(ms, false);
        try {
            FileUtils.set_contents(fn,s);
        } catch (Error e) {
            stderr.puts(e.message);
            stderr.putc('\n');
        }
    }
}

#if JSON_TEST_MAIN
int main (string[] args) {

    if (args.length < 2) {
        stderr.printf ("Argument required!\n");
        return 1;
    }

    Mission ms;
    if ((ms = JsonIO.read_json_file (args[1])) != null)
    {
        ms.dump();
        double d;
        int lt;
        var res = ms.calculate_distance(out d, out lt);
        if (res == true)
        {
            var et = (int)(d / 3.0);
            print("calc dist %.1f %ds (%ds)\n",d,et,lt);
        }
        else
            print("Indeterminate\n");

        if (args.length == 3)
            JsonIO.to_json_file(args[2], ms);
    }
    return 0;
}
#endif
