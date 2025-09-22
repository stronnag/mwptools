namespace MwpCameras {
	public struct VideoDev {
		string devicename;
		string displayname;
		string driver;
		string launch_props;
		Array<string> caps;
	}

	private struct MPos {
		int sp;
		int ep;
		string str;
	}

	public SList<VideoDev?> list;
	public Cameras cams;
	private VariantDict camdict;

	private string camera_dict_fn() {
		var uc = MWPUtils.get_confdir();
		return GLib.Path.build_filename(uc, ".cameras.v0.dict");
	}

	public void init() {
		if (list == null) {
			list = new SList<VideoDev?>();
			cams =  new Cameras();
			cams.setup_device_monitor();
			Variant x = null;
			try {
				var fn = camera_dict_fn();
				uint8 []data;
				FileUtils.get_data(fn, out data);
				var b = new Bytes(data);
				x = new Variant.from_bytes(VariantType.VARDICT, b, true);
				camdict = new  VariantDict(x);
			} catch (Error e) {
				camdict = new VariantDict();
			}
		}
	}

	public int16 lookup_camera_opt(string cam) {
		var v = camdict.lookup_value(cam,  VariantType.INT16);
		if (v != null) {
			return v.get_int16();
		} else {
			return -1;
		}
	}

	public void update_camera_opt(string cam, int16 v) {
		if (v == -1) {
			camdict.remove(cam);
		} else {
			camdict.insert_value(cam, new Variant.int16(v));
		}
		save_camera_dict();
	}

	public void save_camera_dict() {
		var fn = camera_dict_fn();
		var x = camdict.end();
		var ns = x.get_size();
		if (ns > 0) {
			uint8 []data = new uint8[ns];
			x.store(data);
			try {
				FileUtils.set_data(fn, data);
			} catch (Error e) { }
			var b = new Bytes(data);
			x = new Variant.from_bytes(VariantType.VARDICT, b, true);
			camdict = new  VariantDict(x);
		} else {
			camdict = new VariantDict();
			FileUtils.unlink(fn);
		}
	}

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

	public unowned string[]? get_caps (string devname) {
		unowned var dv = find_camera(devname);
		if (dv != null) {
			return dv.caps.data;
		}
		return null;
	}

	private string[]? replace_caps(string pr) {
		string []res = null;
		MPos []mpos = {};
		int fp=0;
		int lp=0;
		for(; ; ) {
			fp = pr.index_of ("{ ", fp);
			if (fp == -1)
				break;
			lp = pr.index_of(" }", fp);
			if (lp != -1) {
				var m = MPos(){sp=fp, ep=lp+2, str=pr.substring(fp+2, (lp-fp-2))};
				mpos += m;
			}
			fp = lp+2;
		}

		if(mpos.length == 1) {
			res = {};
			var fmt = pr.splice(mpos[0].sp, mpos[0].ep, "%s");
			var parts = mpos[0].str.split(", ");
			foreach (var p in parts) {
				res += fmt.printf(p);
			}
		}
		return res;
	}

	public void process_caps(ref VideoDev ds, string cs) {
		var capstr = cs.split("; ");
		try {
			var regex = new Regex("\\(\\S+\\)");
			foreach(var c in capstr) {
				string pr = regex.replace (c, c.length, 0, "");
				var rparts = replace_caps(pr);
				if (rparts != null) {
					foreach(var r in rparts) {
						ds.caps.append_val(r);
					}
				} else {
					ds.caps.append_val(pr);
				}
			}
		} catch (Error e) {
			print("Regex: %s\n", e.message);
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
			ds.caps = new Array<string>();
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
			var elm = device.create_element(null);
			if (elm != null) {
				var efac  = elm.get_factory();
				if (efac != null) {
					ds.driver = efac.name;
					get_launch_props(elm, ref ds);
				}
			}
			var cs = device.get_caps();
			if (cs != null) {
				process_caps(ref ds, cs.to_string());
			}
			return ds;
		}

		private void get_launch_props(Gst.Element elm, ref VideoDev ds) {
			/*
			  Find the property that differs between the template element and the
			  actual element. This will be the launch properties.
			*/
			const string[] ignore={ "name", "parent", "direction", "template", "caps"};
			var pe = Gst.ElementFactory.make (ds.driver);
			Type type = pe.get_type();
			ObjectClass ocl = (ObjectClass) type.class_ref ();
			foreach (ParamSpec spec in ocl.list_properties ()) {
				var typ = spec.value_type;
				Value v0= new Value(typ);
				Value v1= new Value(typ);
				string name = spec.get_name();
				bool ignored = false;
				foreach (var ign in ignore) {
					if (ign == name) {
						ignored = true;
						break;
					}
				}
				if (!ignored) {
					elm.get_property(name, ref v0);
					pe.get_property(name, ref v1);
					if(Gst.Value.compare(v0, v1)  != Gst.VALUE_EQUAL) {
						var sv = Gst.Value.serialize(v0);
						StringBuilder sb = new StringBuilder();
						sb.append(name);
						sb.append_c('=');
						sb.append(sv);
						ds.launch_props = sb.str;
						break;
					}
				}
			}
			if(ds.launch_props == null) {
				if (ds.devicename != null) {
					ds.launch_props = "device=".concat(ds.devicename);
				} else if (ds.displayname != null) {
					StringBuilder sb = new StringBuilder();
					sb.append("devicename=");
					sb.append_c('"');
					sb.append(ds.displayname);
					sb.append_c('"');
					ds.launch_props = sb.str;
				}
			}
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

		public void check_cams() {
			var ll = monitor.get_devices();
			ll.foreach ((d) => {
					var ds =  get_node_info(d);
					add_list(ds);
				});
#if WINDOWS
			if(list.length() == 0) {
				MWPLog.message("WINDOWS: Use camera fallback\n");
				MainContext.@default().invoke(() => {
						string cs = WinCam.get_cameras();
						MWPLog.message("WINDOWS: Use camera fallback %p\n", cs);
						if (cs != null) {
							var parts = cs.split("\r");
							foreach (var p in parts) {
								MWPLog.message("WIN-FALLBACK: %s\n", p);
								var cparts = p.split("\t");
								VideoDev ds = {};
								ds.caps = new Array<string>();
								ds.displayname = cparts[0];
								ds.devicename = cparts[0];
								ds.driver = "ksvideosrc";
								StringBuilder sb = new StringBuilder("device-name=\"");
								sb.append(ds.displayname);
								sb.append_c('"');
								ds.launch_props = sb.str;
								add_list(ds);
							}
						}
						return false;
					});
			}
#endif
		}

		public void setup_device_monitor () {
			monitor = new Gst.DeviceMonitor ();
			monitor.add_filter ("Video/Source", null);
			check_cams();
			var bus  = monitor.get_bus();
			bus.add_watch(Priority.DEFAULT, bus_callback);
			monitor.start();
		}

		public void stop() {
			monitor.stop();
		}
	}
}
