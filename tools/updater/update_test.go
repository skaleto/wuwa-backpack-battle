package main

import (
	"archive/zip"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"testing"
	"time"
)

func fixtureKey(t *testing.T) (*rsa.PrivateKey, []byte) {
	t.Helper()
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	der, _ := x509.MarshalPKIXPublicKey(&key.PublicKey)
	return key, pem.EncodeToMemory(&pem.Block{Type: "PUBLIC KEY", Bytes: der})
}
func signed(t *testing.T, key *rsa.PrivateKey, r Release) Envelope {
	t.Helper()
	raw, _ := json.Marshal(r)
	sum := sha256.Sum256(raw)
	sig, err := rsa.SignPKCS1v15(rand.Reader, key, crypto.SHA256, sum[:])
	if err != nil {
		t.Fatal(err)
	}
	return Envelope{Payload: base64.StdEncoding.EncodeToString(raw), Signature: base64.StdEncoding.EncodeToString(sig)}
}
func TestSignedFullSelection(t *testing.T) {
	key, pub := fixtureKey(t)
	a := Artifact{Kind: "full", SHA256: hex.EncodeToString(make([]byte, 32)), Bytes: 123, ArchiveRoot: "SolarisBrawl", Executable: "SolarisBrawl.exe"}
	r := Release{Schema: 1, Sequence: 12, Version: "0.2.0", Platforms: map[string]Artifact{"Windows": a}}
	env := signed(t, key, r)
	got, artifact, err := verifyManifest(env, pub, "Windows")
	if err != nil || got.Sequence != 12 || artifact.Executable != a.Executable {
		t.Fatalf("signed full selection failed: %v", err)
	}
	env.Payload = base64.StdEncoding.EncodeToString([]byte(`{"schema":1}`))
	if _, _, err = verifyManifest(env, pub, "Windows"); err == nil {
		t.Fatal("tampered payload accepted")
	}
	env = signed(t, key, r)
	if _, _, err = verifyManifest(env, pub, "macOS"); err == nil {
		t.Fatal("wrong platform accepted")
	}
	nested := a
	r.Platforms["Windows"] = Artifact{Kind: "patch", Full: &nested}
	if _, _, err = verifyManifest(signed(t, key, r), pub, "Windows"); err != nil {
		t.Fatal(err)
	}
}
func makeZip(t *testing.T, entries map[string]string, special string, mode os.FileMode) string {
	t.Helper()
	p := filepath.Join(t.TempDir(), "bundle.zip")
	f, err := os.Create(p)
	if err != nil {
		t.Fatal(err)
	}
	w := zip.NewWriter(f)
	for name, body := range entries {
		h := &zip.FileHeader{Name: name, Method: zip.Deflate}
		h.SetMode(0644)
		if name == special {
			h.SetMode(mode)
		}
		out, err := w.CreateHeader(h)
		if err != nil {
			t.Fatal(err)
		}
		out.Write([]byte(body))
	}
	if err = w.Close(); err != nil {
		t.Fatal(err)
	}
	f.Close()
	return p
}
func TestSafeExtraction(t *testing.T) {
	for _, name := range []string{"../escape", "SolarisBrawl/../../escape", "/SolarisBrawl/exe", "SolarisBrawl\\evil", "SolarisBrawl/a:stream", "SolarisBrawl/CON", "SolarisBrawl/a.", "Other/exe", "SolarisBrawl/a/./b"} {
		t.Run(name, func(t *testing.T) {
			p := makeZip(t, map[string]string{name: "bad"}, "", 0)
			if err := extractZip(p, filepath.Join(t.TempDir(), "stage"), "SolarisBrawl"); err == nil {
				t.Fatalf("accepted unsafe %q", name)
			}
		})
	}
	p := makeZip(t, map[string]string{"SolarisBrawl/link": "/tmp/out"}, "SolarisBrawl/link", os.ModeSymlink|0777)
	if err := extractZip(p, filepath.Join(t.TempDir(), "stage"), "SolarisBrawl"); err == nil {
		t.Fatal("accepted symlink")
	}
	p = makeZip(t, map[string]string{"SolarisBrawl/game": "ok"}, "SolarisBrawl/game", 0755)
	dest := filepath.Join(t.TempDir(), "stage")
	if err := extractZip(p, dest, "SolarisBrawl"); err != nil {
		t.Fatal(err)
	}
	b, _ := os.ReadFile(filepath.Join(dest, "game"))
	if string(b) != "ok" {
		t.Fatal("wrong extracted bytes")
	}
}
func install(t *testing.T, parent, version string, seq int64) string {
	t.Helper()
	dir := filepath.Join(parent, version)
	if err := os.MkdirAll(dir, 0700); err != nil {
		t.Fatal(err)
	}
	os.WriteFile(filepath.Join(dir, "game"), []byte(version), 0755)
	m := InstallMarker{Schema: 1, AppID: appID, Sequence: seq, Executable: "game", Files: []string{"game"}}
	raw, _ := json.Marshal(m)
	os.WriteFile(filepath.Join(dir, "update-install.json"), raw, 0600)
	return dir
}
func TestDedicatedInstallation(t *testing.T) {
	dir := install(t, t.TempDir(), "live", 1)
	if _, err := validateInstallation(dir); err != nil {
		t.Fatal(err)
	}
	os.WriteFile(filepath.Join(dir, "notes.txt"), []byte("user notes"), 0600)
	if _, err := validateInstallation(dir); err == nil {
		t.Fatal("accepted unknown user file")
	}
	os.Remove(filepath.Join(dir, "notes.txt"))
	os.Symlink("game", filepath.Join(dir, "alias"))
	if _, err := validateInstallation(dir); err == nil {
		t.Fatal("accepted install symlink")
	}
}
func TestSwapRollback(t *testing.T) {
	p := t.TempDir()
	live := install(t, p, "live", 1)
	staged := install(t, p, "stage", 2)
	if err := replaceInstallation(live, staged, func(string) error { return errors.New("no launch") }); err == nil {
		t.Fatal("expected launch failure")
	}
	b, _ := os.ReadFile(filepath.Join(live, "game"))
	if string(b) != "live" {
		t.Fatal("old install not restored")
	}
	staged = install(t, p, "stage2", 2)
	if err := replaceInstallation(live, staged, func(string) error { return nil }); err != nil {
		t.Fatal(err)
	}
	b, _ = os.ReadFile(filepath.Join(live, "game"))
	if string(b) != "stage2" {
		t.Fatal("new install not activated")
	}
	if _, err := os.Stat(live + ".update-backup"); err != nil {
		t.Fatal("rollback backup not retained")
	}
}
func TestArchiveHash(t *testing.T) {
	p := filepath.Join(t.TempDir(), "archive")
	os.WriteFile(p, []byte("hello"), 0600)
	sum := sha256.Sum256([]byte("hello"))
	a := Artifact{Bytes: 5, SHA256: hex.EncodeToString(sum[:])}
	if err := verifyArchive(p, a); err != nil {
		t.Fatal(err)
	}
	os.WriteFile(p, []byte("Hello"), 0600)
	if err := verifyArchive(p, a); err == nil {
		t.Fatal("tampered archive accepted")
	}
	a.Bytes = 4
	if err := verifyArchive(p, a); err == nil {
		t.Fatal("wrong size accepted")
	}
}

