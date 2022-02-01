using Gtk;
using Clutter;
using Champlain;
using GtkChamplain;

namespace GCSDebug {
	bool debug;
}

public class GCSIcon : GLib.Object {
	private static Champlain.Label icon;
	public static Champlain.Label? gcs_icon() {
		try {
			var actor = new Clutter.Actor ();
			var img =MWPMarkers.load_image_from_file("gcs.svg", MWP.conf.misciconsize, MWP.conf.misciconsize);
			double w, h;
			img.get_preferred_size(out w, out h);
			actor.set_size((int)w, (int)h);
			actor.content = img;
			icon = new Champlain.Label.with_image(actor);

			icon.set_pivot_point(0.5f, 0.5f);
			icon.set_draw_background (false);
            icon.set_selectable(false);
            icon.set_draggable(true);
			FakeHome.get_hmlayer().add_marker(icon);
			icon.visible = false;
			icon.opacity = 200;
			if (MWP.conf.gpsdhost != "") {
				var g = new GpsdReader();
				g.read_gps.begin();
				g.gpsd_result.connect((s) => {
						if (s == null) {
							Timeout.add_seconds(60, () => {
									g.read_gps.begin();
									return false;
								});
						} else {
							var d = g.gpsd_parse(s);
							if ((d.mask & (GpsdReader.Mask.TIME|GpsdReader.Mask.LAT|GpsdReader.Mask.LON)) != 0) {
								if (d.fix == 3) {
									icon.set_location(d.lat, d.lon);
								}
							}
						}
				});
			}
			return icon;
		} catch {}
		return null;
	}

	public static void set_location(double lat, double lon) {
		icon.set_location(lat, lon);
	}

	public static void default_location(double lat, double lon) {
		if(icon.latitude == 0 && icon.longitude == 0)
			icon.set_location(lat, lon);
	}

	public static void set_visible(bool state) {
		icon.visible = state;
	}

	public static void show() {
		icon.visible = true;
	}

	public static void hide() {
		icon.visible = false;
	}

	public static bool get_location(out double lat, out double lon) {
		if(icon.visible) {
			lat = icon.latitude;
			lon = icon.longitude;
			return true;
		} else {
			lat = -91;
			lon = -181;
			return false;
		}
	}
}

public class GpsdReader :Object {
	public enum Mask {
		TIME = (1<<0),
		FIX = (1<<1),
		LAT = (1<<2),
		LON = (1<<3),
		ALT = (1<<4),
		CSE = (1<<5),
		SPD = (1<<6),
	}

	public struct Gpsd_data {
		Mask mask;
		uint8 fix;
		int alt;
		int cse;
		int spd;
		double lat;
		double lon;
		string time;
	}
	public signal void gpsd_result(string? d);
	private SocketConnection conn;
	private int lastsec = -1;
	public async bool read_gps()  throws Error {
		try {
			var resolver = Resolver.get_default ();
			var addresses = yield resolver.lookup_by_name_async (MWP.conf.gpsdhost, null);
			var address = addresses.nth_data (0);
			var  client = new SocketClient ();
			conn = yield client.connect_async (new InetSocketAddress (address, 2947));
			if(GCSDebug.debug)
				MWPLog.message("GCSLOC: Connected to gpsd\n");

		} catch (Error e) {
			if(GCSDebug.debug)
				MWPLog.message("GPSLOC: gpsd connection %s\n", e.message);
			gpsd_result(null);
			return false;
		}
		conn.output_stream.write("""?WATCH={"enable":true,"json":true}""".data);
		var fd = conn.socket.fd;
		var io_read = new IOChannel.unix_new(fd);
		if(io_read.set_encoding(null) != IOStatus.NORMAL)
			error("Failed to set encoding");
		io_read.add_watch(IOCondition.IN|IOCondition.HUP, (chan, cond) => {
				string str = null;
				size_t length = -1;
				size_t pos = 0;
				if (cond == IOCondition.HUP) {
					gpsd_result(null);
					return false;
				}
				try {
					IOStatus status = chan.read_line (out str, out length, out pos);
					if (status == IOStatus.EOF) {
						gpsd_result(null);
						return false;
					}
					gpsd_result(str);
					return true;
				} catch (IOChannelError e) {
					stderr.printf ("IOChannelError: %s\n", e.message);
				return false;
				} catch (ConvertError e) {
					stderr.printf ("ConvertError: %s\n", e.message);
					return false;
				}
			});
		return true;
	}

	public Gpsd_data gpsd_parse(string data) {
		var d = Gpsd_data();
		try {
			var parser = new Json.Parser ();
			parser.load_from_data ((string) data);
			var obj = parser.get_root ().get_object ();
			var klass = obj.get_string_member ("class");
			switch (klass) {
			case "TPV":
				if (obj.has_member("time")) {
					d.time = obj.get_string_member("time");
					d.mask |= Mask.TIME;
 #if USE_TV1
					var q = d.time.split("T:+-");
					var dt = new DateTime.local(
						int.parse(q[0]), int.parse(q[1]),
						int.parse(q[2]),
						int.parse(q[3]), int.parse(q[4]),
						double.parse(q[5]));

#else
					var dt = new DateTime.from_iso8601 (d.time, null);
#endif
					if (dt.get_second() != lastsec) {
                                            if (obj.has_member("mode")) {
							d.fix = (uint8)obj.get_int_member("mode");
							d.mask |= Mask.FIX;
						}
						if (obj.has_member("lat")) {
							d.lat = obj.get_double_member("lat");
							d.mask |= Mask.LAT;
						}
						if (obj.has_member("lon")) {
							d.lon = obj.get_double_member("lon");
							d.mask |= Mask.LON;
						}
						if (obj.has_member("alt")) {
							d.alt = (int)obj.get_double_member("alt");
							d.mask |= Mask.ALT;
						}
						if (obj.has_member("track")) {
							d.cse = (int)obj.get_double_member("track");
							d.mask |= Mask.CSE;
						}
						if (obj.has_member("speed")) {
							d.spd = (int)obj.get_double_member("speed");
							d.mask |= Mask.SPD;
						}
						lastsec = dt.get_second();
					}
				}
				if(GCSDebug.debug) {
					if ((d.mask & (GpsdReader.Mask.TIME)) == GpsdReader.Mask.TIME) {
						if (d.fix == 3) {
							MWPLog.message("GCSLOC: %s %.6f %.6f\n", d.time, d.lat, d.lon);
						} else {
							MWPLog.message("GCSLOC: %s %d\n", d.time, d.fix);
						}
					} else {
						MWPLog.message("GCSLOC: %s\n", (string) data);
					}
				}
				break;
			default:
				break;
			}
		} catch {}
		return d;
	}
}
