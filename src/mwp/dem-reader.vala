namespace HGT {
	public const double NODATA=-32768.0;
}

public class HgtHandle {
	public int fd;
	public int blat;
	public int blon;
	private int width;
	private int arc;
	private string fname;

	public static string getbase(double lat, double lon, out int? _oblat, out int? _oblon) {
		var oblat = (int)Math.floor(lat);
		var oblon = (int)Math.floor(lon);
		var _blat = oblat.abs();
		var _blon = oblon.abs();
		char latc = (lat >= 0.0) ? 'N' : 'S';
		char lonc = (lon >= 0.0) ? 'E' : 'W';
		_oblat = oblat;
		_oblon = oblon;
		return "%c%02d%c%03d.hgt".printf(latc, _blat, lonc, _blon);
	}

	public HgtHandle (double lat, double lon) {
		fname = getbase(lat, lon, out blat, out blon);
		var _fname = Path.build_filename(MWP.demdir, fname);
		fd = Posix.open(_fname, Posix.O_RDONLY);
		if (fd != -1) {
			Posix.Stat st;
			if(Posix.stat(_fname, out st) == 0) {
				var ssz = st.st_size /2;
				if (ssz/1201 == 1201) {
					width = 1201;
					arc = 3;
				} else if (ssz/3601 == 3601) {
					width = 3601;
					arc = 1;
				}
			}
		}
	}

	private int16 readpt(int y, int x) {
        int16 hgt = 0xffff;
        var row = width - 1 - y;
		var pos = (2 * (row*width + x));
		uint8 buf[2];
		Posix.lseek(fd, pos, Posix.SEEK_SET);
		var n = Posix.read(fd, buf, 2);
		if (n == 2) {
			hgt = (buf[0]<<8) | buf[1];
        }
        return hgt;
	}

	public double get_elevation(double lat, double lon) {
        var dslat = 3600.0 * (lat - blat);
        var dslon = 3600.0 * (lon - blon);

        var y = (int)dslat / arc;
		var x = (int)dslon / arc;

        int16 elevs[4];
        elevs[0] = readpt(y+1, x);
        elevs[1] = readpt(y+1, x+1);
        elevs[2] = readpt(y, x);
        elevs[3] = readpt(y, x+1);

        var dy = Math.fmod(dslat, arc) / arc;
		var dx = Math.fmod(dslon, arc) / arc;

        var e = elevs[0]*dy*(1-dx) +
			elevs[1]*dy*(dx) +
			elevs[2]*(1-dy)*(1-dx) +
			elevs[3]*(1-dy)*dx;
        return e;
	}
}

public class DEMMgr {
	private HgtHandle [] hgts;
	public DEMMgr() {
		hgts = {};
		/**
		Dir dir = Dir.open (MWP.demdir, 0);
		string? name = null;
		while ((name = dir.read_name ()) != null) {
			string path = Path.build_filename (MWP.demdir, name);
			if (FileUtils.test (path, FileTest.IS_REGULAR)) {
			}
		}
		**/
	}

	~DEMMgr() {
		foreach (var hh in hgts) {
			if (hh.fd != -1) {
				Posix.close(hh.fd);
			}
		}
	}

	public HgtHandle? findHgt(double lat, double lon) {
		int blat;
		int blon;
        HgtHandle.getbase(lat, lon, out blat, out blon);
		foreach (var hh in hgts) {
			if (hh.blat == blat && hh.blon == blon) {
				return hh;
			}
        }
        return null;
	}

	public double lookup(double lat, double lon) {
        var  hh = findHgt(lat, lon);
        if (hh == null) {
			hh  = new HgtHandle(lat, lon);
			if (hh.fd != -1) {
				hgts +=  hh;
			} else {
				hh = null;
				stderr.printf("Failed to open DEM\n");
				return HGT.NODATA;
			}
		}
		return hh.get_elevation(lat, lon);
	}
}

#if TEST
public struct Point {
	double lat;
	double lon;
}

public static int main(string[] args) {
	Point[] pts = {};

	if (args.length < 3 || (args.length&1) == 0) {
		pts = {
			{54.1250310, -4.7300753},
			{54.149461, -4.669315},
			{37.3382131, -122.108032},
			{37.3322088, -122.0847559},
			{50.9153213, -1.53035998},
		};
	} else {
		for(var j = 0; j < args.length; j += 2) {

			var pt = Point();
			pt.lat = double.parse(args[j]);
			pt.lon = double.parse(args[j+1]);
			pts += pt;
		}
	}

	var hdb = new DEMMgr("DEMs");
	foreach (var p in pts) {
		var e0 = hdb.lookup(p.lat, p.lon);
		stdout.printf("Lookup %f %f -> %.1f\n", p.lat, p.lon, e0);
	}
	return 0;
}
#endif
