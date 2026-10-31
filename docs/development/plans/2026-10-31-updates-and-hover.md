# In-game updates and hover details implementation plan

> Execution: subagent-driven-development for isolated implementation/review tasks; keep existing worktree and reviewed changes. User approved implementation of both features.

**Goal:** Show item details on hover while preserving click-to-pin; check and install signed updates from the game without replacing saves or a running battle.

**Architecture:** A bootstrap loads a verified active content pack before loading game scripts. An independent updater checks a signed release feed, downloads to a temporary file, verifies, and stages a versioned pack; activation occurs after restart. A successful game startup acknowledges activation, failed trial boots roll back. A native helper handles full application replacement when the boot/runtime version must change. Rendering consumes update state and sends intents, never writes gameplay state.

**Tech stack:** Godot 4.7.2 GDScript, RSA/SHA-256 signatures through Godot Crypto, Python release tooling with OpenSSL, Go standard-library full-update helper, CloudBase static HTTPS distribution.

## User-visible behavior

- Hover item for 0.25 seconds: same readable detail content, read-only; leaving closes it. Click retains existing lift and pins the card with recipe controls. Dragging and active modal suppress hover; hover never pauses battles, plays sounds, buys or saves. Touch continues using click.
- Check in background on normal desktop launch; settings provides manual check and current release label. Show available version, short notes and bytes, download progress, retry and restart action. No network requirement to play offline.
- No activation while a run is active or a frozen online match is pending; downloading is allowed, restart activation only at the camp without an unfinished run. Preserve stable user directory and identity. Older client pools remain distinct already.
- Web offers reload after a newer hosted build is detected; native patch loader is desktop-only. iOS does not download executable updates.
- Public feed and pack signatures are required, HTTPS primary/fallback hosts allowlisted, redirects cannot silently leave trusted origins. Private signing key remains outside repository/staging.

## Tasks

- [x] Hover: add an isolated hover presenter/state; integrate narrowly into `scripts/game.gd` and `scripts/ui/items/item_panel.gd`; pointer tests prove dwell, leave, pin, recipe access, drag suppression and no inventory/storage/audio/battle mutations. Update the obsolete V51 no-hover expectation only.
- [x] Signed update protocol: `scripts/update/update_manifest.gd`, `data/update-channel.json`; validate exact signed payload, schema, sequence, base ID, platform, runtime compatibility, hash/size, fixed HTTPS hosts and path. Reject invalid signatures, downgrades and oversized/invalid fields. Tests use generated test keys, never production private key.
- [x] Update storage/bootstrap: `scripts/update/update_store.gd`, `scripts/update/bootstrap.gd`; `main.tscn` loads bootstrap without preloading game. Stage in private update directory, atomic pointer JSON replacement, verify signed metadata/pack again at boot, reject incompatible or incomplete files. Retain last healthy pack; trial failures quarantine candidate and restore previous. Ready acknowledgement only after the scene actually starts.
- [x] Download/controller/view: `scripts/update/update_client.gd`, `scripts/ui/update_view.gd`; bounded asynchronous feed fetch, streaming download, progress, cancel/retry and complete-file checksum, staging via store. Add main/settings actions and version text; isolate updater from run data. Only production boot auto-checks, QA never contacts production.
- [x] Full-app helper: `tools/updater/` Go module, compiled per platform. Verify signed archive metadata and digest again; safely extract strict archive layout rejecting traversal/symlinks/duplicates, preserve executable modes, stage beside install for atomic rename, wait for parent exit, preserve rollback on failure, launch new executable. No shell interpolation or credentials. Tests cover malicious ZIPs, wrong hashes, interrupted swaps and rollback.
- [x] Publishing: `tools/build_update.py` creates full/cumulative content packs against exact immutable base inventory, signs release envelope and emits immutable versioned objects. Base refresh/full installer package carries helper and pinned public key. Upload signed current feed only after referenced objects exist; old clients continue to get manually downloadable packages.
- [x] Verify: run focused Godot and Go tests (including real localhost HTTP with explicit QA config), signed-pack activation/rollback outside source, hidden native UI captures, complete existing regression, privacy scan, rule hash equality; publish working current channel and build bootstrap Windows/macOS packages locally (do not overwrite the current GitHub release). Record platform-native testing limits and no claimed updater compatibility for existing pre-bootstrap binaries.

## Acceptance commands

`python3 tools/check.py --jobs 2`; `python3 -m unittest discover -s tests -p 'test_*update*.py'`; `go test ./...` in helper; `python3 tools/privacy.py`; `python3 tools/release_manifest.py --check`.

No rule hashes, economy, object IDs, images, saved combat, live player files or account profile changes are authorized by this task. This plan lives under the existing maintained development docs directory.

## Completed evidence

- Clean final regression: 167/167 (`build/qa/update-clean-regression.log`). Independent hover checks: 21/21; spec and quality review passed after boundary fixes.
- Three Python checks: real HTTPS delivery/signature/tamper/origin behavior and immutable-base publishing guards. Actual changed-file cumulative PCK export produced a 1.5 KiB patch; no-change export correctly refuses an empty patch.
- Native helper: 11 Go groups with macOS preflight/ack/crash/rollback and path/ZIP validation, race and vet; Windows cross-compiled but not run on Windows.
- Native hidden screenshots of settings/update/download/hover/pinned cards; production macOS app started headless outside source with the release-smoke profile. Source/stage inventory matches 1072 files; runtime includes stable script UIDs for reproducible patch identity.
- Frozen 37-item battle with active hover: process P95 0.559 ms, draw P95 9.456 ms, all performance gates pass. A GPU-readback regression discovered during development was fixed with geometric rejection before alpha reads; no hit tolerances changed.
- Catalogue hash unchanged: `16cf6ae5e46b9328761bf304624cd172bbf74e7da6f6bcc0a639e7c7ee46e82f`.
- CloudBase current signed desktop channel deployed and verified, live Godot HTTPS check returns current. Its current-version PCK is idempotent on the new baseline; future releases increment sequence and publish cumulative patches or signed full-client metadata. No first-install full ZIP or GitHub release was published in this task.
- Local complete packages: Windows 899075344 bytes; macOS universal 921429957 bytes. The Mac app and helper pass strict ad-hoc signature verification; both unpacked packages passed the privacy scan. Existing players must install this base once to obtain an updater.

Evidence and build outputs remain ignored under `build/`; signing private key remains outside repository. Do not commit keys or local update jobs. No player saves, installation identities, original gameplay data or frozen results were changed. A pre-existing untracked recruitment-review image import was left untouched.
