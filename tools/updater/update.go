package main

import (
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
)

const appID = "game.solarisbrawl.demo"
const manifestLimit = 65536
const packageLimit int64 = 2147483648
const markerName = "update-install.json"

type Envelope struct {
	Payload   string `json:"payload"`
	Signature string `json:"signature"`
}
type Artifact struct {
	Kind        string    `json:"kind"`
	SHA256      string    `json:"sha256"`
	Bytes       int64     `json:"bytes"`
	ArchiveRoot string    `json:"archive_root"`
	Executable  string    `json:"executable"`
	Full        *Artifact `json:"full,omitempty"`
}
type Release struct {
	Schema    int                 `json:"schema"`
	Sequence  int64               `json:"sequence"`
	Version   string              `json:"version"`
	Platforms map[string]Artifact `json:"platforms"`
}
type InstallMarker struct {
	Schema     int      `json:"schema"`
	AppID      string   `json:"app_id"`
	Sequence   int64    `json:"sequence"`
	Executable string   `json:"executable"`
	Files      []string `json:"files"`
}

func verifyManifest(env Envelope, publicPEM []byte, platform string) (Release, Artifact, error) {
	fail := func() (Release, Artifact, error) { return Release{}, Artifact{}, errors.New("invalid_release") }
	if len(env.Payload) > manifestLimit*2 || len(env.Signature) > 2048 || (platform != "Windows" && platform != "macOS") {
		return fail()
	}
	raw, err := base64.StdEncoding.Strict().DecodeString(env.Payload)
	if err != nil || len(raw) == 0 || len(raw) > manifestLimit {
		return fail()
	}
	sig, err := base64.StdEncoding.Strict().DecodeString(env.Signature)
	if err != nil {
		return fail()
	}
	block, rest := pem.Decode(publicPEM)
	if block == nil || len(strings.TrimSpace(string(rest))) != 0 || block.Type != "PUBLIC KEY" {
		return fail()
	}
	anyKey, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return fail()
	}
	key, ok := anyKey.(*rsa.PublicKey)
	if !ok || key.Size() < 256 {
		return fail()
	}
	sum := sha256.Sum256(raw)
	if rsa.VerifyPKCS1v15(key, crypto.SHA256, sum[:], sig) != nil {
		return fail()
	}
	var release Release
	if json.Unmarshal(raw, &release) != nil || release.Schema != 1 || release.Sequence < 1 || release.Sequence > 2147483647 || release.Version == "" || len(release.Version) > 80 {
		return fail()
	}
	a, ok := release.Platforms[platform]
	if !ok {
		return fail()
	}
	if a.Kind == "patch" && a.Full != nil {
		a = *a.Full
	}
	hash, err := hex.DecodeString(a.SHA256)
	if a.Kind != "full" || err != nil || len(hash) != 32 || a.SHA256 != strings.ToLower(a.SHA256) || a.Bytes < 1 || a.Bytes > packageLimit || !safeRelative(a.ArchiveRoot) || strings.Contains(a.ArchiveRoot, "/") || !safeRelative(a.Executable) {
		return fail()
	}
	return release, a, nil
}

func verifyArchive(path string, a Artifact) error {
	info, err := os.Lstat(path)
	if err != nil || !info.Mode().IsRegular() || info.Size() != a.Bytes || a.Bytes < 1 || a.Bytes > packageLimit {
		return errors.New("archive_size")
	}
	f, err := os.Open(path)
	if err != nil {
		return errors.New("archive_read")
	}
	defer f.Close()
	h := sha256.New()
	n, err := io.Copy(h, io.LimitReader(f, a.Bytes+1))
	if err != nil || n != a.Bytes || hex.EncodeToString(h.Sum(nil)) != a.SHA256 {
		return errors.New("archive_checksum")
	}
	return nil
}

func readBounded(path string, limit int64) ([]byte, error) {
	info, err := os.Lstat(path)
	if err != nil || !info.Mode().IsRegular() || info.Size() > limit {
		return nil, errors.New("invalid_file")
	}
	f, err := os.Open(path)
	if err != nil {
		return nil, errors.New("file_read")
	}
	defer f.Close()
	data, err := io.ReadAll(io.LimitReader(f, limit+1))
	if err != nil || int64(len(data)) > limit {
		return nil, errors.New("file_size")
	}
	return data, nil
}

