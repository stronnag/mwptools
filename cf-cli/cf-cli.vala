
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


/* Upload a cleanflight CLI dump back into a naze32 FC */

extern string default_name();

int main (string[] args)
{
    int ini_res;
    string restore_file = null;
    var s = new MWSerial();

    if ((ini_res =s.init_app(args, ref restore_file)) != 0)
        return ini_res;

    if(MWSerial.devname == null)
    {
        MWSerial.devname = default_name();
        if(MWSerial.devname == null)
        {
            message("On non-Linux OS you must define the serial device (-d DEVNAME)\n");
            Posix.exit(0);
        }
    }
    s.set_iofd(stderr.fileno());
    if(s.try_open())
    {
        int err = s.fc_init();
        if(err == 0)
        {
            if(restore_file == null)
                s.perform_backup();
            else
                s.perform_restore(restore_file);
        }
    }
    s.message("Done\n");
    s.close();
    return 0;
}
