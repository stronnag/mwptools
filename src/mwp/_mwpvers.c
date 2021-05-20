
/* ugly hack because vala doesn't support -Dx=y */
#if defined(MWPGITVERSION) && defined(MWPGITSTAMP)
#include <stdio.h>
#include <mwp-config.h>

#define xstr(s) str(s)
#define str(x) #x

const char * get_build(void)
{
     static char stamp[80];
     char * gv = xstr(MWPGITVERSION);
     char * gs = xstr(MWPGITSTAMP);
     sprintf(stamp, "%s / %s", gv, gs);
     return stamp;
}

const char * get_id(void)
{
     return MWP_VERSION_STRING;
}

#else
#include "mwpvers.h"
char * get_build(void)
{
     // git dddd-mm-yy
     return mwpvers;
}
char * get_id(void)
{
     //yy.jd.ds/100
     return mwpid;
}
#endif
