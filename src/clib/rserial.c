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
#include "rserial.h"

#if !defined( WIN32 )
#ifdef  __FreeBSD__
# define __BSD_VISIBLE 1
#endif
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <errno.h>
#include <glib-unix.h>

#ifdef __linux__
#include <asm/termbits.h>
#ifndef TCGETS2
#include <asm-generic/ioctls.h>
#endif
#else
#include <termios.h>
#endif

#ifdef __APPLE__
#include <IOKit/serial/ioss.h>
#endif

void flush_serial(int fd) {
#ifdef __linux__
  ioctl(fd, TCFLSH, TCIOFLUSH);
#else
  tcflush(fd, TCIOFLUSH);
#endif
}

#if !defined( __linux__) && !defined(__APPLE__)
static int rate_to_constant(int baudrate) {
#ifdef __FreeBSD__
  return baudrate;
#else
#define B(x) case x: return B##x
    switch(baudrate) {
        B(50);     B(75);     B(110);    B(134);    B(150);
        B(200);    B(300);    B(600);    B(1200);   B(1800);
        B(2400);   B(4800);   B(9600);   B(19200);  B(38400);
        B(57600);  B(115200); B(230400);
        default:
          return 0;
    }
#undef B
#endif
}
#endif

int set_fd_speed(int fd, int rate) {
  int res = 0;
#ifdef __linux__
  struct termios2 t;
  if((res = ioctl(fd, TCGETS2, &t)) != -1) {
    t.c_ospeed = t.c_ispeed = rate;
    t.c_cflag &= ~CBAUD;
    t.c_cflag |= (BOTHER|CBAUDEX);
    res = ioctl(fd, TCSETS2, &t);
  }
#elif __APPLE__
  speed_t speed = rate;
  res = ioctl(fd, IOSSIOSPEED, &speed);
#else
  int speed = rate_to_constant(rate);
  struct termios term;
  if (tcgetattr(fd, &term))
    return -1;
  if (speed == 0) {
    res = -1;
  } else {
    if (cfsetispeed(&term, speed) != -1) {
      cfsetospeed(&term, speed);
      res = tcsetattr(fd, TCSANOW, &term);
    }
  }
#endif
  return res;
}

int open_serial(const char *device, int baudrate) {
  int fd;
  fd = open(device, O_RDWR|O_NOCTTY);
  if(fd != -1) {
    struct termios tio = {0};
    int res = -1;
#ifdef __linux__
    res = ioctl(fd, TCGETS, &tio);
#else
    res = tcgetattr(fd, &tio);
#endif
  // cfmakeraw ...
    if (res == 0) {
    tio.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON);
    tio.c_oflag &= ~OPOST;
    tio.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
    tio.c_cflag &= ~(CSIZE | PARENB);
    tio.c_cflag |= CS8;
    tio.c_cc[VTIME] = 0;
    tio.c_cc[VMIN] = 1;
#ifdef __linux__
    ioctl(fd, TCSETS, &tio);
#else
    tcsetattr(fd,TCSANOW,&tio);
#endif
    }
    if(set_fd_speed(fd, baudrate) == -1) {
      close(fd);
      fd = -1;
    }
  }
  return fd;
}

void set_timeout(int fd, int tenths, int number) {
  struct termios tio = {0};
#ifdef __linux__
  ioctl(fd, TCGETS, &tio);
#else
  tcgetattr(fd, &tio);
#endif
  tio.c_cc[VTIME] = tenths;
  tio.c_cc[VMIN] = number;
#ifdef __linux__
  ioctl(fd, TCSETS, &tio);
#else
  tcsetattr(fd,TCSANOW,&tio);
#endif
}

void close_serial(int fd) {
  flush_serial(fd);
  struct termios tio = {0};
#ifdef __linux__
  ioctl(fd, TCGETS, &tio);
#else
  tcgetattr(fd, &tio);
#endif
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
#ifdef __linux__
  ioctl(fd, TCSETS, &tio);
#else
  tcsetattr(fd,TCSANOW,&tio);
#endif
  close(fd);
}

ssize_t read_serial(int fd, uint8_t*buffer, size_t buflen) {
  return read(fd, buffer, buflen);
}

ssize_t write_serial(int fd, uint8_t*buffer, size_t buflen) {
  return write(fd, buffer, buflen);
}

int cf_pipe(int *fds) {
  gboolean res = g_unix_open_pipe (fds, O_CLOEXEC|O_NONBLOCK, NULL);
  return (res == TRUE) ? 0 : -1;
}

char *get_error_text(int errnum, char *buf, size_t buflen) {
  *buf = 0;
  strerror_r(errnum, buf, buflen);
  return buf;
}

#else
#include <windows.h>
#include <time.h>

__attribute__ ((unused))
static void show_error(DWORD errval) {
  char errstr[1024];
  FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM, NULL, errval,
                MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), errstr, sizeof(errstr)-1, NULL);
  fprintf(stderr, "Err: %s\n", errstr);
}

