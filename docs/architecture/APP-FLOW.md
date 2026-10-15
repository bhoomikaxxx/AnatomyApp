# App flow — what actually runs

Traced from the code on 2026-10-15 (v1.0.0, build 1, `main` @ `84f251b`). If the code and this file
disagree, the code wins — fix this file in the same change.

## Scenes (`AnatomyAppApp`)

| Scene | Id | Content | Notes |
|---|---|---|---|
| `WindowGroup` | `Launcher` | `ContentView` | volumetric default role (`Info.plist`) |
| `ImmersiveSpace` | `AnatomySpace` | `ImmersiveView` | `.mixed` only |

`ClinicalMixMatchView` exists but is **not presented by any scene** and does not compile yet
(KNOWN_ISSUES #1).

## Launch
1. `ContentView` shows "Interactive Heart" and the rotation hint.
2. On `.task` it opens `AnatomySpace` immediately. If the result is `.opened`, the `Launcher` window is
   dismissed (the space is now the only scene). On `.error` an **Enter Anatomy Space** button appears.

## The heart (`ImmersiveView`)
- Loads `heart` from `realityKitContentBundle`; placed at `[0, 1.25, -0.75]`, scale 3×;
  `ManipulationComponent.configureEntity` makes it interactive.
- **Drag** (`DragGesture.targetedToAnyEntity`) moves it relative to its parent.
- **Magnify** scales it uniformly, clamped to 0.75–8×.
- **Rotate** — `HandRotationController` (ARKit hand tracking, device only): when either hand's index and
  middle fingertips are together (< 2.5 cm) with both fingers extended, the heart follows that hand's
  orientation change from the moment the gesture started. Released when the fingers part.
- `onDisappear` stops hand tracking.

## Clinical Mix & Match (`ClinicalMixMatchView`, not yet reachable)
- Loads the heart at scale 4.5×; discovers parts whose **parent** node name is one of 8 known USD names
  (`anatomicalName(for:)`), sorted by label; all parts start hidden.
- Attachments: `ClinicalHeader` (title + phase subtitle) above, `ClinicalPanel` to the right.
- **Naming**: one part is shown at a time; the user types its name (compared after lowercasing and
  stripping non-alphanumerics).
- **Matching**: every part is shown, offset by a fixed scramble table, and made draggable
  (`releaseBehavior = .stay`). On `ManipulationEvents.WillEnd`, a part within **0.1 m** of its original
  position animates home (0.35 s) and locks.
- **Complete** when all parts are matched. "Back to Clinical Cases" opens `Launcher` first, then dismisses
  the space.
