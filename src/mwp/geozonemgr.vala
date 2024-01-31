public class GeoZoneManager {
	public enum GZType {
		Unused = 0xff,
		Exclusive = 0,
		Inclusive = 1,
	}

	public enum GZShape {
		Circular = 0,
		Polygon = 1,
	}

	public enum GZAction {
		None = 0,
		Avoid = 1,
		PosHold = 2,
		RTH = 3,
	}

	const size_t VSIZE = 9;
	const size_t ZSIZEMIN = 13;

	public struct Vertex {
		uint8 zindex;
		uint8 index;
		int latitude;
		int longitude;
	}

	public struct GeoZone {
		GZShape shape;
		GZType type;
		GZAction action;
		int minalt;
		int maxalt;
	}

	public const int MAXGZ = 63;
	private const int MAXVTX = 126;

	private const int W_Thin = 4;
	private const int W_Thick = 12;//012345678
	private const string LCOL_RED = "#ff0000a0";
	private const string LCOL_GREEN = "#00ff00a0";
	private const string FCOL_RED = "#ff00001a";
	private const string FCOL_GREEN = "#00ff001a";

	private GeoZone []zs;
	private Vertex []vs;

	public void reset() {
		for(var k = 0; k < MAXGZ; k++) {
			zs[k].type = GZType.Unused;
		}
		for(var k = 0; k < MAXVTX; k++) {
			vs[k].zindex = 0xff;
		}
	}

	public GeoZoneManager() {
		zs = new GeoZone[MAXGZ];
		vs = new Vertex[MAXVTX];
		reset();
	}

	public uint length() {
		uint n = 0;
		foreach (var z in zs) {
			if(z.type != GZType.Unused)
				n++;
		}
		return n;
	}

	public GeoZone get_zone(uint n) {
		return zs[n];
	}

	public void set_zone (uint n, GeoZone z) {
		zs[n] = z;
	}

	public GZType get_ztype(uint n) {
		return zs[n].type;
	}
	public void set_ztype(uint n, GZType val) {
		zs[n].type = val;
	}

	public GZShape get_shape(uint n) {
		return zs[n].shape;
	}

	public void set_shappe(uint n, GZShape val) {
		zs[n].shape = val;
	}

	public GZAction get_action(uint n) {
		return zs[n].action;
	}

	public void set_action(uint n, GZAction val) {
		zs[n].action = val;
	}

	public void set_minalt(uint n, int val) {
		zs[n].minalt = val;
	}
	public int get_minalt(uint n) {
		return zs[n].minalt;
	}

	public int get_maxalt(uint n) {
		return zs[n].maxalt;
	}

	public void set_maxalt(uint n, int val) {
		zs[n].maxalt = val;
	}

	public void remove_zone(uint n) {
		zs[n].type = GZType.Unused;
		for(var j = 0; j < MAXVTX; j++) {
			if (vs[j].zindex == n) {
				vs[j].zindex = 0xff;
			}
		}

		for(var i = n+1; i < MAXGZ; i++) {
			if(zs[i].type != GZType.Unused) {
				zs[i-1] = zs[i];
				zs[i].type= GZType.Unused;
			}
		}

		for(var j = 0; j < MAXVTX; j++) {
			if(vs[j].zindex > n) {
				vs[j].zindex -= 1;
			}
		}
	}

	public void append_zone(uint n,  GZShape shape,  GZType ztype, int minalt, int maxalt,
							GZAction action) {
		zs[n].shape = shape;
		zs[n].type = ztype;
		zs[n].minalt = minalt;
		zs[n].maxalt = maxalt;
		zs[n].action = action;
	}

	public void append_vertex(uint n, uint zidx, int lat, int lon) {
		var k = find_free_vertex();
		vs[k].zindex = (uint8)n;
		vs[k].index = (uint8)zidx;
		vs[k].latitude = lat;
		vs[k].longitude = lon;
	}

	public void insert_vertex_at(uint n, uint zidx, int lat, int lon) {
		for(var j = 0; j < MAXVTX; j++) {
			if (vs[j].zindex == (uint8)n && vs[j].index == (uint8)zidx) {
				vs[j].index += 1;
			}
		}
		append_vertex(n, zidx, lat, lon);
	}

	public void remove_vertex_at(uint n, uint zidx) {
		var k = find_vertex(n, zidx);
		vs[k].zindex = 0xff;
		for(var j = 0; j < MAXVTX; j++) {
			if (vs[j].zindex == (uint8)n && vs[j].index > (uint8)zidx) {
				vs[j].index -= 1;
			}
		}
	}

	public uint nvertices(uint n) {
		uint k = 0;
		foreach(var v in vs) {
			if(v.zindex == (uint8)n)
				k++;
		}
		return k;
	}

	public int find_free_vertex() {
		int n = 0;
		foreach(var v in vs) {
			if(v.zindex == 0xff)
				return n;
			n++;
		}
		return -1;
	}

	public int find_vertex(uint j, uint k) {
		int n = 0;
		foreach(var v in vs) {
			if(v.zindex == (uint)j && v.index == (uint8)k)
				return n;
			n++;
		}
		return -1;
	}

	public uint[] find_vertices(uint j) {
		uint []nvs = {};
		uint n = 0;
		uint nn = 0;
		foreach(var v in vs) {
			if(v.zindex == (uint8)j) {
				nvs += v.index;
				nvs += n;
				nn++;
			}
			n++;
		}
		var res = new uint[nn];
		for(var k = 0; k < nn; k++) {
			for(var m = 0; m < nvs.length;) {
				if(nvs[m++] == k) {
					res[k] = nvs[m++];
					break;
				} else {
					m++;
				}
			}
		}
		return res;
	}

	public int get_latitude(uint n) {
		return vs[n].latitude;
	}
	public void set_latitude(uint n, int l) {
		vs[n].latitude = l;
	}
	public int get_longitude(uint n) {
		return vs[n].longitude;
	}
	public void set_longitude(uint n, int l) {
		vs[n].longitude = l;
	}

	public uint8[] encode (int n) {
		uint8[] buf;
		if (n < MAXGZ) {
			var vsz = find_vertices(n);
			var zvsize = ZSIZEMIN + vsz.length*VSIZE;
			buf = new uint8[zvsize];
			uint8*ptr = &buf[0];
			*ptr++ = (uint8)zs[n].type;
			*ptr++ = (uint8)zs[n].shape;
			ptr = SEDE.serialise_i32(ptr, zs[n].minalt);
			ptr = SEDE.serialise_i32(ptr, zs[n].maxalt);
			*ptr++ = (uint8)zs[n].action;
			*ptr++ = (uint8)vsz.length;
			*ptr++ = (uint8)n;

			foreach(var v in vsz) {
				*ptr++ = vs[v].index;
				ptr = SEDE.serialise_i32(ptr, vs[v].latitude);
				ptr = SEDE.serialise_i32(ptr, vs[v].longitude);
			}
		} else {
			buf = new uint8[ZSIZEMIN];
			Posix.memset(buf, 0, ZSIZEMIN);
		}
		return buf;
	}

	public int parse(uint8[] buf) {
		uint8* ptr = &buf[0];
		var z = GeoZone();
		z.type = (GZType)*ptr++;
		z.shape = (GZShape)*ptr++;
		ptr = SEDE.deserialise_i32(ptr, out z.minalt);
		ptr = SEDE.deserialise_i32(ptr, out z.maxalt);

		z.action = (GZAction)*ptr++;

		var nvertices = *ptr++;
		var index = (int)*ptr++;
		var zvsize = ZSIZEMIN + nvertices*VSIZE;

		var k = find_free_vertex();
		if(k != -1 && index < MAXGZ && zvsize ==  buf.length) {
			zs[index] = z;
			for (var j = 0; j < nvertices; j++) {
				vs[k].zindex = (uint8)index;
				vs[k].index = *ptr++;
				ptr = SEDE.deserialise_i32(ptr, out vs[k].latitude);
				ptr = SEDE.deserialise_i32(ptr, out vs[k].longitude);
			}
		} else {
			return -1;
		}
		return index;
	}

  /*
# Colours

|  ACTION    |   TYPE      | FILL COLOUR | OUTLINE COLOUR |
| ---------- | ----------- | ----------- | -------------- |
|  None 0    | Inclusive 1 |    none     |   Green(dots)  |
|  None 0    | Exclusive 0 |    none     |    Red(dots)   |
|  Avoid 1   | Inclusive 1 |    none     |   Green(thin)  |
|  Avoid 1   | Exclusive 0 |     Red     |    Red(thin)   |
|  PosHold 2 | Inclusive 1 |    None     |   Green(thick) |
|  PosHold 2 | Exclusive 0 |     Red     |    Red(thick)  |
|  RTH 3     | Inclusive 1 |    Green    |   Green(thick) |
|  RTH 3     | Exclusive 0 |     Red     |    Red(thick)  |
   */

	public OverlayItem.StyleItem fetch_style(uint n) {
		return get_style(zs[n]);
	}

	private OverlayItem.StyleItem get_style(GeoZone z) {
		OverlayItem.StyleItem s = OverlayItem.StyleItem();
		s.styled = true;
		s.line_dotted = false;
		switch (z.type) {
		case GZType.Exclusive:
			s.line_colour = LCOL_RED;
			s.line_width = W_Thick;
			s.fill_colour = null;
			switch (z.action) {
			case GZAction.None:
				s.line_width = W_Thin;
				s.line_dotted = true;
				break;
			case GZAction.Avoid:
				s.line_width = W_Thin;
				s.fill_colour = FCOL_RED;
				break;
			case GZAction.PosHold:
				s.fill_colour = FCOL_RED;
				break;
			case GZAction.RTH:
				s.fill_colour = FCOL_RED;
				break;
			default:
				s.styled = false;
				break;
			}
			break;
		case GZType.Inclusive:
			s.line_colour = LCOL_GREEN;
			s.line_width = W_Thick;
			s.fill_colour = null /*""*/;
			switch (z.action) {
			case GZAction.None:
				s.line_width = W_Thin;
				s.line_dotted = true;
				break;
			case GZAction.Avoid:
				s.line_width = W_Thin;
				break;
			case GZAction.PosHold:
				break;
			case GZAction.RTH:
				s.fill_colour = FCOL_GREEN;
				break;
			default:
				s.styled = false;
				break;
			}
			break;
		default:
			s.styled = false;
			break;
		}
		if (s.line_colour != null && s.line_width == W_Thick) {
			s.line_colour = s.line_colour.replace("a0", "80");
		}
		return s;
	}

	public OverlayItem generate_overlay_item(Overlay o, uint n) {
		var oi = new OverlayItem();
		oi.type = OverlayItem.OLType.POLYGON;
		oi.idx = (uint8)n;
		var sb = new StringBuilder();
		sb.append_printf("geozone %u %d %d %d %d %d", n, zs[n].shape, zs[n].type,
						 zs[n].minalt, zs[n].maxalt, zs[n].action);
		oi.styleinfo =  get_style(zs[n]);

		if (zs[n].shape == GZShape.Circular) {
			oi.name = "Circle %2u".printf(n);
			var nvs = find_vertices(n);
			sb.append_printf(" circle %d %d %d", vs[nvs[0]].latitude, vs[nvs[0]].longitude,
							 vs[nvs[1]].latitude);
			var clat = (double)vs[nvs[0]].latitude/1e7;
			var clon = (double)vs[nvs[0]].longitude/1e7;
			var range = (double)vs[nvs[1]].latitude/(100.0*1852.0);

			oi.circ.lat = clat;
			oi.circ.lon = clon;
			oi.circ.radius_nm = range;
			for (var i = 0; i < 360; i += 5) {
				double plat, plon;
				Geo.posit(clat, clon, i, range, out plat, out plon);
				oi.add_point(plat, plon);
			}
		} else {
			oi.name = "Polygon %2u".printf(n);
			var nvs = find_vertices(n);
			foreach (var l in nvs) {
				double plat = (double)vs[l].latitude / 1e7;
				double plon = (double)vs[l].longitude / 1e7;
				oi.add_point(plat, plon);
			}
		}
		oi.desc = sb.str;
		o.add_element(oi);
		return oi;
	}

	public Overlay generate_overlay(Champlain.View view) {
		var o = new Overlay(view);
		for(var i = 0; i < MAXGZ; i++) {
			if(zs[i].type != GZType.Unused) {
				generate_overlay_item(o, i);
			}
		}
		return o;
	}

	public int append(uint8[] raw, size_t len) {
		if (len > ZSIZEMIN) {
			return parse(raw[0:len]);
		}
		return MAXGZ;
	}

	public string to_string() {
		StringBuilder sb = new StringBuilder();
		int n = 0;
		foreach (var z in zs) {
			if(z.type != GZType.Unused) {
				stderr.printf("GZ %d\n", n);
				sb.append_printf("geozone %d %d %d %d %d %d\n", n, z.shape, z.type,
							 z.minalt, z.maxalt, z.action);
				var nvs = find_vertices(n);
				stderr.printf("Find vertices for %d %u\n", n, nvs.length);
				foreach(var v in nvs) {
					sb.append_printf("geozone vertex %d %d %d %d\n", vs[v].zindex, vs[v].index, vs[v].latitude, vs[v].longitude);
				}
				n++;
			}
		}
		return sb.str;
	}

	public void dump(Overlay ov, string _vname) {
		var vname  = _vname;
		if (length() > 0) {
			time_t currtime;
			string spath = MWP.conf.logsavepath;
			var f = File.new_for_path(spath);
			if(f.query_exists() == false) {
				try {
					f.make_directory_with_parents();
				} catch {
					spath = Environment.get_home_dir();
				}
			}
			time_t(out currtime);
			if (vname == null || vname.length == 0) {
				vname="unknown";
			} else {
				vname = vname.replace(" ", "_");
			}
			var ts = Time.local(currtime).format("%F_%H%M%S");
			var basen = "GeoZones-%s-%s.kml".printf(vname, ts);
			var outfn = GLib.Path.build_filename(spath, basen);
			MWPLog.message("Save KML %s\n", outfn);
			var s = KMLWriter.ovly_to_string(ov);
			try {
				FileUtils.set_contents(outfn, s);
			} catch (Error e) {
				MWPLog.message("kmlwriter: %s\n", e.message);
			}
			reset();
		}
	}

	public bool from_string(string s) {
		MemoryInputStream ms = new MemoryInputStream.from_data (s.data);
		DataInputStream ds = new DataInputStream (ms);
		string line;
		var res = true;
		try {
			reset();
			while ((line = ds.read_line (null)) != null) {
				stderr.printf("%s\n", line);
				if(line.length == 0 || line.has_prefix(";") || line.has_prefix("#")
				   || !line.has_prefix("geozone"))
					continue;
				var parts = line.split(" ");
				if (parts.length > 5) {
					switch (parts[1]) {
					case "vertex":
						var k = find_free_vertex();
						vs[k].zindex = (uint8)int.parse(parts[2]);
						vs[k].index = (uint8)int.parse(parts[3]);
						vs[k].latitude = int.parse(parts[4]);
						vs[k].longitude = int.parse(parts[5]);
						break;
					default:
						var z = GeoZone();
						var index = int.parse(parts[1]);
						z.shape = (GZShape)int.parse(parts[2]);
						z.type =(GZType)int.parse(parts[3]);
						z.minalt = int.parse(parts[4]);
						z.maxalt = int.parse(parts[5]);
						z.action = (GZAction)int.parse(parts[6]);
						zs[index] = z;
						break;
					}
				}
			}
		} catch {
			reset();
			res = false;
		}
		return res;
	}

	public void from_file(string fn) {
		string str;
		try {
			if(FileUtils.get_contents(fn, out str)) {
				from_string(str);
			}
		} catch {}
	}
}