static HANDLE check_handle_from_fd(int fd) {
     HANDLE hfd;
     if ((fd & 0x4000000)  != 0) {
          hfd = (HANDLE)((intptr_t)fd & ~0x4000000);
     } else {
          hfd = (HANDLE)_get_osfhandle(fd);
     }
     return hfd;
}

void flush_serial(int fd) {
     HANDLE hfd = check_handle_from_fd(fd);
     PurgeComm(hfd, PURGE_RXABORT|PURGE_TXABORT|PURGE_RXCLEAR|PURGE_TXCLEAR);
}

int set_fd_speed(int fd, int baudrate) {
     HANDLE hfd = check_handle_from_fd(fd);
     DCB dcb = {0};
     BOOL res = FALSE;

     dcb.DCBlength = sizeof(DCB);
     if ((res = GetCommState(hfd, &dcb))) {
        dcb.ByteSize=8;
        dcb.StopBits=ONESTOPBIT;
        dcb.Parity=NOPARITY;
	dcb.BaudRate = baudrate;
	res = SetCommState(hfd, &dcb);
	return 0;
     }
     return -1;
}

void set_timeout(int fd, __attribute__ ((unused)) int p0, __attribute__ ((unused)) int p1) {
     HANDLE hfd = check_handle_from_fd(fd);
     COMMTIMEOUTS ctout;
     GetCommTimeouts(hfd, &ctout);
     ctout.ReadIntervalTimeout = MAXDWORD;
     ctout.ReadTotalTimeoutMultiplier = MAXDWORD;
     ctout.ReadTotalTimeoutConstant = MAXDWORD-1;
     SetCommTimeouts(hfd, &ctout);
}

int open_serial(const char *device, int baudrate) {
     HANDLE hfd = CreateFile(device,
			     GENERIC_READ|GENERIC_WRITE,
			     0,
			     NULL,
			     OPEN_EXISTING,
			     FILE_FLAG_OVERLAPPED,
			     NULL);

     int fd = -1;
     if(hfd != INVALID_HANDLE_VALUE) {
	  u_long ft = GetFileType(hfd);
          if(ft != 0) {
               fd = _open_osfhandle ((intptr_t)hfd, O_RDWR);
          } else {
               fd = 0x4000000 + (int)(intptr_t)hfd;
          }
	  set_timeout(fd, 0, 0);
	  set_fd_speed(fd, baudrate);
     }
     return fd;
}

void close_serial(int fd) {
     if ((fd & 0x4000000)  != 0) {
          HANDLE hfd = (HANDLE)((intptr_t)fd & ~0x4000000);
          CloseHandle(hfd);
     } else {
          close(fd);
     }
}

ssize_t read_serial(int fd, uint8_t*buffer, size_t buflen) {
     HANDLE hfd = check_handle_from_fd(fd);
     DWORD nb= 0;
     OVERLAPPED ovl={0};
     ovl.hEvent =   CreateEvent(NULL, true, false, NULL);
     if (ReadFile (hfd, buffer, buflen, &nb, &ovl) == 0) {
	  DWORD eval = GetLastError();
	  if (eval == ERROR_IO_PENDING) {
	       GetOverlappedResult(hfd, &ovl, &nb, true);
	  } else {
	       //      show_error(eval);
	       nb = 0;
	  }
     }
     CloseHandle(ovl.hEvent);
     return (ssize_t)nb;
}

ssize_t write_serial(int fd, uint8_t*buffer, size_t buflen) {
     HANDLE hfd = check_handle_from_fd(fd);
     DWORD nb= 0;
     OVERLAPPED ovl={0};
     ovl.hEvent = CreateEvent(NULL, true, false, NULL);
     if (WriteFile (hfd, buffer, buflen, &nb, &ovl) == 0) {
	  DWORD eval = GetLastError();
	  if (eval == ERROR_IO_PENDING) {
	       GetOverlappedResult(hfd, &ovl, &nb, true);
	  } else {
	       //      show_error(eval);
	       nb = 0;
	  }
     }
     CloseHandle(ovl.hEvent);
     return (ssize_t)nb;
}

int cf_pipe(int *fds) { _pipe(fds, 1024, _O_BINARY); return 0; }

char *get_error_text(int dummy, char *pBuf, size_t bufSize) {
  /*
  DWORD retSize;
  LPTSTR pTemp = NULL;
  if (bufSize < 16) {
    if (bufSize > 0) {
      pBuf[0] = '\0';
    }
    return (pBuf);
  }
  retSize = FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_ARGUMENT_ARRAY, NULL, GetLastError(), LANG_NEUTRAL, (LPTSTR)&pTemp, 0, NULL);
  if (!retSize || pTemp == NULL) {
    pBuf[0] = '\0';
  } else {
    char *s = pTemp + retSize -1;
    while (s > pTemp && isspace((int)*s))
      *s-- = 0;
    sprintf(pBuf, "%s (0x%lx)", pTemp, GetLastError());
    LocalFree((HLOCAL)pTemp);
  }
  return (pBuf);
  */
  return "windows ... anything could have gone wrong. We have no idea";
}
#endif
