public class LogRebase : Object {
	static double nlat = -99999;
	static double nlon = -99999;
	static string olddb;
	static bool verbose;
	static string aidx;
	Sqlite.Database db;

	private int[] process_aidx() {
		string? a = aidx;
		int[] res = {};
		bool b = false;

		while(!b) {
			int k;
			unowned string rem;
			b = int.try_parse(a, out k, out rem);
			res += k;
			if (rem[0] == ',') {
				a = rem.substring(1);
			} else if (rem[0] == '-') {
				a = rem.substring(1);
				int j;
				b = int.try_parse(a, out j, out rem);
				for(int i = k+1; i <= j; i++) {
					res += i;
				}
				if (!b)
					a = rem.substring(1);
			} else {
				break;
			}
		}
		return res;
	}

	public LogRebase(string dbname) {
		var src = File.new_for_path (olddb);
		var dst = File.new_for_path (dbname);

		try {
			src.copy (dst, FileCopyFlags.OVERWRITE, null, null);
		} catch (Error e) {
			print ("Error: %s\n", e.message);
		}

		var rc = Sqlite.Database.open_v2 (dbname, out db);
		if(rc != Sqlite.OK) {
			print ("Failed to open %s\n", dbname);
		}
	}

	private void run() {
		if (db != null) {
			double hlat=0, hlon=0;
			int imin=1,imax=1;
			int []indices={};

			if(aidx == null || aidx == "all") {
				db.exec("select min(id),max(id) from meta", (n_columns, values, column_names) => {
						if (n_columns == 2) {
							imin = int.parse(values[0]);
							imax = int.parse(values[1]);
						}
						return 0;
					}, null);

				for(int i = imin; i <=imax; i++) {
					indices += i;
				}
			} else {
				indices = process_aidx();
			}

			foreach (var idx in indices) {
				var str = "select hlat,hlon from logs where id=%d limit 1".printf(idx);
				db.exec(str, (n_columns, values, column_names) => {
						if (n_columns == 2) {
							hlat = double.parse(values[0]);
							hlon = double.parse(values[1]);
							str = "update logs set hlat=%f, hlon=%f where id=%d".printf(nlat, nlon, idx);
							db.exec("BEGIN");
							db.exec(str, null);
							update_pos(idx, hlat, hlon, nlat, nlon);
							db.exec("COMMIT");
						}
						return 0;
					}, null);
			}
		}
	}

	private void update_pos(int idx, double olat, double olon, double nlat, double nlon) {
		var rebase = new Rebase();
		rebase.set_origin(olat, olon);
		rebase.set_reloc(nlat, nlon);

		var str = "select idx,lat,lon from logs where id=$1";
		Sqlite.Statement stmt;
		var rc = db.prepare_v2 (str, str.length, out stmt);
		if (rc == Sqlite.OK) {
			stmt.bind_int (1, idx);
			int cols = stmt.column_count ();
			if (cols == 3) {
				while (stmt.step () == Sqlite.ROW) {
					var iidx = stmt.column_int(0);
					var lat = stmt.column_double(1);
					var lon = stmt.column_double(2);
					rebase.relocate(ref lat, ref lon);
					str = "update logs set lat=%f,lon=%f where id=%d and idx=%d".printf(lat, lon, idx, iidx);
					rc = db.exec(str);
					if (rc != 0) {
						print("update fails %d\n", rc);
					}
				}
			}
		}
	}

	static int main (string[] args) {
		const OptionEntry[] options = {
			{"old-db", 'd', 0, OptionArg.FILENAME, out olddb, "Extant databse", "DATABASE"},
			{"lat", 0, 0, OptionArg.DOUBLE, out nlat, "Base latitude", "LAT"},
			{"lon", 0, 0, OptionArg.DOUBLE, out nlon, "Base longitude", "LON"},
			{"id", 'i', 0, OptionArg.STRING, out aidx, "Log index", "ID (default all)"},
			{"verbose", 0, 0, OptionArg.NONE, ref verbose, "verbose", null},
			{null}
		};

		string dbfile = null;

		try {
            var opt = new OptionContext(" newdb");
            opt.set_help_enabled(true);
            opt.add_main_entries(options, null);
			opt.parse(ref args);
		} catch (Error e) {
            stderr.printf("Error: %s\n", e.message);
            stderr.printf("Run '%s --help' to see a full list of available options\n", args[0]);
            return 1;
		}

		dbfile = args[1];
		if (nlat == -99999 || nlon == -99999 || dbfile == null || olddb == null) {
            stderr.printf("Missing arguments\nRun '%s --help' to see a full list of available options\n", args[0]);
			return 1;
		}

		print("%s %f %f %s\n", dbfile, nlat, nlon, olddb);
		var l = new LogRebase(dbfile);
		l.run();
		return 0;
	}
}
