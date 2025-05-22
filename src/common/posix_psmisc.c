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

#include <stdio.h>
#include <glib.h>
#include <sys/wait.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/types.h>
#include <libgen.h>
#include <fnmatch.h>

pid_t pid_from_name(const char* name) {
  DIR* dir;
  struct dirent* ent;
  char* endptr;
  char buf[4096];

  if (!(dir = opendir("/proc"))) {
    perror("can't open /proc");
    return -1;
  }

  while((ent = readdir(dir)) != NULL) {
    long lpid = strtol(ent->d_name, &endptr, 10);
    if (*endptr != '\0') {
      continue;
    }

    snprintf(buf, sizeof(buf), "/proc/%ld/cmdline", lpid);
    FILE* fp = fopen(buf, "r");
    if (fp) {
      if (fgets(buf, sizeof(buf), fp) != NULL) {
	char* first = strtok(buf, " ");
	if (fnmatch(name, basename(first), 0) == 0) {
	  fclose(fp);
	  closedir(dir);
	  return (pid_t)lpid;
	}
      }
      fclose(fp);
    }
  }
  closedir(dir);
  return -1;
}

int  parse_wstatus(int sts, int *wsts) {
  int _wsts = 0;
  int res = WIFEXITED(sts);
  if (res == 1) {
    _wsts =  WEXITSTATUS(sts);
  }
  if (wsts != NULL) {
    *wsts = _wsts;
  }
  return res;
}
