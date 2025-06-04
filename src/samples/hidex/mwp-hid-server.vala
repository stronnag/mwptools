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

static MainLoop ml;

public class JoyManager : Object {
	public static bool verbose;
	public static bool fake;
	public static bool check;
	public static int port;

	private IOChannel io_read;
	private SDL.Input.Joystick js;
	private JoyReader jrdr;
	private string mf;
	private bool tinit;

	private Socket socket;
	private SocketAddress remaddr;

	private SList<InetSocketAddress>plist;
	private Socket psocket;

	public JoyManager(string _mf, bool fake = false) {
		tinit = false;
		int njoy = SDL.init (SDL.InitFlag.JOYSTICK|SDL.InitFlag.GAMECONTROLLER);
		if (njoy < 0) {
			stderr.printf("Unable to initialize the joystick subsystem.\n");
		}
		jrdr = new JoyReader(fake);
		mf = _mf;

		jrdr.update.connect((i,v) => {
				if(plist != null) {
					uint16 buf[2];
					buf[0] = (uint16)i;
					buf[1] = (uint16)v;

					plist.@foreach((a) => {
							try {
								var sz = psocket.send_to(a, (uint8[]) buf, null);
								stderr.printf("P-Sent %jd\n", sz);
							} catch (Error e) {
								stderr.printf("P-send: %s\n", e.message);
								unowned var sl = plist.find_custom(a, (CompareFunc<InetSocketAddress?>)ia_comp);
								if(sl != null) {
									plist.remove_link(sl);
								}
							}
						});
				}
			});

	}

	public string? get_info() {
		if(js != null) {
			var sb = new StringBuilder();
			sb.append_printf("Channels: %d %s", get_channels().length, js.get_name());
			var n = js.num_axes();
			if (n > 0) {
				sb.append_printf(" Axes: %d", n);
			}
			n = js.num_buttons();
			if (n > 0) {
				sb.append_printf(" Buttons: %d", n);
			}
			n = js.num_balls();
			if (n > 0) {
				sb.append_printf(" Balls: %d", n);
			}
			n = js.num_hats();
			if (n > 0) {
				sb.append_printf(" Hats: %d", n);
			}
			return sb.str;
		} else {
			return "Channels: %d No joystick connected".printf(get_channels().length);
		}
	}

	public void show_start() {
		if(!tinit) {
			tinit = true;
			for(var j = 1; j <= get_channels().length; j++) {
				stderr.printf(" Ch%02d", j);
			}
			stderr.printf("\n");
		}
	}

	public void read_all() {
		if (js != null) {
			for(var j = 0; j < jrdr.axes.length; j++) {
				if (jrdr.axes[j].channel != 0) {
					var v = js.get_axis(j);
					jrdr.set_axis(j, v);
				}
			}
			for(var j = 0; j < jrdr.buttons.length; j++) {
				if(jrdr.buttons[j].channel != 0) {
					var v = js.get_button(j);
					jrdr.set_button(j, (v ==  SDL.Input.ButtonState.PRESSED));
				}
			}
		}
	}

	public void runner() {
		SDL.Event event;
		while (SDL.Event.wait (out event) == 1) {
			switch(event.type) {
			case SDL.EventType.QUIT:
				stderr.printf("sdl quit\n");
				ml.quit();
				return;
			case SDL.EventType.JOYAXISMOTION:
				if(jrdr.deadband == 0) {
					jrdr.set_axis(event.jaxis.axis, event.jaxis.value);
				} else {
					var last = jrdr.axes[event.jaxis.axis].last;
					if((event.jaxis.value - last).abs() > jrdr.deadband) {
						jrdr.axes[event.jaxis.axis].last = event.jaxis.value;
						jrdr.set_axis(event.jaxis.axis, event.jaxis.value);
					}
				}
				break;
			case SDL.EventType.JOYBUTTONDOWN:
				jrdr.set_button(event.jbutton.button, true);
				break;
			case SDL.EventType.JOYBUTTONUP:
				jrdr.set_button(event.jbutton.button, false);
				break;
			case SDL.EventType.JOYHATMOTION:
				if (verbose)
					stderr.printf("Hat %d value %d.\n", event.jhat.hat, event.jhat.value);
				break;
			case SDL.EventType.JOYDEVICEADDED:
				if (verbose)
					stderr.printf("Joystick #%d connected\n", event.jdevice.which);
				js = new SDL.Input.Joystick(0);
				if (verbose) {
					stderr.printf("%s\n", get_info());
				}
				jrdr.set_sizes(js.num_axes(), js.num_buttons());
				jrdr.reader(mf);
				if(verbose) {
					jrdr.dump_chandef();
				}
				read_all();
				Timeout.add(1000, () => {
						read_all();
						if(verbose) {
							stderr.printf("Deadband: %d\n", jrdr.deadband);
							show_start();
							stderr.printf("%s\n", print_channels());
						}
						return false;
					});
				break;
			case SDL.EventType.JOYDEVICEREMOVED:
				if(verbose) {
					stderr.printf("Joystick %d removed.\n", event.jdevice.which);
				}
				jrdr.reset_all();
				js = null;
				jrdr = null;
				break;
			case 0x607:
				//	print("Joystick %d battery update\n", event.jdevice.which);
				break;
			case 0x608:
				// print("Joystick %d update complete\n", event.jdevice.which);
				break;
			case SDL.EventType.CONTROLLERDEVICEADDED:
				// print("Controller %d connected\n", event.cdevice.which);
				break;
			case SDL.EventType.CONTROLLERDEVICEREMOVED:
				// print("Controller %d removed.\n", event.cdevice.which);
				break;
			default:
				if (verbose)
					stderr.printf("Unhandled %d %x\n", event.type, event.type);
				break;
			}
		}
		if (verbose)
			stderr.printf("sdl done\n");
		ml.quit();
	}

