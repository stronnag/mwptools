extern char** check_ports();

namespace Mwp {
	public class SerialWatcher : Object {
		public SerialWatcher() {}
		public void run() {
			Timeout.add(2000, () => {
					var devs = check_ports();
					for (var sptr = devs; *sptr != null; sptr++) {
						Mwp.prepend_combo(Mwp.dev_combox, (string)*sptr);
					}
					var snames = Mwp.list_combo(Mwp.dev_combox);
					foreach (var name in snames) {
						if(name.has_prefix("COM") && name.contains(" \\Device\\")) {
							var found = false;
							for (var sptr = devs; *sptr != null; sptr++) {
								if((string)*sptr == name) {
									found = true;
									break;
								}
							}
							if (!found) {
								Mwp.remove_combo(Mwp.dev_combox, name);
							}
						}
					}
					for (var sptr = devs; *sptr != null; sptr++) {
						free(*sptr);
					}
					free(devs);
					return true;
				});
		}
	}
}
