namespace SQL {

	public struct TrackEntry {
		public int id;
		public int idx;
		public int stamp;
		double lat;
		double lon;
		int alt;
		int galt;
		double spd;
		double amps;
		double volts;
		double hlat;
		double hlon;
		double vrange;
		int cse;
		int cog;
		int bearing;
		int roll;
		int pitch;
		int hdop;
		int ail;
		int ele;
		int rud;
		int thr;
		int fix;
		int numsat;
		int fmode;
		int rssi;
		int status;
		int activewp;
		int navmode;
		int hwfail;
		int windx;
		int windy;
		int windz;
	}


	public class Db {
		Sqlite.Database db;

		public Db(string fn) {
			var rc = Sqlite.Database.open_v2 (fn, out db, Sqlite.OPEN_READONLY);
			if(rc != Sqlite.OK) {
				MWPLog.message ("Failed to open %s\n", fn);
			}
		}

		public string? get_errors(int idx) {
			Sqlite.Statement stmt;
			string? val = null;
			const string prepared_query_str = "SELECT * FROM logerrs WHERE id = $1;";
			var rc = db.prepare_v2 (prepared_query_str, prepared_query_str.length, out stmt);
			if (rc == Sqlite.OK) {
				stmt.bind_int (1, idx);
				while (stmt.step () == Sqlite.ROW) {
					val = stmt.column_text(1);
				}
			}
			return val;
		}

		public bool get_bounding_box(int idx, out MapUtils.BoundingBox bbox) {
			bool ok=false;
			bbox = {999.0, 999.0, -999.0, -999.0};
			Sqlite.Statement stmt;
			const string prepared_query_str = "SELECT min(lat),min(lon),max(lat),max(lon) FROM logs WHERE id = $1;";
			var rc = db.prepare_v2 (prepared_query_str, prepared_query_str.length, out stmt);
			if (rc == Sqlite.OK) {
				stmt.bind_int (1, idx);
				while (stmt.step () == Sqlite.ROW) {
					bbox.minlat = stmt.column_double(0);
					bbox.minlon = stmt.column_double(1);
					bbox.maxlat = stmt.column_double(2);
					bbox.maxlon = stmt.column_double(3);
				}
				ok = true;
			}
			return ok;
		}

		public int get_log_count(int idx) {
			Sqlite.Statement stmt;
			int nr = 0;
			const string prepared_query_str = "SELECT count(id) FROM logs WHERE id = $1;";
			var rc = db.prepare_v2 (prepared_query_str, prepared_query_str.length, out stmt);
			if (rc == Sqlite.OK) {
				stmt.bind_int (1, idx);
				while (stmt.step () == Sqlite.ROW) {
					nr = stmt.column_int(0);
				}
			}
			return nr;
		}

		public bool get_log_entry(int idx, int nidx, out TrackEntry t) {
			bool ok=false;
			t = {};
			Sqlite.Statement stmt;
			const string prepared_query_str = "SELECT id,idx,stamp,lat,lon,alt,galt,spd,amps,volts,hlat,hlon,vrange,cse,cog,bearing,roll,pitch,hdop,ail,ele,rud,thr,fix,numsat,fmode,rssi,status,activewp,navmode,hwfail,windx,windy,windz from logs WHERE id = $1 and idx=$2;";
			var rc = db.prepare_v2 (prepared_query_str, prepared_query_str.length, out stmt);
			if (rc == Sqlite.OK) {
				stmt.bind_int (1, idx);
				stmt.bind_int (2, nidx);
				while (stmt.step () == Sqlite.ROW) {
					t.id = stmt.column_int(0);
					t.idx = stmt.column_int(1);
					t.stamp = stmt.column_int(2);
					t.lat = stmt.column_double(3);
					t.lon = stmt.column_double(4);
					t.alt = stmt.column_int(5);
					t.galt = stmt.column_int(6);
					t.spd =  stmt.column_double(7);
					t.amps = stmt.column_double(8);
					t.volts = stmt.column_double(9);
					t.hlat = stmt.column_double(10);
					t.hlon = stmt.column_double(11);
					t.vrange =  stmt.column_double(12);
					t.cse = stmt.column_int(13);
					t.cog = stmt.column_int(14);
					t.bearing = stmt.column_int(15);
					t.roll = stmt.column_int(16);
					t.pitch = stmt.column_int(17);
					t.hdop = stmt.column_int(18);
					t.ail = stmt.column_int(19);
					t.ele = stmt.column_int(20);
					t.rud = stmt.column_int(21);
					t.thr = stmt.column_int(22);
					t.fix = stmt.column_int(23);
					t.numsat = stmt.column_int(24);
					t.fmode = stmt.column_int(25);
					t.rssi  = stmt.column_int(26);
					t.status = stmt.column_int(27);
					t.activewp = stmt.column_int(28);
					t.navmode = stmt.column_int(29);
					t.hwfail = stmt.column_int(30);
					t.windx = stmt.column_int(31);
					t.windy = stmt.column_int(32);
					t.windz = stmt.column_int(33);
				}
				ok = true;
			}
			return ok;
		}
	}
}

#if TEST
static int main(string?[]args) {
	if (args.length > 2) {
		var d = new SQL.Db(args[1]);
		var idx = int.parse(args[2]);
		var s = d.get_errors(idx);
		print("Idx %d, errs %s\n", idx, s);

		MapUtils.BoundingBox b;
		d.get_bounding_box(idx, out b);
		print("%f %f %f %f\n", 	b.minlat, b.minlon, b.maxlat, b.maxlon);
		var nr = d.get_log_count(idx);
		print("No log %d\n", nr);
		SQL.TrackEntry t;
		int last = 0;
		for(var j = 0; j < nr; j++) {
			var res = d.get_log_entry(idx, j, out t);
			if (res) {
				var et = t.stamp - last;
				print("%4d %8d %f %f %d\n", t.idx, t.stamp, t.lat, t.lon, et);
				last = t.stamp;
			}
		}
	}
	return 0;
}
#endif