func TestDowngradeAndForeignDirectoryRejected(t *testing.T) {
	dir := install(t, t.TempDir(), "live", 12)
	m, err := validateInstallation(dir)
	if err != nil {
		t.Fatal(err)
	}
	if err := validateUpgrade(m, Release{Sequence: 12}, Artifact{Executable: "game"}, 12); err == nil {
		t.Fatal("same release accepted")
	}
	if err := validateUpgrade(m, Release{Sequence: 13}, Artifact{Executable: "game"}, 14); err == nil {
		t.Fatal("sequence lower than observed accepted")
	}
	if err := validateUpgrade(m, Release{Sequence: 13}, Artifact{Executable: "game"}, 13); err == nil {
		t.Fatal("same current client sequence accepted")
	}
	if err := validateUpgrade(m, Release{Sequence: 13}, Artifact{Executable: "game"}, 12); err != nil {
		t.Fatal(err)
	}
	os.Remove(filepath.Join(dir, markerName))
	if _, err := validateInstallation(dir); err == nil {
		t.Fatal("unmarked directory accepted")
	}
}
func TestFullHealth(t *testing.T) {
	ack := filepath.Join(t.TempDir(), "ack")
	done := make(chan error, 1)
	done <- errors.New("crash")
	if got := waitHealthy(ack, done, 10); got != "exited" {
		t.Fatalf("got %s", got)
	}
	done = make(chan error, 1)
	os.WriteFile(ack, []byte("ok"), 0600)
	if got := waitHealthy(ack, done, 10); got != "healthy" {
		t.Fatalf("got %s", got)
	}
	os.Remove(ack)
	if got := waitHealthy(ack, done, 1); got != "unconfirmed" {
		t.Fatalf("got %s", got)
	}
}
func TestDuplicateAndFileDirectoryZip(t *testing.T) {
	for _, names := range [][]string{{"SolarisBrawl/a", "SolarisBrawl/A"}, {"SolarisBrawl/a", "SolarisBrawl/a"}, {"SolarisBrawl/a", "SolarisBrawl/a/b"}} {
		p := filepath.Join(t.TempDir(), "zip")
		f, _ := os.Create(p)
		w := zip.NewWriter(f)
		for _, name := range names {
			o, _ := w.Create(name)
			o.Write([]byte("x"))
		}
		w.Close()
		f.Close()
		if err := extractZip(p, filepath.Join(t.TempDir(), "stage"), "SolarisBrawl"); err == nil {
			t.Fatal("invalid zip accepted")
		}
	}
}
func TestPrivateJob(t *testing.T) {
	root := t.TempDir()
	os.Chmod(root, 0700)
	j := Job{Platform: "Windows", Archive: filepath.Join(root, "file.zip"), InstallDir: filepath.Join(root, "game"), ParentPID: 123, AckDir: root, AckToken: string(make([]byte, 64))}
	if err := validateJob(j, filepath.Join(root, "job.json"), "Windows"); err == nil {
		t.Fatal("invalid token accepted")
	}
	j.AckToken = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
	if err := validateJob(j, filepath.Join(root, "job.json"), "Windows"); err == nil {
		t.Fatal("long token accepted")
	}
	j.AckToken = j.AckToken[:64]
	if err := validateJob(j, filepath.Join(root, "job.json"), "Windows"); err != nil {
		t.Fatal(err)
	}
	j.AckDir = filepath.ToSlash(root) + "/"
	if err := validateJob(j, filepath.ToSlash(filepath.Join(root, "job.json")), "Windows"); err != nil {
		t.Fatalf("Godot paths rejected: %v", err)
	}
	j.AckDir = root
	if err := validateJob(j, filepath.Join(root, "job.json"), "macOS"); err == nil {
		t.Fatal("wrong helper target accepted")
	}
	if runtime.GOOS != "windows" {
		os.Chmod(root, 0755)
		if err := validateJob(j, filepath.Join(root, "job.json"), "Windows"); err == nil {
			t.Fatal("public cache directory accepted")
		}
		os.Chmod(root, 0700)
	}
}

