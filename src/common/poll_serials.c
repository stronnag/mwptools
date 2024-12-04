#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>

#ifdef _WIN64
#include <windows.h>

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
char ** check_ports() {
  return NULL;
}
int check_delete_name(char *s) {
  return -1;
}

int check_insert_name(char *s) {
  return 1;
}
#endif
