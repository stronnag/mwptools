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
