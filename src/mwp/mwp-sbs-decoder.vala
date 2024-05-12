
public class ADSBReader :Object {
	public signal void result(uint8[]? d);
	private SocketConnection conn;
	private string host;
	private uint16 port;
	private Soup.Session session;
#if SBSTHREADS
	private Thread<int> thr;
#endif

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
#if !COLDSOUP
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
#else
		try {
            var resp = yield session.send_async(msg);
			if( msg.status_code == 200) {
				var mlen = msg.response_headers.get_content_length ();
				if (mlen == 0)
					mlen = (1<<20) - 1;
				var data = new uint8[mlen+1];
				yield resp.read_all_async(data, GLib.Priority.DEFAULT, null, null);
				result(data);
				return true;
			} else {
				MWPLog.message("ADSB fetch: %u\n", msg.status_code);
				result(null);
				return false;
			}
		} catch (Error e) {
			MWPLog.message("ADSB fetch: %s\n", e.message);
			result(null);
			return false;
		}
#endif
	}

	public void poll(uint timeout=1) {
		Timeout.add(timeout, () => {
				fetch.begin((obj, res) => {
						var ok = fetch.end(res);
						if(ok) {
							poll(1000);
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
#if SBSTHREADS
		MWPLog.message("start %s %u async threaded reader\n", host, port);
		thr = new Thread<int> ("sbs", () => {
				var inp = new DataInputStream(conn.input_stream);
				for(;;) {
					try {
						var line = inp.read_line();
						if (line == null) {
							result(null);
							break;
						} else {
							result(line.data);
						}
					} catch (Error e) {
						result(null);
						break;
					}
				}
				thr.join();
				return 0;
			});
		return true;
#else
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
#endif
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
#if SBSTHREADS
		MWPLog.message("start %s %u threader packet reader\n", host, port);
		thr = new Thread<int> ("pba", () => {
				var inp = conn.input_stream;
				for(;;) {
					uint8 sz[4];
					try {
						size_t nb = 0;
						var ok = inp.read_all(sz, out nb, null);
						if (ok) {
							uint32 msize;
							SEDE.deserialise_u32(sz, out msize);
							uint8[]pbuf = new uint8[msize];
							try {
								ok = inp.read_all(pbuf, out nb, null);
								if (ok && nb == msize) {
									result(pbuf);
								} else {
									MWPLog.message("PB read data %d %d\n", (int)msize, (int)nb);
									result(null);
									break;
								}
							} catch (Error e) {
								result(null);
								break;
							}
						} else {
							MWPLog.message("PB read size %d\n", (int)nb);
							result(null);
							break;
						}
					} catch (Error e) {
						result(null);
						break;
					}
				}
				thr.join();
				return 0;
			});
		return true;
#else
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
#endif
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