	public uint16[] get_channels() {
		if (jrdr != null) {
			return jrdr.get_channels();
		} else {
			return {};
		}
	}

	public void quit() {
		SDL.quit ();
	}

	public string print_channels() {
		StringBuilder sb = new StringBuilder();
		var chans = get_channels();
		for(var k = 0; k < chans.length; k++) {
			sb.append_printf(" %4d", chans[k]);
		}
		return sb.str;
	}

	private void set_chans(string cmd) {
		var parts = cmd.split(" ");
		if(parts.length > 1 && parts.length <= 1+get_channels().length) {
			for(var k = 1; k < parts.length; k++) {
				int v = int.parse(parts[k]);
				if (v > 880 && v < 2100) {
					jrdr.set_channel(k, v);
				}
			}
		}
	}

	private void set_init_chans(string cmd) {
		var parts = cmd.split(" ");
		if(parts.length > 1 && parts.length <= 1+get_channels().length) {
			for(var k = 1; k < parts.length; k++) {
				int v = int.parse(parts[k]);
				if (v > 880 && v < 2100) {
					jrdr.init_channel(k, v);
				}
			}
		}
	}

	private int ia_comp(InetSocketAddress? a, InetSocketAddress? b) {
		return GLib.strcmp(a.to_string(), b.to_string());
	}

	private void setup_pusher(string cmd) {
		if (psocket == null) {
			SocketFamily[] fam_arry = {SocketFamily.IPV6, SocketFamily.IPV4};
			foreach(var fam in fam_arry) {
				try {
					psocket = new Socket (fam, SocketType.DATAGRAM, SocketProtocol.UDP);
				} catch (Error e) {
					stderr.printf("psocket: %s\n", e.message);
					return;
				}
				break;
			}
		}
		var parts = cmd.split(" ");
		if(parts.length == 2) {
			uint16 port = (uint16)uint.parse(parts[1]);
			var fam = psocket.get_family();
			var addr = new InetAddress.loopback(fam);
			var ia = new InetSocketAddress(addr, port);
			if(plist == null) {
				plist = new SList<InetSocketAddress>();
				plist.append(ia);
			} else {
				unowned var sl = plist.find_custom(ia, (CompareFunc<InetSocketAddress?>)ia_comp);
				if(sl == null) {
					plist.append(ia);
				}
			}
		}
	}

	public bool setup_ip(uint16 port) {
		try {
			SocketFamily[] fam_arry = {SocketFamily.IPV6, SocketFamily.IPV4};
			foreach(var fam in fam_arry) {
				var sa = new InetSocketAddress (new InetAddress.any(fam), (uint16)port);
				if (sa != null) {
					socket = new Socket (fam, SocketType.DATAGRAM, SocketProtocol.UDP);
					//WinFix.set_v6_dual_stack(socket.fd);
					socket.bind (sa, true);
					return true;
				}
			}
		} catch (Error e) {
			stderr.printf ("%s\n",e.message);
		}
		return false;
	}


	public void ufetch() {
#if WINDOWS
		io_read = new IOChannel.win32_socket(socket.fd);
#else
		io_read = new IOChannel.unix_new(socket.fd);
#endif
		try {
			if(io_read.set_encoding(null) != IOStatus.NORMAL) {
				error("Failed to set encoding");
			}
			io_read.set_buffered(false);
			io_read.add_watch(IOCondition.IN|
							  IOCondition.HUP|
							  IOCondition.ERR|
							  IOCondition.NVAL, (chan, cond) => {
								  if((cond & (IOCondition.HUP|IOCondition.ERR|IOCondition.NVAL)) != 0) {
									  return false;
								  }
								  uint8 buf[128];
								  try {
									  var sz = socket.receive_from(out remaddr, buf);
									  if (sz <= 0) {
										  return false;
									  }
									  string cmd = ((string)buf[:sz]).strip();
									  if(cmd == "quit") {
										  socket.send_to(remaddr, "ok".data);
										  SDL.quit();
										  ml.quit();
									  } else if (cmd == "raw") {
										  var chans = get_channels();
										  socket.send_to(remaddr, (uint8[])chans);
									  } else if (cmd == "text") {
										  var s = print_channels();
										  socket.send_to(remaddr, s.data);
									  } else if (cmd == "info") {
										  socket.send_to(remaddr, get_info().data);
									  } else if (cmd.has_prefix("set ")) {
										  set_chans(cmd);
										  socket.send_to(remaddr, "ok".data);
									  } else if (cmd.has_prefix("push ")) {
										  setup_pusher(cmd);
										  socket.send_to(remaddr, "ok".data);
									  } else {
										  socket.send_to(remaddr, "err".data);
									  }
									  return true;
								  } catch (Error e) {
									  stderr.printf("recv_from: %s\n", e.message);
									  return false;
								  }
							  });
		} catch (Error e) {
			stderr.printf("ioreader: %s\n", e.message);
		}
	}

