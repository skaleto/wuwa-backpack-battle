package main

import (
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

// Set by build.py from the public channel key. Jobs cannot choose a trust anchor.
var publicKeyB64 string

type Job struct {
	Envelope        Envelope `json:"envelope"`
	Platform        string   `json:"platform"`
	Archive         string   `json:"archive"`
	InstallDir      string   `json:"install_dir"`
	ParentPID       int      `json:"parent_pid"`
	MinimumSequence int64    `json:"minimum_sequence"`
	AckDir          string   `json:"ack_dir"`
	AckToken        string   `json:"ack_token"`
}

func validateUpgrade(old InstallMarker, r Release, a Artifact, minimum int64) error {
	if r.Sequence <= old.Sequence || r.Sequence <= minimum || minimum < 0 || a.Executable == "" {
		return errors.New("not_newer")
	}
	return nil
}
func normalizeJob(j Job, jobPath string) (Job, string, error) {
	paths := []*string{&j.Archive, &j.InstallDir, &j.AckDir, &jobPath}
	for _, p := range paths {
		converted := filepath.FromSlash(*p)
		if !filepath.IsAbs(converted) {
			return j, jobPath, errors.New("invalid_job_path")
		}
		for _, part := range strings.Split(filepath.ToSlash(converted), "/") {
			if part == ".." {
				return j, jobPath, errors.New("invalid_job_path")
			}
		}
		*p = filepath.Clean(converted)
	}
	return j, jobPath, nil
}
func validateJob(j Job, jobPath, platform string) error {
	var err error
	j, jobPath, err = normalizeJob(j, jobPath)
	if err != nil {
		return err
	}
	token, err := hex.DecodeString(j.AckToken)
	if err != nil || len(token) != 32 || j.AckToken != strings.ToLower(j.AckToken) || j.Platform != platform || j.ParentPID < 1 || j.ParentPID == os.Getpid() {
		return errors.New("invalid_job")
	}
	if filepath.Dir(jobPath) != j.AckDir || filepath.Dir(j.InstallDir) == j.InstallDir {
		return errors.New("invalid_job_path")
	}
	info, err := os.Lstat(j.AckDir)
	if err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 || (runtime.GOOS != "windows" && info.Mode().Perm()&0077 != 0) {
		return errors.New("cache_permissions")
	}
	if _, err = os.Lstat(filepath.Join(j.AckDir, "full-"+j.AckToken+".ack")); !os.IsNotExist(err) {
		return errors.New("stale_job")
	}
	return nil
}
func waitHealthy(ack string, done <-chan error, timeoutMS int) string {
	timer := time.NewTimer(time.Duration(timeoutMS) * time.Millisecond)
	defer timer.Stop()
	tick := time.NewTicker(100 * time.Millisecond)
	defer tick.Stop()
	for {
		if f, err := os.Lstat(ack); err == nil && f.Mode().IsRegular() && f.Size() <= 128 {
			return "healthy"
		}
		select {
		case <-done:
			// An acknowledged game may exit before the polling interval expires.
			if f, err := os.Lstat(ack); err == nil && f.Mode().IsRegular() && f.Size() <= 128 {
				return "healthy"
			}
			return "exited"
		case <-timer.C:
			return "unconfirmed"
		case <-tick.C:
		}
	}
}
func launchGame(executable, token string) (<-chan error, error) {
	args := []string{}
	if token != "" {
		args = []string{"--", "--update-ack", token}
	}
	cmd := exec.Command(executable, args...)
	cmd.Dir = filepath.Dir(executable)
	configureChild(cmd)
	if err := cmd.Start(); err != nil {
		return nil, errors.New("launch_failed")
	}
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	return done, nil
}
func restoreBackup(live, staged string) error {
	if os.Rename(live, staged) != nil {
		return errors.New("rollback_failed")
	}
	if os.Rename(live+".update-backup", live) != nil {
		return errors.New("rollback_failed")
	}
	return nil
}
func runJob(jobPath string) (string, error) {
	raw, err := readBounded(jobPath, 131072)
	if err != nil {
		return "", errors.New("job_read")
	}
	if runtime.GOOS != "windows" {
		info, _ := os.Stat(jobPath)
		if info.Mode().Perm()&0077 != 0 {
			return "", errors.New("job_permissions")
		}
	}
	var j Job
	if json.Unmarshal(raw, &j) != nil {
		return "", errors.New("job_format")
	}
	platform := ""
	if runtime.GOOS == "windows" {
		platform = "Windows"
	}
	if runtime.GOOS == "darwin" {
		platform = "macOS"
	}
	j, jobPath, err = normalizeJob(j, jobPath)
	if err != nil {
		return "", err
	}
	if err = validateJob(j, jobPath, platform); err != nil {
		return "", err
	}
	key, err := base64.StdEncoding.DecodeString(publicKeyB64)
	if err != nil || len(key) == 0 {
		return "", errors.New("missing_trust_key")
	}
	release, a, err := verifyManifest(j.Envelope, key, platform)
	if err != nil {
		return "", err
	}
	if err = recoverInterrupted(j.InstallDir); err != nil {
		return "", err
	}
	old, err := validateInstallation(j.InstallDir)
	if err != nil {
		return "", err
	}
	if err = validateUpgrade(old, release, a, j.MinimumSequence); err != nil {
		return "", err
	}
	if err = verifyArchive(j.Archive, a); err != nil {
		return "", err
	}
	// Stage beside the installation so both renames remain on one filesystem.
	stage, err := os.MkdirTemp(filepath.Dir(j.InstallDir), ".solaris-update-")
	if err != nil {
		return "", errors.New("install_not_writable")
	}
	os.Remove(stage)
	defer os.RemoveAll(stage)
	if err = extractZip(j.Archive, stage, a.ArchiveRoot); err != nil {
		return "", err
	}
	next, err := validateInstallation(stage)
	if err != nil {
		return "", err
	}
	if next.Sequence != release.Sequence || next.Executable != a.Executable {
		return "", errors.New("marker_mismatch")
	}
	// A previous confirmed installation can leave a backup after interrupted cleanup.
	// Never delete it if it contains files outside its own installation manifest.
	backup := j.InstallDir + ".update-backup"
	if _, statErr := os.Lstat(backup); statErr == nil {
		previous, validationErr := validateInstallation(backup)
		if validationErr != nil || previous.Sequence >= old.Sequence || j.MinimumSequence < old.Sequence {
			return "", errors.New("backup_needs_review")
		}
		if os.RemoveAll(backup) != nil {
			return "", errors.New("backup_cleanup")
		}
	}
	if err = writeReady(jobPath + ".ready"); err != nil {
		return "", err
	}
	defer os.Remove(jobPath + ".ready")
	if err = waitParent(j.ParentPID, 120*time.Second); err != nil {
		return "", err
	}
	var done <-chan error
	err = replaceInstallation(j.InstallDir, stage, func(executable string) error {
		var launchErr error
		done, launchErr = launchGame(executable, j.AckToken)
		return launchErr
	})
	if err != nil {
		if restored, e := validateInstallation(j.InstallDir); e == nil && restored.Sequence == old.Sequence {
			_, _ = launchGame(filepath.Join(j.InstallDir, filepath.FromSlash(old.Executable)), "")
		}
		return "", err
	}
	ack := filepath.Join(j.AckDir, "full-"+j.AckToken+".ack")
	switch waitHealthy(ack, done, 90000) {
	case "healthy":
		// The game has started; the backup is retained until the next confirmed update.
		return "installed", nil
	case "exited":
		if err = restoreBackup(j.InstallDir, stage); err != nil {
			return "", err
		}
		_, _ = launchGame(filepath.Join(j.InstallDir, filepath.FromSlash(old.Executable)), "")
		return "rolled_back", errors.New("startup_failed")
	default:
		// Never rename files under a process that is still running.
		return "awaiting_health", nil
	}
}
func writeReady(path string) error {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return errors.New("ready_write")
	}
	_, err = f.Write([]byte(`{"schema":1,"ready":true}`))
	if err == nil {
		err = f.Sync()
	}
	f.Close()
	if err != nil {
		os.Remove(path)
		return errors.New("ready_write")
	}
	return nil
}
func writeResult(path, status string, err error) {
	value := map[string]any{"schema": 1, "status": status, "ok": err == nil}
	if err != nil {
		value["error"] = err.Error()
	}
	raw, _ := json.Marshal(value)
	tmp := path + ".tmp"
	f, e := os.OpenFile(tmp, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0600)
	if e != nil {
		return
	}
	_, e = f.Write(raw)
	if e == nil {
		e = f.Sync()
	}
	f.Close()
	if e == nil {
		os.Rename(tmp, path)
	} else {
		os.Remove(tmp)
	}
}
func main() {
	job := flag.String("job", "", "private update job JSON")
	flag.Parse()
	if *job == "" || !filepath.IsAbs(*job) {
		fmt.Fprintln(os.Stderr, "invalid_job")
		os.Exit(2)
	}
	status, err := runJob(*job)
	writeResult(*job+".result.json", status, err)
	if err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(1)
	}
}
