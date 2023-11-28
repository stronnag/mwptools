extern unowned string ptsname(int fd);

namespace DevManager {
  public static BluetoothMgr btmgr;
}

namespace MWPLog {
	public void  message(string format, ...) {
		var args = va_list();
		stdout.vprintf(format, args);
	}
}

public class GattTest : Application {
	private string? addr;
	private BleSerial gs;
	private int rdfd;
	private int wrfd;
	private int pfd;
	private MainLoop loop;
	private IOChannel rchan;
	private IOChannel pchan;
	private string dpath;
	private int mtu;
	private uint rdtag;
	private uint pftag;

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
		var options = new OptionEntry[] {
			{ "address", 'a', 0, OptionArg.STRING, addr, "BT address", null},
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
		if (o.contains("address")) {
			addr = (string)o.lookup_value("address", VariantType.STRING);
		} else if (args.length > 1) {
			addr = args[1];
		} else {
			addr =  Environment.get_variable("MWP_BLE");
		}
		if(addr == null) {
			stderr.printf("usage: mwp-ble-bridge ADDR (or set $MWP_BLE)\n");
			return 127;
		} else {
			activate();
			return 0;
		}
	}

	private int do_handle_local_options(VariantDict o) {
        if (o.contains("version")) {
            stdout.printf("0.0.1\n");
            return 0;
        }
		return -1;
    }

	private void init () {
		DevManager.btmgr = new BluetoothMgr();
		DevManager.btmgr.init();
		gs = new BleSerial();
		gs.bdev = DevManager.btmgr.get_device(addr, out dpath);
		MWPLog.message("Open BLE device %s\n", addr);
		gs.bdev.connected_changed.connect((v) => {
				if(v) {
					MWPLog.message("Connected\n");
				} else {
					MWPLog.message("BLE Disconnected\n");
				}
			});
		if (gs.bdev.connect()) {
			int gid = gs.find_service(dpath);
			if (gid != -1) {
				mtu = gs.get_bridge_fds(gid, out rdfd, out wrfd);
				MWPLog.message("BLE chipset %s, mtu %d\n", gs.get_chipset(gid), mtu);
			} else {
				MWPLog.message("Failed to find service\n");
				loop.quit();
			}
			start_session();
		} else {
			this.quit();
		}
	}

	public override void activate () {
		hold ();
		Idle.add(() => {
				init();
				return false;
			});
		return;
	}

	private void close_session () {
		if (rdtag > 0)
			Source.remove(rdtag);
		if (pftag > 0)
			Source.remove(pftag);
		if(rdfd != -1)
			Posix.close(rdfd);
		if(wrfd != -1)
			Posix.close(wrfd);
		if(pfd != -1)
			Posix.close(pfd);
		pfd = rdfd = wrfd = -1;
		if (gs != null) {
			MWPLog.message("Disconnect\n");
			gs.bdev.disconnect();
		}
		this.quit();
	}

	private void start_session () {
		if (rdfd != -1 && wrfd != -1) {
			pfd = Posix.posix_openpt(Posix.O_RDWR|Posix.O_NONBLOCK);
			if (pfd != -1) {
				Posix.grantpt(pfd);
				Posix.unlockpt(pfd);
				unowned string s = ptsname(pfd);
				print("%s <=> %s\n",addr, s);
				io_readers();
			} else {
				close_session();
			}
		}
	}

	private void io_readers() {
		rchan = new IOChannel.unix_new (rdfd);
		rdtag = rchan.add_watch (IOCondition.IN | IOCondition.HUP|IOCondition.NVAL|IOCondition.ERR, (ch, cond) => {
				bool res = false;
				uint8[] buf = new uint8[mtu];
				if(cond == IOCondition.IN) {
					var n = Posix.read(rdfd, buf, mtu);
					if (n > 0 && Posix.write(pfd, buf, n) > 0) {
						res = true;
					}
				}
				if (res == false) {
					close_session();
				}
				return res;
			});

		pchan = new IOChannel.unix_new (pfd);
		pftag = pchan.add_watch (IOCondition.IN|IOCondition.HUP|IOCondition.NVAL|IOCondition.ERR, (ch, cond) => {
				bool res = false;
				uint8 buf [20];
				if(cond == IOCondition.IN) {
					var n = Posix.read(pfd, buf, 20);
					if (n > 0 && Posix.write(wrfd, buf, n) > 0) {
						res = true;
					}
				}
				if (res == false) {
					close_session();
				}
				return res;
			});
	}

	private bool on_sigint () {
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
