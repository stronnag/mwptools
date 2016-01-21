
/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */


/* Based on the Multiwii UBLOX parser, GPL by a cast of thousands */

// valac --pkg posix --pkg gio-2.0 --pkg posix  ublox.vapi ublox-test.vala -o ublox-test

public static MainLoop ml;
public static int main (string[] args)
{
    var s = new MWSerial();
    ml = new MainLoop();
    if (s.parse_option(args) == 0)
    {
        if(s.ublox_open(MWSerial.devname, MWSerial.brate))
        {
            Posix.signal (Posix.SIGQUIT, (s) => {
                    ml.quit();
            });

            Posix.signal (Posix.SIGINT, (s) => {
                    ml.quit();
            });
            s.init_timer();
            ml.run();
            var st = s.getstats();
            MWPLog.message("\n%.0fs, rx %lub, tx %lub, (%.0fb/s, %0.fb/s)\n",
                           st.elapsed, st.rxbytes, st.txbytes,
                           st.rxrate, st.txrate);
        }
    }
    return 0;
}
