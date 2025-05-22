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
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

#ifdef _WIN64
#include <windows.h>
#include <string.h>

char ** check_ports() {
  HKEY h;
  LSTATUS result;
  DWORD nvals = 0;
  char **devs = NULL;

  result = RegOpenKeyEx(HKEY_LOCAL_MACHINE, "HARDWARE\\DEVICEMAP\\SERIALCOMM", 0, KEY_READ, &h);
  if (result != ERROR_SUCCESS) {
    return NULL;
  }

  result = RegQueryInfoKey(h, NULL,NULL,NULL,NULL,NULL,NULL,&nvals,NULL,NULL,NULL,NULL);
  if (result == ERROR_SUCCESS && nvals > 0) {
    devs = calloc(nvals+1, sizeof(char*));
    for(int i = 0; i < nvals; i++) {
      char data[256];
      char name[1024];
      DWORD namelen = sizeof(name);
      DWORD datalen = sizeof(data);
      result = RegEnumValue(h, (DWORD)i, name, &namelen, NULL, NULL, data, &datalen);
      if (result != ERROR_SUCCESS) {
	   break;
      }
      char *element = malloc(namelen+datalen+2);
      sprintf(element, "%s %s", data, name);
      devs[i] = element;
    }
  }
  return devs;
}

int check_insert_name(char *s) {
  if(strstr(s, "USBSER") != NULL) {
    return 1;
  }
  //                       012345678..
  char *modem = strstr(s, "BthModem");
  if (modem != NULL) {
       if(*(modem+8) != 0) {
	    int id = atoi(modem+8);
	    if ((id & 1) == 0) {
		 return -1;
	    } else {
		 return 0;
	    }
       }
  }
  return -1;
}

int check_delete_name(char *s) {
  int res = -1;
  if(strlen(s) > 3) {
    if(*s == 'C' && s[1] == 'O' && s[2] == 'M') {
      if (strstr(s+3, " \\Device\\") != NULL) {
	return 0;
      }
    }
  }
  return res;
}

#endif
#ifdef __FreeBSD__
#include <sys/stat.h>
#include <string.h>
char ** check_ports() {
  char **devs = NULL;
  char name[32];
  char ids[32];
  struct stat sb;
  int n = 0;
  for(int i = 0; i < 32; i++) {
    sprintf(name, "/dev/cuaU%d", i);
    if(stat(name, &sb) == 0) {
      if((sb.st_mode & S_IFMT) == S_IFCHR) {
	ids[n] = i;
	n++;
      }
    }
  }

  if(n  > 0) {
    devs = calloc(n+1, sizeof(char*));
    for(int j = 0; j < n; j++) {
      char *element = malloc(16);
      sprintf(element, "/dev/cuaU%d", ids[j]);
      devs[j] = element;
    }
  }
  return devs;
}

int check_insert_name(char *s) {
  return 1;
}

int check_delete_name(char *s) {
  return strncmp(s, "/dev/cuaU", sizeof("/dev/cuaU")-1);
}
#endif

#ifdef __APPLE__
#include <string.h>
#include <strings.h>
#include <dirent.h>

char ** check_ports() {
   DIR* dir;
  struct dirent* ent;
  char **devs = NULL;

  if (!(dir = opendir("/dev"))) {
    perror("can't open /dev");
    return NULL;
  }

  int n = 0;
  while((ent = readdir(dir)) != NULL) {
    if(strncasecmp(ent->d_name, "cu.usb", 6) == 0) {
      n++;
      continue;
    }

    if(strncasecmp(ent->d_name, "cu.bluetooth", 12) == 0) {
      if (strstr(ent->d_name, "modem") != NULL) {
	n++;
      }
    }
  }
  closedir(dir);

  if(n  > 0) {
    int j = 0;
    devs = calloc(n+1, sizeof(char*));
    if (!(dir = opendir("/dev"))) {
      perror("can't open /dev");
      return devs;
    }

    while((ent = readdir(dir)) != NULL) {
      if(strncasecmp(ent->d_name, "cu.usb", 6) == 0) {
	char *element = malloc(strlen(ent->d_name)+6);
	strcpy(element, "/dev/");
	strcat(element, ent->d_name);
	devs[j] = element;
	j++;
	continue;
      }

      if(strncmp(ent->d_name, "cu.bluetooth", 12) == 0) {
	if (strstr(ent->d_name, "modem") != NULL) {
	  char *element = malloc(strlen(ent->d_name)+6);
	  strcpy(element, "/dev/");
	  strcat(element, ent->d_name);
	  devs[j] = element;
	  j++;
	}
      }
    }
    closedir(dir);
  }
  return devs;
}

int check_delete_name(char *s) {
  int res = strncasecmp(s, "/dev/cu.usb", sizeof("/dev/cu.usb")-1);
  if (res != 0) {
    res = strncmp(s, "/dev/cu.bluetooth", sizeof("/dev/cu.bluetooth")-1);
  }
  return res;
}

int check_insert_name(char *s) {
  return 1;
}
#endif

#if defined (TESTMEHARDER) && defined( __linux__)
#define _GNU_SOURCE
#include <string.h>
#include <dirent.h>

char ** check_ports() {
   DIR* dir;
  struct dirent* ent;
  char* endptr;
  char **devs = NULL;

  if (!(dir = opendir("/dev"))) {
    perror("can't open /dev");
    return NULL;
  }

  int n = 0;
  while((ent = readdir(dir)) != NULL) {
    if(strncasecmp(ent->d_name, "ttyUSB", 6) == 0) {
      n++;
      continue;
    }

    if(strncasecmp(ent->d_name, "ttyACM", 6) == 0) {
      n++;
    }
  }
  closedir(dir);

  if(n  > 0) {
    int j = 0;
    devs = calloc(n+1, sizeof(char*));
    if (!(dir = opendir("/dev"))) {
      perror("can't open /dev");
      return devs;
    }

    while((ent = readdir(dir)) != NULL) {
      if(strncasecmp(ent->d_name, "ttyUSB", 6) == 0) {
	char *element = malloc(strlen(ent->d_name)+6);
	strcpy(element, "/dev/");
	strcat(element, ent->d_name);
	devs[j] = element;
	j++;
	continue;
      }

      if(strncasecmp(ent->d_name, "ttyACM", 6) == 0) {
	char *element = strdup(ent->d_name);
	strcpy(element, "/dev/");
	strcat(element, ent->d_name);
	devs[j] = element;
	j++;
      }
    }
    closedir(dir);
  }
  return devs;
}

int check_delete_name(char *s) {
  return 0;
}

int check_insert_name(char *s) {
  return 1;
}
#endif
