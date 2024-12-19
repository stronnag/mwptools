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

namespace GCS {
	bool debug;
	MWPMarker icon=null;

	public void init() {
		if(Gpsd.reader == null) {
			Gpsd.init();
		}
		if(icon == null) {
			GCS.create_icon();
		}
	}

	public MWPMarker? create_icon () {
		try {
			var img = Img.load_image_from_file("gcs.svg", Mwp.conf.misciconsize,Mwp.conf.misciconsize);
			icon = new MWPMarker.from_image(img);
			Gis.hm_layer.add_marker (icon);
			icon.visible = false;
			icon.opacity = 0.8;
			icon.set_draggable(true);
			if(Gpsd.reader != null) {
				Gpsd.reader.gpsd_result.connect((s) => {
						if(s != null && s.contains("TPV")) {
							var d = Gpsd.parse(s);
							if ((d.mask & (Gpsd.Mask.TIME|Gpsd.Mask.LAT|Gpsd.Mask.LON)) != 0 && d.fix == 3) {
								icon.set_location(d.lat, d.lon);
							}
						}
					});
			}
			MWPLog.message("Generated GCS icon\n");
			return icon;
		} catch (Error e) {
			MWPLog.message("Failed to generate GCS icon: %s\n", e.message);
			return null;
		}
	}

	public void set_location(double lat, double lon) {
		icon.set_location(lat, lon);
	}

	public void default_location(double lat, double lon) {
		if(icon.latitude == 0 && icon.longitude == 0) {
			icon.set_location(lat, lon);
		}
	}

	public void set_visible(bool state) {
		icon.visible = state;
	}

	public void show() {
		icon.visible = true;
	}

	public void hide() {
		icon.visible = false;
	}

	public bool get_location(out double lat, out double lon) {
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

namespace Gpsd {
	[Flags]
	public enum Mask {
		TIME,
		FIX,
		LAT,
		LON,
		ALT,
		CSE,
		SPD,
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

	private int lastsec = -1;
	Reader reader;

	void init() {
		if (Mwp.conf.gpsdhost != "") {
			reader = new Gpsd.Reader();
			reader.try_gps_read();
		}
	}

	public Gpsd_data parse(string data) {
		Gpsd_data d = {};
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
					var dt = new DateTime.from_iso8601 (d.time, null);

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
					}
				}
				if(GCS.debug) {
					if ((d.mask & Mask.TIME) == Mask.TIME) {
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
		} catch (Error e) {
			MWPLog.message("GPSd parser: %s\n", e.message);
		}
		return d;
	}

	public class Reader :Object {
		public signal void gpsd_result(string? d);
		private SocketConnection conn;

		public void try_gps_read() {
			this.read_gps.begin((obj,res) => {
					try {
						var ares = this.read_gps.end(res);
						if (!ares) {
							Timeout.add_seconds(30, () => {
									try_gps_read();
									return false;
								});
						}
					} catch {}
				});
		}

		public async bool read_gps()  throws Error {
			try {
				var resolver = Resolver.get_default ();
				var addresses = yield resolver.lookup_by_name_async (Mwp.conf.gpsdhost, null);
				var address = addresses.nth_data (0);
				var  client = new SocketClient ();
				conn = yield client.connect_async (new InetSocketAddress (address, 2947));
				if(GCS.debug)
					MWPLog.message("GCSLOC: Connected to gpsd\n");

			} catch (Error e) {
				if(GCS.debug)
					MWPLog.message("GPSLOC: gpsd connection %s\n", e.message);
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
	}
}