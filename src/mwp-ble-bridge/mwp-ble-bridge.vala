extern unowned string ptsname(int fd);

namespace DevManager {
  public static BluetoothMgr btmgr;
}

namespace MWPLog {
	public void  message(string format, ...) {
		return;
		/*
		var args = va_list();
		var fmt = format.replace("\n", "");
		GLib.message(fmt, args);
		*/
	}
}

public class GattTest : Application {
	private string? addr;
	private int rcount;
	private BleSerial gs;
	private int rdfd;
	private int wrfd;
	private int pfd;

	public GattTest () {
        Object (flags: ApplicationFlags.HANDLES_COMMAND_LINE);
        Unix.signal_add (
            Posix.Signal.INT,
            on_sigint,
            Priority.DEFAULT
        );
		startup.connect (on_startup);
        shutdown.connect (on_shutdown);
	}

	private void please_release_me() {
		if(rcount == 0) {
			rcount++;
			release();
		}
	}

	public override int command_line (ApplicationCommandLine command_line) {
		string[] args = command_line.get_arguments ();
		addr =  Environment.get_variable("MWP_BLE");
		if (addr == null && args.length > 1) {
			addr = args[1];
		}
		if(addr == null) {
			stderr.printf("usage: mwp-ble-bridge ADDR (or set $MWP_BLE)\n");
			return 127;
		} else {
			activate();
			return 0;
		}
	}

	public async bool open_async () {
		var thr = new Thread<bool> ("mwp-ble", () => {
				int gid = gs.find_service();
				//				message("BLE chipset %s", gs.get_chipset(gid));
				if (gid != -1) {
					int count = 0;
					//					message("Connected %s",gs.bdev.connected.to_string());
					while (!gs.bdev.connected) {
						Thread.usleep(10000);
						count++;
						if (count > 2*1000) {
							return false;
						}
					}
					gs.get_bridge_fds(gid, out rdfd, out wrfd);
				}
				Idle.add (open_async.callback);
				return true;
			});
		yield;
		return thr.join();
	}

	public override void activate () {
		hold ();
		rdfd = wrfd = pfd = -1;
		gs = new BleSerial();
		gs.bdev = DevManager.btmgr.get_device(addr);
		if(!gs.bdev.connected) {
			gs.bdev.connect();
		}
		start_session();
		return;
	}

	private void close_session () {
		Posix.close(rdfd);
		Posix.close(wrfd);
		Posix.close(pfd);
		pfd = rdfd = wrfd = -1;
		if (gs != null) {
			gs.bdev.disconnect();
		}
	}

	private void start_session () {
		open_async.begin((obj, res) => {
				open_async.end(res);
				if (rdfd != -1 && wrfd != -1) {
					pfd = Posix.posix_openpt(Posix.O_RDWR|Posix.O_NONBLOCK);
					if (pfd != -1) {
						Posix.grantpt(pfd);
						Posix.unlockpt(pfd);
						unowned string s = ptsname(pfd);
						print("%s <=> %s\n",addr, s);
						io_thread.begin((obj,res) => {
								io_thread.end(res);
								on_sigint();
							});
					} else {
						close_session();
					}
				}
			});
	}

	private async int io_thread() {
		var thr = new Thread<int> ("mwp-ble", () => {
				uint8 buf[512];
				int done = 0;
				while (done == 0) {
					var n = Posix.read(pfd, buf, 20);
					if (n > 0) {
						Posix.write(wrfd, buf, n);
					} else if (n < 0) {
						if(Posix.errno == Posix.EAGAIN) {
							Thread.usleep(2000);
						} else {
							done = Posix.errno;
						}
					} else {
						done =  -3;
					}
					var nr = Posix.read(rdfd, buf, 512);
					if (nr > 0) {
						Posix.write(pfd, buf, nr);
					} else if (nr < 0) {
						if(Posix.errno == Posix.EAGAIN) {
							Thread.usleep(2000);
						} else {
							done = Posix.errno;
						}
					} else {
						done =  -3;
					}
				}
				Idle.add (io_thread.callback);
				return done;
			});
		yield;
		return thr.join();
	}

	private bool on_sigint () {
		if (gs != null) {
			if(addr != null) {
				if(gs.bdev.connected) {
					print("Disconnecting\n");
					gs.bdev.disconnect();
				}
			}
		}
		please_release_me();
		return Source.REMOVE;
    }

	private void on_startup() {	}

	private void on_shutdown() {
	}
}

public static int main (string[] args) {
	DevManager.btmgr = new BluetoothMgr();
	DevManager.btmgr.init();
	var ga = new GattTest();
	ga.run(args);
	return 0;
}
