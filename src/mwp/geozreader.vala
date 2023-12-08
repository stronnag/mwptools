namespace GeoZoneReader {
	public enum GZType {
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
		uint8 index;
		int latitude;
		int longitude;
	}

	public struct GeoZone {
		uint8 index;
		GZShape shape;
		GZType type;
		int minalt;
		int maxalt;
		GZAction action;
		uint8 nvertices;
		Vertex []vertices;
	}

	private const int W_Thin = 4;
	private const int MAXGZ = 63;
	private const int W_Thick = 12;//012345678
	private const string LCOL_RED = "#ff0000a0";
	private const string LCOL_GREEN = "#00ff00a0";
	private const string FCOL_RED = "#ff00001a";
	private const string FCOL_GREEN = "#00ff001a";

	private static int cnt;
	private static GeoZone[] zs;

	public void reset() {
		cnt = 0;
		zs = {};
	}

	public GeoZone parse(uint8[] buf) {
		uint8* ptr = &buf[0];
		var z = GeoZone();
		z.type = (GZType)*ptr++;
		z.shape = (GZShape)*ptr++;
		ptr = SEDE.deserialise_i32(ptr, out z.minalt);
		ptr = SEDE.deserialise_i32(ptr, out z.maxalt);

		z.action = (GZAction)*ptr++;
		z.nvertices = *ptr++;
		z.index = *ptr++;

		var zvsize = ZSIZEMIN + z.nvertices*VSIZE;
		if(zvsize ==  buf.length) {
			z.vertices = new Vertex[z.nvertices];
			for (var j = 0; j < z.nvertices; j++) {
				var v = Vertex();
				v.index = *ptr++;
				ptr = SEDE.deserialise_i32(ptr, out v.latitude);
				ptr = SEDE.deserialise_i32(ptr, out v.longitude);
				z.vertices[j] = v;
			}
		} else {
			z.nvertices = 0;
		}
		return z;
	}

	/*
	  ACTION  │   TYPE    │ FILL COLOUR │ OUTLINE COLOUR
	  ──────────┼───────────┼─────────────┼─────────────────
	  None    │ Inclusive │    none     │   Green(dots)
	  None    │ Exclusive │    none     │    Red(dots)
	  ------  │ ----      │ ----------- │ --------------
	  Avoid   │ Inclusive │    none     │   Green(thin)
	  Avoid   │ Exclusive │     Red     │    Red(thin)
	  ------  │ ----      │ ----------- │ --------------
	  PosHold │ Inclusive │    None     │   Green(thick)
	  PosHold │ Exclusive │     Red     │    Red(thick)
	  ------  │ ----      │ ----------- │ --------------
	  RTH     │ Inclusive │    Green    │   Green(thick)
	  RTH     │ Exclusive │     Red     │    Red(thick)

	*/

	private Overlay.StyleItem get_style(GeoZone z) {
		Overlay.StyleItem s = Overlay.StyleItem();
		s.styled = true;
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
			s.fill_colour = "";
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

	public Overlay generate_overlay(Champlain.View view) {
		var o = new Overlay(view);
		for(var j = 0; j < zs.length; j++) {
			var oi = Overlay.OverlayItem();
			oi.type = Overlay.OLType.POLYGON;
			oi.name = "V%2d".printf(j);
			oi.styleinfo =  get_style(zs[j]);
			Overlay.Point[] pts = {};
			if (zs[j].shape == GZShape.Circular) {
				var clat = (double)zs[j].vertices[0].latitude/1e7;
				var clon = (double)zs[j].vertices[0].longitude/1e7;
				for (var i = 0; i < 360; i += 5) {
					var p = Overlay.Point();
					var range = (double)zs[j].vertices[1].latitude/(100.0*1852.0);
					Geo.posit(clat, clon, i, range,
							  out p.latitude, out p.longitude);
					pts += p;
				}
			} else {
				for(var k = 0; k < zs[j].vertices.length; k++) {
					var p = Overlay.Point();
					p.latitude = (double)zs[j].vertices[k].latitude / 1e7;
					p.longitude = (double)zs[j].vertices[k].longitude / 1e7;
					pts += p;
				}
			}
			oi.pts = pts;
			o.add_element(oi);
		}
		return o;
	}

	private int append(uint8[] raw, size_t len) {
		if (len > ZSIZEMIN) {
			var z = GeoZoneReader.parse(raw[0:len]);
			zs += z;
		}
		cnt += 1;
		return cnt;
	}

	public string to_string() {
		StringBuilder sb = new StringBuilder();
		foreach (var z in zs) {
			sb.append_printf("geozone %d %d %d %d %d %d\n", z.index, z.shape, z.type,
							 z.minalt, z.maxalt, z.action);
			var k = 0;
			foreach(var v in z.vertices) {
				sb.append_printf("geozone vertex %d %d %d %d\n", z.index, k, v.latitude, v.longitude);
				k++;
			}
		}
		return sb.str;
	}

	public void dump(string _vname) {
		var vname  = _vname;
		if (zs.length > 0) {
			string afn = null;;
			try {
				int fd = FileUtils.open_tmp ("gzones_XXXXXX", out afn);
				var s = to_string();
				Posix.write(fd, s.data, s.length);
				Posix.close(fd);
				try {
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
					string []args = {"geozones", "-name", vname, "-no-points", "-output", outfn, afn};

					var gkml = new Subprocess.newv(args, SubprocessFlags.NONE);
					gkml.wait_check_async.begin(null, (obj,res) => {
							try {
								gkml.wait_check_async.end(res);
							}  catch (Error e) {
								MWPLog.message("gkml spawn %s\n", e.message);
							}
							Posix.unlink(afn);
						});
                } catch (Error e) {
					MWPLog.message("gkml spawn %s\n", e.message);
					Posix.unlink(afn);
                }
			} catch {}
			zs ={};
		}
	}

	bool from_string(string s) {
		MemoryInputStream ms = new MemoryInputStream.from_data (s.data);
		DataInputStream ds = new DataInputStream (ms);
		string line;
		var res = true;
		var maxvtx = 126;
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
						int zid = int.parse(parts[2]);
						var v = Vertex();
						v.index = (uint8)int.parse(parts[3]);
						v.latitude = int.parse(parts[4]);
						v.longitude = int.parse(parts[5]);
						if (zid < zs.length) {
							zs[zid].vertices[v.index] = v;
							zs[zid].nvertices += 1;
							maxvtx -= 1;
						}
						break;
					default:
						var z = GeoZone();
						z.index = (uint8)int.parse(parts[1]);
						z.shape = (GZShape)int.parse(parts[2]);
						z.type =(GZType)int.parse(parts[3]);
						z.minalt = int.parse(parts[4]);
						z.maxalt = int.parse(parts[5]);
						z.action = (GZAction)int.parse(parts[6]);
						z.vertices = new Vertex[maxvtx];
						zs += z;
						break;
					}
				}
			}
			for(var j = 0; j < zs.length; j++) {
				zs[j].vertices.resize(zs[j].nvertices);
			}
		} catch {
			reset();
			res = false;
		}
		return res;
	}

	void from_file(string fn) {
		string str;
		try {
			if(FileUtils.get_contents(fn, out str)) {
				from_string(str);
			}
		} catch {}
	}
}
