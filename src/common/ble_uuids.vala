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

public class BLEKnownUUids : Object {
	public struct BleUUIDs {
		string name;
		string svcuuid;
		string txuuid;
		string rxuuid;
	}
	private static BleUUIDs[] BLEIDS = {
		{   "CC2541",
			"0000ffe0-0000-1000-8000-00805f9b34fb",
			"0000ffe1-0000-1000-8000-00805f9b34fb",
			"0000ffe1-0000-1000-8000-00805f9b34fb"},
		{	"Nordic Semi NRF",
			"6e400001-b5a3-f393-e0a9-e50e24dcca9e",
			"6e400003-b5a3-f393-e0a9-e50e24dcca9e",
			"6e400002-b5a3-f393-e0a9-e50e24dcca9e"},
		{	"SpeedyBee Type 2",
			"0000abf0-0000-1000-8000-00805f9b34fb",
			"0000abf1-0000-1000-8000-00805f9b34fb",
			"0000abf2-0000-1000-8000-00805f9b34fb"},
		{   "SpeedyBee Type 1",
			"00001000-0000-1000-8000-00805f9b34fb",
			"00001001-0000-1000-8000-00805f9b34fb",
			"00001002-0000-1000-8000-00805f9b34fb"}
	};

	public static uint n_ids() {
		return  BLEKnownUUids.BLEIDS.length;
	}

	public static new BleUUIDs? get(uint j) {
		if(j >= 0 && j< n_ids()) {
			return BLEKnownUUids.BLEIDS[j];
		}
		return null;
	}

	public static uint verify_serial(string[]uuids, out int bleid) {
		bleid = -1;
		if (uuids[0].has_prefix("00001101")) {
			return 1;
		} else {
			for( var i = 0; i < uuids.length; i++) {
				for (var j =0; j < 4; j++) {
					var s = BLEKnownUUids.get(j);
					if (uuids[i] == s.svcuuid) {
						bleid = j;
						return 2;
					}
				}
			}
		}
		return 0;
	}
}
/**
#if TEST
int main(string?[] args) {
	new BLEKnownUUids();
	string [] uuids = {
		"000000ff-0000-1000-8000-00805f9b34fb",
		"00001800-0000-1000-8000-00805f9b34fb",
		"00001801-0000-1000-8000-00805f9b34fb",
		"0000abf0-0000-1000-8000-00805f9b34fb"
	};
	uint sid;
	uint bid = 0;
	sid = BLEKnownUUids.verify_serial(uuids, out bid);
	message("res = %u %u", sid, bid);
	return 0;
}
#endif
**/
