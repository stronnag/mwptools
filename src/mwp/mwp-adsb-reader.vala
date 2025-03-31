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


public class ADSBReader :Object {
	public signal void result(uint8[]? d);
	private SocketConnection conn;
	private string host;
	private uint16 port;
	private Soup.Session session;
	private uint range;
	private uint interval;
	private uint nreq;
	private string format;
	private string keyid;
	private string keyval;
	public  string suffix;
	private int id;
	private Cancellable can;
	private int ecount;

	static int instance = 0;

	public ADSBReader() {
		id = instance;
		instance++;
		interval = 1000;
		ecount = 0;
		can = new Cancellable();
	}

	public void cancel()  {
		can.cancel();
	}

	public ADSBReader.net(UriParser.UriParts u, uint16 _port=30003) {
		this();
		nreq = 0;
		host = "localhost";
		port = _port;
		var h = u.host;
		var p = u.port;
		if (p != -1) {
			port = (uint16)p;
		}
		if (h != null && h != "") {
			host = h;
		}
	}

	public ADSBReader.web(string pn) {
		this();
		session = new Soup.Session ();
		host = pn;
	}

	public ADSBReader.adsbx(UriParser.UriParts u) {
		this();
		format="v2/point/%s/%s/%s";
		session = new Soup.Session ();
		var h = u.host;
		host = "https://%s".printf(h);
		if (u.qhash != null) {
			string? v;
			v = u.qhash.get("range");
			if (v != null) {
				range = uint.parse(v);
				if (range > 250) {
					range = 250;
				}
			}
			v = u.qhash.get("interval");
			if (v != null) {
				interval = uint.parse(v);
				if(interval < 1000) {
					interval = 1000;
				}
			}
			v = u.qhash.get("format");
			if (v != null) {
				format = v.replace("{}", "%s");
			}

			v = u.qhash.get("api-key");
			if (v != null) {
				var kp = v.split(":", 2);
				if(kp.length == 2) {
					keyid = kp[0];
					keyval = kp[1];
				}
			}
		}
	}

	private void log_data(uint8[]data) {
		if(Mwp.rawlog && suffix != null) {
			FileStream fs;
			string fn;
			string mode;
			var logdir = UserDirs.get_default();
			if (suffix == ".txt") {
				fn  = "adsb_%03d.txt".printf(id);
				mode = "a";
			} else {
				var dt =  new DateTime.now_local ();
				var ms = dt.get_microsecond()/1000;
				fn  = "adsb_%03d_%jd.%03d.%s".printf(id, dt.to_unix(), ms, suffix);
				mode = "wb";
			}
			var lfn = Path.build_filename(logdir, fn);
			if(mode == "a") {
				fs = FileStream.open(lfn, mode);
				fs.write(data, data.length);
				fs.flush();
			} else {
				try {
					FileUtils.set_data(lfn, data);
				} catch {}
			}
		}
	}

	private async bool fetch() {
		Soup.Message msg;
		string ahost;
		Radar.set_astatus();
		if (range == 0) {
			ahost = host;
		} else {
			// .format to force '.' in ',' locales
			char[] labuf = new char[double.DTOSTR_BUF_SIZE];
			char[] lobuf = new char[double.DTOSTR_BUF_SIZE];
			StringBuilder sb = new StringBuilder(host);
			sb.append_c('/');
			sb.append_printf(format, Radar.lat.format(labuf, "%f"), Radar.lon.format(lobuf, "%f"), range.to_string());
			ahost = sb.str;
		}
		msg = new Soup.Message ("GET", ahost);
		if(keyid != null && keyval != null) {
			msg.request_headers.append(keyid, keyval);
		}

		try {
			nreq++;
			var byt = yield session.send_and_read_async (msg, Priority.DEFAULT, can);
			if (msg.status_code == 200) {
				var data =  byt.get_data();
				log_data(data);
				result(data);
				ecount = 0;
				return true;
			} else {
				if(ecount == 0) {
					MWPLog.message("ADSB fetch <%s> : %u %s (%u)\n", ahost, msg.status_code, msg.reason_phrase, nreq);
				}
				ecount++;
				result(null);
				return false;
			}
		} catch (Error e) {
			if (can.is_cancelled()) {
				can.reset();
			}
			if(ecount == 0) {
				MWPLog.message("ADSB fetch <%s> : %s\n", ahost, e.message);
			}
			ecount++;
			result(null);
			return false;
		}
	}

	public void poll(uint t=1000) {
		if (interval == 0) {
			interval = t;
		}
		fetch.begin((obj, res) => {
				var ok = fetch.end(res);
				if(ok) {
					Timeout.add(interval, () => {
							poll(t);
							return false;
						});
				}
			});
	}

	public async bool line_reader()  throws Error {
		try {
			var resolver = Resolver.get_default ();
			var addresses = yield resolver.lookup_by_name_async (host, null);
			var address = addresses.nth_data (0);
			var  client = new SocketClient ();
			conn = yield client.connect_async (new InetSocketAddress (address, port));
		} catch (Error e) {
			result(null);
			return false;
		}
		MWPLog.message("start %s %u async line reader\n", host, port);
		var inp = new DataInputStream(conn.input_stream);
		for(;;) {
			try {
				var line = yield inp.read_line_async(Priority.DEFAULT, can);
				if (line == null) {
					result(null);
					return false;
				} else {
					Radar.set_astatus();
					log_data(line.data);
					result(line.data);
				}
			} catch (Error e) {
				if (e.matches(Quark.from_string("g-io-error-quark"), IOError.CANCELLED)) {
					can.reset();
				}
				result(null);
				return false;
			}
		}
	}

	public async bool packet_reader()  throws Error {
		try {
			var resolver = Resolver.get_default ();
			var addresses = yield resolver.lookup_by_name_async (host, null);
			var address = addresses.nth_data (0);
			var  client = new SocketClient ();
			conn = yield client.connect_async (new InetSocketAddress (address, port));
		} catch (Error e) {
			result(null);
			return false;
		}
		MWPLog.message("start %s %u async packet reader\n", host, port);
		var inp = conn.input_stream;
		for(;;) {
			uint8 sz[4];
			try {
				size_t nb = 0;
				var ok = yield inp.read_all_async(sz, Priority.DEFAULT, can, out nb);
				if(ok && nb == 4) {
					uint32 msize;
					SEDE.deserialise_u32(sz, out msize);
					uint8[]pbuf = new uint8[msize];
					try {
						ok = yield inp.read_all_async(pbuf, Priority.DEFAULT, can, out nb);
						if (ok && nb == msize) {
							Radar.set_astatus();
							log_data(pbuf);
							result(pbuf);
						} else {
							MWPLog.message("PB read %d %d\n", (int)msize, (int)nb);
							result(null);
							return false;
						}
					} catch (Error e) {
						result(null);
						return false;
					}
				} else {
					result(null);
					return false;
				}
			} catch (Error e) {
				if (e.matches(Quark.from_string("g-io-error-quark"), IOError.CANCELLED)) {
					can.reset();
				}
				result(null);
				return false;
			}
		}
	}

	public string[]? parse_csv_message(string s) {
		var p = s.split(",");
		if (p.length > 8) {
			switch(p[0]) {
			case "MSG":
				var p1 = int.parse(p[1]);
				if(p1 < 6) {
					return p;
				}
				break;
			case "STA":
				break;
			}
		}
		return null;
	}
}
