namespace GZMisc {

	const double RAD = 0.017453292;
	const double A = 6378137;
	const double F = 1.0 / 298.257224;

	AreaCalc.Vec to_ecef (double lat, double lon /*, double h*/) {
		double ESQ1 = (1-F)*(1-F);
		lat = lat * RAD;
		lon = lon * RAD;
		var c  = 1.0/(Math.sqrt( (Math.cos(lat)*Math.cos(lat)) + ESQ1*Math.sin(lat)*Math.sin(lat)));
		AreaCalc.Vec p={};
		p.x = ((A*c)*Math.cos(lat)*Math.cos(lon));
		p.y = ((A*c)*Math.cos(lat)*Math.sin(lon));
		return p;
	}

	private bool is_clockwise(AreaCalc.Vec []v) {
		double sum = 0;
		for (var i = 0; i < v.length; i++) {
			var v0 = v[i];
			var v1 = v[(i + 1) % v.length];
			sum += (v1.x - v0.x) * (v1.y + v0.y);
		}
		return sum > 0.0;
	}

	private bool is_complex(AreaCalc.Vec []v) {
		for (var i = 0; i < v.length; i++) {
			AreaCalc.Vec v0 = v[i];
			AreaCalc.Vec v1 = v[(i + 1) % v.length];
			for(var j = 0; j < v.length; j++) {
				if(j == i) {
					continue;
				}
				AreaCalc.Vec t0 = v[j];
				AreaCalc.Vec t1 = v[(j + 1) % v.length];
				if (AreaCalc.linesCross(v0, v1, t0, t1) != null) {
					return true;
				}
			}
		}
		return false;
	}

	public uint8 validate_polygon(AreaCalc.Vec []v) {
		uint8 res = 0;
		if (is_clockwise(v)) {
			res |= 1;
		}
		if (is_complex(v)) {
			res |= 2;
		}
		return res;
	}
}
