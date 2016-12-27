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

public class DevManager
{
    private DumpGUI du;
    public static const int RFCOMM_TTY_MAJOR = 216;
    public static const int USB_TTY_MAJOR = 188;

    public DevManager(DumpGUI _u)
    {
        du = _u;
    }

    public void initialise_devices()
    {
            // C:\Documents and Settings\username\Local Settings\Application Data
        var ud = Environment.get_user_data_dir();
        var app = "cf-cli-ui"; //Environment.get_application_name();
        var fn = GLib.Path.build_filename(ud,app,"cf-devices.txt");
        var fp = FileStream.open(fn, "r");
        if(fp == null)
            fp = FileStream.open("cf-devices.txt", "r");

        if(fp != null)
        {
            string line;
            while((line = fp.read_line ()) != null)
            {
                if(line.length > 3)
                    du.add_to_list(line, USB_TTY_MAJOR);
            }
        }
        else
        {
            for (var i = 1; i < 10; i++)
            {
                var s = "COM%d:".printf(i);
                du.add_to_list(s, USB_TTY_MAJOR);
            }
        }
    }
}
