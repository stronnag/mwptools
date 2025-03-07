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

public class Forwarder : Object {
	private string devname;
	private MWSerial? fdev;
	private uint8 rcount;
	private Utils.Warning_box wb;

	public Forwarder(string? _dev) {
		if (_dev != null) {
			devname = _dev;
			fdev = new MWSerial.forwarder();
			fdev.mavsysid = (uint8)Mwp.conf.mavlink_sysid;
		}
	}

	public bool available() {
		if (fdev != null) {
			return fdev.available;
		} else {
			return false;
		}
	}

	public void forward_command(uint16 cmd, uint8[]raw, size_t len, bool v2=true) {
		fdev.use_v2 = v2;
		fdev.send_command(cmd, raw, len);
	}

	public void forward_ltm(uint16 cmd, uint8[]raw, size_t len) {
		fdev.send_ltm((uint8)cmd, raw, len);
	}

	public void forward_mav(uint16 cmd, uint8[]raw, size_t len, uint8 vers) {
		if (vers == 0) {
			fdev.mavvid = Mwp.msp.mavvid;
		} else {
			fdev.mavvid = vers;
		}
		fdev.send_mav(cmd, raw, len);
	}

	public void close() {
		fdev.close();
	}

	public void try_open(MWSerial msp) {
        if(!fdev.available) {
			fdev.open_async.begin(devname, 0,  (obj,res) => {
					var ok = fdev.open_async.end(res);
					if (ok) {
						fdev.set_mode(MWSerial.Mode.SIM);
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
								fdev.get_error_message(out fstr);
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
