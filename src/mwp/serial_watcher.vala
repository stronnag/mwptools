namespace Mwp {
	public class SerialWatcher : Object {
		public SerialWatcher() {}
		public void run() {
			Timeout.add(2000, () => {
					var devs = MwpMisc.check_ports();
					if (devs != null) {
						for (var sptr = devs; *sptr != null; sptr++) {
							if (Mwp.find_combo(Mwp.dev_combox, (string)*sptr) == -1) {
								var addme = MwpMisc.check_insert_name(*sptr);
								if (addme == 1) {
									Mwp.prepend_combo(Mwp.dev_combox, (string)*sptr);
								} else if (addme == -1) {
									Mwp.append_combo(Mwp.dev_combox, (string)*sptr);
								}
							}
						}
					}
					var snames = Mwp.list_combo(Mwp.dev_combox);
					foreach (var name in snames) {
						if(MwpMisc.check_delete_name((char*)name.data) == 0) {
							var found = false;
							if (devs != null) {
								for (var sptr = devs; *sptr != null; sptr++) {
									if((string)*sptr == name) {
										found = true;
										break;
									}
								}
							}
							if (!found) {
								Mwp.remove_combo(Mwp.dev_combox, name);
							}
						}
					}
					if (devs != null) {
						for (var sptr = devs; *sptr != null; sptr++) {
							free(*sptr);
						}
						free(devs);
					}
					return true;
				});
		}
	}
}
