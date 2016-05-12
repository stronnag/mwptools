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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>

#ifdef __linux__
#include <bluetooth/bluetooth.h>
#include <bluetooth/rfcomm.h>
#include <bluetooth/hci.h>
#include <bluetooth/hci_lib.h>
#include <sys/socket.h>

int connect_bt_device(char *btaddr)
{
    struct sockaddr_rc addr = { 0 };
    int s=-1, status = -1;

    s = socket(AF_BLUETOOTH, SOCK_STREAM, BTPROTO_RFCOMM);
    if (s < 0)
    {
        fprintf(stderr, "Socket fails %d (%s)\n", s, strerror(errno));
    }
    else
    {
        addr.rc_family = AF_BLUETOOTH;
        addr.rc_channel = (uint8_t) 1;
        str2ba(btaddr, &addr.rc_bdaddr );
        status = connect(s, (struct sockaddr *)&addr, sizeof(addr));
        if(status != 0)
        {
            fprintf(stderr, "connect fails %d (%s)\n", status, strerror(errno));
            close(s);
            s = -1;
        }
    }
    return s;
}
#else
static int create_bt_dev(char *btaddr)
{
    return -1;
}
#endif
