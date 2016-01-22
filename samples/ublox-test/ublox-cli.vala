
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

static MainLoop ml;
static int sfd[2];
static MWSerial msp;

void show_stats(MWSerial s)
{
    var st = s.getstats();
    stderr.puts("\n");
    MWPLog.message("%.0fs, rx %lub, tx %lub, (%.0fb/s, %0.fb/s)\n",
                   st.elapsed, st.rxbytes, st.txbytes,
                   st.rxrate, st.txrate);
    stderr.puts("\n");
}

void signal_handler(int s)
{
    Posix.write(sfd[1], &s, sizeof(int));
}

private bool sig_reader (IOChannel gio, IOCondition condition)
{
    int s=0;
    var ret = Posix.read(gio.unix_get_fd(), &s, sizeof(int));
    if(ret != sizeof(int))
        return false;
    show_stats(msp);
    if(s == Posix.SIGINT)
        ml.quit();
    return true;
}

public static int main (string[] args)
{
    ml = new MainLoop();
    msp = new MWSerial();

    if (msp.parse_option(args) == 0)
    {
        if(msp.ublox_open(MWSerial.devname, MWSerial.brate))
        {
            int [] sigs = {Posix.SIGINT, Posix.SIGUSR1,
                           Posix.SIGUSR2, Posix.SIGQUIT};
            var mask = Posix.sigset_t();
            Posix.sigemptyset(mask);
            var act = Posix.sigaction_t ();
            act.sa_handler = signal_handler;
            act.sa_mask = mask;
            act.sa_flags = 0;
            foreach(var s in sigs)
                Posix.sigaction (s, act, null);

            if(0 == Posix.socketpair (SocketFamily.UNIX,
                                      SocketType.DATAGRAM, 0, sfd))
            {
                var io_read  = new IOChannel.unix_new(sfd[0]);
                io_read.add_watch(IOCondition.IN, sig_reader);
            }
            msp.init_timer();
            ml.run();
        }
    }
    return 0;
}
