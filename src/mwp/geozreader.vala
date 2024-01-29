public class GeoZoneReader {
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
		unowned List<Vertex?> vertices;
	}

	private const int W_Thin = 4;
	public const int MAXGZ = 63;
	private const int W_Thick = 10;//012345678
	private const string LCOL_RED = "#ff0000a0";
	private const string LCOL_GREEN = "#00ff00a0";
	private const string FCOL_RED = "#ff00001a";
	private const string FCOL_GREEN = "#00ff001a";

	private int cnt;
	private List<GeoZone?> zs;

	public GeoZoneReader() {
		zs = new List<GeoZone?>();
	}

	public uint length() {
		return zs.length();
	}

	public unowned GeoZone nth_data(uint n) {
		return zs.nth_data(n);
	}

	public void remove_zone(uint nitem) {
		zs.remove(zs.nth_data(nitem));
		zs.remove_link(zs.nth(nitem));
	}

	public void reset() {
		cnt= 0;
		zs.foreach((ze) => {
				unowned var vv = ze.vertices;
				while(!vv.is_empty()) {
					vv.remove_link(vv);
				}
			});

		while(!zs.is_empty()) {
			zs.remove(zs.data);
			zs.remove_link(zs);
		}
	}

	public void parse(uint8[] buf) {
		uint8* ptr = &buf[0];
		var ztype = (GZType)*ptr++;
		var zshape = (GZShape)*ptr++;
		int minalt, maxalt;
		ptr = SEDE.deserialise_i32(ptr, out minalt);
		ptr = SEDE.deserialise_i32(ptr, out maxalt);

		var action = (GZAction)*ptr++;
		var nvertices = *ptr++;
		var index = *ptr++;
		append_zone(index, zshape, ztype, minalt, maxalt, action);

		var zvsize = ZSIZEMIN + nvertices*VSIZE;
		if(zvsize ==  buf.length) {
			for (var j = 0; j < nvertices; j++) {
				var vindex = *ptr++;
				int vlat, vlon;
				ptr = SEDE.deserialise_i32(ptr, out vlat);
				ptr = SEDE.deserialise_i32(ptr, out vlon);
				append_vertex(index, vindex, vlat, vlon);
			}
		}
	}

	/*
	  ACTION    |   TYPE      | FILL COLOUR | OUTLINE COLOUR
	  -------------------------------------------------------
	  None 0    │ Inclusive 1 |    none     │   Green(dots)
	  None 0    │ Exclusive 0 │    none     │    Red(dots)
	  ------------------------------------------------------
	  Avoid 1   │ Inclusive 1 │    none     │   Green(thin)
	  Avoid 1   │ Exclusive 0 │     Red     │    Red(thin)
	  ------------------------------------------------------
	  PosHold 2 │ Inclusive 1 │    None     │   Green(thick)
	  PosHold 2 │ Exclusive 0 │     Red     │    Red(thick)
	  ------------------------------------------------------
	  RTH 3     │ Inclusive 1 │    Green    │   Green(thick)
	  RTH 3     │ Exclusive 0 │     Red     │    Red(thick)

	*/

	private OverlayItem.StyleItem get_style(GeoZone z) {
		OverlayItem.StyleItem s = OverlayItem.StyleItem();
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

	public OverlayItem generate_overlay_item(Overlay o, GeoZone ze, int j) {
		var oi = new OverlayItem();
		oi.type = OverlayItem.OLType.POLYGON;
		oi.idx = ze.index;
		var sb = new StringBuilder();
		sb.append_printf("geozone %d %d %d %d %d %d", ze.index, ze.shape, ze.type,
						 ze.minalt, ze.maxalt, ze.action);
		oi.styleinfo =  get_style(ze);
		if (ze.shape == GZShape.Circular) {
			oi.name = "Circle %2d".printf(j);
			sb.append_printf(" circle %d %d %d", ze.vertices.nth_data(0).latitude,
							 ze.vertices.nth_data(0).longitude,
							 ze.vertices.nth_data(1).latitude);
			var clat = (double)ze.vertices.nth_data(0).latitude/1e7;
			var clon = (double)ze.vertices.nth_data(0).longitude/1e7;
			var range = (double)ze.vertices.nth_data(1).latitude/(100.0*1852.0);
			oi.circ.lat = clat;
			oi.circ.lon = clon;
			oi.circ.radius_nm = range;
			for (var i = 0; i < 360; i += 5) {
				double plat, plon;
				Geo.posit(clat, clon, i, range, out plat, out plon);
				oi.add_point(plat, plon);
			}
		} else {
			oi.name = "Polygon %2d".printf(j);
			var k = 0;
			ze.vertices.foreach((ve) => {
					double plat = (double)ve.latitude / 1e7;
					double plon = (double)ve.longitude / 1e7;
					oi.add_point(plat, plon);
					k++;
				});
		}
		oi.desc = sb.str;
		o.add_element(oi);
		return oi;
	}

	public Overlay generate_overlay(Champlain.View view) {
		var o = new Overlay(view);
		var j = 0;
		zs.foreach((ze) => {
				generate_overlay_item(o, ze, j);
				j++;
			});
		return o;
	}

	public int append(uint8[] raw, size_t len) {
		if (len > ZSIZEMIN) {
			parse(raw[0:len]);
		}
		cnt += 1;
		return cnt;
	}

	public string to_string() {
		StringBuilder sb = new StringBuilder();
		zs.foreach((z) => {
				sb.append_printf("geozone %d %d %d %d %d %d\n", z.index, z.shape, z.type,
								 z.minalt, z.maxalt, z.action);
				z.vertices.foreach((v) => {
						sb.append_printf("geozone vertex %d %d %d %d\n", z.index, v.index, v.latitude, v.longitude);
					});
			});
		return sb.str;
	}

	public void dump(Overlay ov, string _vname) {
		var vname  = _vname;
		if (zs.length() > 0) {
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
				if(line.length == 0 || line.has_prefix(";") || line.has_prefix("#")
				   || !line.has_prefix("geozone"))
					continue;
				var parts = line.split(" ");
				if (parts.length > 5) {
					switch (parts[1]) {
					case "vertex":
						append_vertex(int.parse(parts[2]),
									  int.parse(parts[3]),
									  int.parse(parts[4]),
									  int.parse(parts[5]));
						break;
					default:
						append_zone(
							int.parse(parts[1]),
							int.parse(parts[2]),
							int.parse(parts[3]),
							int.parse(parts[4]),
							int.parse(parts[5]),
							int.parse(parts[6]));
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

	public void append_vertex(int zid, int idx, int lat, int lon) {
		var v = Vertex();
		v.index = (uint8)idx;
		v.latitude = lat;
		v.longitude = lon;
		if (zid < zs.length()) {
			zs.nth_data(zid).vertices.append(v);
			zs.nth_data(zid).nvertices += 1;
		}
	}

	public void insert_vertex_position(int zid, int idx, int lat, int lon) {
		var v = Vertex();
		v.index = (uint8)idx;
		v.latitude = lat;
		v.longitude = lon;
		if (zid < zs.length()) {
			zs.nth_data(zid).vertices.insert(v, idx);
			zs.nth_data(zid).nvertices += 1;
			uint8 j = 0;
			zs.nth_data(zid).vertices.foreach((v) => {
					v.index = j;
					j++;
				});
		}
	}

	public uint append_zone(uint id, int shape, int ztype, int minalt, int maxalt, int action) {
		var z = GeoZone();
		z.index = (uint8)id;
		z.shape = (GZShape)shape;
		z.type  = (GZType)ztype;
		z.minalt = minalt;
		z.maxalt = maxalt;
		z.action = (GZAction)action;
		var uv = new List<Vertex?>();
		z.vertices = uv;
		zs.append(z);
		return zs.length();
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

namespace KMLWriter {
	private string fixcol(string col) {
		StringBuilder sb = new StringBuilder();
		sb.append(col[7:9]);
		sb.append(col[5:7]);
		sb.append(col[3:5]);
		sb.append(col[1:3]);
		return sb.str;
	}

	public string ovly_to_string(Overlay o) {
		string s;
        Xml.Doc* doc = new Xml.Doc ("1.0");
		Xml.Node* root = new Xml.Node (null, "kml");
        doc->set_root_element (root);
		var ns = new Xml.Ns (root, "http://www.opengis.net/kml/2.2", "gx");
		Xml.Node* comment = new Xml.Node.comment ("created from mwp");
        root->add_child (comment);
		Xml.Node* folder;
		folder = root->new_text_child (ns, "Folder", "");
		folder->new_text_child (ns, "name", "Zones");
		folder->new_text_child (ns, "open", "1");
		int j = 0;
		o.get_elements().foreach((el) => {
			var sname = "StyleItem_%d".printf(j);
			var style = folder->new_text_child (ns, "Style", "");
			style->new_prop ("id", sname);
			Xml.Node* style_item;
			if(el.styleinfo.point_colour != null && el.styleinfo.point_colour != "")  {
				style_item = style->new_text_child (ns, "IconStyle", "");
				style_item->new_text_child (ns, "scale", "1");
				style_item->new_text_child (ns, "color", fixcol(el.styleinfo.point_colour));
			}
			style_item = style->new_text_child (ns, "PolyStyle", "");
			if(el.styleinfo.fill_colour != null && el.styleinfo.fill_colour != "")  {
				style_item->new_text_child (ns, "color", fixcol(el.styleinfo.fill_colour));
			} else {
				style_item->new_text_child (ns, "color", "00000000");
			}
			if(el.styleinfo.line_colour != null && el.styleinfo.line_colour != "")  {
				style_item = style->new_text_child (ns, "LineStyle", "");
				style_item->new_text_child (ns, "color", fixcol(el.styleinfo.line_colour));
				style_item->new_text_child (ns, "width", el.styleinfo.line_width.to_string());
			}
			var vfolder = folder->new_text_child (ns, "Folder", "");
			vfolder->new_text_child (ns, "visibility", "1");
			vfolder->new_text_child (ns, "name", el.name);
			vfolder->new_text_child (ns, "description", el.desc);
			int alt = 0;
			if(el.desc.has_prefix("geozone")) {
				var gels = el.desc.split(" ");
				if (gels.length >= 7) {
					Xml.Node* xdata = new Xml.Node (ns, "ExtendedData");
					var gns = xdata->new_ns("http://geo.daria.co.uk/zones/1.0", "gzone");
					xdata->new_text_child (gns, "id", gels[1]);
					xdata->new_text_child (gns, "shape", gels[2]);
					xdata->new_text_child (gns, "type", gels[3]);
					xdata->new_text_child (gns, "minalt", gels[4]);
					xdata->new_text_child (gns, "maxalt", gels[5]);
					alt = int.parse(gels[5])/100;
					xdata->new_text_child (gns, "action", gels[6]);
					if(gels.length == 11 && gels[7] == "circle") {
						xdata->new_text_child (gns, "centre-lat", gels[8]);
						xdata->new_text_child (gns, "centre-lon", gels[9]);
						xdata->new_text_child (gns, "radius", gels[10]);
					}
					vfolder->add_child(xdata);
				}
			}
			var pmark = vfolder->new_text_child (ns, "Placemark", "");
			pmark->new_text_child (ns, "name", el.name);
			pmark->new_text_child (ns, "styleUrl", "#%s".printf(sname));
			var polyg = pmark->new_text_child (ns, "Polygon", "");
			polyg->new_text_child (ns, "altitudeMode", "relativeToGround");
			polyg->new_text_child (ns, "extrude", "1");
			polyg->new_text_child (ns, "tessellate", "0");
			var obis = polyg->new_text_child (ns, "outerBoundaryIs", "");
			var lring = obis->new_text_child (ns, "LinearRing", "");
			var sb = new StringBuilder();

			foreach (var p in  el.mks) {
				sb.append_printf("%.7f,%.7f,%d ", p.longitude, p.latitude, alt);
			}
			sb.append_printf("%.7f,%.7f,%d", el.mks.nth_data(0).longitude, el.mks.nth_data(0).latitude, alt);
			lring->new_text_child (ns, "coordinates", sb.str);
			j++;
			});
		doc->dump_memory_enc_format (out s, null, "utf-8", false);
		return s;
	}
}
