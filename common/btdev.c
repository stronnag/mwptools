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

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>

#ifdef __linux__
#include <sys/socket.h>

/* I'd really prefer not to have to require bluez-lib-devel ... */

#define _BA_SIZE 6
#define BTPROTO_RFCOMM	3

/* BD Address */
typedef struct {
        uint8_t b[6];
} __attribute__((packed)) bdaddr_t;

/* RFCOMM socket address */
struct sockaddr_rc {
        sa_family_t     rc_family;
        bdaddr_t        rc_bdaddr;
        uint8_t         rc_channel;
};

static int _mwp_str2ba(const char *str, bdaddr_t * ba)
{
       uint8_t b[6];
       const char *ptr = str;
       int i;

       for (i = 0; i < 6; i++) {
              b[5-i] = (uint8_t) strtol(ptr, NULL, 16);
              if (i != 5 && !(ptr = strchr(ptr, ':')))
                     ptr = ":00:00:00:00:00";
              ptr++;
       }
       memcpy(ba, b, _BA_SIZE);
       return 0;
}

static int connect_nb(int s, struct sockaddr_rc *addr, size_t slen)
{
    int flags;
    int res;

    flags = fcntl(s, F_GETFL, NULL) | O_NONBLOCK;
    fcntl(s, F_SETFL, flags);

    res = connect(s, (const struct sockaddr *)addr, slen);
    if (res < 0)
    {
        fd_set set;
        struct timeval tv;
        socklen_t lon;
        int valopt;

        if (errno == EINPROGRESS)
        {
            tv.tv_sec = 15;
            tv.tv_usec = 0;
            FD_ZERO(&set);
            FD_SET(s, &set);
            if (select(s+1, NULL, &set, NULL, &tv) > 0)
            {
                lon = sizeof(int);
                getsockopt(s, SOL_SOCKET, SO_ERROR, (void*)(&valopt), &lon);
                if (valopt)
                {
                    fprintf(stderr, "Error in connection() %d - %s\n", valopt, strerror(valopt));
                    res = -1;
                }
                else
                    res = 0;
            }
            else
            {
                fprintf(stderr, "Timeout or error() %d - %s\n", valopt, strerror(valopt));
                res = -1;
            }
        }
        else
        {
            fprintf(stderr, "Error connecting %d - %s\n", errno, strerror(errno));
            res = -1;
        }
    }
    flags = fcntl(s, F_GETFL, NULL) & (~O_NONBLOCK);
    fcntl(s, F_SETFL, flags);
    return res;
}

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
        _mwp_str2ba(btaddr, &addr.rc_bdaddr );
        status = connect_nb (s, &addr, sizeof(addr));
        if(status != 0)
        {
            close(s);
            s = -1;
        }
    }
    return s;
}
#else
int connect_bt_device (char *btaddr)
{
    return -1;
}
#endif
