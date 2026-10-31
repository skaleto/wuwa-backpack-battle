//go:build !windows

package main

import (
	"errors"
	"os/exec"
	"syscall"
	"time"
)

func waitParent(pid int, timeout time.Duration) error {
	end := time.Now().Add(timeout)
	for time.Now().Before(end) {
		err := syscall.Kill(pid, 0)
		if err == syscall.ESRCH {
			return nil
		}
		if err != nil {
			return errors.New("parent_wait_failed")
		}
		time.Sleep(100 * time.Millisecond)
	}
	return errors.New("parent_still_running")
}
func configureChild(cmd *exec.Cmd) { cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true} }
