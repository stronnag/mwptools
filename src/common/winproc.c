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
#include <glib.h>

typedef enum  {
  PROCESS_LAUNCH_NONE = 0,
  PROCESS_LAUNCH_STDIN = 1,
  PROCESS_LAUNCH_STDOUT = 2,
  PROCESS_LAUNCH_STDERR = 4,
  PROCESS_LAUNCH_WAIT = 8,
  PROCESS_LAUNCH_WINSPECIAL = 10,
} ProcessLaunch;

static HANDLE get_nul_handle(void) {
  SECURITY_ATTRIBUTES secattr;
  secattr.nLength = sizeof secattr;
  secattr.lpSecurityDescriptor = NULL;
  secattr.bInheritHandle = FALSE;
  return CreateFile(_T("NUL"), GENERIC_ALL, 0, &secattr, OPEN_EXISTING, 0, NULL);
}

HANDLE create_win_process(char *cmd, int flags, int *sinp,  int *sout, int *eout, DWORD *pid) {
     PROCESS_INFORMATION piProcInfo;
     STARTUPINFO siStartInfo;
     bool bSuccess;
     HANDLE ihandle = NULL;
     HANDLE shandle = NULL;
     HANDLE ehandle = NULL;
     int ipipes[2];
     int spipes[2];
     int epipes[2];

     *sout = -1;
     *eout = -1;
     *sinp = -1;

     if((((ProcessLaunch)flags) & PROCESS_LAUNCH_STDIN) == PROCESS_LAUNCH_STDIN) {
       _pipe(ipipes, 4096,_O_BINARY);
       ihandle = (HANDLE)_get_osfhandle(ipipes[0]);
     }
     if((((ProcessLaunch)flags) & PROCESS_LAUNCH_STDOUT) == PROCESS_LAUNCH_STDOUT) {
       _pipe(spipes, 4096,_O_BINARY);
       shandle = (HANDLE)_get_osfhandle(spipes[1]);
     } else {
       shandle = get_nul_handle();
     }
     if((((ProcessLaunch)flags) & PROCESS_LAUNCH_STDERR) == PROCESS_LAUNCH_STDERR) {
	  _pipe(epipes, 4096,_O_BINARY);
	  ehandle = (HANDLE)_get_osfhandle(epipes[1]);
     } else {
       ehandle = get_nul_handle();
     }

     memset(&piProcInfo, 0, sizeof(PROCESS_INFORMATION) );
     memset( &siStartInfo, 0, sizeof(STARTUPINFO) );
     siStartInfo.cb = sizeof(STARTUPINFO);

     siStartInfo.wShowWindow = SW_HIDE;
     siStartInfo.hStdError = ehandle;
     siStartInfo.hStdOutput = shandle;
     siStartInfo.hStdInput = ihandle;

     siStartInfo.dwFlags |= STARTF_USESTDHANDLES|STARTF_USESHOWWINDOW;

     DWORD cflags = 0;
     if((((ProcessLaunch)flags) & PROCESS_LAUNCH_WINSPECIAL) == PROCESS_LAUNCH_WINSPECIAL) {
       cflags = DETACHED_PROCESS|CREATE_BREAKAWAY_FROM_JOB;
     }

     bSuccess = CreateProcess(NULL,
			      cmd,     // command line
			      NULL,          // process security attributes
			      NULL,          // primary thread security attributes
			      TRUE,          // handles are inherited
			      cflags,        // creation flags
			      NULL,          // use parent's environment
			      NULL,          // current directory
			      &siStartInfo,  // STARTUPINFO pointer
			      &piProcInfo);  // receives PROCESS_INFORMATION

     if((flags & PROCESS_LAUNCH_STDIN) == PROCESS_LAUNCH_STDIN) {
	  *sinp = ipipes[1];
	  close(ipipes[0]);
     }
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
       if((flags & PROCESS_LAUNCH_STDIN) == PROCESS_LAUNCH_STDIN) {
	 close(ipipes[0]);
       }
       if((flags & PROCESS_LAUNCH_STDOUT) == PROCESS_LAUNCH_STDOUT) {
	 close(spipes[1]);
       }
       if((flags & PROCESS_LAUNCH_STDERR) == PROCESS_LAUNCH_STDERR) {
	 close(epipes[1]);
       }
     }
     *pid =  piProcInfo.dwProcessId;
     return piProcInfo.hProcess;
}

BOOL waitproc(HANDLE h, int *sts) {
  BOOL rv = false;
  if(h != NULL) {
    WaitForSingleObject(h, INFINITE);
    DWORD wait_status;
    rv = GetExitCodeProcess(h, &wait_status);
    //    if((int)rv == 0) {
    //DWORD errc = GetLastError();
    //fprintf(stderr, ":DBG: ERROR errc %lx\n", errc);
    //}
    CloseHandle(h);
    if (sts != NULL) {
      *sts = (int)wait_status;
    }
  }
  return rv;
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

  pe.dwSize = sizeof(PROCESSENTRY32);
  hResult = Process32First(hSnapshot, &pe);
  while (hResult) {
    if (g_regex_match_simple (procname, pe.szExeFile, 0, 0)) {
      pid = pe.th32ProcessID;
      break;
    }
    hResult = Process32Next(hSnapshot, &pe);
  }

  CloseHandle(hSnapshot);
  return pid;
}
