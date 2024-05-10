
public class ADSBReader :Object {
	public signal void result(uint8[]? d);
	private SocketConnection conn;
	private string host;
	private uint16 port;
	private Thread<int> thr;
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
