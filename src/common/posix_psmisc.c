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
