#if !USE_TV
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
		var options = new OptionEntry[] {
			{ "address", 'a', 0, OptionArg.STRING, gc, "BT address", null},
            { "version", 'v', 0, OptionArg.NONE, null, "show version", null},
			{null}
		};
		set_option_context_parameter_string(" - GATT serial bridge");
		set_option_context_description("mwp-gatt-bridge requires a BT address or $MWP_BLE to be set");
		add_main_option_entries(options);
		handle_local_options.connect(do_handle_local_options);
	}

	private int do_handle_local_options(VariantDict o) {
        if (o.contains("version")) {
            stdout.printf("0.0.1\n");
            return 0;
        }
		return -1;
    }

	public override int command_line (ApplicationCommandLine command_line) {
		string[] args = command_line.get_arguments ();
		addr =  Environment.get_variable("MWP_BLE");

		var o = command_line.get_options_dict();
		if (o.contains("address")) {
			addr = (string)o.lookup_value("address", VariantType.STRING);
		}
		if (addr == null && args.length > 1) {
			addr = args[1];
		}

		if (!validate_addr()) {
			addr = null;
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
		Gatt_Status status;
		gc = new GattClient (addr, out status);
		if (gc != null) {
			stdout.printf("pseudo-terminal:  %s\n", gc.get_devnode());
			gatt_async.begin((obj,res) => {
					gatt_async.end(res);
					release();
				});
		} else {
			stderr.printf("Unable to open %s (%s)\n", addr, status.to_string());
			release();
		}
		return;
	}

	private bool on_sigint () {
		if (gc != null)
			release ();
        return Source.REMOVE;
    }


	private bool validate_addr() {
		var nok = 0;
		if (addr != null) {
			var parts = addr.split(":");
			if (parts.length == 6) {
				foreach(var p in parts) {
					if(p.length == 2) {
						if (p[0].isxdigit() && p[1].isxdigit()) {
							nok += 1;
						}
					}
				}
			}
		}
		return (nok == 6);
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

	private void on_startup() {}

	private void on_shutdown() {
		gc = null;
	}

	public static int main (string[] args) {
        var ga = new GattTest();
		ga.run(args);
		return 0;
	}
}
#else
public static int main (string[] args) {
	stderr.printf("Not available");
	return 127;
}
#endif
