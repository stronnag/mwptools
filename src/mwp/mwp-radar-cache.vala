public enum RadarSource {
    NONE = 0,
    INAV = 1,
    TELEM = 2,
    MAVLINK = 4,
    SBS = 8,
    M_INAV = (INAV|TELEM),
    M_ADSB = (MAVLINK|SBS),
}

public struct RadarPlot {
    public string name;
    public double latitude;
    public double longitude;
    public double altitude;
    public uint16 heading;
    public double speed;
    public uint lasttick;
    public uint8 state;
    public uint8 lq; // tslc for ADSB
    public uint8 source;
    public bool posvalid;
	public uint8 alert;
	public uint8 etype;
	public DateTime dt;
	public uint32 srange;
}

public enum RadarAlert {
	NONE = 0,
	ALERT = 1,
	SET= 2
}

public class RadarCache : Object {
	HashTable<uint, RadarPlot?> table;

	public RadarCache() {
		table = new HashTable<uint,RadarPlot?> (direct_hash, direct_equal);
	}

	public bool remove(uint rid) {
		return table.remove(rid);
	}

	public bool upsert(uint k, RadarPlot v) {
		bool found = table.contains(k);
		if (found){
			table.replace(k, v);
		} else {
			table.insert(k, v);
		}
		return found;
	}

	public uint size() {
		return table.size();
	}

	public unowned RadarPlot? lookup(uint k) {
		return table.lookup(k);
	}

	public List<unowned uint> get_keys() {
		return (List<unowned uint>)table.get_keys();
	}

}
