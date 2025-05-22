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

public class GattTest : Application {
	private string? addr;
	private BleSerial gs;
	private int rdfd;
	private int wrfd;
	private int pfd;
	private int mtu;
	private int delay;
	private bool verbose;
	private Bluez bt;
	private uint id;
	private uint8 bmode;
	private Socket skt;
	private SocketAddress raddr;
	private bool persist;
	private uint16 port;
	private uint ftag;
	private uint ptag;


	public GattTest () {
        Object (application_id: "org.mwptools.mwp-ble-bridge",
				flags: ApplicationFlags.HANDLES_COMMAND_LINE);
        Unix.signal_add (
            Posix.Signal.INT,
            on_sigint,
            Priority.DEFAULT
        );
		startup.connect (on_startup);
        shutdown.connect (on_shutdown);
		delay = 500;
		bmode = 'p';
		persist = false;
		port = 0;

		var options = new OptionEntry[] {
			{ "address", 'a', 0, OptionArg.STRING, null, "BT address", null},
			{ "settle", 's', 0, OptionArg.INT, null, "BT settle time (ms)", null},
			{ "port", 'p', 0, OptionArg.INT, null, "IP port", null},
			{ "keep-alive", 'k', 0, OptionArg.NONE, null, "keep alive", null},
			{ "tcp", 't', 0, OptionArg.NONE, null, "TCP server (vice pseudo-terminal)", null},
			{ "udp", 'u', 0, OptionArg.NONE, null, "UDP server (vice pseudo-terminal)", null},
			{ "verbose", 'V', 0, OptionArg.NONE, null, "be verbose", null},
            { "version", 'v', 0, OptionArg.NONE, null, "show version", null},
			{null}
		};
		set_option_context_parameter_string(" - BLE serial bridge");
		set_option_context_description(" requires a BT address or $MWP_BLE to be set");
		add_main_option_entries(options);
		handle_local_options.connect(do_handle_local_options);
	}

	public override int command_line (ApplicationCommandLine command_line) {
		string[] args = command_line.get_arguments ();
		var o = command_line.get_options_dict();

		int itmp = 0;
		o.lookup("port", "i", ref itmp);
		port = (uint16)itmp;
		o.lookup("address", "s", ref addr);
		o.lookup("settle", "i", ref delay);
		o.lookup("verbose", "b", ref verbose);
		o.lookup("keep-alive", "b", ref persist);

		if(o.contains("tcp")) {
			bmode = 't';
		} else if(o.contains("udp")) {
			bmode = 'u';
		}

		if (addr == null) {
			if (args.length > 1) {
				addr = args[1];
			} else {
				addr =  Environment.get_variable("MWP_BLE");
			}
		}
		if(addr == null) {
			stderr.printf("usage: mwp-ble-bridge --address ADDR (or set $MWP_BLE)\n");
			return 127;
		} else {
			activate();
			return 0;
		}
	}

	private int do_handle_local_options(VariantDict o) {
        if (o.contains("version")) {
            stdout.printf("0.0.2\n");
            return 0;
        }
		return -1;
    }

	public override void activate () {
		hold ();
		new BLEKnownUUids();
		bt = new Bluez();
		Idle.add(() => {
				bt.init();
				init();
				return false;
			});
		return;
	}

	private void init () {
		gs = new BleSerial();
		if(addr.has_prefix("bt://")) {
			addr = addr[5:addr.length];
		}

		open_async.begin((obj, res) =>  {
				var ok = open_async.end(res);
				if (ok == 0) {
					mtu = gs.get_bridge_fds(bt, id, out rdfd, out wrfd);
					var sb = new StringBuilder();
					sb.append_printf("BLE chipset %s, mtu %d", gs.get_chipset(), mtu);
					if(mtu < 256) {
						sb.append(" (may not end well)");
					}
					MWPLog.message("%s\n", sb.str);
					start_session();
				} else {
					MWPLog.message("Failed to find service (%d)\n", ok);
					close_session();
				}
			});
	}

	private async int open_async() {
		var thr = new Thread<int> (addr, () => {
				var res = open_w();
				Idle.add (open_async.callback);
				return res;
			});
		yield;
		return thr.join();
	}

	private int open_w() {
		if(verbose) {
			message("start %s", addr);
		}
		uint tc = 0;
		while ((id = bt.get_id_for(addr)) == 0) {
			Thread.usleep(5000);
			tc++;
			if(tc > 200*15) {
				return -1;
			}
		}
		if(verbose) {
			message("id %u", id);
		}

		if (!bt.set_device_connected(id, true)) {
			return -2;
		}
		if(verbose) {
			message("connecting");
		}
		tc = 0;
		while (!bt.get_device(id).is_connected) {
			Thread.usleep(5000);
			tc++;
			if(tc > 200*5) {
				return -2;
			}
		}
		if(verbose) {
			message("get properties");
		}
		tc = 0;
		while(true) {
			int gid = -1;
			var uuids =  bt.get_device_property(id, "UUIDs").dup_strv();
			var sid = BLEKnownUUids.verify_serial(uuids, out gid);
			gs.set_gid(gid);
			if(sid == 2) {
				break;
			}
			Thread.usleep(5000);
			tc++;
			if (tc > 200*15) {
				return -3;
			}
		}
		if(verbose) {
			message("servicing");
		}
		tc = 0;
		while (!gs.find_service(bt, id)) {
			Thread.usleep(5000);
			tc++;
			if (tc > 200*2) {
				return -4;
			}
		}
		if(verbose) {
			message("serviced OK");
		}
		return 0;
	}

