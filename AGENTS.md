# MetalWars development

Keep the addon small, dependency-free and focused on level-19 Warsong Gulch.
Runtime code lives in `addon/MetalWars`; TOC order is authoritative. Read
`COMPATIBILITY.md` before changing WoW APIs. Forever is not Classic Era.

- Use public API metadata and native widgets. Never branch on, format or do
  arithmetic with secret combat values. Unknown state must stay unknown.
- Keep Flagstack's pure model separate from its WoW UI. Its keyboard capture
  must end on hide, pause, combat, death and typing. Never restore it automatically.
- No automatic casting, targeting, movement, equipment swapping or anti-AFK.
- Use `python3 scripts/check.py` (Lua 5.1), or `--lupa` with Lupa's Lua 5.1 runtime.
  Keep tests focused on meaningful state/input/packaging regressions.
- Live-client validation is pending until someone actually performs and records
  it. A mock API test or successful package build is not in-game validation.
- Do not vendor Blizzard's exported UI code or add runtime frameworks. Reference
  sources are linked in `COMPATIBILITY.md`.
- The install ZIP must have exactly one `MetalWars/` root directory. Pages and
  tagged releases are built by the same packager. Keep public version labels and
  release notes aligned before tagging. CurseForge is a future channel.
