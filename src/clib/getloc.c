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
