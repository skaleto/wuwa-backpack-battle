//go:build windows

package main

import (
	"errors"
	"os/exec"
	"syscall"
	"time"
)

func waitParent(pid int, timeout time.Duration) error {
	handle, err := syscall.OpenProcess(0x00100000, false, uint32(pid))
	if err == syscall.Errno(87) {
		return nil
	}
	if err != nil {
		return errors.New("parent_wait_failed")
	}
	defer syscall.CloseHandle(handle)
	event, err := syscall.WaitForSingleObject(handle, uint32(timeout.Milliseconds()))
	if err != nil {
		return errors.New("parent_wait_failed")
	}
	if event != 0 {
		return errors.New("parent_still_running")
	}
	return nil
}
func configureChild(cmd *exec.Cmd) { cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: 0x00000200} }
