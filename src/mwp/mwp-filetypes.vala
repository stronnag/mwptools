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

public enum FType {
	UNKNOWN = 0,
	MISSION = 1,
	BBL = 2,
	OTXLOG = 3,
	MWPLOG = 4,
	KMLZ = 5,
	INAV_CLI = 6,
	INAV_CLI_M = 7,
}

namespace MWPFileType {
		private void handle_file_by_type(FType ftyp, string? fn) {
			switch(ftyp) {
			case FType.MISSION:
				Mwp.mission = fn;
				break;
			case FType.BBL:
				Mwp.bfile = fn;
				break;
			case FType.OTXLOG:
				Mwp.otxfile = fn;
				break;
			case FType.MWPLOG:
				Mwp.rfile = fn;
				break;
			case FType.KMLZ:
				if(Mwp.kmlfile == null) {
					Mwp.kmlfile = fn;
				} else {
					Mwp.kmlfile = string.join(",", Mwp.kmlfile, fn);
				}
				break;
			case FType.INAV_CLI:
				Mwp.sh_load = fn;
				Mwp.gz_load = fn;
				Mwp.sh_disp = true;
				break;
			case FType.INAV_CLI_M:
				if (Mwp.mission == null) {
					Mwp.mission = fn;
				}
				Mwp.sh_load = fn;
				Mwp.gz_load = fn;
				Mwp.sh_disp = true;
				break;
			default:
				break;
			}
		}

	public 	string? validate_cli_file(string fn) {
		var vfn = Posix.realpath(fn);
		if (vfn == null) {
			MWPLog.message("CLI provided file \"%s\" not found\n", fn);
		}
		return vfn;
	}

	public FType guess_content_type(string uri, out string fn) {
		fn="";
		var ftyp = FType.UNKNOWN;
		try {
			if (uri.has_prefix("file://")) {
				fn = Filename.from_uri(uri);
			} else {
				fn = uri;
			}
			uint8 []buf = new uint8[64*1024];
			var fs = FileStream.open (fn, "r");
			if (fs != null) {
				if(fs.read (buf) > 0) {
					var mt = GLib.ContentType.guess(fn, buf, null);
					switch (mt) {
					case "application/vnd.mw.mission":
					case "application/vnd.mwp.json.mission":
						ftyp = FType.MISSION;
						break;
					case "application/vnd.blackbox.log":
						ftyp = FType.BBL;
						break;
					case "application/vnd.otx.telemetry.log":
						ftyp = FType.OTXLOG;
						break;
					case "application/vnd.mwp.log":
						ftyp = FType.MWPLOG;
						break;
					case "application/vnd.google-earth.kmz":
					case "application/vnd.google-earth.kml+xml":
						ftyp = FType.KMLZ;
						break;
					default:
						break;
					}

					if(ftyp == FType.UNKNOWN) {
						if(Regex.match_simple ("^(geozone|safehome) ", (string)buf, RegexCompileFlags.MULTILINE|RegexCompileFlags.RAW)) {
							ftyp = FType.INAV_CLI;
						}
						if (Regex.match_simple("^#wp \\d+ valid", (string)buf, RegexCompileFlags.MULTILINE|RegexCompileFlags.RAW)) {
							ftyp = FType.INAV_CLI_M;
						}
					}
					if(ftyp == FType.UNKNOWN) {
						if(((string)buf).contains("<mission>") || ((string)buf).contains("<MISSION>")) {
							ftyp = FType.MISSION;
						} else if (((string)buf).has_prefix("H Product:Blackbox flight data recorder")) {						ftyp = FType.BBL;
						} else if (((string)buf).has_prefix("{\"type\":\"environment\"")) {
							ftyp = FType.MWPLOG;
						} else if (((string)buf).has_prefix("Date,Time,")) {
							ftyp = FType.OTXLOG;
						} else if (((string)buf).contains("<kml xmlns=\"http://www.opengis.net/kml/2.2\">")) {
							ftyp = FType.KMLZ;
						}
					}
				}
			}
		} catch (Error e) {
			message("regex %s", e.message);
		}
		return ftyp;
	}
}
