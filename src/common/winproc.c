#include <windows.h>
#include <wchar.h>
#include <tchar.h>
#include <stdio.h>
#include <strsafe.h>
#include <io.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdbool.h>

#define BUFSIZE 2048

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
     if((flags & 1) == 1) {
	  _pipe(spipes, 4096,_O_BINARY);
	  shandle = (HANDLE)_get_osfhandle(spipes[1]);
     }
     if((flags & 2) == 2) {
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

     if((flags & 1) == 1) {
	  *sout = spipes[0];
	  close(spipes[1]);
     }
     if((flags & 2) == 2) {
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

void waitproc(HANDLE h) {
     if(h != NULL) {
	  WaitForSingleObject(h, INFINITE);
	  CloseHandle(h);
    }
}

DWORD proc_get_pid(HANDLE h) {
     return GetProcessId(h);
}

void proc_kill (DWORD pid) {
     HANDLE h = OpenProcess(PROCESS_TERMINATE, false, pid);
     if (h != NULL) {
	  TerminateProcess(h, 1);
	  CloseHandle(h);
     }
}
