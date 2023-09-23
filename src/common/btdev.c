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

#include <errno.h>

#if defined(__linux__) || defined(__FreeBSD__)

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <signal.h>

#ifdef __FreeBSD__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-W#warnings"
#include <bluetooth.h>
#pragma clang diagnostic pop
#endif

#define RFCOMM_CHANNEL 1
#define _BA_SIZE 6

#if __linux
#define BTPROTO_RFCOMM 3
/* I'd really prefer not to have to require bluez-lib-devel ... */
/* BD Address */
typedef struct {
  uint8_t b[6];
} __attribute__((packed)) bdaddr_t;

/* RFCOMM socket address */
struct sockaddr_rc {
  sa_family_t rc_family;
  bdaddr_t rc_bdaddr;
  uint8_t rc_channel;
};
#endif

static int _mwp_str2ba(const char *str, bdaddr_t *ba) {
  uint8_t b[6];
  const char *ptr = str;
  int i;

  for (i = 0; i < 6; i++) {
    b[5 - i] = (uint8_t)strtol(ptr, NULL, 16);
    if (i != 5 && !(ptr = strchr(ptr, ':')))
      ptr = ":00:00:00:00:00";
    ptr++;
  }
  memcpy(ba, b, _BA_SIZE);
  return 0;
}

static int connect_socket(int s, struct sockaddr *addr, size_t slen, int *status) {
  int res;
  sigset_t intmask;

  // on Linux 5.17 at least, we can deadlock if we ^C in the connect
  // so block signals
  sigemptyset(&intmask);
  sigaddset(&intmask, SIGINT);
  sigprocmask(SIG_BLOCK, &intmask, NULL);
  res = connect(s, (struct sockaddr *)addr, slen);
  if (status != NULL) {
    *status = errno;
  }
  sigprocmask(SIG_UNBLOCK, &intmask, NULL);
  return res;
}

int connect_bt_device(char *btaddr, int *lasterr) {
  int fd = -1;
#ifdef __FreeBSD__
#define RFPROTO_NAME BLUETOOTH_PROTO_RFCOMM

  struct sockaddr_rfcomm rem_addr;
  memset(&rem_addr, 0, sizeof(rem_addr));
  rem_addr.rfcomm_len = sizeof(rem_addr);
  rem_addr.rfcomm_family = AF_BLUETOOTH;
  rem_addr.rfcomm_channel = RFCOMM_CHANNEL;
  /**
       struct hostent * he;
       if(strlen(btaddr) == 17 && btaddr[2] == ':') {
            _mwp_str2ba (btaddr, &rem_addr.rfcomm_bdaddr);
       } else if ((he = bt_gethostbyname(btaddr))) {
            rem_addr.rfcomm_bdaddr = *(bdaddr_t *) he->h_addr_list[0];
            if (0)
                 printf("Actual BT address for '%s': %s\n",
                        btaddr, bt_ntoa(&(rem_addr.rfcomm_bdaddr),NULL));
       } else {
            *lasterr = errno;
            return -1;
       }
  **/
  _mwp_str2ba(btaddr, &rem_addr.rfcomm_bdaddr);
#else
#define RFPROTO_NAME BTPROTO_RFCOMM
  struct sockaddr_rc rem_addr;
  _mwp_str2ba(btaddr, &rem_addr.rc_bdaddr);
  rem_addr.rc_family = AF_BLUETOOTH;
  rem_addr.rc_channel = RFCOMM_CHANNEL;
#endif
  if ((fd = socket(PF_BLUETOOTH, SOCK_STREAM, RFPROTO_NAME)) < 0) {
    *lasterr = errno;
    return -1;
  }

  int res = connect_socket(fd, (struct sockaddr *)&rem_addr, sizeof(rem_addr), lasterr);
  if (res != 0) {
    close(fd);
    fd = -1;
  }
  return fd;
}
#else
int connect_bt_device(char *btaddr, int *lasterr) {
  *lasterr = EINVAL;
  return -1;
}
#endif

#ifdef TEST
int main(int argc, char **argv) {
  if (argc > 1) {
    int e;
    int fd = connect_bt_device(argv[1], &e);
    fprintf(stderr, "returns %d %d %s\n", fd, e, strerror(e));
    if (fd != -1) {
      fprintf(stderr, "sleep 30\n");
      sleep(30);
    }
  }
  return 0;
}
#endif
