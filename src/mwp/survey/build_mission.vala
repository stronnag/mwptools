namespace Survey {

	int resolve_alt(double lat, double lon, int alt, bool amsl, out int elev) {
		int p3 = 0;
		elev = alt;
		if(amsl) {
			double e = Hgt.NODATA;
			e = DemManager.lookup(lat, lon);
			if (e != Hgt.NODATA) {
				p3 = 1;
				elev += (int)e;
			}
		}
		return p3;
	}

	void build_mission(AreaCalc.RowPoints []rows, int alt, int lspeed, bool rth, bool amsl) {
		int n = 0;
		int elev;
		int p3;
		var ms = new Mission();
		MissionItem []mis={};
		foreach (var r in rows){
			n++;

			p3 = resolve_alt(r.start.y, r.start.x, alt, amsl, out elev);
			var mi =  new MissionItem.full(n, Msp.Action.WAYPOINT, r.start.y,
										   r.start.x, elev, lspeed, 0, p3, 0);
			mis += mi;
			n++;
			p3 = resolve_alt(r.end.y, r.end.x, alt, amsl, out elev);
			mi =  new MissionItem.full(n, Msp.Action.WAYPOINT, r.end.y,
									   r.end.x, elev, lspeed, 0, p3, 0);
			mis += mi;
		}
		if(rth) {
			n++;
			var mi =  new MissionItem.full(n, Msp.Action.RTH, 0, 0, 0, 0, 0, 0, 0xa5);
			mis += mi;
		}
		mis[n-1].flag = 0xa5;
		ms.points = mis;
		ms.npoints = n;
		MissionManager.msx = {ms};
		MissionManager.is_dirty = true;
		MissionManager.mdx = 0;
		MissionManager.setup_mission_from_mm();
	}

	void build_square_mission(AreaCalc.Vec []vec, int alt, int lspeed, bool rth, bool amsl) {
		int n = 0;
		int elev;
		int p3;
		var ms = new Mission();
		MissionItem []mis={};
		foreach (var v in vec){
			n++;
			p3 = resolve_alt(v.y, v.x, alt, amsl, out elev);
			var mi =  new MissionItem.full(n, Msp.Action.WAYPOINT, v.y, v.x, elev, lspeed, 0, p3, 0);
			mis += mi;
		}
		if(rth) {
			n++;
			var mi =  new MissionItem.full(n, Msp.Action.RTH, 0, 0, 0, 0, 0, 0, 0xa5);
			mis += mi;
		}
		mis[n-1].flag = 0xa5;
		ms.points = mis;
		ms.npoints = n;
		MissionManager.msx = {ms};
		MissionManager.is_dirty = true;
		MissionManager.mdx = 0;
		MissionManager.setup_mission_from_mm();

	}

}