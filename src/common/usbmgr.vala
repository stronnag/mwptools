#if LINUX
public class USBMgr : Object {
	private GUdev.Client uc;
	public signal void add_device_usb(string name, string alias);
	public signal void remove_device_usb(string name);

	public USBMgr() {
		uc = new GUdev.Client({"tty"});
	}

	public void init() {
        uc.uevent.connect((action, dev) => {
				if(dev.get_property("ID_BUS") == "usb") {
					var ds = dev.get_device_file().dup();
					switch (action) {
					case "add":
						//						print_device(dev);
						var alias =  dev.get_property("ID_MODEL").dup();
						add_device_usb(ds, alias);
						break;
					case "remove":
						remove_device_usb(ds);
						break;
					}
                }
            });
		get_serial_devices();
    }

    private void print_device(GUdev.Device d) {
        StringBuilder sb = new StringBuilder();
        if(d.get_property("ID_BUS") == "usb") {
            sb.append_printf("Registered serial device: %s ", d.get_device_file());
            sb.append_printf("[%s:%s], ", d.get_property("ID_VENDOR_ID"),
                             d.get_property("ID_MODEL_ID"));
            sb.append_printf("Vendor: %s, Model: %s, ",
                             d.get_property("ID_VENDOR"),
                             d.get_property("ID_MODEL"));
            sb.append_printf("Serial: %s, Driver: %s\n",
                             d.get_property("ID_SERIAL_SHORT"),
                             d.get_property("ID_USB_DRIVER"));
            MWPLog.message (sb.str);
        }
    }

	private void get_serial_devices() {
		var devs = uc.query_by_subsystem("tty");
        foreach (var dev in devs) {
            if(dev.get_property("ID_BUS") == "usb") {
                print_device(dev);
				var ds = dev.get_device_file().dup();
				var alias =  dev.get_property("ID_MODEL").dup();
				add_device_usb(ds, alias);
            }
        }
        return;
    }
}
#endif
