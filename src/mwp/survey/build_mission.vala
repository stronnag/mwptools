namespace Survey {
	void build_mission(AreaCalc.RowPoints []rows, int alt, int lspeed, bool rth) {
		int n = 0;
		var ms = new Mission();
		MissionItem []mis={};
		foreach (var r in rows){
			n++;
			var mi =  new MissionItem.full(n, Msp.Action.WAYPOINT, r.start.y,
										   r.start.x, alt, lspeed, 0, 0, 0);
			mis += mi;
			n++;
			mi =  new MissionItem.full(n, Msp.Action.WAYPOINT, r.end.y,
									   r.end.x, alt, lspeed, 0, 0, 0);
			mis += mi;
		}
		if(rth) {
			n++;
			var mi =  new MissionItem.full(n, Msp.Action.RTH, 0, 0, 0, 0, 0, 0, 0);
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