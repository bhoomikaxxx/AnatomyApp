# TODO — forward-looking open work

State → [HANDOFF.md](HANDOFF.md); history → [CHANGELOG.md](CHANGELOG.md); limitations →
[KNOWN_ISSUES.md](KNOWN_ISSUES.md). Updated 2026-10-15.

## Next
- [ ] **Restore a green build** — commit the missing `LauncherPage` / launcher navigation that
      `ClinicalMixMatchView` expects, and wire the view into a scene (KNOWN_ISSUES #1).
- [ ] **First device pass** on a Vision Pro: launch → heart appears → drag, magnify, two-finger rotate →
      Mix & Match naming → matching → complete. Record it as `docs/device-passes/DEVICE-PASS-<date>.md`.
      Check specifically: heart scale/position at 0.75 m, rotation gesture triggers reliably and not
      by accident, snap-back radius (0.1 m) feels fair, panel legible.
- [ ] **Record asset sources/licences** for `heart.usdc` and its textures (`docs/reference/ASSET-LICENCES.md`).
- [ ] **Domain review** of the Mix & Match part labels (KNOWN_ISSUES #4).

## Soon
- [ ] Add a shared `AnatomyApp` scheme so CI and agents don't rely on auto-generated schemes.
- [ ] Replace the placeholder test with real tests (part discovery from the USD, answer normalisation).
- [ ] Decide whether large USD assets go through git-lfs (KNOWN_ISSUES #5) — as a recorded decision.
- [ ] Untrack the committed `.DS_Store` files (`repo-butler`).
- [ ] First tagged release via the `version-steward` before the first device deploy.
