namespace TxtIO {
	public Mission?[] read_txt(string fn) {
		Mission[] msx = {};
		MissionItem [] mi = {};
		Mission? ms = null;

        FileStream fs = FileStream.open (fn, "r");
		if(fs == null) {
            return {};
        }
		string line;
		int no = 1;
		while ((line = fs.read_line ()) != null) {
			if(line.has_prefix("wp ")) {
				var parts = line.split(" ");
				if (parts.length == 10) {
					var iact = int.parse(parts[2]);
					if (iact > 0) {
						var ilat = int.parse(parts[3]);
						var ilon = int.parse(parts[4]);
						var ialt = int.parse(parts[5]);
						var p1 = int.parse(parts[6]);
						var p2 = int.parse(parts[7]);
						var p3 = int.parse(parts[8]);
						var flg = int.parse(parts[9]);
						if (iact == 6) {
							p1++; // mission no, not index
						}
						MissionItem m = new MissionItem();
						m.no = no;
						no += 1;
						m.action = (Msp.Action)iact;
						m.lat = (double)ilat / 1e7;
						m.lon = (double)ilon / 1e7;
						m.alt = ialt / 100;
						m.param1 = p1;
						m.param2 = p2;
						m.param3 = p3;
						m.flag = (uint8)flg;
						mi += m;
						if (m.flag == 0xa5) {
							ms = new Mission();
							no = 1;
							ms.points = mi;
							ms.update_meta();
							msx += ms;
							ms = null;
							mi = {};
						}
					}
				}
			} else if (line.has_prefix("fwapproach ")) {
				var parts = line.split(" ");
				if (parts.length == 8) {
					var idx = int.parse(parts[1]);
					if (idx > 7 && idx < FWAPPROACH.maxapproach) {
						FWApproach.approach l={};
						l.appalt = double.parse(parts[2]) /100.0;
						l.landalt = double.parse(parts[3]) /100.0;
						l.dref = (parts[4] == "1") ? true : false;
						l.dirn1 = (int16)int.parse(parts[5]);
						if(l.dirn1 < 0) {
							l.dirn1 = -l.dirn1;
							l.ex1 = true;
						}
						l.dirn2 = (int16)int.parse(parts[6]);
						if(l.dirn2 < 0) {
							l.dirn2 = -l.dirn2;
							l.ex2 = true;
						}
						l.aref = (parts[7] == "1") ? true : false;
						FWApproach.set(idx, l);
					}
				}
			} else if(line.has_prefix("set ")) {
				int val;
				if (line.contains("nav_fw_land_approach_length")) {
					if (Cli.get_set_val(line, out val)) {
						FWPlot.nav_fw_land_approach_length = val/100;
					}
				} else if (line.contains("nav_fw_loiter_radius")) {
					if (Cli.get_set_val(line, out val)) {
						FWPlot.nav_fw_loiter_radius = val/100;
					}
				}
			}
		}
		return msx;
	}
}

namespace Cli {
	bool get_set_val(string s, out int val) {
		val=0;
		var n = s.index_of("=");
		if (n != -1) {
			n++;
			if (s[n] == ' ')
				n++;
			val = int.parse(s[n:s.length]);
			return true;
		} else {
			return false;
		}
	}
}
