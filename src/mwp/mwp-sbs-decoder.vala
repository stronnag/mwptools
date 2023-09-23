public class SbsReader :Object {

	public signal void sbs_result(string? d);
	private SocketConnection conn;
	private string host;
	private uint16 port;

	public SbsReader(string pn) {
		var p = pn[6:pn.length].split(":");
		port = 30003;
		host = "localhost";
		if (p.length > 1) {
			port = (uint16)int.parse(p[1]);
		}
		if (p.length > 0) {
			if(p[0].length > 0)
				host = p[0];
		}
	}

	public async bool read_sbs()  throws Error {
		try {
			var resolver = Resolver.get_default ();
			var addresses = yield resolver.lookup_by_name_async (host, null);
			var address = addresses.nth_data (0);
			var  client = new SocketClient ();
			conn = yield client.connect_async (new InetSocketAddress (address, port));
		} catch (Error e) {
			sbs_result(null);
			return false;
		}
		var fd = conn.socket.fd;
		var io_read = new IOChannel.unix_new(fd);
		if(io_read.set_encoding(null) != IOStatus.NORMAL)
			error("Failed to set encoding");
		io_read.add_watch(IOCondition.IN|IOCondition.HUP|IOCondition.ERR|IOCondition.NVAL,
						  (chan, cond) => {
				string str = null;
				size_t length = -1;
				size_t pos = 0;
				if (cond == IOCondition.HUP) {
					sbs_result(null);
					return false;
				}
				try {
					IOStatus status = chan.read_line (out str, out length, out pos);
					if (status == IOStatus.EOF) {
						sbs_result(null);
						return false;
					}
					sbs_result(str);
					return true;
				} catch (IOChannelError e) {
					return false;
				} catch (ConvertError e) {
					return false;
				}
			});
		return true;
	}


	public string[]? parse_sbs_message(string s) {
		var p = s.split(",");
		if (p.length > 8) {
			switch(p[0]) {
			case "MSG":
				var p1 = int.parse(p[1]);
				if(p1 < 6) {
					return p;
				}
				break;
			case "STA":
				break;
			}
		}
		return null;
	}
}

#if TEST

namespace MWPLog {
	public static void message(string format, ...) {
                var args = va_list();
        stderr.vprintf(format, args);
        stderr.flush();
    }
}

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
}

public SList<RadarPlot?> radar_plot;

public int nticks;

unowned RadarPlot? find_radar_data(uint id) {
	SearchFunc<RadarPlot?,uint>  plot_search = (a,b) =>  {
		return (int) (a.id > b) - (int) (a.id < b);
	};
	unowned SList<RadarPlot?> res = radar_plot.search(id, plot_search);
	unowned RadarPlot? ri = res.nth_data(0);
	return ri;
}

unowned RadarPlot? decode_sbs(string[] p) {
	string s4 = "0x%s".printf(p[4]);
	uint v = (uint)uint64.parse(s4);
	unowned RadarPlot? ri = find_radar_data(v);
	var name = p[10].strip();
	if(ri == null) {
		var r0 = RadarPlot();
		r0.id =  v;
		radar_plot.append(r0);
		ri = find_radar_data(v);
		ri.source = 3;
		ri.posvalid = false;
		ri.state = 5;
		ri.name = name;
	} else {
		if (name.length > 0)
			ri.name = name;
	}
	if(p[1] == "2" || p[1] == "3") {
		double lat = double.parse(p[14]);
		double lng = double.parse(p[15]);
		uint16 hdg = (uint16)int.parse(p[13]);
		int spd = int.parse(p[12]);
		var isvalid = (lat != 0 && lng != 0);

		if ( isvalid && hdg == 0 && spd == 0 && ri.posvalid) {
			double c,d;
			Geo.csedist(ri.latitude, ri.longitude, lat, lng, out d, out c);
			hdg = (uint16)c;
			var tdiff = nticks-ri.lasttick;
			if (tdiff > 0) {
				ri.speed = d*1852.0 * 10.0 / tdiff;
			}
		} else {
			ri.speed = spd *(1852.0/3600.0);
		}
		ri.heading = hdg;
		ri.latitude = lat;
		ri.longitude = lng;
		ri.posvalid = isvalid;
		ri.altitude = int.parse(p[11])*0.3048;
	}
	ri.lasttick = nticks;
	MWPLog.message("p[1]=%s id=%x calls=%s lat=%f lon=%f alt=%.0f hdg=%u speed=%.1f last=%u\n",
				   p[1], ri.id, ri.name, ri.latitude, ri.longitude, ri.altitude, ri.heading, ri.speed, ri.lasttick);
	return ri;
}

void main (string[] args) {
	MainLoop ml = null;
	var uri = (args.length > 1) ? args[1] : "sbs://";

	Timeout.add(100, () => {
			nticks++;
			return true;
		});

	var g = new SbsReader(uri);
	g.read_sbs.begin((obj,res) => {
			try {
				((SbsReader)obj).read_sbs.end(res);
			} catch {}
		});

	g.sbs_result.connect((s) => {
			if (s == null) {
				if(nticks > 1200) {
					ml.quit();
				} else {
					Timeout.add_seconds(60, () => {
							g.read_sbs.begin((obj,res) => {
									try {
										((SbsReader)obj).read_sbs.end(res);
									} catch {}
								});
							return false;
					});
				}
			} else {
				var p = g.parse_sbs_message(s);
				if (p != null)
					decode_sbs(p);
			}
		});
	ml = new MainLoop();
	ml.run(/* */);
}
#endif
