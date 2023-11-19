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
		double latitude;
		double longitude;
	}

	public struct GeoZone {
		GZType type;
		GZShape shape;
		double minalt;
		double maxalt;
		GZAction action;
		uint8 nvertices;
		uint8 index;
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
		int32 val;

		var z = GeoZone();
		z.type = (GZType)*ptr++;
		z.shape = (GZShape)*ptr++;
		ptr = SEDE.deserialise_i32(ptr, out val);
		z.minalt = (double)val/100;
		ptr = SEDE.deserialise_i32(ptr, out val);
		z.maxalt = (double)val/100;
		z.action = (GZAction)*ptr++;
		z.nvertices = *ptr++;
		z.index = *ptr++;

		var zvsize = ZSIZEMIN + z.nvertices*VSIZE;
		if(zvsize ==  buf.length) {
			z.vertices = new Vertex[z.nvertices];
			for (var j = 0; j < z.nvertices; j++) {
				var v = Vertex();
				v.index = *ptr++;
				ptr = SEDE.deserialise_i32(ptr, out val);
				if (z.shape == GZShape.Circular && j == 1) {
					v.latitude = (double)val/100.0;
				} else {
					v.latitude = (double)val/1e7;
				}
				ptr = SEDE.deserialise_i32(ptr, out val);
				v.longitude = (double)val/1e7;
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
			oi.type = "Polygon";
			oi.name = "V%2d".printf(j);
			oi.styleinfo =  get_style(zs[j]);
			Overlay.Point[] pts = {};
			if (zs[j].shape == GZShape.Circular) {
				for (var i = 0; i < 360; i += 5) {
					var p = Overlay.Point();
					Geo.posit(zs[j].vertices[0].latitude, zs[j].vertices[0].longitude,
							  i, zs[j].vertices[1].latitude/1852.0,
							  out p.latitude, out p.longitude);
					pts += p;
				}
			} else {
				for(var k = 0; k < zs[j].vertices.length; k++) {
					var p = Overlay.Point();
					p.latitude = zs[j].vertices[k].latitude;
					p.longitude = zs[j].vertices[k].longitude;
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

#if LOCGZTEST
	private void read_from_directory(string dirname) {
		string? name = null;
		cnt = 0;
		try {
			Dir dir = Dir.open (dirname, 0);
			while ((name = dir.read_name ()) != null) {
				string path = Path.build_filename (dirname, name);
				if (FileUtils.test (path, FileTest.IS_REGULAR)) {
					if(name.has_prefix("msp_0x2050_") && name.has_suffix(".dat")) {
						int fd = Posix.open(path, Posix.O_RDONLY);
						if (fd != -1) {
							Posix.Stat st;
							Posix.fstat(fd, out st);
							if (st.st_size > GeoZoneReader.ZSIZEMIN) {
								var buf = new uint8[st.st_size];
                                Posix.read(fd, buf, st.st_size);
                                GeoZoneReader.append(buf, st.st_size);
								Posix.close(fd);
							}
						}
					}
				}
			}
		} catch (Error e) {
			MWPLog.message("Failed to read %s %s\n", MWP.demdir, e.message);
		}
	}

	public Overlay ? test_gz_load(Champlain.View view) {
		Overlay? o = null;
		var gzdir = Environment.get_variable("MWP_ZONE_DIR");
		if (gzdir != null) {
			GeoZoneReader.read_from_directory(gzdir);
			if (zs.length > 0) {
				o  = GeoZoneReader.generate_overlay(view);
			}
		}
		return o;
	}
#endif
}
