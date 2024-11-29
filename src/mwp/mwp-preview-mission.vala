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
public class Previewer : Object {
	private MissionPreviewer mprv;
	private bool preview_running = false;
	Thread<int> thr = null;
	int fds[2];
	Craft pcraft;
	double posn[3];

	public Previewer() {
		MwpMenu.set_menu_state(Mwp.window, "mpreview", false);
		MwpMenu.set_menu_state(Mwp.window, "mxpreview", true);
        mprv = new MissionPreviewer();
		fds={-1,-1};
	}

	public void run() {
		pcraft = new Craft("mpreview.svg");
        pcraft.new_craft(false);

#if UNIX
		try {
			GLib.Unix.open_pipe(fds, 0);
		} catch (Error e) {
			MWPLog.message("Unix Pipe %s\n", e.message);
		}
#else
		MwoPipe.pipe(fds);
#endif

		mprv.is_mr = false;
		mprv.fd = fds[1];

		mprv.mission_replay_event.connect(() => {
				var n = Posix.read(fds[0], posn, 3*sizeof(double));
				if (n == 3*sizeof(double)) {
					pcraft.set_lat_lon(posn[0], posn[1], posn[2]);
				} else {
					done();
				}
			});

		mprv.mission_replay_done.connect(() => {
				done();
			});

		var ms = MissionManager.current();
		if (ms.points[ms.npoints-1].action == Msp.Action.RTH) {
			if (HomePoint.is_valid()) {
				HomePos hpos = HomePos(){ hlat=HomePoint.lat(), hlon=HomePoint.lon(), valid=true};
				mprv.set_home(hpos);
			}
		}

        thr = mprv.run_mission(ms);
        preview_running = true;
    }

	private void done() {
		preview_running = false;
		thr.join();
		MwpMenu.set_menu_state(Mwp.window, "mxpreview", false);
		Timeout.add_seconds(2,() => {
				pcraft.park();
				MwpMenu.set_menu_state(Mwp.window, "mpreview", true);
				MwpMenu.set_menu_state(Mwp.window, "mxpreview", false);
				return false;
			});
		Posix.close(fds[0]);
	}

    public void quit() {
        if (preview_running)
            mprv.stop();
    }
}