	public void sfetch() {
#if !WINDOWS
		io_read = new IOChannel.unix_new(stdin.fileno());
#else
		io_read = new IOChannel.win32_new_fd(stdin.fileno());
#endif

		try {
			if(io_read.set_encoding(null) != IOStatus.NORMAL) {
				error("Failed to set encoding");
			}
			io_read.add_watch(IOCondition.IN|
							  IOCondition.HUP|
							  IOCondition.ERR|
							  IOCondition.NVAL, (chan, cond) => {
								  if((cond & (IOCondition.HUP|IOCondition.ERR|IOCondition.NVAL)) != 0) {
									  return false;
								  }
								  string buf;
								  try {
									  var iostat = chan.read_line(out buf, null, null);
									  if(iostat != IOStatus.NORMAL) {
										  ml.quit();
										  return false;
									  }
									  string cmd = buf.strip();
									  if(cmd == "quit") {
										  var s = "ok\n";
										  Posix.write(1, s.data, s.length);
										  SDL.quit();
										  ml.quit();
									  } else if (cmd == "raw") {
										  var chans = get_channels();
										  Posix.write(1, chans, 2*chans.length);
									  } else if (cmd == "text") {
										  var s = "%s\n".printf(print_channels());
										  Posix.write(1, s.data, s.length);
									  } else if (cmd == "info") {
										  var s = "%s\n".printf(get_info());
										  Posix.write(1, s.data, s.length);
									  } else if (cmd.has_prefix("init")) {
										  set_init_chans(cmd);
										  var s = "ok\n";
										  Posix.write(1, s.data, s.length);
									  } else if (cmd.has_prefix("push ")) {
										  setup_pusher(cmd);
										  var s = "ok\n";
										  Posix.write(1, s.data, s.length);
									  } else {
										  var s = "err\n";
										  Posix.write(1, s.data, s.length);
									  }
									  return true;
								  } catch (Error e) {
									  stderr.printf("Reader: %s\n", e.message);
									  return false;
								  }
							  });
		} catch (Error e) {
			stderr.printf("ioreader: %s\n", e.message);
		}
	}
}

const OptionEntry[] options = {
	{"verbose", 'v', 0, OptionArg.NONE, ref JoyManager.verbose, "Verbose mode", null},
	{"fake", 'f', 0, OptionArg.NONE, ref JoyManager.fake, "Fake values", null},
	{"port", 'p', 0, OptionArg.INT, ref JoyManager.port, "Udp port", "31025"},
	{"check", 'c', 0, OptionArg.NONE, ref JoyManager.check, "Check mapping file", "false"},
	{null}
};

static int main(string? []args) {
	JoyManager jm;
	JoyManager.port = 31025;

	try {
		var opt = new OptionContext(" mapfile");
		opt.set_help_enabled(true);
		opt.add_main_entries(options, null);
		opt.parse(ref args);
	}
	catch (OptionError e) {
		stderr.printf("Error: %s\n", e.message);
		stderr.printf("Run '%s --help' to see a full list of available "+
					  "options\n", args[0]);
		return 1;
	}

	if (args.length > 1) {
		if(JoyManager.check) {
			var jrdr = new JoyReader(true);
			jrdr.set_sizes(8, 24, 0, 0);
			jrdr.reader(args[1]);
			stderr.printf("\n");
			jrdr.dump_chandef();
			return 0;
		}

		jm = new JoyManager(args[1], JoyManager.fake);
		ml = new MainLoop();

		new Thread<int> ("jstick", () => {
				jm.runner();
				return 0;
			});

		jm.sfetch();
		if(jm.setup_ip((uint16)JoyManager.port)) {
			jm.ufetch();
		}

		if (JoyManager.verbose) {
			Timeout.add_seconds(10, () => {
					jm.show_start();
					stderr.printf("%s\n", jm.print_channels());
					return true;
					});
		}
		ml.run();
		SDL.quit();
	} else {
		stderr.printf("no mapping file\n");
	}
	return 0;
}
