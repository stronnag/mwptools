/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * (c) Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#define _GNU_SOURCE 1
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>

#if !defined(WIN32)
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
static int sigs[] = {SIGINT, SIGUSR1, SIGUSR2, SIGQUIT};
#else
#include <windows.h>
#define pipe(__p1) _pipe(__p1, 4096, _O_BINARY)
static int sigs[] = {SIGINT};
#endif

static int fds[2];

void signal_handler(int s) { write(fds[1], &s, sizeof(int)); }

int init_signals() {
  fds[0] = -1;
  if (-1 != pipe(fds)) {
#if !defined(WIN32)
    struct sigaction sac;
    sigemptyset(&(sac.sa_mask));
    sac.sa_flags = 0;
    sac.sa_handler = signal_handler;
#endif
    int i;
    for (i = 0; i < sizeof(sigs) / sizeof(int); i++) {
#if !defined(WIN32)
      sigaction(sigs[i], &sac, NULL);
#else
      signal(sigs[i], signal_handler);
#endif
    }
  }
  return fds[0];
}
