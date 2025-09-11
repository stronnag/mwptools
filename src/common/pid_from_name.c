#include <stddef.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <glib.h>

#ifdef __linux
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <sys/types.h>
#include <libgen.h>

int* pid_from_name(const char* procname, int *array_length) {
  DIR* dir;
  struct dirent* ent;
  char* endptr;
  char buf[4096];

  int nres = 0;
  int nalloc = 16;

  if (!(dir = opendir("/proc"))) {
    return NULL;
  }

  int *pids = calloc(sizeof(int), nalloc);

  uid_t uid = getuid();

  while((ent = readdir(dir)) != NULL) {
    long lpid = strtol(ent->d_name, &endptr, 10);
    if (*endptr != '\0') {
      continue;
    }

    int fd;
    char *ptr = stpcpy(buf, "/proc/");
    ptr = stpcpy(ptr, ent->d_name);
    strcpy(ptr, "uid_map");
    fd = open(buf, O_RDONLY);
    if (fd != -1) {
      int n = read(fd, buf, sizeof(buf));
      close(fd);
      if (n > 0) {
	long luid = strtol(buf, NULL, 10);
	if (luid != uid) {
	  continue;
	}
      }
    }

    strcpy(ptr, "/comm");
    fd = open(buf, O_RDONLY);
    if (fd != -1) {
      if (read(fd, buf, sizeof(buf)) > 0) {
	char *sp = strchr(buf, '\n');
	if (sp != NULL) {
	  *sp = 0;
	}
	if (g_regex_match_simple (procname, buf, 0, 0)) {
	  if (nres == nalloc) {
	    nalloc += 16;
	    pids = realloc(pids, (nalloc*sizeof(int)));
	  }
	  pids[nres] = lpid;
	  nres++;
	}
      }
      close(fd);
    }
  }
  closedir(dir);
  *array_length = nres;
  return pids;
}

#elif defined(__WINNT)
#include <windows.h>
#include <wchar.h>
#include <tchar.h>
#include <tlhelp32.h>
#include <strsafe.h>
#include <io.h>

int *pid_from_name(char *procname, int* array_length) {
  HANDLE hSnapshot;
  PROCESSENTRY32 pe;
  int pid = -1;
  BOOL hResult;
  int nres = 0;
  int nalloc = 16;

  int *pids = calloc(sizeof(int), nalloc);
  hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (hSnapshot != INVALID_HANDLE_VALUE) {
    pe.dwSize = sizeof(PROCESSENTRY32);
    hResult = Process32First(hSnapshot, &pe);
    while (hResult) {
      if (g_regex_match_simple (procname, pe.szExeFile, 0, 0)) {
	if (nres == nalloc) {
	  nalloc += 16;
	  pids = realloc(pids, (nalloc*sizeof(int)));
	}
	pids[nres] = (int)pe.th32ProcessID;
	nres++;
      }
      hResult = Process32Next(hSnapshot, &pe);
    }
    CloseHandle(hSnapshot);
  }
  *array_length = nres;
  return pids;
}

#else
#include <unistd.h>
#include <sys/types.h>
#include <sys/user.h>
#include <sys/sysctl.h>

typedef struct kinfo_proc kinfo_proc;

int * pid_from_name (char *procname, int* array_length) {
  int nres = 0;
  int nalloc = 16;
  int err;
  kinfo_proc *kp;
  bool  done;
  size_t length;
  int proc_count = 0;
  int  name[] = { CTL_KERN, KERN_PROC, KERN_PROC_UID, 0, 0 };
  kp = NULL;
  done = false;

  uid_t uid =  getuid();
  name[3] = uid;

  do {
    length = 0;
    err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
		  NULL, &length,
		  NULL, 0);
    if (err == -1) {
      err = errno;
    }

    if (err == 0) {
      kp = malloc(length);
      if (kp == NULL) {
	err = ENOMEM;
      }
    }
    if (err == 0) {
      err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
		    kp, &length,
		    NULL, 0);
      if (err == -1) {
	err = errno;
      }
      if (err == 0) {
	done = true;
      } else if (err == ENOMEM) {
	free(kp);
	kp = NULL;
	err = 0;
      }
    }
  } while (err == 0 && ! done);

  if (err != 0 && kp != NULL) {
    free(kp);
    kp = NULL;
  }
  if (err == 0) {
    proc_count = length / sizeof(kinfo_proc);
  }

  int *pids = calloc(sizeof(int), nalloc);

  for(int i = 0; i < proc_count; i++) {
#ifdef __APPLE__
    if (g_regex_match_simple (procname, kp[i].kp_proc.p_comm, 0, 0)) {
#else
    if (g_regex_match_simple (procname, kp[i].ki_comm, 0, 0)) {
#endif
      if (nres == nalloc) {
        nalloc += 16;
        pids = realloc(pids, (nalloc*sizeof(int)));
      }
#ifdef __APPLE__
      pids[nres] = (int)kp[i].kp_proc.p_pid;
#else
      pids[nres] = (int)kp[i].ki_pid;
#endif
      nres++;

    }
  }
  free(kp);
  *array_length = nres;
  return pids;
}
#endif
