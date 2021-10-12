
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

public class MWPUtils
{
    public static bool exists_on_path(string s)
    {
        int n;

        n = Posix.access(s, Posix.X_OK|Posix.R_OK);
        if (n != 0)
        {
            var ep = Environment.get_variable("PATH");
            if (ep != null)
            {
                var parts = ep.split(":");
                foreach(var p in parts)
                {
                    string pp = Path.build_filename(p, s);
                    n = Posix.access(pp, Posix.X_OK|Posix.R_OK);
                    if (n == 0)
                        break;
                }
            }
        }
        return (n == 0);
    }

    private static string? have_conf_file(string fn)
    {
        var file = File.new_for_path (fn);
        if (file.query_exists ())
        {
            return fn;
        }
        else
        {
            return null;
        }
    }

    public static string? find_conf_file(string fn, string? dir=null)
    {
        string cfile=null;
        string wanted = (dir != null) ? dir+"/"+fn  : fn;

        var uc = Environment.get_user_config_dir();
        var app = Environment.get_application_name();
        if(app == null)
            app = MwpVers.progname;

        cfile = have_conf_file(GLib.Path.build_filename(uc,app,wanted));
        if (cfile == null)
        {
            uc =  Environment.get_user_data_dir();
            cfile = have_conf_file(GLib.Path.build_filename(uc,app,wanted));
            if(cfile == null)
            {
                var confdirs = Environment.get_system_data_dirs();
                foreach (string c in confdirs)
                {
                    if ((cfile = have_conf_file(GLib.Path.build_filename (c,app,wanted))) != null)
                        break;
                }
            }

            if (cfile == null)
            {
                cfile = have_conf_file(GLib.Path.build_filename ("./",wanted));
            }
            if (cfile == null)
            {
                cfile = have_conf_file(GLib.Path.build_filename ("./",fn));
            }
        }
        return cfile;
    }
}
