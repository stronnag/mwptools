#include <windows.h>
#include <wchar.h>
#include <tchar.h>
#include <stdio.h>
#include <strsafe.h>
#include <io.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdbool.h>
#include <tlhelp32.h>
#include <fnmatch.h>

#define BUFSIZE 2048

typedef enum  {
  PROCESS_LAUNCH_NONE = 0,
  PROCESS_LAUNCH_STDIN = 1,
  PROCESS_LAUNCH_STDOUT = 2,
  PROCESS_LAUNCH_STDERR = 4,
  PROCESS_LAUNCH_WAIT = 80
} ProcessLaunch;



/* Copyright (C) 1992 Free Software Foundation, Inc.
This file is part of the GNU C Library.

The GNU C Library is free software; you can redistribute it and/or
modify it under the terms of the GNU Library General Public License as
published by the Free Software Foundation; either version 2 of the
License, or (at your option) any later version.

The GNU C Library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Library General Public License for more details.  */

/* Modified slightly by Brian Berliner <berliner@sun.com> and
   Jim Blandy <jimb@cyclic.com> for CVS use */
/* Modified slightly by j.f. dockes for recoll use */

#ifdef _WIN32
#include <ctype.h>
static inline int fold_fn_char(int c)
{
    /* Only ASCII for now... */
    if (c == '\\')
        return '/';
    if (c > 0 && c <= 127)
        return tolower(c);
    return c;
}
#define FOLD_FN_CHAR(c) fold_fn_char(c)
#endif /* _WIN32 */

/* Some file systems are case-insensitive.  If FOLD_FN_CHAR is
   #defined, it maps the character C onto its "canonical" form.  In a
   case-insensitive system, it would map all alphanumeric characters
   to lower case.  Under Windows NT, / and \ are both path component
   separators, so FOLD_FN_CHAR would map them both to /.  */
#ifndef FOLD_FN_CHAR
#define FOLD_FN_CHAR(c) (c)
#endif

#include <errno.h>

/* Bits set in the FLAGS argument to `fnmatch'.  */
#undef FNM_PATHNAME
#define    FNM_PATHNAME    (1 << 0)/* No wildcard can ever match `/'.  */
#undef FNM_NOESCAPE
#define    FNM_NOESCAPE    (1 << 1)/* Backslashes don't quote special chars.  */
#undef FNM_PERIOD
#define    FNM_PERIOD    (1 << 2)/* Leading `.' is matched only explicitly.  */
#undef __FNM_FLAGS
#define    __FNM_FLAGS    (FNM_PATHNAME|FNM_NOESCAPE|FNM_PERIOD)

/* Value returned by `fnmatch' if STRING does not match PATTERN.  */
#undef FNM_NOMATCH
#define    FNM_NOMATCH    1

/* Match STRING against the filename pattern PATTERN, returning zero if
   it matches, nonzero if not.  */
int fnmatch (const char *pattern, const char *string, int flags) {
  register const char *p = pattern, *n = string;
  register char c;

  if ((flags & ~__FNM_FLAGS) != 0)
    {
      errno = EINVAL;
      return -1;
    }

  while ((c = *p++) != '\0')
    {
      switch (c)
    {
    case '?':
      if (*n == '\0')
        return FNM_NOMATCH;
      else if ((flags & FNM_PATHNAME) && *n == '/')
        return FNM_NOMATCH;
      else if ((flags & FNM_PERIOD) && *n == '.' &&
           (n == string || ((flags & FNM_PATHNAME) && n[-1] == '/')))
        return FNM_NOMATCH;
      break;

    case '\\':
      if (!(flags & FNM_NOESCAPE))
        c = *p++;
      if (*n != c)
        return FNM_NOMATCH;
      break;

    case '*':
      if ((flags & FNM_PERIOD) && *n == '.' &&
          (n == string || ((flags & FNM_PATHNAME) && n[-1] == '/')))
        return FNM_NOMATCH;

      for (c = *p++; c == '?' || c == '*'; c = *p++, ++n)
        if (((flags & FNM_PATHNAME) && *n == '/') ||
        (c == '?' && *n == '\0'))
          return FNM_NOMATCH;

      if (c == '\0')
        return 0;

      {
        char c1 = (!(flags & FNM_NOESCAPE) && c == '\\') ? *p : c;
        for (--p; *n != '\0'; ++n)
          if ((c == '[' || *n == c1) &&
          fnmatch(p, n, flags & ~FNM_PERIOD) == 0)
        return 0;
        return FNM_NOMATCH;
      }

    case '[':
      {
        /* Nonzero if the sense of the character class is inverted.  */
        register int not;

        if (*n == '\0')
          return FNM_NOMATCH;

        if ((flags & FNM_PERIOD) && *n == '.' &&
        (n == string || ((flags & FNM_PATHNAME) && n[-1] == '/')))
          return FNM_NOMATCH;

        not = (*p == '!' || *p == '^');
        if (not)
          ++p;

        c = *p++;
        for (;;)
          {
        register char cstart = c, cend = c;

        if (!(flags & FNM_NOESCAPE) && c == '\\')
          cstart = cend = *p++;

        if (c == '\0')
          /* [ (unterminated) loses.  */
          return FNM_NOMATCH;

        c = *p++;

        if ((flags & FNM_PATHNAME) && c == '/')
          /* [/] can never match.  */
          return FNM_NOMATCH;

        if (c == '-' && *p != ']')
          {
            cend = *p++;
            if (!(flags & FNM_NOESCAPE) && cend == '\\')
              cend = *p++;
            if (cend == '\0')
              return FNM_NOMATCH;
            c = *p++;
          }

        if (*n >= cstart && *n <= cend)
          goto matched;

        if (c == ']')
          break;
          }
        if (!not)
          return FNM_NOMATCH;
        break;

      matched:;
        /* Skip the rest of the [...] that already matched.  */
        while (c != ']')
          {
        if (c == '\0')
          /* [... (unterminated) loses.  */
          return FNM_NOMATCH;

        c = *p++;
        if (!(flags & FNM_NOESCAPE) && c == '\\')
          /* 1003.2d11 is unclear if this is right.  %%% */
          ++p;
          }
        if (not)
          return FNM_NOMATCH;
      }
      break;

    default:
      if (FOLD_FN_CHAR (c) != FOLD_FN_CHAR (*n))
        return FNM_NOMATCH;
    }

      ++n;
    }

  if (*n == '\0')
    return 0;

  return FNM_NOMATCH;
}


