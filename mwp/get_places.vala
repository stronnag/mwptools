public class Places :  GLib.Object
{
    public struct PosItem
    {
        string name;
        double lat;
        double lon;
        int zoom;
    }
/*
    public struct TerrainDefs
    {
        int margin;
        int rthalt;
        int sanity;
    }
*/
    private enum PFmt
    {
        CSV,
        JSON
    }

    private static PFmt pfmt;
    private static PosItem[]pls = {};
    private const string DELIMS="\t|;:,";

    private static void parse_delim(string fn)
    {
        var file = File.new_for_path(fn);
        try {
            var dis = new DataInputStream(file.read());
            string line;
            while ((line = dis.read_line (null)) != null)
            {
                if(line.strip().length > 0 &&
                   !line.has_prefix("#") &&
                   !line.has_prefix(";"))
                {
                    var parts = line.split_set("\t|;:,");
                    if(parts.length > 2)
                    {
                        var p = PosItem();
                        p.lat = double.parse(parts[1]);
                        p.lon = double.parse(parts[2]);
                        p.name = parts[0];
                        if(parts.length > 3)
                            p.zoom = int.parse(parts[3]);
                        else
                            p.zoom = -1;
                        pls += p;
                    }
                }
            }
        } catch (Error e) {
            error ("%s", e.message);
        }
    }

    private static void parse_json(string fn)
    {
        try {
            var parser = new Json.Parser ();
            parser.load_from_file (fn);
            var root_object = parser.get_root ().get_object ();
            foreach (var node in
                     root_object.get_array_member ("places").get_elements ())
            {
                var p = PosItem();
                var item = node.get_object ();
                p.name = item.get_string_member("name");
                p.lat = item.get_double_member("lat");
                p.lon = item.get_double_member("lon");
                if (item.has_member("zoom"))
                p.zoom = (int)item.get_int_member("zoom");
                else
                    p.zoom = -1;
                pls += p;
            }
        } catch (Error e) {
            error ("%s", e.message);
        }
    }

    public static PosItem[] get_places(double dlat,double dlon)
    {
        string? fn;
        pfmt = PFmt.CSV;
        pls +=  PosItem(){name="Default", lat=dlat, lon=dlon};
        if((fn = MWPUtils.find_conf_file("places")) != null)
        {
            parse_delim(fn);
        }
        else if ((fn = MWPUtils.find_conf_file("places.json")) != null)
        {
            pfmt = PFmt.JSON;
            parse_json(fn);
        }
        return pls;
    }
/*
    private static TerrainDefs parse_terrain_defs(File file)
    {
        TerrainDefs td = {0,0};
        try {
            var dis = new DataInputStream(file.read());
            string line;
            while ((line = dis.read_line (null)) != null)
            {
                if(line.strip().length > 0 &&
                   !line.has_prefix("#") &&
                   !line.has_prefix(";"))
                {
                    var parts = line.split("=");
                    if(parts.length == 2)
                    {
                        var p0 = parts[0].strip();
                        var p1 = parts[1].strip();
                        var iv = InputParser.get_scaled_int(p1);

                        switch (p0)
                        {
                            case "margin":
                                td.margin = (int)iv;
                                break;
                            case "sanity":
                                td.sanity = (int)iv;
                                break;
                            case "rth-alt":
                                td.rthalt = (int)iv;
                                break;
                        }
                    }
                }
            }
        } catch (Error e) {
            error ("%s", e.message);
        }
        return td;
    }

    public static TerrainDefs get_terrain_defs()
    {
        string []tfiles = {".config/mwp/elev-plot", ".elev-plot.rc"};
        var file = File.new_for_path(tfiles[1]);
        if (file.query_exists ())
        {
            var tf = parse_terrain_defs(file);
            return tf;
        } else {
            var hd = Environment.get_home_dir();
            foreach(var tn in tfiles) {
                string tnx = Path.build_filename(hd, tn);
                file = File.new_for_path(tnx);
                if (file.query_exists ())
                {
                    var tf = parse_terrain_defs(file);
                    return tf;
                }
            }
        }
        return TerrainDefs();// {margin = 0, sanity = 0, rthalt = 0};
    }
*/
}