// A marker makes a directory an installation, never an arbitrary user folder.
// Unknown files cause refusal, and the whole previous installation is retained.
func validateInstallation(dir string) (InstallMarker, error) {
	fail := func() (InstallMarker, error) { return InstallMarker{}, errors.New("unrecognized_installation") }
	info, err := os.Lstat(dir)
	if err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return fail()
	}
	markerPath := markerName
	if macDir, macErr := os.Lstat(filepath.Join(dir, "Contents", "MacOS")); macErr == nil && macDir.IsDir() {
		markerPath = "Contents/Resources/" + markerName
		if _, rootErr := os.Lstat(filepath.Join(dir, markerName)); !os.IsNotExist(rootErr) {
			return fail()
		}
	}
	raw, err := readBounded(filepath.Join(dir, filepath.FromSlash(markerPath)), 4*1024*1024)
	if err != nil {
		return fail()
	}
	var m InstallMarker
	if json.Unmarshal(raw, &m) != nil || m.Schema != 1 || m.AppID != appID || m.Sequence < 1 || m.Sequence > 2147483647 || !safeRelative(m.Executable) || len(m.Files) == 0 || len(m.Files) > 50000 {
		return fail()
	}
	if markerPath != markerName && !strings.HasPrefix(m.Executable, "Contents/MacOS/") {
		return fail()
	}
	expected := map[string]bool{markerPath: true}
	folded := map[string]bool{strings.ToLower(markerPath): true}
	for _, name := range m.Files {
		if !safeRelative(name) || folded[strings.ToLower(name)] {
			return fail()
		}
		expected[name] = true
		folded[strings.ToLower(name)] = true
	}
	if !expected[m.Executable] {
		return fail()
	}
	found := map[string]bool{}
	err = filepath.WalkDir(dir, func(path string, d os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return errors.New("install_read")
		}
		if d.Type()&os.ModeSymlink != 0 {
			return errors.New("install_symlink")
		}
		if d.IsDir() {
			return nil
		}
		info, err := d.Info()
		if err != nil || !info.Mode().IsRegular() {
			return errors.New("install_file")
		}
		rel, err := filepath.Rel(dir, path)
		if err != nil {
			return err
		}
		name := filepath.ToSlash(rel)
		if !expected[name] {
			return errors.New("unowned_file")
		}
		found[name] = true
		return nil
	})
	if err != nil || len(found) != len(expected) {
		return fail()
	}
	return m, nil
}

// Rename on the same volume: never destroy the running install to make room.
// A prior backup is retained and prevents another swap until explicitly resolved.
func replaceInstallation(live, staged string, launch func(string) error) error {
	if _, err := validateInstallation(live); err != nil {
		return err
	}
	next, err := validateInstallation(staged)
	if err != nil {
		return err
	}
	backup := live + ".update-backup"
	if _, err = os.Lstat(backup); !os.IsNotExist(err) {
		return errors.New("backup_exists")
	}
	if err = os.Rename(live, backup); err != nil {
		return errors.New("backup_failed")
	}
	if err = os.Rename(staged, live); err != nil {
		if os.Rename(backup, live) != nil {
			return errors.New("rollback_failed")
		}
		return errors.New("activation_failed")
	}
	if err = launch(filepath.Join(live, filepath.FromSlash(next.Executable))); err != nil {
		if os.Rename(live, staged) != nil {
			return errors.New("rollback_failed")
		}
		if os.Rename(backup, live) != nil {
			return errors.New("rollback_failed")
		}
		return errors.New("launch_failed")
	}
	return nil
}

// Rerunning a job after a power loss between the two renames restores the old
// installation first. A present destination is never overwritten by recovery.
func recoverInterrupted(live string) error {
	if _, err := os.Lstat(live); err == nil {
		return nil
	} else if !os.IsNotExist(err) {
		return errors.New("install_read")
	}
	backup := live + ".update-backup"
	if _, err := validateInstallation(backup); err != nil {
		return errors.New("installation_missing")
	}
	if os.Rename(backup, live) != nil {
		return errors.New("rollback_failed")
	}
	return nil
}
