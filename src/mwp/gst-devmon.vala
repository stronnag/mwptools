using Gst;

public class GstMonitor : Gst.Object {
	public struct VideoDev {
            string devicename;
            string displayname;
	}

	public bool verbose;

	public signal void source_changed(string s, VideoDev d);

        private string[] namekeys = {
            "api.v4l2.cap.card", "node.description", "device.product.name",
            "v4l2.device.card", "device.serial"
        };

        private VideoDev? get_node_info(Device device) {
            var s = device.get_properties();
            if(verbose) {
                var p = s.to_string();
                var parts = p.split(", ");
                foreach(var pl in parts) {
                    print("%s\n", pl);
                }
            }

            var dn = s.get_string("api.v4l2.path");
            if (dn == null)
                dn = s.get_string("device.path");
            if (dn != null) {
                VideoDev ds = {};
                ds.devicename = dn;
                foreach (var nk in namekeys) {
                    var nks = s.get_string(nk);
                    if (nks != null) {
                        ds.displayname = nks;
                        break;
                    }
                }
                if(ds.displayname == null) {
                    ds.displayname = "?Camera?";
                }
                return ds;
            }
            return null;
        }

        private bool bus_callback (Gst.Bus bus, Gst.Message message) {
		Device device;
		switch (message.type) {
		case Gst.MessageType.DEVICE_ADDED:
                    message.parse_device_added (out device);
                    var ds = get_node_info(device);
                    if (ds != null) {
                        source_changed("add", ds);
                    }
                    break;

//	case Gst.MessageType.DEVICE_REMOVED:
		default:
                    message.parse_device_removed (out device);
                    var ds = get_node_info(device);
                    if (ds != null) {
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

//		var caps = new Caps.any(); //gst_caps_new_empty_simple ("video/x-raw");
		var caps = new Caps.empty();
		caps.append(new Caps.empty_simple ("video/x-raw"));
		caps.append(new Caps.empty_simple ("image/jpeg"));
		monitor.add_filter ("Video/Source", caps);
		var devs = monitor.get_devices();
		//		devs.@foreach((dv) => {
		for (unowned var lp = devs.first(); lp != null; lp = lp.next) {
			var dv = lp.data;
			var ds = get_node_info(dv);
			if(ds != null)
				source_changed("init", ds);
		}
		monitor.start();
		return monitor;
	}

#if TEST
        public static int main (string? []args) {
            Gst.init (ref args);
            var dm = new GstMonitor();
			dm.verbose = true;
			dm.source_changed.connect((a,d) => {
                    print("GST: \"%s\" %s <%s>\n", a, d.displayname, d.devicename);
                });
            dm.setup_device_monitor();
            new GLib.MainLoop().run(/* */);
            return 0;
        }
#endif
}