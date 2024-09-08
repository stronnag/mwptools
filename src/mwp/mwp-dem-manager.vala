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

namespace DemManager {
	public DEMMgr? demmgr = null;
    public  AsyncDL? asyncdl = null;
	private string demdir;

	void init() {
		demdir = GLib.Path.build_filename(Environment.get_user_cache_dir(), "mwp", "DEMs");
		var file = File.new_for_path(demdir);
		if(file.query_exists() == false) {
			try {
				file.make_directory_with_parents();
			} catch (Error e) {
				MWPLog.message("Failed to create %s : %s\n", demdir, e.message);
				demdir = null;
			};
		}

		if (demdir != null) {
			demmgr = new DEMMgr();
            asyncdl = new AsyncDL(demdir);
			asyncdl.run_async.begin((obj,res) => {
					asyncdl.run_async.end(res);
				});
		}
	}

	double lookup(double lat, double lon) {
		return demmgr.lookup(lat, lon);
	}
}