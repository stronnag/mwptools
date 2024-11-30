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
