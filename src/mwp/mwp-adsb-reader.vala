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
	public signal void result(bool ok);
	private SocketConnection conn;
	private string host;
	private uint16 port;
	private Soup.Session session;
	private Soup.WebsocketConnection websocket;
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
	public Radar.DecType dtype;

	static int instance = 0;

	public ADSBReader() {
		id = instance;
		instance++;
		interval = 1000;
		ecount = 0;
		dtype = Radar.DecType.NONE;
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

	public ADSBReader.ws(string pn) {
		this();
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

	public void set_dtype(Radar.DecType d) {
		dtype = d;
		switch(dtype) {
		case Radar.DecType.SBS:
			suffix = "txt";
			break;
		case Radar.DecType.JSON:
		case Radar.DecType.JSONX:
		case Radar.DecType.PICOJS:
			suffix = "json";
			break;
		case Radar.DecType.PROTOB:
			suffix = "pb";
			break;
		default:
			break;
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

	private string make_string(uint8[]data) {
		var sz = data.length;
		uint8[] sdata = new uint8[sz+1];
		Memory.copy(sdata, data, sz);
		sdata[sz] = 0;
		return (string)sdata;
	}

	public async void ws_reader() {
		session = new Soup.Session ();
		session.idle_timeout = 5;
		session.timeout = 2;
		var msg = new Soup.Message("GET", host);
		uint tid = 0;
		try {
			MWPLog.message("start %s web socket reader\n", host);
			websocket =  yield session.websocket_connect_async(msg, "localhost", null, Priority.DEFAULT, can);
			websocket.message.connect((typ, message) => {
					if(tid != 0) {
						Source.remove(tid);
						tid = 0;
					}
					var s = (string)message.get_data();
					//					MWPLog.message("WS: %s\n", s);
					if (s.has_prefix("""{"aircraft":""")) {
						Radar.decode_pico(s);
					}
					tid = Timeout.add_seconds(2, () => {
							tid = 0;
							can.cancel();
							return false;
						});
				});
			websocket.error.connect((e) => {
					MWPLog.message("WS Error: %s\n", e.message);
				});
			websocket.closing.connect(() => {
					MWPLog.message("** WS Closing\n");
				});
			websocket.closed.connect(() => {
					MWPLog.message ("*** WS Closed\n");
					session.abort();
					result(false);
				});
		} catch (Error e) {
			MWPLog.message("WS Connecr: %s\n",e.message);
			if(websocket != null) {
				websocket.close(Soup.WebsocketCloseCode.NO_STATUS, null);
			}
			if (can.is_cancelled()) {
				can.reset();
			}
			result(false);
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
				var data = byt.get_data();
				var sz = byt.length;
				switch (dtype) {
				case Radar.DecType.PROTOB:
					Radar.decode_pba(data[:sz]);
					break;
				case Radar.DecType.PICOJS:
					var s = make_string(data);
					Radar.decode_pico(s);
					break;
				case Radar.DecType.JSON:
					var s = make_string(data);
					Radar.decode_jsa(s);
					break;
				case Radar.DecType.JSONX:
					var s = make_string(data);
					Radar.decode_jsa(s, true);
					break;
				default:
					MWPLog.message("::ERROR:: httpx reader %s\n", dtype.to_string());
					break;
				}
				log_data(data);
				result(true);
				ecount = 0;
				return true;
			} else {
				if(ecount == 0) {
					MWPLog.message("ADSB fetch <%s> : %u %s (%u)\n", ahost, msg.status_code, msg.reason_phrase, nreq);
				}
				ecount++;
				result(false);
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
			result(false);
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
			result(false);
			return false;
		}
		MWPLog.message("start %s %u async line reader\n", host, port);
		var inp = new DataInputStream(conn.input_stream);
		for(;;) {
			try {
				var line = yield inp.read_line_async(Priority.DEFAULT, can);
				if (line == null) {
					result(false);
					return false;
				} else {
					Radar.set_astatus();
					switch(dtype) {
					case Radar.DecType.JSON:
						Radar.decode_jsa((string)line.data);
						break;
					case Radar.DecType.SBS:
						var px = parse_csv_message((string)line);
						if (px != null) {
							Radar.decode_sbs(px);
						}
						break;
					default:
						MWPLog.message("::ERROR:: line reader %s\n", dtype.to_string());
						break;
					}
					log_data(line.data);
					result(true);
				}
			} catch (Error e) {
				if (can.is_cancelled()) {
					can.reset();
				}
				result(false);
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
			result(false);
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
							result(true);
						} else {
							MWPLog.message("PB read %d %d\n", (int)msize, (int)nb);
							result(false);
							return false;
						}
					} catch (Error e) {
						result(false);
						return false;
					}
				} else {
					result(false);
					return false;
				}
			} catch (Error e) {
				if (can.is_cancelled()) {
					can.reset();
				}
				result(false);
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
