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
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

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
