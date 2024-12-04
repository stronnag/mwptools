#include <windows.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

char ** check_ports() {
  HKEY h;
  LSTATUS result;
  DWORD nvals = 0;
  char **devs = NULL;

  result = RegOpenKeyEx(HKEY_LOCAL_MACHINE, "HARDWARE\\DEVICEMAP\\SERIALCOMM", 0, KEY_READ, &h);
  if (result != ERROR_SUCCESS) {
    //printf("Error RegOpenKeyEx > %d\n", result);
    return NULL;
  }

  result = RegQueryInfoKey(h, NULL,NULL,NULL,NULL,NULL,NULL,&nvals,NULL,NULL,NULL,NULL);
  if (result == ERROR_SUCCESS) {
//    printf("Found nkeys %d\n", nvals);
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
//      printf("C: %s\n", element);
      devs[i] = element;
    }
  }
  return devs;
}
