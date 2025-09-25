/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * (c) Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */



namespace Mwp {
	namespace Shortcuts {
#if ADW_SHORTCUTS
		public void show_dialog() {
			var schash = new HashTable<string, string> (str_hash, str_equal);
			schash.insert("win.mission-append", "Append mission file to current mission");
			schash.insert("win.mission-save", "Save mission to extant file");
			schash.insert("win.mission-save-as", "Save mission to new file");
			schash.insert("win.clifile", "Open CLI file (mission,safehome,geozone etc.");
			schash.insert("win.download-mission", "Download mission from FC");
			schash.insert("win.replay-sql-log", "Replay log file");
			schash.insert("win.replay-raw-log", "Replay raw file");
			schash.insert("win.stop-replay", "Stop raw replay");
			schash.insert("win.kml-load", "Load KML overlay");
			schash.insert("win.kml-remove", "Unload KML overlay");
			schash.insert("win.gz-load", "Load Geozone file");
			schash.insert("win.gz-edit", "Edit Geozones");
			schash.insert("win.gz-save", "Save Geozones to CLI file");
			schash.insert("win.gz-kml", "Save Geozones as KML file");
			schash.insert("win.gz-clear", "Clear Geozones");
			schash.insert("win.gz-check", "Validate Geozones");
			schash.insert("win.gz-dl", "Download Geozones from FC");
			schash.insert("win.gz-ul", "Upload Geozones to FC");
			schash.insert("win.safe-homes", "Invoke Safe home dialog");
			schash.insert("win.assistnow", "Invoke Assist Now dialog");
			schash.insert("win.followme", "Invoke MSP Follow-me dialog");
			schash.insert("win.msprc", "Show MSPRC dialog");
			schash.insert("win.mwpset", "All settings dialog");
			schash.insert("win.areap", "Invoke the survey / area planner");
			schash.insert("win.mman", "Multi-mission manager");
			schash.insert("win.mission-info", "(not implemented)");
			schash.insert("win.seed-map", "Invoke the map seeder");
			schash.insert("win.audio-test", "Invoke the audio test");
			schash.insert("win.recentre", "Zoom to mission");
			schash.insert("win.defloc", "Save current location as default");
			schash.insert("win.centre-on", "Centre on position chooser");
			schash.insert("win.gps-stats", "Show GPS statistics");
			schash.insert("win.radar-view", "Invoke the radar view");
			schash.insert("win.ttrack-view", "Invoke the telemetry tracker dialog");
			schash.insert("win.vstream", "Invoke the video stream dialog");
			schash.insert("win.locicon", "Toggle the display of the GCS icon");
			schash.insert("win.manual", "Load the mwp user guide");
			schash.insert("win.keys", "Show this shortcut keys window");

			schash.insert("win.about", "About");
			schash.insert("win.cliploc", "Location (raw) to clipboard");
			schash.insert("win.fmtcliploc", "Location (formatted) to clipboard");
			schash.insert("win.mission-open", "Open Mission File");
			schash.insert("win.dmeasure", "Measurement tool");
			schash.insert("win.hardreset", "Reset display");
			schash.insert("win.clearmission", "Clear Mission");
			schash.insert("win.pausereplay", "Pause raw replay / video");
			schash.insert("win.go-base", "Centre on preference location");
			schash.insert("win.go-home", "Cente on home location");
			schash.insert("win.toggle-home", "Toggle home icon display");
			schash.insert("win.toggle-fs", "Toggle full screen");
			schash.insert("win.handle-connect", "Toggle connection state");
			schash.insert("win.show-serial-stats", "Insert serial stats into log file");
			schash.insert("win.upload-mission", "Upload current mission to FC");
			schash.insert("win.upload-missions", "Upload all missions to FC");
			schash.insert("win.restore-mission", "Restore mission from FC");
			schash.insert("win.store-mission", "Save mission to FC EEPROM");
			schash.insert("win.prefs", "Show preferences dialog");
			schash.insert("win.terminal", "Open CLI terminal");
			schash.insert("win.reboot", "Reboot FC");
			schash.insert("win.flight-stats", "Display flight statistics");
			schash.insert("win.quit", "Quit the application");
			schash.insert("win.radar-devices", "Invoke radar device dialog");
			schash.insert("win.vlegend", "Show the ADSB altitude legend");
			schash.insert("win.trackdump", "Write current telemetry data to logfile");
			schash.insert("win.mtote", "Invoke the mission tote");
			schash.insert("win.usemsprc", "Toggle MSPRC");
			schash.insert("win.show-channels", "Show MSPRC channels");
			schash.insert("win.modeswitch", "Toggle FPV Mode");

			var scview = new Adw.ShortcutsDialog();
			scview.title = "Mwp Shortcuts";
			var scsect = new Adw.ShortcutsSection("Avaialble Shortcuts");
			scview.add(scsect);
			var sas = Mwp.window.application.list_action_descriptions();
			foreach(var a in sas) {
				var kas = Mwp.window.application.get_accels_for_action(a);
				foreach (var k in kas) {
					var aname = schash.get(a);
					if (aname == null) {
						aname = a;
					}
					var scitem = new Adw.ShortcutsItem(aname, k);
					scsect.add(scitem);
				}
			}
			scview.present(Mwp.window);
		}
#else
		public void show_dialog() {
			var sc = new SCWindow();
			sc.present();
		}

		public class SCWindow : Object {
			private Gtk.ShortcutsWindow scview;
			public SCWindow() {
				var builder = new Gtk.Builder.from_resource("/org/stronnag/mwp/mwpsc.ui");
				scview = builder.get_object("scwindow") as Gtk.ShortcutsWindow;
				var scsect = builder.get_object("shortcuts") as Gtk.ShortcutsSection;
				scsect.visible = true;
				scview.transient_for = Mwp.window;
			}
			public void present() {
				scview.present();
			}
		}
#endif
	}
}
