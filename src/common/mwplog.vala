/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 3
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class MWPLog : GLib.Object {

    private static FileStream fs;
    private static bool init = false;
    private static string tfstr;
    private static bool echo = false;
	private static bool addcr;

    public static void set_time_format(string _t) {
        tfstr = _t;
    }

	public static void set_cr() {
		addcr = true;
	}

	public static void fputs(string s) {
        fs.puts(s);
		fs.flush();
    }

    public static void puts(string s) {
        fs.puts(s);
        if(echo)
            stderr.puts(s);
    }

    public static void sputs(string s) {
        if(echo)
            stderr.puts(s);
    }

    public static void message(string format, ...) {
        if(init == false) {
            time_t currtime;
            time_t(out currtime);
			Posix.Stat st;
			if (Posix.fstat(stderr.fileno(), out st) == 0) {
				echo = ((st.st_mode & (Posix.S_IFCHR|Posix.S_IFIFO)) != 0);
			}

			string logdir = UserDirs.get_default();

			var dt = new DateTime.from_unix_local(currtime);
            var fn = Path.build_filename(logdir, "mwp_stderr_%s.txt".printf(dt.format("%F")));

            fs = FileStream.open(fn,"a");
            if(fs == null) {
                echo = false;
                fs  = FileStream.fdopen(stderr.fileno(), "a");
            }

            init = true;

            if ((tfstr = Environment.get_variable ("MWP_TIME_FMT")) == null)
				tfstr = "%T.%f";
        }

        var args = va_list();
        var now = new DateTime.now_local ();
        StringBuilder sb = new StringBuilder();
        sb.append(now.format(tfstr));
        sb.append_c(' ');
        sb.append_vprintf(format, args);
        fs.puts(sb.str);
		fs.flush();
        if(echo) {
			if(addcr) {
				var sout = sb.str.replace("\n", "\r\n");
				stderr.puts(sout);
			} else {
				stderr.puts(sb.str);
			}
		}
	}
}
