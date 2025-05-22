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
