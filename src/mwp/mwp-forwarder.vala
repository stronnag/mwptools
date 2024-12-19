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
 */

public class Forwarder : Object {
	private string devname;
	private MWSerial? fwddev;
	private uint8 rcount;
	internal Utils.Warning_box wb;

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
								wb = new Utils.Warning_box(
									"Failed to open forwarding device %s after 5 attempts: %s\n".printf(devname, fstr), 10);
								wb.present();
							}
						}
					}
				});
		}
	}
}
