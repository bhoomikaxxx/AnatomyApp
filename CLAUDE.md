# CLAUDE.md — working notes for Claude Code

Agent-facing conventions for this repo. Human overview is in `README.md`; what the app actually does in
`docs/architecture/APP-FLOW.md`; current state/runbook in `HANDOFF.md`; dated history in `CHANGELOG.md`;
open work in `TODO.md`; known limitations in `KNOWN_ISSUES.md`.

## What this is
**AnatomyApp** — a visionOS anatomy-teaching app. A participant enters a mixed-immersion space with a 3D
**heart** they can move, scale and rotate with their hands, and (in progress) a **Clinical Mix & Match**
activity: name heart parts, then drag scrambled parts back into place.
- **One app**: `AnatomyApp/AnatomyApp.xcodeproj`, scheme `AnatomyApp` (auto-generated — there is no shared
  scheme yet), visionOS only (`XROS_DEPLOYMENT_TARGET = 26.5`). Bundle id `i3d.AnatomyApp`, team
  `BN46ZCXPGU`. Test target `AnatomyAppTests` (Swift Testing, placeholder only).
- **Sources** are in `AnatomyApp/AnatomyApp/` (Xcode 16+ file-system-synchronised groups: a new `.swift`
  file in that folder is in the target automatically, no pbxproj edit).
- **3D content** is the `RealityKitContent` package (`AnatomyApp/Packages/RealityKitContent`); the heart is
  `RealityKitContent.rkassets/heart.usdc` (~14 MB) with textures in `textures/`. Part names in the USD
  (`Mitral_Valve_GEO`, `Tricuspid_Valve_GEO`, …) are load-bearing — `ClinicalMixMatchView.anatomicalName`
  maps them to labels.

## Build (one at a time per derived-data path)
```bash
xcodebuild build -project AnatomyApp/AnatomyApp.xcodeproj -scheme AnatomyApp \
  -destination 'generic/platform=visionOS Simulator' -derivedDataPath /tmp/anatomy-dd-vision \
  CODE_SIGNING_ALLOWED=NO > /tmp/anatomy-build.log 2>&1; echo "EXIT=$?"
grep -Eo 'BUILD SUCCEEDED|BUILD FAILED' /tmp/anatomy-build.log
grep -E '(error|fatal error): ' /tmp/anatomy-build.log | sort -u
```
- **Check the real xcodebuild exit code**, not a piped `tail`'s — `cmd | tail -1` reports tail's exit,
  always 0. Compiler errors print long before the summary, so grep for them.
- **DerivedData goes in `/tmp`, never inside the repo.** `/tmp` is wiped on reboot (first build is cold).
- **Never run two builds that share a `-derivedDataPath` concurrently** — "database is locked" reads as
  `BUILD FAILED` but is not a code failure.
- **The deploy target (26.5) must be supported by the local Xcode.** Check `xcodebuild -showsdks` first if
  a build fails with an SDK/deployment-target error rather than a Swift error.
- **Device builds**: `-destination 'generic/platform=visionOS'` (with signing) so the build does not die
  when the headset naps, then install with `scripts/install-when-awake.sh`. Exit 70 from xcodebuild =
  device dropped off, NOT a code failure — and the products dir may then hold a STALE app. Verify
  freshness before installing: `strings -a <app>/AnatomyApp | grep -c '<a new log string>'` (a Debug
  build puts code in `AnatomyApp.debug.dylib` instead).
- **Parallel Claude sessions may run in this tree.** Before committing, check `git status` for another
  session's in-flight files; prefer path-scoped `git add` over `-A`.

## Run & verify on the simulator
Resolve the simulator by NAME every session — UDIDs churn when runtimes are re-downloaded:
```bash
SIM=$(xcrun simctl list devices available | grep -m1 "Apple Vision Pro" | grep -Eo '[0-9A-F-]{36}')
xcrun simctl bootstatus "$SIM" -b
APP=/tmp/anatomy-dd-vision/Build/Products/Debug-xrsimulator/AnatomyApp.app
xcrun simctl install "$SIM" "$APP"
xcrun simctl launch --console-pty "$SIM" i3d.AnatomyApp > /tmp/anatomy-run.log 2>&1 &
```
- **Read output from `--console-pty` into a file.** `log show` redacts `print` content.
- **Hand tracking does not exist in the simulator.** `HandRotationController` logs "Hand tracking is
  unavailable" and does nothing there. A green simulator run proves loading, layout, drag/magnify via
  the pointer and the Mix & Match state machine — **not** the two-finger rotation gesture.

