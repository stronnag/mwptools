public class ModelMap :  GLib.Object {
    private struct MTMap {
        string name;
        int mtype;
    }

    private MTMap [] tmap = {};
    private const string DELIMS="\t|;:,";

    private void parse_delim(string fn) {
        var file = File.new_for_path(fn);
        try {
            var dis = new DataInputStream(file.read());
            string line;
            while ((line = dis.read_line (null)) != null) {
                if(line.strip().length > 0 && !line.has_prefix("#") && !line.has_prefix(";")) {
                    var parts = line.split_set("\t|;:,");
                    if(parts.length > 1) {
                        var m = MTMap();
                        m.mtype = int.parse(parts[1]);
                        m.name = parts[0];
                        tmap += m;
                    }
                }
            }
        } catch (Error e) {
            error ("%s", e.message);
        }
    }

    public void init() {
        string? fn;
        if((fn = MWPUtils.find_conf_file("modelmap.txt")) != null) {
            parse_delim(fn);
        }
    }

    public int get_model_type(string name) {
        int mtyp = 0;
        foreach(var m in tmap) {
            if (m.name == name) {
                mtyp = m.mtype;
                break;
            }
        }
        return mtyp;
    }
}

/*************
public int main(string?[]args) {
    var p = new ModelMap();
    var pl = p.get_places();
    foreach(var l in pl) {
        print ("Key %s = %f %f\n",l.name, l.lat, l.lon);
    }
    return 0;
}
*****************/
