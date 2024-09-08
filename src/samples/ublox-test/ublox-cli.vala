
/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 3
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


static MainLoop ml;
static MWSerial msp;

void show_stats(MWSerial s) {
    var st = s.getstats();
    stderr.puts("\n");
    MWPLog.message("%.0fs, rx %lub, tx %lub, (%.0fb/s, %0.fb/s)\n",
                   st.elapsed, st.rxbytes, st.txbytes,
                   st.rxrate, st.txrate);
    stderr.puts("\n");
}

private bool sigfunc() {
    show_stats(msp);
    return Source.CONTINUE;
}

private bool sigfunc_quit () {
    show_stats(msp);
    ml.quit();
    return Source.REMOVE;
}

public static int main (string[] args) {
    ml = new MainLoop();
    msp = new MWSerial();

    if (msp.parse_option(args) == 0) {
        if(msp.ublox_open(MWSerial.devname, MWSerial.brate)) {
            Unix.signal_add(MwpSignals.Signal.INT, sigfunc_quit);
            Unix.signal_add(MwpSignals.Signal.USR1, sigfunc);
            Unix.signal_add(MwpSignals.Signal.USR2, sigfunc);
            ml.run();
        }
    }
    return 0;
}
