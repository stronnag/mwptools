namespace AreaCalc {
	public struct Vec {
		double x;
		double y;
	}

	private struct XVec {
		double frac;
		Vec point;
	}

	public struct RowPoints {
		Vec start;
		Vec end;
	}

	private const double MLAT=111120; // 1 deg lat = 60NM, 1NM=1852m
	private const double DEG2RAD = (Math.PI / 180);

	private Vec perp(Vec vec) {
		return Vec(){x=-vec.y, y=vec.x};
	}

	private Vec negate(Vec vec) {
		return Vec(){x=-vec.x, y=-vec.y};
	}

	private double dot(Vec v0, Vec v1) {
		return v0.x * v1.x + v0.y * v1.y;
	}

	private bool areVecsEqual(Vec v0, Vec v1) {
		return v0.x == v1.x && v0.y == v1.y;
	}

	private Vec add(Vec a, Vec b) {
		return Vec(){x = a.x + b.x, y= a.y + b.y};
	}

	private Vec sub(Vec a, Vec b) {
		return Vec(){x = a.x - b.x, y= a.y - b.y};
	}

	private Vec scale (Vec vec, double s) {
		return Vec(){ x = vec.x * s, y = vec.y * s };
	}

	private double dist(Vec a, Vec b) {
		var dx = a.x - b.x;
		var dy = a.y - b.y;
		return Math.sqrt( dx*dx + dy*dy );
	}

	private XVec? linesCross(Vec v0, Vec v1, Vec t0, Vec t1) {
		if ( areVecsEqual(v1,t0) ||
			 areVecsEqual(v0,t0) ||
			 areVecsEqual(v1,t1) ||
			 areVecsEqual(v0,t1) )
			return null;

		var vnormal = sub(v1, v0);
		vnormal = perp(vnormal);
		var v0d = dot(vnormal, v0);
		var t0d = dot(vnormal, t0);
		var t1d = dot(vnormal, t1);

		if ( t0d > v0d && t1d > v0d )
			return null;
		if ( t0d < v0d && t1d < v0d )
			return null;

		var tnormal = sub(t1, t0);
		tnormal = perp(tnormal);
		t0d = dot(tnormal, t0);
		v0d = dot(tnormal, v0);
		var v1d = dot(tnormal, v1);
		if ( v0d > t0d && v1d > t0d )
			return null;
		if ( v0d < t0d && v1d < t0d )
			return null;

		var fullvec = sub(v1,v0);
		var frac = (t0d-v0d)/(v1d-v0d);

		return XVec() {frac=frac, point=add(v0, scale(fullvec,frac)) };
	}

	public RowPoints[] generateFlightPath(Vec[] points, double angle, uint8 turn, double separation) {
		// get vector parallel to rows
		var rad = angle * DEG2RAD;
		Vec parallelVec = Vec() { x = Math.sin(rad), y = Math.cos(rad) };

		// get vector perpendicular to strips
		var perpVec = perp(parallelVec);
		if ( turn == 1 )
			perpVec = negate(perpVec);

		//find extents in parallel and perp directions
		double minParallel=0, maxParallel=0, minPerp=0, maxPerp=0;
		uint minParallelInd=0, maxParallelInd=0, minPerpInd=0, maxPerpInd=0;
		for (var i = 0; i < points.length; i++) {
			var pt = points[i];
			var parallelDot = dot(pt,parallelVec);
			var perpDot = dot(pt,perpVec);
			if ( i == 0 ) {
				minParallel = maxParallel = parallelDot;
				minPerp = maxPerp = perpDot;
				minParallelInd = maxParallelInd = 0;
				minPerpInd = maxPerpInd = 0;
			} else {
				if (parallelDot < minParallel) {
					minParallel = parallelDot;
					minParallelInd = i;
				}
				if (parallelDot > maxParallel) {
					maxParallel = parallelDot;
					maxParallelInd = i;
				}
				if (perpDot < minPerp) {
					minPerp = perpDot;
					minPerpInd = i;
				}
				if (perpDot > maxPerp) {
					maxPerp = perpDot;
					maxPerpInd = i;
				}
			}
		}

		double metersPerLat = MLAT;
		double alat = (maxParallel + minParallel )/2;
		double metersPerLng = 111120.0 * Math.cos(alat* DEG2RAD);

		// get row separation in lat/lng dimension (along perpVec)
		var quadrantAngle = angle;
		if (quadrantAngle > 180) {
			quadrantAngle = 360 - quadrantAngle;
		}
		if (quadrantAngle > 90) {
			quadrantAngle = 180 - quadrantAngle;
		}
		var lngToLatRatio = quadrantAngle / 90;
		var latLngSeparationPerDegree = metersPerLng + lngToLatRatio * (metersPerLat - metersPerLng);
		var latLngSeparation = separation / latLngSeparationPerDegree;

		// find corners of oriented bounding box
		var parallelMinPoint = points[minParallelInd];
		var parallelMaxPoint = points[maxParallelInd];
		var perpMinPoint = points[minPerpInd];
		var perpMaxPoint = points[maxPerpInd];

		var parallelMinExtended1 = add(parallelMinPoint, scale(perpVec,-10000));
		var parallelMinExtended2 = add(parallelMinPoint, scale(perpVec, 10000));
		var parallelMaxExtended1 = add(parallelMaxPoint, scale(perpVec,-10000));
		var parallelMaxExtended2 = add(parallelMaxPoint, scale(perpVec, 10000));

		var perpMinExtended1 = add(perpMinPoint, scale(parallelVec,-10000));
		var perpMinExtended2 = add(perpMinPoint, scale(parallelVec, 10000));
		var perpMaxExtended1 = add(perpMaxPoint, scale(parallelVec,-10000));
		var perpMaxExtended2 = add(perpMaxPoint, scale(parallelVec, 10000));

		parallelMinExtended1 = add(parallelMinExtended1, scale(parallelVec, -0.0001));
		parallelMinExtended2 = add(parallelMinExtended2, scale(parallelVec, -0.0001));
		parallelMaxExtended1 = add(parallelMaxExtended1, scale(parallelVec,  0.0001));
		parallelMaxExtended2 = add(parallelMaxExtended2, scale(parallelVec,  0.0001));

		perpMinExtended1 = add(perpMinExtended1, scale(perpVec,  latLngSeparation*0.5));
		perpMinExtended2 = add(perpMinExtended2, scale(perpVec,  latLngSeparation*0.5));

		var lxlyInt = linesCross(parallelMinExtended1, parallelMinExtended2, perpMinExtended1, perpMinExtended2);
		var uxlyInt = linesCross(parallelMinExtended1, parallelMinExtended2, perpMaxExtended1, perpMaxExtended2);
		var lxuyInt = linesCross(parallelMaxExtended1, parallelMaxExtended2, perpMinExtended1, perpMinExtended2);

		var lxly = lxlyInt.point;
		var uxly = uxlyInt.point;
		var lxuy = lxuyInt.point;

		var perpDist = dist(lxly,uxly);
		var rowsNeeded = Math.ceil( perpDist / latLngSeparation );

		RowPoints[] rowends = {};

		for (var i = 0; i < rowsNeeded; i++) {
			var start = add(lxly, scale(perpVec,i*latLngSeparation));
			var end = add(lxuy, scale(perpVec,i*latLngSeparation));
			rowends += RowPoints() {start = start, end = end};
		}

		for (var i = 0; i < rowends.length; i++) {
			var row = rowends[i];
			double closestDist = 99999999, furthestDist = -99999999;
			Vec closestHit={0}, furthestHit={0};

			for (var k = 0; k < points.length; k++) {
				var pt0 = points[k];
				var pt1 = points[(k+1)%points.length];
				var intersection = linesCross(row.start, row.end, pt0, pt1);
				if (intersection == null)
					continue;
				if (intersection.frac < closestDist ) {
					closestDist = intersection.frac;
					closestHit = intersection.point;
                }
				if (intersection.frac > furthestDist ) {
					furthestDist = intersection.frac;
					furthestHit = intersection.point;
				}
			}
			row.start = closestHit;
			row.end = furthestHit;
			if ( i%2 == 1 ) {
				// swap start and end for every second row
				var tmp = row.start.x;
				row.start.x = row.end.x;
				row.end.x = tmp;
				tmp = row.start.y;
				row.start.y = row.end.y;
				row.end.y = tmp;
			}
			rowends[i] =row;
		}
		return rowends;
	}
}
#if TEST
int main(string?[] args) {
    const Vec[] pts = {
        { -1.5348707085286151, 50.910896623759626  },
        { -1.5341680195342633, 50.910785335938584  },
        { -1.5335010516901093, 50.91056130177018 },
        { -1.5336998488237441, 50.910251948423792 },
        { -1.5341474079104955, 50.910230815349649 },
        { -1.5345665908989758, 50.909881861158311 },
        { -1.5354053210057828, 50.910074227940598 },
        { -1.5348707085286151, 50.910896623759626  }
	};

    AreaCalc.RowPoints[] r;
    r = AreaCalc.generateFlightPath((Vec[])pts, 0, 0, 20);
    uint i =0;
    print("<?xml version=\"1.0\" encoding=\"UTf-8\"?>\n<MISSION>\n <VERSION value=\"2.3 pre8\"></VERSION>\n");
    foreach(var p in r) {
        print("<MISSIONITEM no=\"%u\" action=\"WAYPOINT\" lat=\"%f\" lon=\"%f\" alt=\"18\" parameter1=\"0\" parameter2=\"0\" parameter3=\"0\"></MISSIONITEM>\n",
              ++i, p.start.y, p.start.x);
        print("<MISSIONITEM no=\"%u\" action=\"WAYPOINT\" lat=\"%f\" lon=\"%f\" alt=\"18\" parameter1=\"0\" parameter2=\"0\" parameter3=\"0\"></MISSIONITEM>\n",
              ++i, p.end.y, p.end.x);
    }
    print("</MISSION>\n");
    return 0;
}
#endif
