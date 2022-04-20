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
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <stdbool.h>
#if !defined( WIN32 )
#ifdef  __FreeBSD__
# define __BSD_VISIBLE 1
#endif
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <termios.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <errno.h>

#ifdef __linux__
#include <linux/serial.h>
#endif

void flush_serial(int fd)
{
    tcflush(fd, TCIOFLUSH);
}

static int rate_to_constant(int baudrate) {
#define B(x) case x: return B##x
    switch(baudrate) {
        B(50);     B(75);     B(110);    B(134);    B(150);
        B(200);    B(300);    B(600);    B(1200);   B(1800);
        B(2400);   B(4800);   B(9600);   B(19200);  B(38400);
        B(57600);  B(115200); B(230400);
#ifdef __linux__
        B(460800); B(921600);
        B(500000); B(576000); B(1000000); B(1152000); B(1500000);
#endif
#ifdef __FreeBSD__
        B(460800); B(500000);  B(921600);
        B(1000000); B(1500000);
	B(2000000); B(2500000);
	B(3000000); B(3500000);
	B(4000000);
#endif
	default: return 0;
    }
#undef B
}

int set_fd_speed(int fd, int rate)
{
    struct termios tio;
    int res=0;
    int speed = rate_to_constant(rate);

#ifdef __linux__
    if(speed == 0)
    {
#include <asm/termios.h>
#include <asm/ioctls.h>
        struct termios2 t;
        if((res = ioctl(fd, TCGETS2, &t)) != -1)
        {
	     t.c_ospeed = t.c_ispeed = rate;
	     t.c_cflag &= ~CBAUD;
	     t.c_cflag |= (BOTHER|CBAUDEX);
	     res = ioctl(fd, TCSETS2, &t);
#ifdef TEST
	     fprintf(stderr, "TCSETS2 %d %d\n", rate, res);
	     int res2 = ioctl(fd, TCGETS2, &t);
	     fprintf(stderr, "TCGETS2 %d %d %d\n", t.c_ospeed, t.c_ispeed, res2);
#endif
        }
    }
#endif
    if (speed != 0)
    {
	 tcgetattr(fd, &tio);
	 if((res = cfsetispeed(&tio,speed)) != -1)
	      res = cfsetospeed(&tio,speed);
	 tcsetattr(fd,TCSANOW,&tio);
#ifdef TEST
	 fprintf(stderr, "Speed %d %d\n", speed, res);
#endif
    }
    return res;
}

int open_serial(char *device, uint baudrate)
{
    int fd;
    fd = open(device, O_RDWR|O_NOCTTY);
    if(fd != -1)
    {
        struct termios tio;
        memset (&tio, 0, sizeof(tio));
        tcgetattr(fd, &tio);
        cfmakeraw(&tio);
        tio.c_cc[VTIME] = 0;
        tio.c_cc[VMIN] = 0;
        tcsetattr(fd,TCSANOW,&tio);
        if(set_fd_speed(fd, baudrate) == -1)
        {
            close(fd);
            fd = -1;
        }
    }
    return fd;
}

void set_timeout(int fd, int tenths, int number)
{
    struct termios tio;
    memset (&tio, 0, sizeof(tio));
    tcgetattr(fd, &tio);
    tio.c_cc[VTIME] = tenths;
    tio.c_cc[VMIN] = number;
    tcsetattr(fd,TCSANOW,&tio);
}

void close_serial(int fd)
{
    tcflush(fd, TCIOFLUSH);
    struct termios tio ={0};
    tio.c_iflag &= ~IGNBRK;
    tio.c_iflag |=  BRKINT;

    tio.c_iflag |=  IGNPAR;
    tio.c_iflag &= ~PARMRK;

    tio.c_iflag &= ~ISTRIP;

    tio.c_iflag &= ~(INLCR | IGNCR | ICRNL);

    tio.c_cflag &= ~CSIZE;
    tio.c_cflag |=  CS8;

    tio.c_cflag |=  CREAD;

    tio.c_lflag |=  ISIG;

    tio.c_lflag &= ~ICANON;

    tio.c_lflag &= ~(ECHO | ECHOE | ECHOK | ECHONL);

    tio.c_lflag &= ~IEXTEN;

    tio.c_cc[VTIME] = 0;
    tio.c_cc[VMIN] = 1;
    tcsetattr(fd,TCSANOW,&tio);
    close(fd);
}

char *get_error_text (int errnum, char *buf, size_t buflen)
{
    *buf = 0;
    strerror_r(errnum, buf, buflen);
    return buf;
}

#else

/** COMPLETELY untested **/

#include <windows.h>
static HANDLE hfd;
#define pipe(__p1) _pipe(__p1,4096,_O_BINARY)

void flush_serial(int fd)
{
    fd=fd;
}

