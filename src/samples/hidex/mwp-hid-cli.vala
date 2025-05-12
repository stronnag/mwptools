
public Socket? setup_ip(string host, uint16 port) {
	try {
		var resolver = Resolver.get_default ();
		var addresses = resolver.lookup_by_name (host, null);
		var address = addresses.nth_data (0);
		var sockaddr = new InetSocketAddress (address, port);
		var socket = new Socket (sockaddr.get_family(), SocketType.DATAGRAM, SocketProtocol.UDP);
		socket.connect(sockaddr);
		return socket;
	} catch(Error e) {
		stderr.printf("err: %s\n", e.message);
		return null;
	}
}

int main(string? []args) {
	var host = "localhost";
	if (args.length > 1) {
		host = args[1];
	}
	var socket = setup_ip(host, 31025);
	if(socket != null) {
		string? ln;
		uint8 buf[256];
		while ((ln = Readline.readline("> ")) != null) {
			Readline.History.add (ln);
			try {
				socket.send(ln.data);
				var sz = socket.receive(buf, null);
				if(sz > -1) {
					string rep;
					if(buf[0] == 0) {
						rep = "ok";
					} else {
						buf[sz] = 0;
						rep = (string)buf[:sz];
					}
					print("%s\n", rep);
					if(ln == "quit") {
						break;
					}
				}
			} catch (Error e) {
				stderr.printf("UDP: %s\n", e.message);
				break;
			}
		}
	}
	return 0;
}
