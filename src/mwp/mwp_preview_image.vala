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


class MissionPix {
	public static string get_cached_mission_image(string mfn) {
        var cached = GLib.Path.build_filename(Environment.get_user_cache_dir(), "mwp");
        try {
            var dir = File.new_for_path(cached);
            dir.make_directory_with_parents ();
        } catch {}

        string md5name = mfn;
        if(!mfn.has_suffix(".mission")) {
            var ld = mfn.last_index_of_char ('.');
            if(ld != -1) {
                StringBuilder s = new StringBuilder(mfn[0:ld]);
                s.append(".mission");
                md5name = s.str;
            }
        }

        var chk = Checksum.compute_for_string(ChecksumType.MD5, md5name);
        StringBuilder sb = new StringBuilder(chk);
        sb.append(".png");
        return GLib.Path.build_filename(cached,sb.str);
    }

	public static void get_mission_pix(GtkChamplain.Embed e, MWPMarkers mk, Mission? ms, string? last_file) {
        if(last_file != null && ms != null) {
            var path = get_cached_mission_image(last_file);
			var wdw = e.get_window();
            var w = wdw.get_width();
            var h = wdw.get_height();
			double dw,dh;
			if(w > h) {
				dw = 256;
				dh = 256* h / w;
			} else {
				dh = 256;
				dw = 256* w / h;
			}

			mk.temp_mission_markers(ms);
			var ssurf = e.champlain_view.to_surface(true);
			var nsurf = new Cairo.Surface.similar (ssurf, Cairo.Content.COLOR, (int)dw, (int)dh);
			var cr = new Cairo.Context(nsurf);
			cr.scale  (dw/w, dh/h);
			cr.set_source_surface(ssurf, 0, 0);
			cr.paint();
			nsurf.write_to_png(path);
			mk.remove_tmp_mission();
        }
    }
}
