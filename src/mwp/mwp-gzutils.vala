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

namespace GZUtils {
	public void load_dialog() {
		IChooser.Filter []ifm = {
			{"CLI file", {"txt"}},
		};

		var fc = IChooser.chooser(Mwp.conf.missionpath, ifm);
		fc.title = "Load Geozone File";
		fc.modal = true;
		fc.open.begin (Mwp.window, null, (o,r) => {
				try {
					string s;
					var file = fc.open.end(r);
					var fn = file.get_path ();
					Mwp.gzr.from_file(fn);
					if(Mwp.gzone != null) {
						//						Mwp.gzedit.clear(); // FIXME
						Mwp.gzone.remove();
						Mwp.set_gzsave_state(false);
					}
					Mwp.gzone = Mwp.gzr.generate_overlay(); // FIXME
					Mwp.gzone.display();
					//Mwp.gzedit.refresh(gzone); // FIXME
					Mwp.set_gzsave_state(true);
				} catch (Error e) {
					MWPLog.message("Failed to open Geozone file: %s\n", e.message);
				}
			});
	}

	public void save_dialog(bool iskml) {
		IChooser.Filter []ifm;
		string title;

		if (iskml) {
			ifm = {	{"Geozone KML", {"kml"}}, };
			title = "Save KML File";
		} else {
			ifm = {	{"Geozone CLI", {"txt"}}, };
			title = "Save Geozone CLI File";
		}
		var fc = IChooser.chooser(Mwp.conf.missionpath, ifm);
		fc.title = title;
		fc.modal = true;
		fc.save.begin (Mwp.window, null, (o,r) => {
				try {
					string s;
					var fh = fc.save.end(r);
					var fn = fh.get_path ();
					if(iskml) {
						s = KMLWriter.ovly_to_string(Mwp.gzone);
						try {
							FileUtils.set_contents(fn,s );
						} catch (Error e) {
							MWPLog.message("GZ Save %s %s\n", fn,e.message);
						}
					} else {
						Mwp.gzr.save_file(fn);
					}
				} catch (Error e) {
					MWPLog.message("GZ Save %s\n", e.message);
				}
			});
	}
}
