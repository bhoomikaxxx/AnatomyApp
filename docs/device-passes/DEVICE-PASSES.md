# Device passes — rolling index & status ledger

The single source of truth for **"was that device-pass item ever fixed?"**

## How to read this
- A **device pass** is a session on a real Apple Vision Pro. Its raw notes go in a dated file,
  `DEVICE-PASS-YYYY-MM-DD.md` (suffix `B`, `C`, … for a second pass the same day). Dated files are
  **immutable snapshots** — never edited after the fact.
- **Live status is tracked only here.** When an item ships, changes severity, or is deferred, update its
  row below — not the dated file.
- A recurring complaint (`⟳`) is **one row** listing every id it appeared under.
- Status vocabulary: `OPEN` · `FIXED (code) — DEVICE PASS PENDING` · `FIXED — CONFIRMED ON HARDWARE`
  · `DEFERRED` · `WON'T FIX`. Only a later device pass can move an item to CONFIRMED.

## Dated pass files

| Pass | File | Device build | Items |
|---|---|---|---|
| — | *(none recorded yet)* | | |

## Ledger

| ID | First reported | Title | Sev | STATUS | Fixed in / note |
|---|---|---|---|---|---|
| — | | *(no items yet)* | | | |

## Dated pass file template
```markdown
# Device pass — YYYY-MM-DD

- Build on device: vX.Y.Z (build N) — read back from the device, not assumed
- Headset / visionOS: <model>, <version>
- Tester / context: <who, room, lighting>

## Items (verbatim notes, then id)
- **DP-YYYYMMDD-1** — <what was seen, in the tester's words>

## Logs pulled
- <crash / jetsam / console files, or "none — reason">
```
