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
 */


public class ADSBReader :Object {
	public signal void result(uint8[]? d);
	private SocketConnection conn;
	private string host;
	private uint16 port;
	private Soup.Session session;

	public ADSBReader(string pn, uint16 _port=30003) {
		var p = pn[6:pn.length].split(":");
		port = _port;
		host = "localhost";
		if (p.length > 1) {
			port = (uint16)int.parse(p[1]);
		}
		if (p.length > 0) {
			if(p[0].length > 0)
				host = p[0];
		}
	}

	public ADSBReader.web(string pn) {
		session = new Soup.Session ();
		host = pn;
	}

	private async bool fetch() {
		var msg = new Soup.Message ("GET", host);
		try {
			var byt = yield session.send_and_read_async (msg, Priority.DEFAULT, null);
			if (msg.status_code == 200) {
				result(byt.get_data());
				return true;
			} else {
				MWPLog.message("ADSB fetch: %u %s\n", msg.status_code, msg.reason_phrase);
				result(null);
				return false;
			}
		} catch (Error e) {
			MWPLog.message("ADSB fetch: %s\n", e.message);
			result(null);
			return false;
		}
	}

	public void poll(uint timeout=1000) {
		Timeout.add(timeout, () => {
				fetch.begin((obj, res) => {
						var ok = fetch.end(res);
						if(ok) {
							poll(timeout);
						}
					});
				return false;
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
				var line = yield inp.read_line_async();
				if (line == null) {
					result(null);
					return false;
				} else {
					result(line.data);
				}
			} catch (Error e) {
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
				var ok = yield inp.read_all_async(sz, Priority.DEFAULT, null, out nb);
				if(ok && nb == 4) {
					uint32 msize;
					SEDE.deserialise_u32(sz, out msize);
					uint8[]pbuf = new uint8[msize];
					try {
						ok = yield inp.read_all_async(pbuf, Priority.DEFAULT, null, out nb);
						if (ok && nb == msize) {
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
