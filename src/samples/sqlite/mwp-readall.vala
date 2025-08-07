public class LogRebase : Object {
	static bool verbose;
	static int idx = 1;
	Sqlite.Database db;

	public LogRebase() {

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

	private void run(string dbfile) {
		var rc = Sqlite.Database.open_v2 (dbname, out db);
		if(rc != Sqlite.OK) {
			print ("Failed to open %s\n", dbname);
		}
		if (db != null) {
			var nr = get_log_count(idx);



			Sqlite.Statement stmt;
			double hlat=0, hlon=0;
			var str = "select hlat,hlon from logs where id=$1 limit 1";
			var rc = db.prepare_v2 (str, str.length, out stmt);
			if (rc == Sqlite.OK) {
				stmt.bind_int (1, idx);
				int cols = stmt.column_count ();
				if (cols == 2) {
					while (stmt.step () == Sqlite.ROW) {
						hlat = stmt.column_double(0);
						hlon = stmt.column_double(1);
					}
					str = "update logs set hlat=%f, hlon=%f where id=%d".printf(nlat, nlon, idx);
					rc = db.exec(str, null);
					update_pos(hlat, hlon, nlat, nlon);
				}
			}
		}
	}

	static int main (string[] args) {
		const OptionEntry[] options = {
			{"id", 'i', 0, OptionArg.INT, out idx, "Log index", "ID (default 1)"},
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
		var l = new LogRebase();
		l.run(dbfile);
		return 0;
	}
}
