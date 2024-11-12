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

	const size_t VERTSIZEP = 10;
	const size_t VERTSIZEC = 14;
	const size_t ZONESIZE = 14;

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
		uint8 isAMSL;
		uint8 vrec; // to upload only
	}

	private struct ZoneColours {
		string lncolour;
		uint lnwidth;
		uint lndashed;
		string? fillcolour;
	}

	public const int MAXGZ = 63;
	private const int MAXVTX = 126;

	private const int W_Thin = 4;
	private const int W_Thick = 10;
	private const int W_OpacHack = 8;
	private const string LCOL_RED = "rgba(255,0,0,0.625)";
	private const string LCOL_GREEN = "rgba(0,255,0,0.625)";
	private const string FCOL_RED = "rgba(255,0,0,0.125)";
	private const string FCOL_GREEN = "rgba(0,255,0,0.125)";

	private GeoZone []zs;
	private Vertex []vs;
	private ZoneColours [,] zc;

	private int8 _nextz;
	private int8 _nextv;

	public void reset() {
		for(var k = 0; k < MAXGZ; k++) {
			zs[k].type = GZType.Unused;
		}
		for(var k = 0; k < MAXVTX; k++) {
			vs[k].zindex = 0xff;
		}
		_nextz = 0;
		_nextv = 0;
	}

	private bool get_next_vertex() {
		_nextv++;
		if (_nextv >= zs[_nextz].vrec || (zs[_nextz].shape == GZShape.Circular && _nextv > 0)) {
			_nextv = 0;
			_nextz++;
			if(_nextz >= MAXGZ) {
				_nextz = -1;
				return false;
			}
		}
		if (zs[_nextz].vrec == 0) {
			return false;
		}
		return true;
	}

	public GeoZoneManager() {
		zs = new GeoZone[MAXGZ];
		vs = new Vertex[MAXVTX];
		init_colours();
		try_user_colours();
		reset();
	}

	private void init_colours() {
		zc = new ZoneColours[2,4];
		zc[GZType.Exclusive, GZAction.None    ] = {LCOL_RED, W_Thin, W_Thin, null};
		zc[GZType.Exclusive, GZAction.Avoid   ] = {LCOL_RED, W_Thin, 0, FCOL_RED};
		zc[GZType.Exclusive, GZAction.PosHold ] = {LCOL_RED, W_Thick, 0, FCOL_RED};
		zc[GZType.Exclusive, GZAction.RTH     ] = {LCOL_RED, W_Thick, 0, FCOL_RED};
		zc[GZType.Inclusive, GZAction.None    ] = {LCOL_GREEN, W_Thin, W_Thin, null};
		zc[GZType.Inclusive, GZAction.Avoid   ] = {LCOL_GREEN, W_Thin,  0, null};
		zc[GZType.Inclusive, GZAction.PosHold ] = {LCOL_GREEN, W_Thick, 0, null};
		zc[GZType.Inclusive, GZAction.RTH     ] = {LCOL_GREEN, W_Thick, 0, FCOL_GREEN};
	}

		private string? parse_colour(string s) {
		Gdk.RGBA col = Gdk.RGBA();
		string rbg = s;
		double falpha = 0.0;
		if(s[0] == '#' && s.length == 9) {
			rbg = s[0:7];
			int a;
			//			int.try_parse(s[7:9], out a, null, 16); // Cygwin alas
			a = (int)MwpLibC.strtol (s[7:9], null, 16);
			falpha = (double)(a/256.0);
		} else {
			var ss = s.split(";");
			if(ss.length == 2) {
				rbg = ss[0];
				falpha=double.parse(ss[1]);
			}
		}

		if(col.parse(rbg)) {
			if(falpha != 0) {
				col.alpha = (float)falpha;
			}
			return col.to_string();
		} else {
			return null;
		}
	}

	private bool normalise_colour(string s, out string? col) {
		bool ok = false;
		var fcol = s.strip();
		if (fcol.length > 0) {
			col = parse_colour(fcol);
			if( col != null) {
				ok = true;
			}
		} else {
			col = null;
			ok = true;
		}
		return ok;
	}

	public void try_user_colours() {
		var fn = MWPUtils.find_conf_file("zone_colours");
		if(fn != null) {
			FileStream fs = FileStream.open (fn, "r");
			if(fs != null) {
				string s;
				int lineno = 0;
				while((s = fs.read_line()) != null) {
					lineno++;
					if(s.strip().length > 0 && !s.has_prefix("#") && !s.has_prefix(";")) {
						bool ok = false;
						var parts = s.split("|");
						if(parts.length == 6) {
							uint i,j,lw;
							//if (uint.try_parse(parts[0], out i)) { // replaced for cygwin
							i = (uint)MwpLibC.strtoul(parts[0], null, 0);
							{
							    //if (uint.try_parse(parts[1], out j)) {
								j = (uint)MwpLibC.strtoul(parts[1], null, 0);
								{
									if(parts[2].strip().length != 0) {
										//if (uint.try_parse(parts[3], out lw)) {
										lw = (uint)MwpLibC.strtoul(parts[3], null, 0);
										{
											if(i < 2 && j < 4) {
												uint dl;
												//if(uint.try_parse (parts[4], out dl)) {
												dl = (uint)MwpLibC.strtoul(parts[4], null, 0);
												{
													zc[i,j].lnwidth = lw;
													zc[i,j].lndashed = dl;
													if(normalise_colour(parts[2], out zc[i,j].lncolour)) {
														ok = normalise_colour(parts[5], out zc[i,j].fillcolour);
													}
												}
											}
										}
									}
								}
							}
						}
						if(!ok) {
							MWPLog.message("%s failed to parse line %d, %s\n", fn, lineno, s);
						}
					}
				}
			}
		}
	}

	public uint length() {
		uint n = 0;
		foreach (var z in zs) {
			if(z.type != GZType.Unused)
				n++;
		}
		return n;
	}

	public bool validate() {
		bool ok = true;
		for(var i = 0; i < 63; i++) {
			var j = nvertices(i);
			if (zs[i].vrec != j) {
				ok = false;
				MWPLog.message("Zone %d fails vertex count validation\n", i);
			}
		}
		return ok;
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

	public void set_amsl(uint n, uint8 val) {
		zs[n].isAMSL = val;
	}

	public uint8 get_amsl(uint n) {
		return zs[n].isAMSL;
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
			if (vs[j].zindex == (uint8)n) {
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
			if(vs[j].zindex != 0xff) {
				if(vs[j].zindex > n) {
					vs[j].zindex -= 1;
				}
			}
		}
	}

	public void append_zone(uint n,  GZShape shape,  GZType ztype, int minalt, int maxalt,
							uint8 isAMSL, GZAction action, uint8 vrec=0) {
		zs[n].shape = shape;
		zs[n].type = ztype;
		zs[n].minalt = minalt;
		zs[n].maxalt = maxalt;
		zs[n].isAMSL = isAMSL;
		zs[n].action = action;
		zs[n].vrec = vrec;
	}

	public int append_vertex(uint n, uint zidx, int lat, int lon) {
		var k = find_free_vertex();
		if(k != -1) {
			vs[k].zindex = (uint8)n;
			vs[k].index = (uint8)zidx;
			vs[k].latitude = lat;
			vs[k].longitude = lon;
		}
		return k;
	}

	public void insert_vertex_at(uint n, uint zidx, int lat, int lon) {
		for(var j = 0; j < MAXVTX; j++) {
			if (vs[j].zindex == (uint8)n && vs[j].index >= (uint8)zidx) {
				vs[j].index += 1;
			}
		}
		append_vertex(n, zidx, lat, lon);
	}

	public void remove_vertex_at(uint n, uint zidx) {
		var k = find_vertex(n, zidx);
		if (k == -1) {
			MWPLog.message("BUG: Failed to find %u %u\n", n, zidx);
		} else {
			vs[k].zindex = 0xff;
			for(var j = 0; j < MAXVTX; j++) {
				if (vs[j].zindex == (uint8)n && vs[j].index > (uint8)zidx) {
					vs[j].index -= 1;
				}
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

	/*
	public void dump_vertices(uint n) {
		uint k = 0;
		foreach(var v in vs) {
			if(v.zindex == (uint8)n) {
				stderr.printf("DBG: %u Vertex %u %u %d %d\n", k, v.zindex, v.index, v.latitude, v.longitude);
			}
			k++;
		}
	}
	*/
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

	public uint8[] encode_zone (int n) {
		var buf = new uint8[ZONESIZE];
		GLib.Memory.@set(buf, 0, ZONESIZE);
		if (n < MAXGZ) {
			var vsz = find_vertices(n);
			uint8*ptr = &buf[0];
			zs[n].vrec = (uint8)vsz.length;
			*ptr++ = (uint8)n;
			if (zs[n].vrec > 0 ) {
				*ptr++ = (uint8)zs[n].type;
				*ptr++ = (uint8)zs[n].shape;
				ptr = SEDE.serialise_i32(ptr, zs[n].minalt);
				ptr = SEDE.serialise_i32(ptr, zs[n].maxalt);
				*ptr++ = zs[n].isAMSL;
				*ptr++ = (uint8)zs[n].action;
			}
			buf[13] = zs[n].vrec;
		}
		return buf;
	}

	public void init_vertex_iter() {
		_nextz = 0;
		_nextv = 0;
	}

	public uint8[] encode_next_vertex () {
		var mbuf =  encode_vertex (_nextz, _nextv);
		if (mbuf.length > 0) {
			if (zs[_nextz].shape == GZShape.Circular) {
				_nextz++;
				_nextv = 0;
			} else {
				_nextv++;
				if (_nextv >= zs[_nextz].vrec) {
					_nextz++;
					_nextv = 0;
				}
			}
		}
		return mbuf;
	}


	private  uint8[] encode_vertex (int nz, int nv) {
		var k = find_vertex((uint)nz, (uint)nv);
		if (k != -1) {
			uint8 []buf;
			if(zs[nz].shape == GZShape.Circular) {
				var k1 = find_vertex((uint)nz, 1);
				if (k1 == -1) {
					return {};
				}
				buf = new uint8[VERTSIZEC];
				SEDE.serialise_i32(&buf[10], vs[k1].latitude);
			} else {
				buf = new uint8[VERTSIZEP];
			}
			uint8*ptr = &buf[0];
			*ptr++ = (uint8)nz;
			*ptr++ = (uint8)nv;
			ptr = SEDE.serialise_i32(ptr, vs[k].latitude);
			ptr = SEDE.serialise_i32(ptr, vs[k].longitude);
			return buf;
		}
		return {};
	}


	public int zone_decode(uint8[] buf) {
		uint8* ptr = &buf[0];
		var index = *ptr++;
		var ztype = (GZType)*ptr++;
		var shape = (GZShape)*ptr++;
		int minalt, maxalt;
		ptr = SEDE.deserialise_i32(ptr, out minalt);
		ptr = SEDE.deserialise_i32(ptr, out maxalt);
		var isAMSL = *ptr++;
		var action = (GZAction)*ptr++;
		var nvertices = *ptr++;
		if(index < MAXGZ) {
			if (nvertices > 0) {
				append_zone(index, shape, ztype, minalt, maxalt, isAMSL, action, nvertices);
			}
		} else {
			return -1;
		}
		return (int)index;
	}

	public void vertex_decode(uint8[] buf) {
		uint8* ptr = &buf[0];
		var zid = *ptr++;
		var vid = *ptr++;
		int lat, lon;
		ptr = SEDE.deserialise_i32(ptr, out lat);
		ptr = SEDE.deserialise_i32(ptr, out lon);
		append_vertex(zid, vid, lat, lon);
		if(buf.length == VERTSIZEC) {
			int alt;
			ptr = SEDE.deserialise_i32(ptr, out alt);
			append_vertex(zid, vid+1, alt, 0);
		}
	}

	public OverlayItem.StyleItem fetch_style(uint n) {
		return get_style(zs[n]);
	}

	private string adjust_colour(string s) {
		Gdk.RGBA col = Gdk.RGBA();
		col.parse(s);
		col.alpha *= 0.8f;
		return col.to_string();
	}

	private OverlayItem.StyleItem get_style(GeoZone z) {
		OverlayItem.StyleItem s = OverlayItem.StyleItem();
		s.styled = true;
		s.line_colour = zc[z.type, z.action].lncolour;
		s.line_width = zc[z.type, z.action].lnwidth;
		s.line_dash = zc[z.type, z.action].lndashed;
		s.fill_colour = zc[z.type, z.action].fillcolour;
		if (s.line_colour != null && s.line_width > W_OpacHack) {
			s.line_colour = adjust_colour(s.line_colour);
		}
		return s;
	}

	public OverlayItem generate_overlay_item(Overlay o, uint n) {
		bool genok = false;
		var oi = new OverlayItem();
		oi.type = OverlayItem.OLType.POLYGON;
		oi.idx = (uint8)n;
		var sb = new StringBuilder();
		sb.append_printf("geozone %u %d %d %d %d %d %d", n, zs[n].shape, zs[n].type,
						 zs[n].minalt, zs[n].maxalt, zs[n].isAMSL, zs[n].action);
		oi.styleinfo =  get_style(zs[n]);
		if (zs[n].shape == GZShape.Circular) {
			oi.name = "Circle %2u".printf(n);
			var nvs = find_vertices(n);
			if (nvs.length == 2) {
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
					oi.add_line_point(plat, plon, "");
				}
				genok = true;
			}
		} else {
			oi.name = "Polygon %2u".printf(n);
			var nvs = find_vertices(n);
			if(nvs.length > 2) {
				var j = 0;
				foreach (var l in nvs) {
					double plat = (double)vs[l].latitude / 1e7;
					double plon = (double)vs[l].longitude / 1e7;
					oi.add_line_point(plat, plon, "%u/%d".printf(n, j));
					j++;
				}
				genok = true;
			}
		}
		oi.desc = sb.str;
		o.add_element(oi);
		if (!genok) {
			MWPLog.message("failed to generate overlay item\n");
		}
		return oi;
	}

	public Overlay generate_overlay() {
		var o = new Overlay();
		for(var i = 0; i < MAXGZ; i++) {
			if(zs[i].type != GZType.Unused) {
				generate_overlay_item(o, i);
			}
		}
		return o;
	}

	public int zone_parse(uint8[] raw, size_t len) {
		if (len == ZONESIZE) {
			return 1+zone_decode(raw[0:len]);
		}
		return MAXGZ;
	}

	public bool vertex_parse(uint8[] raw, size_t len, out int8 nzone, out int8 nvert) {
		bool res = false;
		nzone = -1;
		nvert = -1;
		if (len == VERTSIZEP || len == VERTSIZEC) {
			vertex_decode(raw[0:len]);
			_nextz = (int8)raw[0];
			_nextv = (int8)raw[1];
			res =  get_next_vertex();
			if (res) {
				nzone = (int8) _nextz;
				nvert = (int8) _nextv;
			}
		}
		return res;
	}

	public void save_file(string filename) {
		var s = to_string();
		UpdateFile.save(filename, "geozone", s);
	}

	public string to_string() {
		StringBuilder sb = new StringBuilder();
		int n = 0;
		foreach (var z in zs) {
			if(z.type != GZType.Unused) {
				sb.append_printf("geozone %d %d %d %d %d %d %d\n", n, z.shape, z.type,
								 z.minalt, z.maxalt, z.isAMSL, z.action);
				var nvs = find_vertices(n);
				foreach(var v in nvs) {
					sb.append_printf("geozone vertex %d %d %d %d\n", vs[v].zindex, vs[v].index, vs[v].latitude, vs[v].longitude);
				}
				n++;
				sb.append_c('\n');
			}
		}
		return sb.str;
	}

	public void dump(Overlay ov, string _vname) {
		var vname  = _vname;
		if (length() > 0) {
			time_t currtime;
			string spath = Mwp.conf.logsavepath;
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
						z.isAMSL = (uint8) int.parse(parts[6]);
						z.action = (GZAction)int.parse(parts[7]);
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
