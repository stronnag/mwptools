using Gst;

public class GstMonitor : Gst.Object {
	public struct VideoDev {
		string devicename;
		string displayname;
	}

	public signal void source_changed(string s, VideoDev d);

	private VideoDev get_info(string dn) {
            VideoDev vd = {};
#if LINUX
            var uc = new GUdev.Client({});
            var dv = uc.query_by_device_file(dn);
            string model;
            vd.devicename = dn;
            if (dv != null) {
                model = dv.get_property("ID_MODEL");
                var vendor = dv.get_property("ID_VENDOR");
                if (vendor != model) {
                    model = "%s - %s".printf(model, vendor);
			}
            } else {
                model = "";
            }
            vd.displayname = model;
#else
            vd = {"Camera", dn};
#endif
            return vd;
	}


	private bool bus_callback (Gst.Bus bus, Gst.Message message) {
		Device device;
		switch (message.type) {
		case Gst.MessageType.DEVICE_ADDED:
			message.parse_device_added (out device);
			var s = device.get_properties();
			var dn = s.get_string("api.v4l2.path");
			if (dn != null) {
                            var ds = get_info(dn);
                            source_changed("add", ds);
			}
			break;

//	case Gst.MessageType.DEVICE_REMOVED:
		default:
			message.parse_device_removed (out device);
			var s = device.get_properties();
			var dn = s.get_string("api.v4l2.path");
			if (dn != null) {
                            var ds = get_info(dn);
                            source_changed("remove", ds);
			}
			break;
		}
		return true;
	}

	public DeviceMonitor  setup_device_monitor () {
		var monitor = new DeviceMonitor ();
		var bus  = monitor.get_bus();
		bus.add_watch(Priority.DEFAULT, bus_callback);

		var caps = new Caps.any(); //gst_caps_new_empty_simple ("video/x-raw");
		monitor.add_filter ("Video/Source", caps);
		monitor.start();
		return monitor;
	}
}

#if TEST
static int main (string? []args) {
	Gst.init (ref args);
	var dm = new GstMonitor();
	dm.source_changed.connect((a,d) => {
			print("GST: %s %s <%s>\n", a, d.displayname, d.devicename);
		});
	dm.setup_device_monitor();
	new GLib.MainLoop().run();
	return 0;
}
#endif
