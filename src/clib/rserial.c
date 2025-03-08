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


#define GENERR "Operation failed: the log may have more detail"

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

#include <sys/time.h>
#include <time.h>


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

static inline void timespec_diff(struct timespec *a, struct timespec *b,
    struct timespec *result) {
    result->tv_sec  = a->tv_sec  - b->tv_sec;
    result->tv_nsec = a->tv_nsec - b->tv_nsec;
    if (result->tv_nsec < 0) {
        --result->tv_sec;
        result->tv_nsec += 1000000000L;
    }
}

static clock_t clk0;
static struct timespec tp0;

void start_cpu_stats() {
  clock_gettime(CLOCK_MONOTONIC, &tp0);
  clk0 = clock();
}

int end_cpu_stats(double *cpu0, double* cpu1) {
  clock_t clk1 = clock();
  struct timespec tp1;
  clock_gettime(CLOCK_MONOTONIC, &tp1);
  long ncpu = sysconf(_SC_NPROCESSORS_ONLN);
  struct timespec td;
  timespec_diff(&tp1, &tp0, &td);
  double utd;
  double ctd;
  utd = (double)(clk1-clk0)/CLOCKS_PER_SEC;
  ctd = (td.tv_sec + (double)td.tv_nsec/1000000000);
  *cpu0 =  100.0*utd/ctd;
  *cpu1 = *cpu0/ncpu;
  return 0;
}

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

/*
static void set_timeout(int fd, int tenths, int number) {
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
*/
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
  if(errnum != 0) {
    *buf = 0;
    strerror_r(errnum, buf, buflen);
  } else {
    strcpy(GENERR, buf);
  }
  return buf;
}

