/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * (c) Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace SQL {
	public struct Meta {
		int id;
		string dtg;
		double duration;
		string name;
		string firmware;
		string fwdate;
		int sensors;
		int features;
		uint8 disarm;
	}

	public struct TrackEntry {
		public int64 stamp;
		double lat;
		double lon;
		double spd;
		double amps;
		double volts;
		double hlat;
		double hlon;
		double vrange;
		public int id;
		public int idx;
		int alt;
		int galt;
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
		int energy;
	}

	public class Db {
		Sqlite.Database db;
		Sqlite.Statement bbstmt;
		Sqlite.Statement mtstmt;
		Sqlite.Statement flstmt;
		Sqlite.Statement logstmt;

		const string bbquery = "SELECT min(lat),min(lon),max(lat),max(lon) FROM logs WHERE id = $1;";
		const string mtquery = "SELECT * from meta WHERE id = $1;";
		const string flquery = "SELECT id,idx,stamp,lat,lon,alt,galt,spd,amps,volts,hlat,hlon,vrange,cse,cog,bearing,roll,pitch,hdop,ail,ele,rud,thr,fix,numsat,fmode,rssi,status,activewp,navmode,hwfail,windx,windy,windz,energy from logs WHERE id = $1 and idx=$2;";
		const string logquery = "SELECT id,idx,stamp,lat,lon,alt,galt,spd,amps,volts,hlat,hlon,vrange,cse,cog,bearing,roll,pitch,hdop,ail,ele,rud,thr,fix,numsat,fmode,rssi,status,activewp,navmode,hwfail,windx,windy,windz,energy from logs WHERE id = $1;";

		public Db(string fn) {
			var rc = Sqlite.Database.open_v2 (fn, out db, Sqlite.OPEN_READONLY);
			if(rc != Sqlite.OK) {
				MWPLog.message ("Failed to open %s\n", fn);
			}
			rc = db.prepare_v2 (bbquery, bbquery.length, out bbstmt);
			if (rc != Sqlite.OK) {
				MWPLog.message ("Failed to prepare bbstmt %s\n", fn);
			}
			rc = db.prepare_v2 (mtquery, mtquery.length, out mtstmt);
			if (rc != Sqlite.OK) {
				MWPLog.message ("Failed to prepare mtstmt %s\n", fn);
			}
			rc = db.prepare_v2 (flquery, flquery.length, out flstmt);
			if (rc != Sqlite.OK) {
				MWPLog.message ("Failed to prepare flstmt %s\n", fn);
			}
			rc = db.prepare_v2 (logquery, logquery.length, out logstmt);
			if (rc != Sqlite.OK) {
				MWPLog.message ("Failed to prepare logstmt %s\n", fn);
			}
		}

		private void read_meta(Sqlite.Statement stmt, out Meta m) {
			m = {};
			var ns = stmt.column_count();
			for (int i = 0; i < ns; i++) {
				switch (stmt.column_name(i)) {
				case "id":
					m.id = stmt.column_int(i);
					break;
				case "dtg":
					m.dtg = stmt.column_text(i);
					break;
				case "duration":
					m.duration = stmt.column_double(i);
					break;
				case "mname":
					m.name = stmt.column_text(i);
					break;
				case "firmware":
					m.firmware = stmt.column_text(i);
					break;
				case "fwdate":
					m.fwdate = stmt.column_text(i);
					break;
				case "sensors":
					m.sensors = stmt.column_int(i);
					break;
				case "features":
					m.features = stmt.column_int(i);
					break;
				case "disarm":
					m.disarm = (uint8)stmt.column_int(i);
					break;
				}
			}
		}

		public bool get_meta(int idx, out Meta m) {
			int n = 0;
			m = {};
			mtstmt.reset();
			mtstmt.bind_int (1, idx);
			while (mtstmt.step () == Sqlite.ROW) {
				read_meta(mtstmt, out m);
				n++;
			}
			return (n==1);
		}

		public bool get_metas(out Meta[] ms) {
			int n = 0;
			Meta[]mms = {};
			Sqlite.Statement stmt;
			const string query = "SELECT * FROM meta;";
			db.prepare_v2 (query, query.length, out stmt);
			while (stmt.step () == Sqlite.ROW) {
                var m = Meta();
				read_meta(stmt, out m);
				if (m.duration > 10) {
					mms += m;
					n++;
				}
			}
			ms = mms;
			return (n>0);
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

		public string? get_misc(int idx, string type) {
			Sqlite.Statement stmt;
			string? val = null;
			const string str = "SELECT content FROM misc WHERE id = $1 and type = $2;";
			var rc = db.prepare_v2 (str, str.length, out stmt);
			if (rc == Sqlite.OK) {
				stmt.bind_int (1, idx);
				stmt.bind_text (2, type);
				while (stmt.step () == Sqlite.ROW) {
					val = stmt.column_text(0);
				}
			}
			return val;
		}

		public bool get_bounding_box(int idx, out MapUtils.BoundingBox bbox) {
			int n = 0;
			bbox = {999.0, 999.0, -999.0, -999.0};
			bbstmt.reset();
			bbstmt.bind_int (1, idx);
			while (bbstmt.step () == Sqlite.ROW) {
				bbox.minlat = bbstmt.column_double(0);
				bbox.minlon = bbstmt.column_double(1);
				bbox.maxlat = bbstmt.column_double(2);
				bbox.maxlon = bbstmt.column_double(3);
				n++;
			}
			return (n==1);
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

		public int get_log(int idx, ref TrackEntry[] tks) {
			logstmt.reset();
			logstmt.bind_int (1, idx);
			int n = 0;
			while (logstmt.step () == Sqlite.ROW) {
				tks[n].id = logstmt.column_int(0);
				tks[n].idx = logstmt.column_int(1);
				tks[n].stamp = logstmt.column_int64(2);
				tks[n].lat = logstmt.column_double(3);
				tks[n].lon = logstmt.column_double(4);
				tks[n].alt = logstmt.column_int(5);
				tks[n].galt = logstmt.column_int(6);
				tks[n].spd =  logstmt.column_double(7);
				tks[n].amps = logstmt.column_double(8);
				tks[n].volts = logstmt.column_double(9);
				tks[n].hlat = logstmt.column_double(10);
				tks[n].hlon = logstmt.column_double(11);
				tks[n].vrange =  logstmt.column_double(12);
				tks[n].cse = logstmt.column_int(13);
				tks[n].cog = logstmt.column_int(14);
				tks[n].bearing = logstmt.column_int(15);
				tks[n].roll = logstmt.column_int(16);
				tks[n].pitch = logstmt.column_int(17);
				tks[n].hdop = logstmt.column_int(18);
				tks[n].ail = logstmt.column_int(19);
				tks[n].ele = logstmt.column_int(20);
				tks[n].rud = logstmt.column_int(21);
				tks[n].thr = logstmt.column_int(22);
				tks[n].fix = logstmt.column_int(23);
				tks[n].numsat = logstmt.column_int(24);
				tks[n].fmode = logstmt.column_int(25);
				tks[n].rssi  = logstmt.column_int(26);
				tks[n].status = logstmt.column_int(27);
				tks[n].activewp = logstmt.column_int(28);
				tks[n].navmode = logstmt.column_int(29);
				tks[n].hwfail = logstmt.column_int(30);
				tks[n].windx = logstmt.column_int(31);
				tks[n].windy = logstmt.column_int(32);
				tks[n].windz = logstmt.column_int(33);
				tks[n].energy = logstmt.column_int(34);
				n++;
			}
			return n;
		}


		public bool get_log_entry(int idx, int nidx, out TrackEntry t) {
			t = {};
			int n = 0;
			flstmt.reset();
			flstmt.bind_int (1, idx);
			flstmt.bind_int (2, nidx);
			while (flstmt.step () == Sqlite.ROW) {
				n++;
				t.id = flstmt.column_int(0);
				t.idx = flstmt.column_int(1);
				t.stamp = flstmt.column_int64(2);
				t.lat = flstmt.column_double(3);
				t.lon = flstmt.column_double(4);
				t.alt = flstmt.column_int(5);
				t.galt = flstmt.column_int(6);
				t.spd =  flstmt.column_double(7);
				t.amps = flstmt.column_double(8);
				t.volts = flstmt.column_double(9);
				t.hlat = flstmt.column_double(10);
				t.hlon = flstmt.column_double(11);
				t.vrange =  flstmt.column_double(12);
				t.cse = flstmt.column_int(13);
				t.cog = flstmt.column_int(14);
				t.bearing = flstmt.column_int(15);
				t.roll = flstmt.column_int(16);
				t.pitch = flstmt.column_int(17);
				t.hdop = flstmt.column_int(18);
				t.ail = flstmt.column_int(19);
				t.ele = flstmt.column_int(20);
				t.rud = flstmt.column_int(21);
				t.thr = flstmt.column_int(22);
				t.fix = flstmt.column_int(23);
				t.numsat = flstmt.column_int(24);
				t.fmode = flstmt.column_int(25);
				t.rssi  = flstmt.column_int(26);
				t.status = flstmt.column_int(27);
				t.activewp = flstmt.column_int(28);
				t.navmode = flstmt.column_int(29);
				t.hwfail = flstmt.column_int(30);
				t.windx = flstmt.column_int(31);
				t.windy = flstmt.column_int(32);
				t.windz = flstmt.column_int(33);
				t.energy = flstmt.column_int(34);
			}
			return (n==1);
		}

		private string get_max_with_time(string v, int i) {
			// can you say "SQL Injection"
			return "select %s, stamp from logs where (id=%d and %s = (select max(%s) from logs where id=%d)) limit 1;".printf(v,i,v,v,i);
		}

		public bool populate_odo(int idx) {
			string cmd;
			cmd = "select max(stamp) from logs where id=%d;".printf(idx);
			var rc = db.exec(cmd, (nc, values, cn) => {
					if (values[0] != null) {
						Odo.stats.time = uint.parse(values[0])/(1000*1000);
						return 0;
					}
					return -1;
				}, null);

			if (rc == Sqlite.OK) {
				cmd = get_max_with_time("vrange", idx);
				db.exec(cmd, (nc, values, cn) => {
						if(nc > 1) {
							Odo.stats.range = double.parse(values[0]);
							Odo.stats.rng_secs = uint.parse(values[1])/(1000*1000);
						}
						return 0;
					}, null);
				cmd = get_max_with_time("alt", idx);
				db.exec(cmd, (nc, values, cn) => {
						if(nc > 1) {
							Odo.stats.alt = double.parse(values[0]);
							Odo.stats.alt_secs = int.parse(values[1])/(1000*1000);
						}
						return 0;
					}, null);
				cmd = get_max_with_time("spd", idx);
				db.exec(cmd, (nc, values, cn) => {
						if(nc > 1) {
							Odo.stats.speed = double.parse(values[0]);
							Odo.stats.spd_secs = int.parse(values[1])/(1000*1000);
						}
						return 0;
					}, null);
				cmd = "select max(tdist) from logs where id=%d;".printf(idx);
				db.exec(cmd, (nc, values, cn) => {
						if(nc > 0 && values[0] != null) {
							Odo.stats.distance = double.parse(values[0]);
						}
						return 0;
					}, null);

				cmd = "select max(amps) from logs where id=%d;".printf(idx);
				db.exec(cmd, (nc, values, cn) => {
						if(nc > 0) {
							Odo.stats.amps = (uint16)(double.parse(values[0])*100);
						}
						return 0;
					}, null);
				return true;
			} else {
				return false;
			}
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
		if (d.get_bounding_box(idx, out b)) {
			print("%f %f %f %f\n", 	b.minlat, b.minlon, b.maxlat, b.maxlon);
		}
		var nr = d.get_log_count(idx);
		print("No log %d\n", nr);
		SQL.TrackEntry t;
		int64 last = 0;
		for(var j = 0; j < nr; j++) {
			var res = d.get_log_entry(idx, j, out t);
			if (res) {
				var et = t.stamp - last;
				print("%4d %8jd %f %f %d\n", t.idx, t.stamp, t.lat, t.lon, et);
				last = t.stamp;
			}
		}

		SQL.Meta []ms;
		var res = d.get_metas(out ms);
		if(res) {
			foreach (var m in ms) {
				print("id=%d dur=%f dtg=%s name=%s fw=%s\n", m.id, m.duration, m.dtg, m.name, m.firmware);
			}
		}

		Odo.stats={};
		d.populate_odo(idx);
		if (Odo.stats.range > 0) {
			print("Odo rng %f %u\n", Odo.stats.range, Odo.stats.rng_secs);
			print("Odo alt %f %u\n", Odo.stats.alt, Odo.stats.alt_secs);
			print("Odo spd %f %u\n", Odo.stats.speed, Odo.stats.spd_secs);
			print("Odo time %u, tdist %.1f, centiamps %u\n", Odo.stats.time, Odo.stats.distance, Odo.stats.amps);
		}
		var mfn = d.get_misc(idx, "mission");
		print("Get mission %s\n", mfn);
		d=null;
	}

	return 0;
}
#endif
