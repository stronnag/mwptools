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

namespace Mwp {
	public void setup_terminal_reboot()  {
		var saq = new GLib.SimpleAction("terminal",null);
        saq.activate.connect(() => {
				var txpoll = nopoll;
				var in_cli = false;
				var devname = msp.get_devname();
				if(msp.available && armed == 0) {
					mq.clear();
					serstate = SERSTATE.NONE;
					nopoll = true;
					CLITerm t = new CLITerm(window);
					t.on_exit.connect(() => {
							MWPLog.message("Dead  terminal\n");
							//							if (in_cli) {
							Msp.close_serial();
							Timeout.add_seconds_once(2, () => {
									Msp.try_reopen(devname);
									nopoll = txpoll;
									//serstate = SERSTATE.NORMAL;
								});
							t=null;
						});
					t.reboot.connect(() => {
							MWPLog.message("Terminal reboot signalled\n");
							in_cli = false;
							Timeout.add_seconds_once(2, () => {
									Msp.try_reopen(devname);
									nopoll = txpoll;
								});
						});

					t.enter_cli.connect(() => {
							in_cli = true;
							nopoll = true;
							mq.clear();
							serstate = SERSTATE.NONE;
						});
					t.configure_serial(msp, true);
					t.present ();
				}
			});
		window.add_action(saq);

        saq = new GLib.SimpleAction("reboot",null);
        saq.activate.connect(() => {
				if(msp.available && armed == 0) {
					queue_cmd(Msp.Cmds.REBOOT,null, 0);
				}
            });
        window.add_action(saq);
	}
}