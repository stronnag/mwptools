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

#if !defined( WINDOWS )
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <termios.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <errno.h>

int open_serial(char *device, uint baudrate, char estr[], size_t elen)
{
    int fd;
    fd = open(device, O_RDWR|O_NOCTTY);
    if(fd != -1)
    {
        struct termios tio;
        memset (&tio, 0, sizeof(tio));
        cfmakeraw(&tio);
        tio.c_cflag |= (CS8 | CLOCAL | CREAD);
        tio.c_iflag |= IGNPAR;
        tio.c_oflag = 0;
        tio.c_lflag = 0;
        tio.c_cc[VTIME] = 1;
        tio.c_cc[VMIN] = 1;

        switch (baudrate)
        {
            case 0:      baudrate=B57600; break;
            case 4800:   baudrate=B4800; break;
            case 9600:   baudrate=B9600; break;
            case 19200:  baudrate=B19200; break;
            case 38400:  baudrate=B38400; break;
            case 57600:  baudrate=B57600; break;
            case 115200: baudrate=B115200; break;
            case 230400: baudrate=B230400; break;
        }
        cfsetispeed(&tio,baudrate);
        cfsetospeed(&tio,baudrate);
        tcsetattr(fd,TCSANOW,&tio);
    }
    else
    {
        strerror_r(errno, estr, elen);
//        fprintf(stderr,"Failed to open %s : %s\n", device, estr);
    }
    return fd;
}

void close_serial(int fd)
{
    tcflush(fd, TCIOFLUSH);
    close(fd);
}
#else

/** COMPLETELY untested **/

#include <Windows.h>
static HANDLE hfd;

int open_serial(const char *device, int baudrate)
{
    int fd=-1;

    HANDLE hfd = CreateFile(device,
                            GENERIC_READ | GENERIC_WRITE,
                            0,
                            NULL,
                            OPEN_EXISTING,
                            FILE_ATTRIBUTE_NORMAL,
                            NULL);

    if(hfd != INVALID_HANDLE_VALUE)
    {
        DCB dcbserial = {0};
        if (GetCommState(hfd, &dcbserial))
        {
            dcbserial.ByteSize=8;
            dcbserial.StopBits=ONESTOPBIT;
            dcbserial.Parity=NOPARITY;
            dcbserial.BaudRate=baudrate;

            if(!SetCommState(hfd, &dcbserial))
            {
                fd = -1;
            }
            else
            {
                fd = _open_osfhandle((long)hfd, O_RDWR);
            }
        }
    }
    return fd;
}

void close_serial(int fd)
{
        /* Correct ?? , close both ?? */
    CloseHandle(hfd);
    hfd = 0;
    close(fd);
}

#endif
