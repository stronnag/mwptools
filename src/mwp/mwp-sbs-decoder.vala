public class JSACReader : Object {
	public signal void result(string? d);
	private SocketConnection conn;
	private string host;
	private uint16 port;
	private const uint JSACCOND=IOCondition.IN|IOCondition.HUP|IOCondition.ERR|IOCondition.NVAL;

	public JSACReader(string pn) {
		var p = pn[6:pn.length].split(":");
		port = 37007;
		host = "localhost";
		if (p.length > 1) {
			port = (uint16)int.parse(p[1]);
		}
		if (p.length > 0) {
			if(p[0].length > 0)
				host = p[0];
		}
	}

	public async bool read_jsa()  throws Error {
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
		var fd = conn.socket.fd;
		var io_read = new IOChannel.unix_new(fd);
		if(io_read.set_encoding(null) != IOStatus.NORMAL)
			error("Failed to set encoding");
		io_read.add_watch(JSACCOND, (chan, cond) => {
				string buf;
				size_t length = -1;
				if (cond == IOCondition.HUP) {
					result(null);
					return false;
				}
				try {
					IOStatus status = chan.read_line(out buf, out length, null);
					if (status == IOStatus.EOF) {
						result(null);
						return false;
					}
					result(buf);
					return true;
				} catch (IOChannelError e) {
					return false;
				} catch (ConvertError e) {
					return false;
				}
			});
		return true;
	}
}

public class SbsReader :Object {
	public signal void result(string? d);
	private SocketConnection conn;
	private string host;
	private uint16 port;

	public SbsReader(string pn) {
		var p = pn[6:pn.length].split(":");
		port = 30003;
		host = "localhost";
		if (p.length > 1) {
			port = (uint16)int.parse(p[1]);
		}
		if (p.length > 0) {
			if(p[0].length > 0)
				host = p[0];
		}
	}

	public async bool read_sbs()  throws Error {
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
		var fd = conn.socket.fd;
		var io_read = new IOChannel.unix_new(fd);
		if(io_read.set_encoding(null) != IOStatus.NORMAL)
			error("Failed to set encoding");
		io_read.add_watch(IOCondition.IN|IOCondition.HUP|IOCondition.ERR|IOCondition.NVAL,
						  (chan, cond) => {
				string str = null;
				size_t length = -1;
				size_t pos = 0;
				if (cond == IOCondition.HUP) {
					result(null);
					return false;
				}
				try {
					IOStatus status = chan.read_line (out str, out length, out pos);
					if (status == IOStatus.EOF) {
						result(null);
						return false;
					}
					result(str);
					return true;
				} catch (IOChannelError e) {
					return false;
				} catch (ConvertError e) {
					return false;
				}
			});
		return true;
	}

	public string[]? parse_message(string s) {
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
