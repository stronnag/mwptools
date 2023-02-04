
/* ugly hack because vala doesn't support -Dx=y */
#include "_mwpvers.h"
#if defined(MWPGITVERSION) && defined(MWPGITSTAMP)
#include <stdio.h>
#include <mwp-config.h>

//#define xstr(s) str(s)
//#define str(x) #x

const char * get_build(void) {
     static char stamp[80];
     char * gv = MWPGITVERSION;
     char * gs = MWPGITSTAMP;
     sprintf(stamp, "%s / %s", gv, gs);
     return stamp;
}

const char * get_id(void) {
     return MWP_VERSION_STRING;
}

const char * get_build_host(void) {
  return
#ifdef BUILDINFO
      BUILDINFO;
#else
  "";
#endif
}

const char * get_build_compiler(void) {
  return
#ifdef COMPINFO
      COMPINFO;
#elif defined(__clang__)
      __VERSION__;
#else
  "gcc " __VERSION__;
#endif
}

#else
#include "mwpvers.h"
const char * get_build(void) {
  // git dddd-mm-yy
  return mwpvers;
}
const char * get_id(void) {
  //yy.jd.ds/100
  return mwpid;
}
const char * get_build_host(void) {
  return "";
}
#endif