int get_error_number() {
  return errno;
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

void flush_serial(int hfd) {
  PurgeComm((HANDLE)((intptr_t)hfd), PURGE_RXABORT|PURGE_TXABORT|PURGE_RXCLEAR|PURGE_TXCLEAR);
}

int set_fd_speed(int hfd, int baudrate) {
     DCB dcb = {0};
     BOOL res = FALSE;

     dcb.DCBlength = sizeof(DCB);
     if ((res = GetCommState((HANDLE)((intptr_t)hfd), &dcb))) {
        dcb.ByteSize=8;
        dcb.StopBits=ONESTOPBIT;
        dcb.Parity=NOPARITY;
	dcb.BaudRate = baudrate;
	res = SetCommState((HANDLE)((intptr_t)hfd), &dcb);
	return 0;
     }
     return -1;
}

void set_timeout(int hfd, uint32_t readint, uint32_t readmult, uint32_t readconst) {
  COMMTIMEOUTS ctout = {0};
  ctout.WriteTotalTimeoutMultiplier = 0;
  ctout.WriteTotalTimeoutConstant = 0;
  ctout.ReadIntervalTimeout = readint;
  ctout.ReadTotalTimeoutMultiplier = readmult;
  ctout.ReadTotalTimeoutConstant = readconst;
  SetCommTimeouts((HANDLE)((intptr_t)hfd), &ctout);
}

int open_serial(const char *device, int baudrate) {
  char * dname;

  if(strncmp(device, "COM", 3) == 0) {
    dname = malloc(strlen(device)+16);
    strcpy(dname, "\\\\.\\");
    strcat(dname, device);
  } else {
    dname = device;
  }

  HANDLE hfd = CreateFile(dname,
			  GENERIC_READ|GENERIC_WRITE,
			  0,
			  NULL,
			  OPEN_EXISTING,
			  FILE_FLAG_OVERLAPPED,
			  NULL);
  if(dname != device) {
    free(dname);
  }

  if(hfd != INVALID_HANDLE_VALUE) {
    set_timeout((intptr_t)hfd, (uint32_t)MAXDWORD, (uint32_t)MAXDWORD, (uint32_t)5);
    set_fd_speed((intptr_t)hfd, baudrate);
  }
  return (intptr_t)hfd;
}

void close_serial(int hfd) {
  CloseHandle((HANDLE)((intptr_t)hfd));
}
ssize_t read_serial(int hfd, uint8_t*buffer, size_t buflen) {
     DWORD nb= 0;
     OVERLAPPED ovl={0};
     ovl.hEvent =   CreateEvent(NULL, true, false, NULL);
     if (ReadFile ((HANDLE)((intptr_t)hfd), buffer, buflen, &nb, &ovl) == 0) {
          DWORD eval = GetLastError();
          if (eval == ERROR_IO_PENDING) {
	    GetOverlappedResult((HANDLE)((intptr_t)hfd), &ovl, &nb, true);
          } else {
	    nb = 0;
          }
     }
     CloseHandle(ovl.hEvent);
     return (ssize_t)nb;
}
/*
ssize_t read_serial(int fd, uint8_t*buffer, size_t buflen) {
     HANDLE hfd = check_handle_from_fd(fd);
     DWORD dwWaitResult;
     DWORD nb= 0;
     OVERLAPPED ovl={0};
     ovl.hEvent =   CreateEvent(NULL, true, false, NULL);
     if (!ReadFile (hfd, buffer, buflen, &nb, &ovl)) {
       DWORD eval = GetLastError();
       if (eval == ERROR_IO_PENDING) {
	 dwWaitResult = WaitForSingleObject(ovl.hEvent, INFINITE);
	 switch (dwWaitResult) {
	 case WAIT_OBJECT_0:
	   if (!GetOverlappedResult(hfd, &ovl, &nb, FALSE)) {
	     nb = 0;
	   }
	   break;
	 default:
	   nb = 0;
	   break;
	 }
       } else {
	 nb = 0;
       }
     }
     CloseHandle(ovl.hEvent);
     return (ssize_t)nb;
}
*/
/*
ssize_t write_serial(int fd, uint8_t*buffer, size_t buflen) {
     HANDLE hfd = check_handle_from_fd(fd);
     DWORD nb= 0;
     OVERLAPPED ovl={0};
     ovl.hEvent = CreateEvent(NULL, true, false, NULL);
     if (!WriteFile (hfd, buffer, buflen, &nb, &ovl)) {
       DWORD eval = GetLastError();
       if (eval == ERROR_IO_PENDING) {
	 DWORD dwWaitResult = WaitForSingleObject(ovl.hEvent, INFINITE);
	 switch (dwWaitResult) {
	 case WAIT_OBJECT_0:
	   if(!GetOverlappedResult(hfd, &ovl, &nb, TRUE)) {
	     nb = 0;
	   }
	   break;
	 default:
	   nb = 0;
	   break;
	 }
       } else {
	 //      show_error(eval);
	 nb = 0;
       }
     }
     CloseHandle(ovl.hEvent);
     return (ssize_t)nb;
}
*/

ssize_t write_serial(int hfd, uint8_t*buffer, size_t buflen) {
     DWORD nb= 0;
     OVERLAPPED ovl={0};
     ovl.hEvent = CreateEvent(NULL, true, false, NULL);
     if (WriteFile ((HANDLE)((intptr_t)hfd), buffer, buflen, &nb, &ovl) == 0) {
          DWORD eval = GetLastError();
          if (eval == ERROR_IO_PENDING) {
	    GetOverlappedResult((HANDLE)((intptr_t)hfd), &ovl, &nb, true);
          } else {
               nb = 0;
          }
     }
     CloseHandle(ovl.hEvent);
     return (ssize_t)nb;
}


int set_bin_mode(int m) {
  return m|_O_BINARY;
}

int cf_pipe(int *fds) { _pipe(fds, 1024, _O_BINARY); return 0; }

int get_error_number() {
  return (int)GetLastError();
}

char *get_error_text(int lerr, char *pBuf, size_t bufSize) {
  if (lerr != ERROR_SUCCESS) {
    DWORD retSize;
    LPTSTR pTemp = NULL;
    if (bufSize < 16) {
      if (bufSize > 0) {
	pBuf[0] = '\0';
      }
      return (pBuf);
    }
    retSize = FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_ARGUMENT_ARRAY, NULL, lerr, LANG_NEUTRAL, (LPTSTR)&pTemp, 0, NULL);
    if (!retSize || pTemp == NULL) {
      pBuf[0] = '\0';
    } else {
      char *s = pTemp + retSize -1;
      while (s > pTemp && isspace((int)*s))
	*s-- = 0;
      sprintf(pBuf, "%s (0x%x)", pTemp, lerr);
      LocalFree((HLOCAL)pTemp);
    }
  } else {
    strcpy(GENERR, pBuf);
  }
  return (pBuf);
}

void start_cpu_stats() {
}

int end_cpu_stats(double *cpu0, double* cpu1) {
  *cpu0=-1.0;
  *cpu1=-1.0;
  return -1;
}
#endif
