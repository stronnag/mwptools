public class GattTest : Application {
	private string? addr;
	private GattClient gc;
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

	public override int command_line (ApplicationCommandLine command_line) {
		string[] args = command_line.get_arguments ();
		addr =  Environment.get_variable("MWP_BLE");
		if (addr == null && args.length > 1) {
			addr = args[1];
		}
		if(addr == null) {
			stderr.printf("usage: mwp-gatt-bridge ADDR (or set $MWP_BLE)\n");
			return 127;
		} else {
			activate();
			return 0;
		}
	}

	public override void activate () {
		hold ();
		int status = 0;
		gc = new GattClient (addr, out status);
		if (gc != null) {
			stdout.printf("pseudo-terminal:  %s\n", gc.get_devnode());
			gatt_async.begin((obj,res) => {
					gatt_async.end(res);
					release();
				});
		} else {
			stderr.printf("Fails, %d\n", status);
			release();
		}
		return;
	}

	private bool on_sigint () {
		if (gc != null)
			release ();
        return Source.REMOVE;
    }

	public async bool gatt_async () {
		var thr = new Thread<bool> ("mwp-ble", () => {
			gc.bridge();
			Idle.add (gatt_async.callback);
			return true;
			});
		yield;
		return thr.join();
	}

	private void on_startup() {
	}

	private void on_shutdown() {
		gc = null;
	}

	public static int main (string[] args) {
        var ga = new GattTest();
		ga.run(args);
		return 0;
	}
}
