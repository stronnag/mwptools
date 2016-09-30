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
