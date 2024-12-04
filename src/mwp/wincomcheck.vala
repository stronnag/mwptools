extern char** check_ports();

namespace Mwp {
	public class SerialWatcher : Object {
		public SerialWatcher() {}
		public void run() {
			Timeout.add(1000, () => {
					var devs = check_ports();
					for (var sptr = devs; *sptr != null; sptr++) {
						Mwp.append_combo(Mwp.dev_combox, (string)*sptr);
						free(*sptr);
					}
					free(devs);
					return true;
				});
		}
	}
}
