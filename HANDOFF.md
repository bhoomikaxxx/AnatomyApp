# HANDOFF — AnatomyApp

Current working state + where to look. **Dated history → [CHANGELOG.md](CHANGELOG.md); per-release
detail → [docs/VERSION-HISTORY.md](docs/VERSION-HISTORY.md); open work → [TODO.md](TODO.md).**
Build/verify/deploy conventions live in [CLAUDE.md](CLAUDE.md) — this file does not duplicate them.

## State (updated 2026-10-15)

| Surface | Version | Note |
|---|---|---|
| Repo `main` @ `84f251b` | **v1.0.0 (build 1)**, untagged | heart model + move/scale/rotate; `ClinicalMixMatchView` added |
| visionOS simulator | **build FAILS** ❌ | 2026-10-15, Xcode 26.2: `ClinicalMixMatchView.swift:8: cannot find type 'LauncherPage' in scope` — the launcher changes that view depends on were not committed (KNOWN_ISSUES #1) |
| Apple Vision Pro | **unknown** | no device pass or install recorded in this repo yet |

Signing: `DEVELOPMENT_TEAM = BN46ZCXPGU` (all configurations), bundle id `i3d.AnatomyApp`. Provisioning
type and expiry not recorded — note them here on the first device install.

## Device runbook
1. Pair from the **headset**: Settings → General → Remote Devices → this Mac. A fresh personal-team
   profile also needs **Trust** on the headset (Settings → General → VPN & Device Management).
2. `version-steward` → bump + tag.
3. Build for the device (signing on), `-destination 'generic/platform=visionOS'`,
   `-derivedDataPath /tmp/anatomy-dd-device`. Check the real exit code.
4. Freshness check the binary (CLAUDE.md ▸ Build), then `qa-inspector` Phase 2.
5. `scripts/install-when-awake.sh` — leave it running, put the headset on.
6. Walk the experience; write `docs/device-passes/DEVICE-PASS-<date>.md`; `qa-inspector` Phase 3 (pull
   logs) and update the ledger.
7. Update the **State** table above with the version **read back from the device**.

## Where to look
- `docs/architecture/APP-FLOW.md` — what the app actually does, step by step
- `docs/device-passes/DEVICE-PASSES.md` — device ledger
- `docs/decisions/` — decision records
- `docs/reference/ASSET-LICENCES.md` — asset provenance
- `.claude/agents/` — `spatial-steward`, `qa-inspector`, `version-steward`, `repo-butler`
