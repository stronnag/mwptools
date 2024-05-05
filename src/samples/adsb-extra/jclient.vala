
public struct RadarPlot {
    public uint id;
    public string name;
    public double latitude;
    public double longitude;
    public double altitude;
    public uint16 heading;
    public double speed;
    public uint lasttick;
    public uint8 state;
    public uint8 lq;
    public uint8 source;
    public bool posvalid;
	public uint8 alert;
	public string category;
	public DateTime dt;
}


namespace SEDE {
	public uint8* deserialise_u32(uint8* rp, out uint32 v) {
    v = *rp | (*(rp+1) << 8) |  (*(rp+2) << 16) | (*(rp+3) << 24);
    return rp + sizeof(uint32);
  }
}

public class PBReader : Object {
	private SocketConnection conn;
	public signal void result(uint8[]? b);

	public async void runpb_async (string host, uint16 port) {
		try {
			var resolver = Resolver.get_default ();
			var addresses = yield resolver.lookup_by_name_async (host, null);
			var address = addresses.nth_data (0);
			var  client = new SocketClient ();
			conn = yield client.connect_async (new InetSocketAddress (address, port));
		} catch (Error e) {
			stderr.printf(":DBG: PB connection %s\n", e.message);
			result(null);
			return;
		}

		var inp = conn.input_stream;

		for(;;) {
			uint8 sz[4];
			try {
				var isz  = yield inp.read_async(sz);
				stderr.printf(":DBG: Read: %d\n", (int)isz);
				uint32 msize;
				SEDE.deserialise_u32(sz, out msize);
				stderr.printf(":DBG: Bytes to read: %d\n", (int)msize);
				uint8[]pbuf = new uint8[msize];
				try {
					var msz = yield inp.read_async(pbuf);
					stderr.printf(":DBG: Message : %d\n", (int)msz);
					result(pbuf);
				} catch (Error e) {
					stderr.printf(":DBG: Failed to read msge: %s\n", e.message);
					result(null);
					break;
				}
			} catch (Error e) {
				stderr.printf(":DBG: Failed to read msize: %s\n", e.message);
				result(null);
				break;
			}
		}
	}
}

void main() {
	var ml = new MainLoop();
	var pb = new PBReader();
	size_t maxsz = 0;
	pb.result.connect((s) => {
			if(s != null) {
				stderr.printf("read [%d]\n", s.length);
				if (s.length > maxsz) {
					stderr.printf("writing new file\n");
					var os = FileStream.open ("readsb.pb", "w");
					os.write(s);
					maxsz = s.length;
				}
			} else {
				ml.quit();
			}
		});
	pb.runpb_async.begin("localhost", 38008);
	ml.run();
}
