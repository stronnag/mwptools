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
