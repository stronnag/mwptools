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