func TestInterruptedRenameRecovery(t *testing.T) {
	p := t.TempDir()
	live := install(t, p, "live", 1)
	if err := os.Rename(live, live+".update-backup"); err != nil {
		t.Fatal(err)
	}
	if err := recoverInterrupted(live); err != nil {
		t.Fatal(err)
	}
	if _, err := validateInstallation(live); err != nil {
		t.Fatal("interrupted first rename not recovered")
	}
	if err := recoverInterrupted(live); err != nil {
		t.Fatal("healthy installation changed")
	}
}

func TestNativeFullJob(t *testing.T) {
	if runtime.GOOS != "darwin" {
		t.Skip("native mac helper integration")
	}
	for _, scenario := range []string{"acknowledged", "startup_crash", "unknown_backup"} {
		t.Run(scenario, func(t *testing.T) {
			crashes := scenario == "startup_crash"
			key, pub := fixtureKey(t)
			previousKey := publicKeyB64
			publicKeyB64 = base64.StdEncoding.EncodeToString(pub)
			defer func() { publicKeyB64 = previousKey }()
			dir := t.TempDir()
			os.Chmod(dir, 0700)
			live := install(t, dir, "live", 1)
			os.WriteFile(filepath.Join(live, "game"), []byte("#!/bin/sh\nexit 0\n"), 0755)
			if scenario == "unknown_backup" {
				oldBackup := install(t, dir, "backup", 1)
				os.Rename(oldBackup, live+".update-backup")
				os.WriteFile(filepath.Join(live+".update-backup", "notes.txt"), []byte("mine"), 0600)
			}
			token := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
			ack := filepath.Join(dir, "full-"+token+".ack")
			t.Setenv("SOLARIS_QA_ACK", ack)
			executable := "Contents/MacOS/SolarisBrawl"
			m := InstallMarker{Schema: 1, AppID: appID, Sequence: 2, Executable: executable, Files: []string{executable}}
			raw, _ := json.Marshal(m)
			script := "#!/bin/sh\nprintf ok > \"$SOLARIS_QA_ACK\"\nexit 0\n"
			if crashes {
				script = "#!/bin/sh\nexit 1\n"
			}
			zipPath := makeZip(t, map[string]string{"SolarisBrawl.app/" + executable: script, "SolarisBrawl.app/Contents/Resources/" + markerName: string(raw)}, "SolarisBrawl.app/"+executable, 0755)
			content, _ := os.ReadFile(zipPath)
			sum := sha256.Sum256(content)
			a := Artifact{Kind: "full", SHA256: hex.EncodeToString(sum[:]), Bytes: int64(len(content)), ArchiveRoot: "SolarisBrawl.app", Executable: executable}
			parent := exec.Command("/bin/sleep", "60")
			if err := parent.Start(); err != nil {
				t.Fatal(err)
			}
			defer func() { parent.Process.Kill(); parent.Wait() }()
			j := Job{Envelope: signed(t, key, Release{Schema: 1, Sequence: 2, Version: "test2", Platforms: map[string]Artifact{"macOS": a}}), Platform: "macOS", Archive: zipPath, InstallDir: live, ParentPID: parent.Process.Pid, MinimumSequence: 1, AckDir: dir, AckToken: token}
			jobPath := filepath.Join(dir, "job.json")
			raw, _ = json.Marshal(j)
			os.WriteFile(jobPath, raw, 0600)
			type result struct {
				status string
				err    error
			}
			resultCh := make(chan result, 1)
			go func() { status, err := runJob(jobPath); resultCh <- result{status, err} }()
			if scenario == "unknown_backup" {
				select {
				case failed := <-resultCh:
					if failed.err == nil {
						t.Fatal("unknown backup accepted")
					}
					if _, e := os.Stat(jobPath + ".ready"); !os.IsNotExist(e) {
						t.Fatal("ready emitted before rejecting unknown backup")
					}
				case <-time.After(3 * time.Second):
					t.Fatal("preflight waited for parent before rejecting backup")
				}
				return
			}
			deadline := time.Now().Add(5 * time.Second)
			for {
				if _, e := os.Stat(jobPath + ".ready"); e == nil {
					break
				}
				if time.Now().After(deadline) {
					t.Fatal("preflight readiness missing")
				}
				time.Sleep(10 * time.Millisecond)
			}
			before, e := validateInstallation(live)
			if e != nil || before.Sequence != 1 {
				t.Fatal("installation mutated before parent exited")
			}
			parent.Process.Kill()
			parent.Wait()
			resultValue := <-resultCh
			status, err := resultValue.status, resultValue.err
			if crashes {
				if status != "rolled_back" || err == nil {
					t.Fatalf("failed to rollback: %s %v", status, err)
				}
				m, err = validateInstallation(live)
				if err != nil || m.Sequence != 1 {
					t.Fatal("old installation not restored")
				}
			} else {
				if status != "installed" || err != nil {
					t.Fatalf("failed to install: %s %v", status, err)
				}
			}
		})
	}
}