	private void close_session () {
		if(ftag != 0) {
			Source.remove(ftag);
			ftag = 0;
		}
		if(ptag != 0) {
			Source.remove(ptag);
			ptag = 0;
		}
		if(pfd != -1) {
			if(bmode == 'p') {
				Posix.close(pfd);
			} else {
				try {
					if (skt != null) {
						if (bmode == 't') {
							skt.shutdown(true, true);
						}
						skt.close();
					}
				} catch (Error e) {
					message("DBG: shutdown %s", e.message);
				}
				Posix.close(pfd);
			}
			pfd  = -1;
		}
		if(!persist) {
			if(rdfd != -1)
				Posix.close(rdfd);
			if(wrfd != -1)
				Posix.close(wrfd);
			rdfd = wrfd = -1;
			if (gs != null) {
				MWPLog.message("Disconnect\n");
				bt.set_device_connected(id, false);
			}
			this.quit();
		} else if (bmode == 'p') {
			Idle.add(() => {
					start_session();
					return false;
				});
		}
	}

	private uint16 get_host_port(Socket s, out string hostname) {
		char hostn[255];
		var n = Posix.gethostname(hostn);
		hostname = (string)hostn[:n];
		return get_random_port(s);
	}

	private void start_session () {
		if (rdfd != -1 && wrfd != -1) {
			string hostname;
			if(bmode == 'p') {
				pfd = Posix.posix_openpt(Posix.O_RDWR|Posix.O_NONBLOCK);
				if (pfd != -1) {
					Posix.grantpt(pfd);
					Posix.unlockpt(pfd);
					unowned string s = Posix.ptsname(pfd);
					print("%s <=> %s\n",addr, s);
					ioreader();
				}
			} else if (bmode == 'u') {
				skt = getUDPSocket(port);
				pfd = skt.get_fd();
				port = get_host_port(skt, out hostname);
				print("listening on udp port %u\n", port);
				ioreader();
			} else if (bmode == 't') {
				var lskt = getTCPSocket(port);
				port = get_host_port(lskt, out hostname);
				print("listening on tcp port %u\n", port);
				var lsource = lskt.create_source(IOCondition.IN);
				lsource.set_callback((s,c) => {
						try {
							skt = s.accept();
							pfd = skt.get_fd();
							persist = true;
							ioreader();
						} catch (Error e) {
							MWPLog.message("accept: %s\n", e.message);
						}
						return persist;
					});
				lsource.attach(MainContext.default ());
				try {
					lskt.listen();
				} catch {}
			}
		} else {
			close_session();
		}
	}

	private bool preader(IOChannel s, IOCondition c) {
		var done = 0;
		uint8 tbuf[512];
		if((c &IOCondition.IN) != 0) {
			size_t nw = 0;
			if (bmode == 'p') {
				nw = Posix.read(pfd, tbuf, 512);
			} else {
				try {
					nw = skt.receive_from(out raddr, tbuf);
				} catch {
				}
			}
			if (nw > 0) {
				uint8 *p = (uint8*)tbuf;
				for(int n = (int)nw; n > 0; ) {
					var nc = (n > 20) ? 20 : n;
					Posix.write(wrfd, p, nc);
					p += nc;
					n -= nc;
				}
			} else {
				done = -3;
			}
			if(done == 0) {
				return true;
			}
		}
		Idle.add(() => {
				ptag = 0;
				close_session();
				return false;
			});
		return false;
	}


	private bool freader(IOChannel s, IOCondition c) {
		var done = 0;
		uint8 fbuf[512];
		if((c &IOCondition.IN) != 0) {
			var nw = Posix.read(rdfd, fbuf, 512);
			if (nw > 0) {
				if(bmode == 'p') {
					Posix.write(pfd, fbuf, nw);
				} else {
					try {
						skt.send_to (raddr, fbuf[:nw]);
					} catch {}
				}
			} else if (nw < 0) {
				done =  -1;
			}
			if(done == 0) {
				return true;
			}
		}
		Idle.add(() => {
				ftag = 0;
				close_session();
				return false;
			});
		return false;
	}

	private void ioreader() {
		try {
			var bles = new IOChannel.unix_new(pfd);
			bles.set_encoding(null);
			ptag = bles.add_watch(IOCondition.IN|IOCondition.HUP|IOCondition.ERR, preader);
		} catch {}
		try {
			var fds = new IOChannel.unix_new(rdfd);
			fds.set_encoding(null);
			ftag = fds.add_watch(IOCondition.IN|IOCondition.HUP|IOCondition.NVAL|IOCondition.ERR, freader);
		} catch {}
	}

	private bool on_sigint () {
		persist = false;
		close_session();
		return Source.REMOVE;
    }

	private void on_startup() {	}

	private void on_shutdown() {
	}
}

public static int main (string[] args) {
	var ga = new GattTest();
	ga.run(args);
	return 0;
}
