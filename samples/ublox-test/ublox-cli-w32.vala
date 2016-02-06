
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
static MWSerial msp;

public static int main (string[] args)
{
    ml = new MainLoop();
    msp = new MWSerial();
    if (msp.parse_option(args) == 0)
    {
        if(MWSerial.devname == null)
        {
            stderr.puts("On non-Linux OS you must define the serial device (-d DEVNAME)\n");
            Posix.exit(0);
        }
        if(msp.ublox_open(MWSerial.devname, MWSerial.brate))
        {
            msp.init_timer(); // pointless on msw ...
            ml.run();
        }
    }
    return 0;
}
