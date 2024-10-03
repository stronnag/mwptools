namespace Survey {
  private const string DELIMS="\t|;:,";
  private const string kmlp1="""<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://earth.google.com/kml/2.1"><Document><name>Area Polygon</name><Style id="transPoly"><LineStyle><width>4</width><color>a0c5c5c5</color></LineStyle><PolyStyle><color>33000000</color></PolyStyle></Style><Placemark><name>Area Polygon</name><styleUrl>#transPoly</styleUrl><Polygon><extrude>1</extrude><altitudeMode>relativeToGround</altitudeMode><outerBoundaryIs><LinearRing><coordinates>""";
  private const string kmlp2="""
</coordinates></LinearRing></outerBoundaryIs></Polygon></Placemark></Document></kml>""";

  private AreaCalc.Vec[] parse_file(string fn) {
    AreaCalc.Vec[] pls = {};
    var file = File.new_for_path(fn);
    try {
      var dis = new DataInputStream(file.read());
      string line;
      while ((line = dis.read_line (null)) != null) {
	if(line.strip().length > 0 &&
	   !line.has_prefix("#") &&
	   !line.has_prefix(";")) {
	  var parts = line.split_set(DELIMS);
	  if(parts.length > 1) {
	    AreaCalc.Vec p = {};
	    p.y = double.parse(parts[0]);
	    p.x = double.parse(parts[1]);
	    pls += p;
	  }
	}
      }
    } catch (Error e) {
      print ("%s\n", e.message);
    }
    return pls;
  }

  public void write_file(string fn, AreaCalc.Vec[] pts) {
    var os = FileStream.open(fn, "w");
    os.puts("# mwp area file\n");
    os.puts("# Valid delimiters are |;:, and <TAB>.\n");
    os.puts("# Note \",\" is not recommended for reasons of localisation.\n");
    os.puts("#\n");
    foreach(var p in pts) {
      os.printf("%f\t%f\n", p.y, p.x);
    }
  }

  public void write_kml(string fn, int alt, AreaCalc.Vec[] pts) {
    var os = FileStream.open(fn, "w");
    os.puts(kmlp1);
    foreach(var p in pts) {
      os.printf("%f,%f,%d ", p.x, p.y, alt);
    }
    os.puts(kmlp2);
  }
}