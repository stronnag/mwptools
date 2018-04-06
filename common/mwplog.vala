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
    private static string tfstr;

    public static void set_time_format(string _t)
    {
        tfstr = _t;
    }

    public static void puts(string s)
    {
        fs.puts(s);
    }

    public static void message(string format, ...)
    {
        if(init == false)
        {
            var s = Environment.get_variable("MWP_NOLOG_REDIRECT");
            time_t currtime;
            time_t(out currtime);
            if(s == null && Posix.isatty(stderr.fileno()) == false)
            {
                var fn = "mwp_stderr_%s.txt".printf(Time.local(currtime).format("%F"));
                fs = FileStream.open(fn,"a");
            }

            if(fs == null)
                fs  = FileStream.fdopen(stderr.fileno(), "a");

            init = true;
            if(tfstr == null)
                tfstr = "%FT%T%z";
        }

        var v = va_list();
        var now = new DateTime.now_local ();
        string ds = now.format(tfstr);
        fs.puts(ds);
        fs.putc(' ');
        fs.puts(format.vprintf(v));
        fs.flush();
    }
}
