public class Forwarder : Object {
	private string devname;
	private MWSerial? fwddev;
	private uint8 rcount;

	public Forwarder(string? _dev) {
		if (_dev != null) {
			devname = _dev;
			fwddev = new MWSerial.forwarder();
		}
	}

	public bool available() {
		if (fwddev != null) {
			return fwddev.available;
		} else {
			return false;
		}
	}

	public void send_command(uint16 cmd, uint8[]raw, size_t len) {
		fwddev.send_command(cmd, raw, len);
	}

	public void send_ltm(uint8 cmd, uint8[]raw, size_t len) {
		fwddev.send_ltm(cmd, raw, len);
	}

	public void send_mav(uint8 cmd, uint8[]raw, size_t len) {
		fwddev.send_mav(cmd, raw, len);
	}

	public void close() {
		fwddev.close();
	}

	public void try_open(MWSerial msp) {
        if(!fwddev.available) {
			fwddev.open_async.begin(devname, 0,  (obj,res) => {
					var ok = fwddev.open_async.end(res);
					if (ok) {
						fwddev.set_mode(MWSerial.Mode.SIM);
						MWPLog.message("set forwarder %s\n", devname);
						rcount = 0;
					} else {
						if (msp.available) {
							rcount += 1;
							if(rcount < 5) {
								MWPLog.message("retry forwarder %s\n", devname);
								Timeout.add_seconds(30, () => {
										try_open(msp);
										return false;
									});
 							} else {
								string fstr;
								fwddev.get_error_message(out fstr);
								Utils.warning_box(
									"Failed to open forwarding device %s after 5 attempts: %s\n".printf(devname, fstr),
									Gtk.MessageType.ERROR,10);
							}
						}
					}
				});
		}
	}
}
