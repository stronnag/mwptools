namespace GZMisc {
	struct Vec {
		double x;
		double y;
		double z;
	}

	const double RAD = 0.017453292;
	const double A = 6378137;
	const double F = 1.0 / 298.257224;

	Vec to_ecef (double lat, double lon, double h) {
		double ESQ1 = (1-F)*(1-F);
		lat = lat * RAD;
		lon = lon * RAD;
		var c  = 1.0/(Math.sqrt( (Math.cos(lat)*Math.cos(lat)) + ESQ1*Math.sin(lat)*Math.sin(lat)));
		var s = ESQ1 * c;
		Vec p={};
		p.x = (A*c+h)*Math.cos(lat)*Math.cos(lon);
		p.y = (A*c+h)*Math.cos(lat)*Math.sin(lon);
		p.z = (A*s+h)*Math.sin(lat);
		return p;
	}

	private bool is_convex(Vec[] v, out double d0) {// Rory Daulton
		int _base = 0;
		var  n =  v.length;
		double TWO_PI = 2 * Math.PI;
		// points is 'strictly convex': points are valid, side lengths non-zero, interior angles are strictly between zero and a straight
		// angle, and the polygon does not intersect itself.
		// NOTES:  1.  Algorithm: the signed changes of the direction angles from one side to the next side must be all positive or
		// all negative, and their sum must equal plus-or-minus one full turn (2 pi radians). Also check for too few,
		// invalid, or repeated points.
		//      2.  No check is explicitly done for zero internal angles(180 degree direction-change angle) as this is covered
		// in other ways, including the `n < 3` check.
		// needed for any bad points or direction changes
		// Check for too few points
		if (v[_base].x == v[n-1].x && v[_base].y == v[n-1].y) // if its a closed polygon, ignore last vertex
		n--;
  // Get starting information
		var old_x = v[n-2].x;
		var old_y = v[n-2].y;
		var new_x = v[n-1].x;
		var new_y = v[n-1].y;
		double new_direction = Math.atan2(new_y - old_y, new_x - old_x);
		d0 = new_direction / RAD;
		if (n <= 3) {
			return true;
		}
		double old_direction;
		double angle_sum = 0.0;
		double orientation =0.0;
  // Check each point (the side ending there, its angle) and accum. angles for ndx, newpoint in enumerate(polygon):
		for (int i = 0; i < n; i++) {
			// Update point coordinates and side directions, check side length
			old_x = new_x;
			old_y = new_y;
			old_direction = new_direction;
			int p = _base++;
			new_x = v[p].x;
			new_y = v[p].y;
			new_direction = Math.atan2(new_y - old_y, new_x - old_x);
			if (old_x == new_x && old_y == new_y)
				return false; // repeated consecutive points
			// Calculate & check the normalized direction-change angle
			double angle = new_direction - old_direction;
			if (angle <= -Math.PI) {
				angle += TWO_PI;  // make it in half-open interval (-Pi, Pi]
			} else if (angle > Math.PI) {
				angle -= TWO_PI;
			}
			if (i == 0) { // if first time through loop, initialize orientation
				if (angle == 0.0) {
					return false;
				}
				orientation = angle > 0 ? 1 : -1;
			} else  { // if other time through loop, check orientation is stable
				if (orientation * angle <= 0)  // not both pos. or both neg.
					return false;
			}
			// Accumulate the direction-change angle
			angle_sum += angle;
			// Check that the total number of full turns is plus-or-minus 1
		}
		return Math.fabs(Math.round(angle_sum / TWO_PI)) == 1;
	}
}
