# MetalWars 0.1.0 alpha

First public scaffold for level-19 Warsong Gulch on **WoW Forever 1.60.1 / Interface 16001**.

- Movable WSG HUD with six warrior or paladin tools, spellbook checks and native cooldown display.
- Flag-carrier reminders with a manual toggle when aura state is hidden.
- Flagstack falling-block game with ghost/next pieces, lines, levels and saved personal best.
- Combat, death and battleground-event interruption with keyboard release and deliberate manual resume.
- Manual-install ZIP, GitHub Pages download site and repeatable build/release workflow.

**Alpha: not yet tested in the live Forever client.** Lua model/lifecycle checks and package validation do not substitute for an in-game test. WSG/flag identifiers and combat input behavior need the first live smoke pass; see [COMPATIBILITY.md](https://github.com/timosaarinen/metalwars/blob/main/COMPATIBILITY.md).

Download **MetalWars-0.1.0.zip**, extract its single `MetalWars` folder into your Forever client's `Interface/AddOns`, restart WoW, and enable the addon. Usually the final path is `_forever_/Interface/AddOns/MetalWars/MetalWars.toc`.

Start with `/mw help`, `/mw`, and `/mw blocks`. Flagstack opens paused; click **Resume**. Arrows move/rotate/drop, Space hard-drops, P pauses and Escape closes.
