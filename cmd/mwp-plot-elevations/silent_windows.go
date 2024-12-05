//go:build windows
// +build windows

package main

import (
	"os/exec"
	"syscall"
)

func SetSilentProcess(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: 0x08000000} // CREATE_NO_WINDOW
}
