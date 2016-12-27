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

using GUdev;

public class DevManager
{
    public const int RFCOMM_TTY_MAJOR = 216;
    public const int USB_TTY_MAJOR = 188;

    private DumpGUI du;
    private GUdev.Client uc;

    public DevManager(DumpGUI _u)
    {
        du = _u;
    }

    private int check_device(GUdev.Device d)
    {
        var maj = int.parse(d.get_property("MAJOR"));
        if (maj != RFCOMM_TTY_MAJOR && maj !=  USB_TTY_MAJOR)
            maj = 0;
        return maj;
    }

    public void initialise_devices()
    {
        var ud = Environment.get_user_config_dir();
        var app = Environment.get_application_name();
        var fn = GLib.Path.build_filename(ud,app,"cf-devices.txt");
        var fp = FileStream.open(fn, "r");
        if(fp != null)
        {
            string line;
            while((line = fp.read_line ()) != null)
            {
                if(line.length > 3)
                    du.add_to_list(line, USB_TTY_MAJOR);
            }
        }
        uc = new GUdev.Client({"tty"});
        int res;
        var devs = uc.query_by_subsystem("tty");
        foreach (var d in devs)
        {
            if((res = check_device(d)) != 0)
            {
                du.add_to_list(d.get_device_file().dup(), res);
            }
        }
        uc.uevent.connect((action,dev) => {
                switch (action)
                {
                    case "add":
                        if(check_device(dev) == USB_TTY_MAJOR)
                        {
                            du.add_to_list(dev.get_device_file().dup(), USB_TTY_MAJOR);
                        }
                        break;
                    case "remove":
                    du.remove_from_list(dev.get_device_file().dup());
                    break;
                }
            });
    }
}