### CoreSimulator wedges
Symptoms: `simctl install`/`launch` hangs, "Unable to lookup in current state: Shutting Down", or the app
launches but prints nothing. Fix:
```bash
pkill -9 -f "simctl launch"; xcrun simctl shutdown all
killall -9 com.apple.CoreSimulator.CoreSimulatorService; sleep 6
xcrun simctl bootstatus "$SIM" -b
```

## Invariants — do not break
- **Zero open scenes ⇒ visionOS terminates the app.** `ContentView` dismisses the `Launcher` window only
  after `openImmersiveSpace` returns `.opened`; anything leaving the space must `openWindow(id:
  "Launcher")` *before* `dismissImmersiveSpace` (as `ClinicalMixMatchView.returnToClinicalMenu` does).
- **`@Environment` window / space actions resolve only inside a `View`.** Pass them to model objects as
  injected closures; never call them from a controller.
- **ARKit providers cannot restart.** A stopped `HandTrackingProvider` is dead. `HandRotationController`
  creates its provider once — if the space can be re-entered with the same controller, build a fresh
  provider/session in `start`. Never await ARKit unbounded on the main actor.
- **Hand-gesture thresholds are tuned on hardware.** Fingertips-together < 2.5 cm, index extended > 5.5 cm,
  middle > 6 cm (`HandRotationController.areRotationFingersTogether`). Change them only from a device pass.
- **USD part names are an API.** Re-exporting `heart.usdc` must keep the `*_GEO` / `polySurface*` names
  that `anatomicalName(for:)` matches, or parts silently drop out of Mix & Match. Log the parts found.
- **An entity a View touches outside the RealityView `make` closure must be `@State`** — a plain `let`
  is re-created on every re-render and the gesture/handler sees an empty entity.
- **Scale is clamped** (0.75–8×) in the magnify gesture; keep any new scaling path inside that range.

## Conventions
- **Versioning is SEMANTIC: `vMAJOR.MINOR.PATCH` + a build number, managed ONLY via `scripts/version.sh`
  and the `version-steward` agent** (invoke it before every hardware deploy). patch = bug fixes / tuning;
  minor = new features, anatomy models, activities; major = breaking changes to the experience's structure
  or min OS; docs-only never bumps. Every release gets an annotated tag `vX.Y.Z`. Never hand-edit
  `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`. Record the version in the CHANGELOG entry.
- **Checkboxes / PASS only for behaviour actually observed**, on the surface where it runs. Hand rotation,
  pinch-drag feel and model scale-in-room are device-only — verified on a Vision Pro, never claimed from a
  green build. Record device findings in `docs/device-passes/`.
- **Anatomical correctness is content, not code.** Part labels and teaching copy need a domain reviewer;
  note who checked them in the CHANGELOG.
- **Review subagent work with a real run before trusting it.** A subagent's "done" is a claim.
- **Every bundled third-party asset is licensed and recorded** in `docs/reference/ASSET-LICENCES.md`.
- **Decisions that are expensive to re-litigate** get a dated record in `docs/decisions/YYYY-MM-DD-<slug>.md`.
- Scratch builds, harnesses and logs go in `/tmp` or the session scratchpad, not the repo.

## Agents (`.claude/agents/`)
| Agent | Invoke when |
|---|---|
| `spatial-steward` | Building or tuning anything in the immersive / RealityKit / hand-tracking / 3D-asset layer |
| `qa-inspector` | Before committing a fix, before a device deploy, and after every device pass |
| `version-steward` | Before every device deploy, or when versions/tags look wrong |
| `repo-butler` | Tidying stray files and stale docs |

## Where to look
`HANDOFF.md` (state + device runbook) · `docs/architecture/APP-FLOW.md` (what actually runs) ·
`docs/device-passes/DEVICE-PASSES.md` (ledger) · `KNOWN_ISSUES.md` · `docs/decisions/` · `CHANGELOG.md` · `TODO.md`.
