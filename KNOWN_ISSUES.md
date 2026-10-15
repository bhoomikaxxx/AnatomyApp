# Known Issues

Known limitations and technical debt in AnatomyApp. Each item cites the source location that was verified
at the time of writing (2026-10-15, v1.0.0 build 1, `main` @ `84f251b`). Remove an item only when it is
fixed AND verified on the surface where it runs.

## 1. `main` does not build — `LauncherPage` is missing

`ClinicalMixMatchView.swift:8` takes `@Binding var launcherPage: LauncherPage` and sets
`launcherPage = .clinicalMenu`, but no `LauncherPage` type exists anywhere in the tree. Commit `84f251b`
("Explode model, Added UI, Added Mix & Match") added the view and an `EmbryologyHeart` image only; the
launcher/menu changes it depends on appear not to have been committed. Nothing presents
`ClinicalMixMatchView` yet. Verified 2026-10-15: `xcodebuild` exits 65, `error: cannot find type
'LauncherPage' in scope`. **Direction:** ask the commit's author for the missing launcher files before
re-implementing them.

## 2. Hand rotation is device-only and unverified

`HandRotationController` needs ARKit hand tracking, which the simulator lacks (it logs "Hand tracking is
unavailable" and returns). The finger thresholds (2.5 cm / 5.5 cm / 6 cm) have no recorded device pass.
`start` reuses one `HandTrackingProvider` for the controller's lifetime — re-entering the space with the
same controller would try to run a stopped provider (CLAUDE.md ▸ Invariants).

## 3. No automated verification

`AnatomyAppTests` is the Xcode placeholder; no UI tests. CI (added 2026-10-15) only builds.

## 4. Anatomical labels unreviewed

`ClinicalMixMatchView.anatomicalName(for:)` maps USD node names to labels; several are generic
("Exterior Heart Section A/B", "Exterior Heart Vessels A/B") and the source names contain typos
(`Aortice_…`, `…Exteror_Vains…`) that must be kept to match the model. Labels need a domain reviewer.

## 5. 14 MB `heart.usdc` is a plain git blob

No `.gitattributes`/LFS. Fine at this size; revisit before adding more models (a later LFS migration
needs a history rewrite — a team decision).

## 6. `.DS_Store` files are tracked

Several `.DS_Store` files are committed under `AnatomyApp/`. Harmless; `repo-butler` can untrack them.
