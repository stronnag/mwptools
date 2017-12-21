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
 */

public class MWPLog : GLib.Object
{
    private static FileStream fs;
    private static bool init = false;

    public static void message(string format, ...)
    {
        if(init == false)
        {
            time_t currtime;
            time_t(out currtime);
            if(Posix.isatty(stderr.fileno()) == false)
            {
                var fn = "mwp_stderr_%s.txt".printf(Time.local(currtime).format("%F"));
                fs = FileStream.open(fn,"a");
            }
            else fs  = FileStream.fdopen(stderr.fileno(), "a");
            init = true;
        }

        var v = va_list();
        var now = new DateTime.now_local ();
        string ds = now.to_string ();
        fs.puts(ds);
        fs.putc(' ');
        fs.puts(format.vprintf(v));
        fs.flush();
    }
}
