namespace MultiM {
	public MSP_WP[] missonx_to_wps(Mission[]mx, int id=-1) {
		MSP_WP[] wps = {};
		var j = 0;
		var k = 1;
		foreach(var ms in mx) {
			if (id == -1 || id == j) {
				var ml = 0;
				foreach(var m in ms.get_ways()) {
					var w = MSP_WP();
					w.wp_no = k;
					w.action = (uint8)m.action;
					w.lat  = (int)(m.lat*1e7);
					w.lon  = (int)(m.lon*1e7);
					w.altitude = (int)(m.alt*100);
					w.p1 = (int16)m.param1;
					w.p2 = (int16)m.param2;
					w.p3 = (int16)m.param3;
					ml++;
					if (ml == ms.npoints) {
						w.flag = 0xa5;
					} else {
						w.flag = m.flag;
					}
					wps += w;
					k++;
				}
			}
			j++;
		}
		return wps;
	}

	public Mission[] wps_to_missonx(MSP_WP[] wps) {
		Mission[] mx = {};
		Mission? ms = null;
		MissionItem[] mi={};
		uint8 wp_no = 1;

		foreach(var w in wps) {
			if (ms == null)
				ms = new Mission();

			var m = MissionItem();
			m.no= wp_no;
			m.action = (MSP.Action)w.action;
			m.lat = w.lat/10000000.0;
			m.lon = w.lon/10000000.0;
			m.alt = w.altitude/100;
			m.param1 = w.p1;
			m.param2 = w.p2;
			m.param3 = w.p3;
			m.flag = w.flag;
			if(m.action != MSP.Action.RTH && m.action != MSP.Action.JUMP
			   && m.action != MSP.Action.SET_HEAD) {
				if (m.lat > ms.maxy)
					ms.maxy = m.lat;
				if (m.lon > ms.maxx)
						ms.maxx = m.lon;
				if (m.lat <  ms.miny)
					ms.miny = m.lat;
				if (m.lon <  ms.minx)
					ms.minx = m.lon;
				if (m.alt >  ms.maxalt)
					ms.maxalt = m.alt;
			}
			mi += m;
			if (m.flag == 0xa5) {
				ms.update_meta(mi);
				mx += ms;
				ms = null;
				wp_no = 1;
				mi={};
			} else {
				wp_no++;
			}
		}
		if (ms != null) { // legacy, no flags
			ms.npoints = mi.length;
			if (ms.npoints > 0) {
				ms.update_meta(mi);
			}
			mx += ms;
		}
		return mx;
	}
}

#if WPSMAINTEST
int main(string[] ? args) {
	if (args.length < 2) {
        stderr.printf ("Argument required!\n");
        return 1;
    }
	int id = -1;
	if(args.length > 2) {
		id = int.parse(args[2]);
	}

    var  msx = XmlIO.read_xml_file (args[1]);
	var wps = MultiM.missonx_to_wps(msx, id);
	foreach(var w in wps) {
		stderr.printf("%d %d %d %x\n", w.wp_no, w.lat, w.lon, w.flag);
	}

	stderr.printf("\n");
	msx = MultiM.wps_to_missonx(wps);
	foreach (var ms in msx) {
		ms.dump(120);
	}
	return 0;
}
#endif
