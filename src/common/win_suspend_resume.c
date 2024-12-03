#include <windows.h>
#include <stdbool.h>

#define STATUS_INSUFFICIENT_RESOURCES 0xC000009A

typedef _Return_type_success_(return >= 0) LONG NTSTATUS;
typedef NTSTATUS *PNTSTATUS;

#define NT_SUCCESS(Status) (((NTSTATUS)(Status)) >= 0)

typedef NTSTATUS(NTAPI *pNtSuspendProcess) (
    HANDLE ProcessHandle
);

typedef NTSTATUS(NTAPI *pNtResumeProcess)(
    HANDLE ProcessHandle
);

static pNtSuspendProcess fNtSuspendProcess;
static pNtResumeProcess fNtResumeProcess;

BOOLEAN InitializeExports() {
    HMODULE hNtdll = GetModuleHandle("NTDLL");

    if (!hNtdll) {
        return FALSE;
    }

    fNtSuspendProcess = (pNtSuspendProcess)GetProcAddress(hNtdll,
       "NtSuspendProcess");

    fNtResumeProcess = (pNtResumeProcess)GetProcAddress(hNtdll,
        "NtResumeProcess");

    if (fNtSuspendProcess == NULL || fNtResumeProcess == NULL) {
        return FALSE;
    }
    return TRUE;
}

NTSTATUS NTAPI NtSuspendProcess(HANDLE ProcessHandle) {
  if (fNtSuspendProcess == NULL) {
    InitializeExports();
  }

  if (fNtSuspendProcess == NULL) {
    return STATUS_INSUFFICIENT_RESOURCES;
  }
  return fNtSuspendProcess(ProcessHandle);
}

BOOLEAN WINAPI _SuspendProcess(HANDLE ProcessHandle) {
  if (!ProcessHandle) {
    return FALSE;
  }
  return (NT_SUCCESS(NtSuspendProcess(ProcessHandle))) ? TRUE : FALSE;
}

void winsuspend(DWORD pid) {
  //BOOLEAN res = FALSE;
  HANDLE h = OpenProcess(PROCESS_SUSPEND_RESUME, false, pid);
  if (h != NULL) {
    _SuspendProcess(h);
    CloseHandle(h);
  }
  return;
}

NTSTATUS NTAPI NtResumeProcess(HANDLE ProcessHandle) {
    if (!fNtResumeProcess) {
      InitializeExports();
    }
    if (!fNtResumeProcess) {
      return STATUS_INSUFFICIENT_RESOURCES;
    }
    return fNtResumeProcess(ProcessHandle);
}

BOOLEAN WINAPI _ResumeProcess(HANDLE ProcessHandle) {
    if (!ProcessHandle)  {
        return FALSE;
    }
    return (NT_SUCCESS(NtResumeProcess(ProcessHandle)))
        ? TRUE : FALSE;
}

void winresume(DWORD pid) {
  //  BOOLEAN res = FALSE;
  HANDLE h = OpenProcess(PROCESS_SUSPEND_RESUME, false, pid);
  if (h != NULL) {
    _ResumeProcess(h);
    CloseHandle(h);
  }
  return;
}
