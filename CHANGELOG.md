# Changelog

Dated, newest first. Each entry names its version once released (`scripts/version.sh`; see the
`version-steward` agent). Say what was verified and how — "builds" is not "works".

## 2026-10-15 — agentic repo structure (unreleased, docs/tooling only)
- Added `CLAUDE.md`, `.claude/agents/` (`spatial-steward`, `qa-inspector`, `version-steward`,
  `repo-butler`), `HANDOFF.md`, `TODO.md`, `KNOWN_ISSUES.md`, `docs/` (app flow, decisions, device-pass
  ledger, asset licences, version history), `scripts/version.sh`, `scripts/install-when-awake.sh` and a
  build-only CI workflow. Modelled on the Paint the World repo's structure.
- No app code changed. Found while documenting: `main` does not build (`LauncherPage` missing —
  KNOWN_ISSUES #1), so CI's build job is expected to fail until that is fixed.
- Verified: `scripts/version.sh verify` reports v1.0.0 (build 1), all configurations aligned.

## 2026-09-17 — Mix & Match, exploded model, UI (`84f251b`)
- `ClinicalMixMatchView` (naming → matching → complete) and the `EmbryologyHeart` image. Not wired into a
  scene; does not compile on its own (KNOWN_ISSUES #1).

## Earlier — heart model + move / rotate / size (`58c70b9`)
- Heart loaded from `RealityKitContent`, drag + magnify gestures, two-finger hand rotation.
