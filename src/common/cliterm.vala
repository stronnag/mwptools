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

public class CLITerm : Gtk.Window {
#if UNIX
    private MWSerial s;
    private MWSerial.ProtoMode oldmode;
    private Vte.Terminal term;
    public signal void on_exit();
    public signal void reboot();
	public signal void enter_cli();
    public CLITerm (Gtk.Window? w = null) {
        if(w != null) {
            this.set_transient_for (w);
        }
        this.title = "mwp CLI";
        this.close_request.connect (() => {
                uint8 c[1] = {4};
                s.write(c, 1);
                s.pmode = oldmode;
                on_exit();
				return false;
            });
        this.set_default_size (640, 400);
        term = new Vte.Terminal();

        var  cols = new Gdk.RGBA[2];
        cols[0].parse("#002B36");
        cols[1].parse("#839496");
        term.set_color_background(cols[0]);
        term.set_color_foreground(cols[1]);

        term.commit.connect((text,size) => {
                switch(text[0]) {
                    case 3:
                        this.destroy();
                        break;
                    case 8:
                    uint8 c[1] = {127};
                        s.write(c,1);
                        break;
                    case 27:
                        break;
                    default:
                        s.write(text.data, size);
                    break;
                }
            });
        this.set_child (term);
    }

	public void configure_serial (MWSerial _s, bool hash=false) {
        s = _s;
		oldmode  =  s.pmode;
        s.cli_event.connect(() => {
				MWSerial.INAVEvent? m;
				while((m = s.msgq.try_pop()) != null) {
					m.raw[m.len] = 0;
					term.feed(m.raw[0:m.len]);
					if(((string)m.raw).contains("Rebooting")) {
						term.feed("\r\n\n\x1b[1mEither close this window or type # to re-enter the CLI\x1b[0m\r\n".data);
						reboot();
					}
					if (((string)m.raw).contains("Entering") || (m.raw[0] == '#')) {
						enter_cli();
					}
				}
			});

		s.pmode = MWSerial.ProtoMode.CLI;
		if(hash) {
			uint8 c[1] = {'#'};
			s.write(c, 1);
		}
    }
#else
	public void configure_serial (MWSerial _s, bool hash=false) {}
    public CLITerm (Gtk.Window? w = null) {}
#endif
}