HANDLE create_win_process(char *cmd, int flags, int *sout, int *eout, DWORD *pid) {
     PROCESS_INFORMATION piProcInfo;
     STARTUPINFO siStartInfo;
     bool bSuccess;
     HANDLE shandle;
     HANDLE ehandle;
     int spipes[2];
     int epipes[2];

     *sout = -1;
     *eout = -1;
     if((((ProcessLaunch)flags) & PROCESS_LAUNCH_STDOUT) == PROCESS_LAUNCH_STDOUT) {
	  _pipe(spipes, 4096,_O_BINARY);
	  shandle = (HANDLE)_get_osfhandle(spipes[1]);
     }
     if((((ProcessLaunch)flags) & PROCESS_LAUNCH_STDERR) == PROCESS_LAUNCH_STDERR) {
	  _pipe(epipes, 4096,_O_BINARY);
	  ehandle = (HANDLE)_get_osfhandle(epipes[1]);
     }

     memset(&piProcInfo, 0, sizeof(PROCESS_INFORMATION) );
     memset( &siStartInfo, 0, sizeof(STARTUPINFO) );
     siStartInfo.cb = sizeof(STARTUPINFO);

     siStartInfo.wShowWindow = SW_HIDE;
     siStartInfo.hStdError = ehandle;
     siStartInfo.hStdOutput = shandle;
     siStartInfo.dwFlags |= STARTF_USESTDHANDLES|STARTF_USESHOWWINDOW;

     bSuccess = CreateProcess(NULL,
			      cmd,     // command line
			      NULL,          // process security attributes
			      NULL,          // primary thread security attributes
			      TRUE,          // handles are inherited
			      0,             // creation flags
			      NULL,          // use parent's environment
			      NULL,          // current directory
			      &siStartInfo,  // STARTUPINFO pointer
			      &piProcInfo);  // receives PROCESS_INFORMATION

     if((flags & PROCESS_LAUNCH_STDOUT) == PROCESS_LAUNCH_STDOUT) {
	  *sout = spipes[0];
	  close(spipes[1]);
     }
     if((flags & PROCESS_LAUNCH_STDERR) == PROCESS_LAUNCH_STDERR) {
	  *eout = epipes[0];
	  close(epipes[1]);
     }

     if (bSuccess ) {
	  CloseHandle(piProcInfo.hThread);
     } else {
	  if((flags & 1) == 1) {
	       close(spipes[0]);
	  }
	  if((flags & 2) == 2) {
	       close(epipes[1]);
	  }
     }
     *pid =  piProcInfo.dwProcessId;
     return piProcInfo.hProcess;
}

BOOL waitproc(HANDLE h, int *sts) {
  if(h != NULL) {
    WaitForSingleObject(h, INFINITE);
    DWORD wait_status;
    BOOL rv = GetExitCodeProcess(h, &wait_status);
    CloseHandle(h);
    if (sts != NULL) {
      *sts = (int)wait_status;
    }
    return rv;
  }
}

int proc_get_pid(HANDLE h) {
     return GetProcessId(h);
}

void proc_kill (DWORD pid) {
     HANDLE h = OpenProcess(PROCESS_TERMINATE, false, pid);
     if (h != NULL) {
	  TerminateProcess(h, 1);
	  CloseHandle(h);
     }
}

int pid_from_name(char *procname) {
  HANDLE hSnapshot;
  PROCESSENTRY32 pe;
  int pid = -1;
  BOOL hResult;

  hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (INVALID_HANDLE_VALUE == hSnapshot) return 0;

  // initializing size: needed for using Process32First
  pe.dwSize = sizeof(PROCESSENTRY32);

  // info about first process encountered in a system snapshot
  hResult = Process32First(hSnapshot, &pe);
  // retrieve information about the processes
  // and exit if unsuccessful
  while (hResult) {
    // if we find the process: return process ID
    if (fnmatch(procname, pe.szExeFile, 0) == 0) {
      pid = pe.th32ProcessID;
      break;
    }
    hResult = Process32Next(hSnapshot, &pe);
  }

  // closes an open handle (CreateToolhelp32Snapshot)
  CloseHandle(hSnapshot);
  return pid;
}
