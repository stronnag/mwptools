namespace SQL {

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
			return true;
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
	}
	return 0;
}
#endif
