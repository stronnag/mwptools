#include <stdlib.h>
#include <string.h>

#ifdef WIN64
#include <windows.h>
char * get_user_locale() {
  char *lname;
  wchar_t  name[LOCALE_NAME_MAX_LENGTH];
  int nl = GetUserDefaultLocaleName(name, LOCALE_NAME_MAX_LENGTH);
  if(nl != 0) {
    int len = WideCharToMultiByte(CP_UTF8, 0, name, nl, 0, 0, NULL, NULL);
    lname = (char*)malloc(len+1);
    WideCharToMultiByte(CP_UTF8, 0, name, nl, lname, len, NULL, NULL);
    lname[len] = '\0';
  } else {
    lname = strdup("C");
  }
  return lname;
}
#else
char * get_user_locale() {
  char *s;
  s = getenv("LANG");
  if (s == NULL) {
    s = getenv("LC_ALL");
    if (s == NULL) {
      s = "C";
    }
  }
  return strdup(s);
}
#endif
