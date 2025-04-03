static MainLoop ml;

public class JoyManager : Object {
	public static bool dumper;
	public static bool fake;
	public static int port;

	private Socket socket;
	private SocketAddress remaddr;
	private IOChannel io_read;

	private SDL.Input.Joystick js;
	private JoyReader jrdr;
	private string mf;
	private bool tinit;

	public JoyManager(string _mf, bool fake = false) {
		tinit = false;
		int njoy = SDL.init (SDL.InitFlag.JOYSTICK);
		if (njoy < 0) {
			print("Unable to initialize the joystick subsystem.\n");
		}
		jrdr = new JoyReader(fake);
		mf = _mf;
	}

	public string? get_info() {
		if(js != null) {
			var sb = new StringBuilder(js.get_name());
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
			return "No joystick connected";
		}
	}

	public void read_all() {
		if (js != null) {
			for(var j = 0; j < jrdr.axes.length; j++) {
				int chn = jrdr.axes[j];
				if(chn != 0) {
					var v = js.get_axis(j);
					jrdr.set_axis(j, v);
				}
			}
			for(var j = 0; j < jrdr.buttons.length; j++) {
				if(jrdr.buttons[j] != 0) {
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
				print("sdl quit\n");
				ml.quit();
				return;
			case SDL.EventType.JOYAXISMOTION:
				jrdr.set_axis(event.jaxis.axis, event.jaxis.value);
				break;
			case SDL.EventType.JOYBUTTONDOWN:
				jrdr.set_button(event.jbutton.button, true);
				break;
			case SDL.EventType.JOYBUTTONUP:
				jrdr.set_button(event.jbutton.button, false);
				break;
			case SDL.EventType.JOYHATMOTION:
				print("Hat %d value %d.\n", event.jhat.hat, event.jhat.value);
				break;
			case SDL.EventType.JOYDEVICEADDED:
				print("Joystick %d connected\n", event.jdevice.which);
				js = new SDL.Input.Joystick(0);
				print("%s\n", get_info());
				jrdr.set_sizes(js.num_axes(), js.num_buttons());
				jrdr.reader(mf);
				read_all();
				print(print_channels());
				break;
			case SDL.EventType.JOYDEVICEREMOVED:
				print("Joystick %d removed.\n", event.jdevice.which);
				jrdr.reset_all();
				js = null;
				jrdr = null;
				break;
			case 0x607:
				//	print("Joystick %d battery update\n", event.jdevice.which);
				break;
			case 0x608:
				//print("Joystick %d update complete\n", event.jdevice.which);
				break;
			default:
				print("Unhandled %d %x\n", event.type, event.type);
				break;
			}
		}
		print("sdl done\n");
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
		if (!tinit) {
			for(var j = 1; j < 17; j++) {
				sb.append_printf(" Ch%02d", j);
			}
			sb.append_c('\n');
			tinit = true;
		}

		var chans = get_channels();
		for(var k = 0; k < chans.length; k++) {
			sb.append_printf(" %4d", chans[k]);
		}
		sb.append_c('\n');
		return sb.str;
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

	private void set_chans(string cmd) {
		var parts = cmd.split(" ");
		if(parts.length > 1 && parts.length < 6) {
			for(var k = 1; k < parts.length; k++) {
				int v = int.parse(parts[k]);
				if (v > 880 && v < 2100) {
					jrdr.set_channel(k, v);
				}
			}
		}
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
}

const OptionEntry[] options = {
	{"dump", 'v', 0, OptionArg.NONE, ref JoyManager.dumper, "Periodic dump", null},
	{"fake", 'f', 0, OptionArg.NONE, ref JoyManager.fake, "Fake values", null},
	{"port", 'p', 0, OptionArg.INT, ref JoyManager.port, "Udp port", "31025"},
	{null}
};

static int main(string? []args) {
	JoyManager jm;
	JoyManager.port = 31025;

	try {
		var opt = new OptionContext(" - mapfile");
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
		bool ok = true;
		ml = new MainLoop();

		jm = new JoyManager(args[1], JoyManager.fake);

		new Thread<int> ("jstick", () => {
				jm.runner();
				return 0;
			});

		ok = jm.setup_ip((uint16)JoyManager.port);
		if(ok) {
			jm.ufetch();
			if (JoyManager.dumper) {
				Timeout.add_seconds(10, () => {
						print(jm.print_channels());
						return true;
					});
			}
			ml.run();
			SDL.quit();
		}
	} else {
		print("no mapping file\n");
	}
	return 0;
}
