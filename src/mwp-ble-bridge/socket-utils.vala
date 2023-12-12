public Socket? getUDPSocket(uint16 port) {
	return getSocket(SocketType.DATAGRAM, SocketProtocol.UDP, port);
}

public Socket? getTCPSocket(uint16 port) {
	return getSocket(SocketType.STREAM, SocketProtocol.TCP, port);
}

public Socket? getSocket(SocketType type, SocketProtocol protocol, uint16 port) {
	try {
		var sockaddr = new InetSocketAddress (new InetAddress.any(SocketFamily.IPV6), port);
		var fam = sockaddr.get_family();
		var socket = new Socket (fam, type, protocol);
		socket.bind(sockaddr, (protocol ==  SocketProtocol.TCP));
		return socket;
	} catch (Error e) {
		stderr.printf ("%s\n",e.message);
		return null;
	}
}

public uint16 get_random_port(Socket s) {
	try {
		var las = s.get_local_address();
		return ((InetSocketAddress)las).get_port();
	} catch {
		return 0;
	}
}