char *get_error_text (int dummy, char *pBuf, size_t bufSize)
{
    DWORD retSize;
    LPTSTR pTemp=NULL;

    if (bufSize < 16) {
        if (bufSize > 0) {
            pBuf[0]='\0';
        }
        return(pBuf);
     }
    retSize=FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER|
                          FORMAT_MESSAGE_FROM_SYSTEM|
                          FORMAT_MESSAGE_ARGUMENT_ARRAY,
                          NULL,
                          GetLastError(),
                          LANG_NEUTRAL,
                          (LPTSTR)&pTemp,
                          0,
                          NULL );
    if (!retSize || pTemp == NULL) {
          pBuf[0]='\0';
    }
    else {
        pTemp[strlen(pTemp)-2]='\0'; //remove cr and newline character
        sprintf(pBuf,"%0.*s (0x%x)",bufSize-16,pTemp,GetLastError());
        LocalFree((HLOCAL)pTemp);
    }
    return(pBuf);
}

void set_fd_speed(int fd, int baudrate)
{
    fd=fd;
    DCB dcb = {0};
    BOOL res = FALSE;
    char act = 'g';

    dcb.DCBlength = sizeof(DCB);

    if ((res = GetCommState(hfd, &dcb)))
    {
        act = 's';
        dcb.ByteSize=8;
        dcb.StopBits=ONESTOPBIT;
        dcb.Parity=NOPARITY;
        switch (baudrate)
        {
            case 0:
            case 115200:
                dcb.BaudRate=CBR_115200;
                break;
            case 2400:
                dcb.BaudRate=CBR_2400;
                break;
            case 4800:
                dcb.BaudRate=CBR_4800;
                break;
            case 9600:
                dcb.BaudRate=CBR_9600;
                break;
            case 19200:
                dcb.BaudRate=CBR_19200;
                break;
            case 38400:
                dcb.BaudRate=CBR_38400;
                break;
            case 57600:
                dcb.BaudRate=CBR_57600;
                break;
        }
        res = SetCommState(hfd, &dcb);
    }
    if(!res)
    {
        char mbuf[1024];
        fprintf(stderr,"Failed to %cet baud rate\n");
        fprintf(stderr,"%s\n", get_error_text(0, mbuf, sizeof(mbuf)));
    }
}

void set_timeout(int fd, int tenths, int number)
{
    number=number;
    COMMTIMEOUTS ctout;
    GetCommTimeouts(hfd, &ctout);
    ctout.ReadIntervalTimeout = 100*tenths;
    ctout.ReadTotalTimeoutMultiplier = 0;
    ctout.ReadTotalTimeoutConstant = 100*tenths;
    SetCommTimeouts(hfd, &ctout);
}

int open_serial(const char *device, int baudrate)
{
    int fd=-1;
    hfd = CreateFile(device,
                            GENERIC_READ | GENERIC_WRITE,
                            0,
                            NULL,
                            OPEN_EXISTING,
                            FILE_ATTRIBUTE_NORMAL,
                            NULL);

    if(hfd != INVALID_HANDLE_VALUE)
    {
        fd = _open_osfhandle((long)hfd, O_RDWR);
        set_timeout(fd, 1, 0);
        set_fd_speed(fd, baudrate);
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

int cf_pipe(int *fds)
{
    return pipe(fds);
}

int cf_pipe_close(int fd)
{
    return close(fd);
}

char * default_name(void)
{
#ifdef __linux__
    return "/dev/ttyUSB0";
#else
    return NULL;
#endif
}

bool is_cygwin(void)
{
#ifdef __CYGWIN__
    return true;
#else
    return false;
#endif
}

#ifdef __CYGWIN__
#include <sys/cygwin.h>
/* Conversion from incoming posix path to win32 path */
//CCP_RELATIVE
char * get_native_path(char *upath)
{
     char *wpath = NULL;
     wpath = cygwin_create_path (CCP_POSIX_TO_WIN_A, upath);

     if(wpath == NULL)
          perror ("cygwin_create");
     return wpath;
}
#else
char * get_native_path(char *upath)
{
     return upath;
}
#endif

#ifdef TEST

// $CC -O2 -o cserial -DTEST cserial.c

void showspeed(int fd) {
     struct termios tio;
     tcgetattr(fd, &tio);
     int ispeed = cfgetispeed(&tio);
     int ospeed = cfgetospeed(&tio);
     fprintf(stderr, "%d %d\n", ispeed, ospeed);
}


int main(int argc, char **argv) {
     if(argc > 2 ) {
	  int baud = atoi(argv[2]);
          int fd = open_serial(argv[1], baud);
          fprintf(stderr, "returns %d\n", fd);
          if (fd != -1) {
	       showspeed(fd);
               fprintf(stderr, "sleep 30\n");
               sleep(30);
          }
     }
     return 0;
}
#endif
