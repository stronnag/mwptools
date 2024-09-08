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
 */

namespace Audio {
	uint spktid = 0;

	void play_alarm_sound(string sfn) {
		if(Mwp.conf.beep) {
            var fn = MWPUtils.find_conf_file(sfn);
            if(fn != null) {
				var m = Gtk.MediaFile.for_filename(fn);
				m.notify["ended"].connect(() => {
					});
				m.notify["prepared"].connect(() => {
						var t = m.duration;
						var s = t/1000000;
						var ms = t % 1000000;
					});
				m.play();
			}
		}
	}

	private void start_audio(bool live = true) {
		if (spktid == 0) {
            if(Mwp.window.audio_cb.active) {
                string voice = null;
                switch(Mwp.spapi) {
				case 1:
					voice = Mwp.conf.evoice;
					if (voice == "default")
						voice = "en"; // thanks, espeak-ng
					break;
				case 2:
					voice = Mwp.conf.svoice;
					break;
				case 3:
					voice = Mwp.conf.fvoice;
					break;
				default:
					voice = null;
					break;
                }
                //navstatus.logspeak_init(voice, (conf.uilang == "ev"), exvox);
                spktid = Timeout.add_seconds(Mwp.conf.speakint, () => {
                        if(Mwp.replay_paused == false) {
                            //navstatus.announce(sflags); // FIXME
						}
                        return Source.CONTINUE;
                    });
                if(live) {
                    /* FIXME
					   gps_alert(0);
					   navstatus.announce(sflags);
					*/
                }
            }
        }
    }

    private void stop_audio() {
        if(spktid > 0) {
			Source.remove(spktid);
			spktid = 0;
            //navstatus.logspeak_close(); // FIXME
        }
    }
}