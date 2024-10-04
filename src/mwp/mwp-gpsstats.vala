namespace GPSStats {

	[GtkTemplate (ui = "/org/stronnag/mwp/gps_stats_dialog.ui")]
	public class Window : Adw.Window {
		[GtkChild]
		private unowned Gtk.Label gps_stats_last_dt;
		[GtkChild]
		private unowned Gtk.Label gps_stats_errors;
		[GtkChild]
		private unowned Gtk.Label gps_stats_timeouts;
		[GtkChild]
		private unowned Gtk.Label gps_stats_packets;
		[GtkChild]
		private unowned Gtk.Label gps_stats_hdop;
		[GtkChild]
		private unowned Gtk.Label gps_stats_eph;
		[GtkChild]
		private unowned Gtk.Label gps_stats_epv;

		private uint tid = 0;

		public Window() {
			Timeout.add(1000, () => {
					double hz = 1000.0/Mwp.gpsstats.last_message_dt;
					gps_stats_last_dt.label = "%.1f".printf(hz);
					gps_stats_errors.label = "%u".printf(Mwp.gpsstats.errors);
					gps_stats_packets.label = "%u".printf(Mwp.gpsstats.packet_count);
					gps_stats_timeouts.label = "%u".printf(Mwp.gpsstats.timeouts);
					double hdop, eph, epv;
					hdop = Mwp.gpsstats.hdop * 0.01;
					eph = Mwp.gpsstats.eph * 0.01;
					epv = Mwp.gpsstats.epv * 0.01;
					gps_stats_hdop.label = "%.2f".printf(hdop);
					gps_stats_eph.label = "%.2f".printf(eph);
					gps_stats_epv.label = "%.2f".printf(epv);
					return true;
				});

			close_request.connect(() => {
					if(tid != 0) {
						Source.remove(tid);
					}
					return false;
				});
		}
	}
}