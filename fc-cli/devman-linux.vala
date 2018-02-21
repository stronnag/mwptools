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

/*
 * Standalone test with:
 * valac -D TEST --pkg gio-2.0 --pkg gudev-1.0 devman-linux.vala
 */

using GUdev;

public class DevManager
{
    private GUdev.Client uc;
    public signal void device_added (string s);
    public signal void device_removed (string s);

    public DevManager()
    {
        uc = new GUdev.Client({"tty"});
        uc.uevent.connect((action,dev) => {
                if(dev.get_property("ID_BUS") == "usb")
                {
                    var ds = dev.get_device_file().dup();
                     switch (action)
                    {
                        case "add":
                            device_added(ds);
                            break;
                        case "remove":
                            device_removed(ds);
                            break;
                    }
                }
            });
    }

    public string[] get_serial_devices()
    {
        string [] dlist={};
        var devs = uc.query_by_subsystem("tty");
        foreach (var d in devs)
        {
            if(d.get_property("ID_BUS") == "usb")
                dlist += d.get_device_file().dup();
        }
        return dlist;
    }

}

#if TEST
public int main(string?[] args)
{
    var d =  new DevManager();
    d.device_added.connect((s) => {
            print("Add %s\n", s);
        });
    d.device_removed.connect((s) => {
            print("Remove %s\n", s);
        });

    var m = new MainLoop();
    m.run();
    return 0;
}
#endif
