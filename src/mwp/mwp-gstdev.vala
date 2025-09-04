namespace MwpCameras {
	public struct VideoDev {
		string devicename;
		string displayname;
		string driver;
	}
	public SList<VideoDev?> list;
	public Cameras cams;

	public void init() {
		if (list == null) {
			list = new SList<VideoDev?>();
			cams =  new Cameras();
			cams.setup_device_monitor();
		}
	}

	/**
	public unowned SList<VideoDev?>? find_camera(string name) {
		SearchFunc<VideoDev?, string> sfunc = (g,t) => {
			return strcmp(t, g.displayname);
		};
		unowned var ll = list.search(name, sfunc);
		if (ll != null && ll.length() > 0) {
			return ll;
		}
		return null;
	}
	**/

	public unowned VideoDev? find_camera(string name) {
		SearchFunc<VideoDev?, string> sfunc = (g,t) => {
			return strcmp(t, g.displayname);
		};
		unowned var ll = list.search(name, sfunc);
		if (ll != null && ll.length() > 0) {
			return ll.nth_data(0);
		}
		return null;
	}

	public void get_details (string devname, out string device, out string v4l2src) {
		device=null;
		v4l2src=null;
		unowned var dv = find_camera(devname);
		if (dv != null) {
			device = dv.devicename;
			v4l2src = dv.driver;
		}
	}

	public class Cameras : Gst.Object {
		private Gst.DeviceMonitor monitor;
		public signal void updated();

		private string[] namekeys = {
			"api.v4l2.cap.card", "node.description", "device.product.name",
			"v4l2.device.card", "device.serial"
		};

		private VideoDev? get_node_info(Gst.Device device) {
			VideoDev ds = {};
			ds.displayname = device.display_name;
			var s = device.get_properties();
			if (s != null) {
				var dn = s.get_string("api.v4l2.path");
				if (dn == null)
					dn = s.get_string("device.path");

				if (dn == null)
					dn = s.get_string("device.name");

				if (dn != null) {
					ds.devicename = dn;
					foreach (var nk in namekeys) {
						var nks = s.get_string(nk);
						if (nks != null) {
							ds.displayname = nks;
							break;
						}
					}
				}
				if(ds.displayname == null) {
					ds.displayname = "?Camera?";
				}
			}
			if (ds.devicename == null) {
				ds.devicename = ds.displayname;
			}
			var elm = device.create_element(null);
			if (elm != null) {
				var efac  = elm.get_factory();
				if (efac != null) {
					ds.driver = efac.name;
					if (ds.driver == "pipewiresrc") {
						ds.driver = "v4l2src";
					}
				}
			}
			return ds;
		}

		private void add_list(VideoDev ds) {
			unowned var dv = find_camera(ds.displayname);
			if(dv == null) {
				list.append(ds);
			}
		}

		private void remove_list(VideoDev ds) {
			unowned var dv = find_camera(ds.displayname);
			if (dv != null) {
				list.remove(dv);
			}
		}

		private bool bus_callback (Gst.Bus bus, Gst.Message message) {
			Gst.Device device;
			switch (message.type) {
			case Gst.MessageType.DEVICE_ADDED:
				message.parse_device_added (out device);
				var ds = get_node_info(device);
				if (ds != null) {
					add_list(ds);
					updated();
				}
				break;

			case Gst.MessageType.DEVICE_REMOVED:
				message.parse_device_removed (out device);
				var ds = get_node_info(device);
				if (ds != null) {
					remove_list(ds);
					updated();
				}
				break;
			default:
				break;
			}
			return true;
		}

		public void setup_device_monitor () {
			monitor = new Gst.DeviceMonitor ();
			var caps = new Gst.Caps.empty_simple ("video/x-raw");
			var cid= monitor.add_filter ("Video/Source", caps);
			caps = new Gst.Caps.empty_simple ("image/jpeg");
			cid = monitor.add_filter ("Video/Source", caps);
			var bus  = monitor.get_bus();
			bus.add_watch(Priority.DEFAULT, bus_callback);
			monitor.start();
		}
	}
}

#if TEST
public static int main (string? []args) {
	var ml = new GLib.MainLoop();
	Gst.init (ref args);

	Idle.add (() => {
			MwpCameras.init();
			MwpCameras.cams.updated.connect(() => {
					if ( MwpCameras.list.is_empty()) {
						print("<empty>\n");
					} else {
						MwpCameras.list.@foreach((c) => {
							print("  %s = %s [%s]\n", c.displayname, c.devicename, c.driver);
						});
					}
				});
			return false;
		});

	ml.run();
	return 0;
}
#endif
