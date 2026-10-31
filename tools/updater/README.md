# Native full-update helper

The Godot updater uses this helper only when an engine/bootstrap replacement is
required. Compatible content updates use signed PCK staging instead.

## Package

```
python3 tools/updater/build.py build --output build/updater
```

Place `Windows/SolarisUpdater.exe` beside `SolarisBrawl.exe`, or the universal
`macOS/SolarisUpdater` beside the executable inside the app's `Contents/MacOS`.
After packaging all files, mark the dedicated install directory:

```
python3 tools/updater/build.py mark --install build/package/SolarisBrawl --executable SolarisBrawl.exe --sequence 14100
python3 tools/updater/build.py mark --install build/package/SolarisBrawl.app --executable Contents/MacOS/SolarisBrawl --sequence 14100
```

ZIP exactly that directory as one root. Windows keeps `update-install.json` at
that root; macOS stores it at `Contents/Resources/update-install.json` to keep the
bundle root sealed. Do not ship a macOS root marker. After all bundle resources and
helper binaries are in place, create the signature file paths once (an initial
ad-hoc signing pass), generate the marker, then sign the bundle again. The marker
records paths, not hashes, so the final signature can cover it without a hash cycle.
Do not add or remove files after the marker is generated.
The signed full artifact must contain `archive_root`, `executable`, `sha256`,
`bytes`, and `kind: "full"`. A patch artifact may carry this as its `full` field.
The helper embeds the public key from `data/update-channel.json` when built.
It never accepts a key from an update job.

## Client contract

Copy the matching helper to the private update cache (0700 on Unix) and execute it with
`--job <absolute job path>`. Keep the game running during preflight; poll the unique
`<job path>.result.json` for errors first, then `<job path>.ready`. Gracefully quit
only after readiness appears. This file is emitted after signature/hash checks,
ZIP extraction, installation validation and old-backup checks, before waiting for
the parent process. It is removed after the attempt ends. Use a fresh token-specific
job path for every attempt. Godot-style forward-slash and trailing-slash absolute
paths are normalized; explicit `..` components are rejected. The private JSON file
(mode 0600 on Unix) is directly inside the game's `user://updates` directory:

```json
{
  "envelope": {"payload": "base64 signed payload", "signature": "base64 signature"},
  "platform": "Windows",
  "archive": "absolute downloaded ZIP path",
  "install_dir": "absolute existing dedicated installation root",
  "parent_pid": 123,
  "minimum_sequence": 14100,
  "ack_dir": "absolute user update cache directory",
  "ack_token": "fresh 64-character lowercase hex token"
}
```

The helper checks the signature again, target platform, monotonically newer
sequence, archive hash/size, and both installation manifests. ZIP traversal,
Windows ADS/reserved names, symlinks, case collisions, duplicate entries,
file/directory collisions, and more than 6 GiB expanded data are rejected.
Unknown files in the current install cause refusal rather than user-data removal.
An unmarked old install requires a one-time manual installation of a new base.

The helper extracts beside the install directory, waits up to 120 seconds for the
original process to exit, renames the old directory to `.update-backup`, swaps the
new directory into place, then launches its signed executable with user arguments
`-- --update-ack <token>`. After successful startup, the game writes the small
`user://updates/full-<token>.ack` file. Do not write that file before the game scene
is ready. Saves and identity remain in the stable Godot user directory.

It writes `<job path>.result.json` with a fixed status and error code (no paths).
`installed` means startup acknowledged. A process exit before acknowledgement
restores and starts the old version (`rolled_back`). If the new process remains
alive without acknowledgement for 90 seconds, `awaiting_health` retains both
versions without renaming files under a running process. A verified older backup
can be cleaned by the next update when `minimum_sequence` confirms the current
installation. A backup containing unknown files is never deleted.

## Validation and limits

`go test ./...` exercises signature/tamper checks, archive hashes, ZIP safety,
installation ownership, downgrade rejection, swap/launch rollback, and startup
acknowledgement. `go test -race -ldflags=-linkmode=external ./...` runs on the build host
(the host's older Go/macOS combination needs the external linker for race tests). Cross-compilation is
not a Windows native runtime test. macOS unsigned apps may still require the
user's normal first-launch Gatekeeper approval. Install directories must be
writable; the helper never escalates privileges. If startup never exits and never
acknowledges, it cannot safely force rollback; the backup is retained.
