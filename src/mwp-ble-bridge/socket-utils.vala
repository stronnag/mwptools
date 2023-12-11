public Socket? getUDPSocket() {
	return getSocket(SocketType.DATAGRAM, SocketProtocol.UDP);
}

public Socket? getTCPSocket() {
	return getSocket(SocketType.STREAM, SocketProtocol.TCP);
}

public Socket? getSocket(SocketType type, SocketProtocol protocol) {
	try {
		var sockaddr = new InetSocketAddress (new InetAddress.any(SocketFamily.IPV6), 0);
		var fam = sockaddr.get_family();
		var socket = new Socket (fam, type, protocol);
		socket.bind(sockaddr, true);
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
