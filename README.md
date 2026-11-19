# MetalWars

A small **WoW Forever** addon for **level-19 Warsong Gulch**, starting with warrior and paladin. It includes **Flagstack**, a falling-block game for the quiet moments while holding a flag.

**0.1.0 alpha.** Source checked against Forever **1.60.1 / Interface 16001**. Lua tests and packaging checks run locally and in GitHub Actions. **Not yet tested inside the live Forever client.** The current API sources and the first in-game checklist are in [COMPATIBILITY.md](COMPATIBILITY.md).

[Download and manual installation](https://timosaarinen.github.io/metalwars/) · [Tagged alpha downloads](https://github.com/timosaarinen/metalwars/releases) · [Report a problem](https://github.com/timosaarinen/metalwars/issues)

## What's in the first version

- A movable helper panel that appears automatically in WSG. `/mw` opens it elsewhere; `/mw auto` returns to automatic visibility.
- Warrior reminders for **Charge, Hamstring, Shield Bash, Disarm, Bloodrage and Shield Block**.
- Paladin reminders for **Blessing of Freedom, Hammer of Justice, Purify, Lay on Hands, Blessing of Protection and Divine Protection**.
- Known-spell checks and the client's own cooldown widgets. Unlearned spells are dimmed. A `?` means the client could not expose a cooldown. Icons do not judge range, resources, stance or whether casting is currently possible.
- A carrier reminder when a readable flag aura is observed, plus `/mw flag` for an explicit manual reminder. Hidden aura data is shown as **unconfirmed**, never as proof that you are not carrying.
- **Flagstack:** 10×20 board, seven-bag pieces, next/ghost piece, wall kicks, soft/hard drop, score, levels and a saved personal best.

Flagstack starts paused. **Combat, death, player combat events, changing worlds and WSG objective messages close and pause it.** Typing pauses it. It releases keyboard capture on pause/hide, and reopening always requires a deliberate **Resume** click. The unfinished board survives hiding within the current UI session; only the personal best persists across logins. It cannot guarantee detection of an approaching enemy or decide when a flag is capturable.

The addon has no dependencies, gameplay automation, chat broadcasting, telemetry or anti-AFK behavior. No spell-casting buttons or equipment changes are installed; keep using your normal action bars and bindings.

## Manual installation

1. Download **MetalWars-0.1.0.zip** or **MetalWars-latest.zip** from the download page or a tagged GitHub release. GitHub's green **Code → Download ZIP** is a source checkout, not the install package.
2. Close WoW and extract the archive. It contains one `MetalWars` directory.
3. Use Battle.net's **Open game directory** option for Forever. Copy the folder into the actual client's `Interface/AddOns` directory. The usual resulting path is:

   ```text
   World of Warcraft/_forever_/Interface/AddOns/MetalWars/MetalWars.toc
   ```

4. Restart the game, enable **MetalWars** at character selection, log in and type `/mw help`.
5. Try `/mw` and `/mw blocks` outside combat first. Then follow the short in-client checklist in [COMPATIBILITY.md](COMPATIBILITY.md). Run `/mw status` when reporting errors.

For updates, replace the old addon folder while WoW is closed. Keep your `WTF` folder so settings and the personal best survive. Do not enable an out-of-date addon blindly after a client update: check the target interface and release notes.

## Commands and game controls

| Command | Action |
|---|---|
| `/mw` or `/metalwars` | Toggle the helper panel |
| `/mw show` / `/mw hide` | Explicitly show / hide it |
| `/mw auto` | Restore automatic WSG visibility |
| `/mw flag` | Toggle the session-only manual carrier reminder |
| `/mw blocks` or `/mw game` | Open / close Flagstack |
| `/mw reset` | Reset the HUD position |
| `/mw status` | Print client version, interface, class and map diagnostics |
| `/mw help` | Show help |

Drag the HUD header to move it. Flagstack has its own movable window. Click **Resume**, then use **← / →** to move, **↑** to rotate, **↓** to soft-drop and **Space** to hard-drop. **P** pauses and releases keyboard capture; click **Resume** to continue. **Escape** closes the game. It never changes character key bindings.

## Development

Runtime code is plain Lua compatible with Lua 5.1 and the Forever API. Python 3 packages the addon/site; Lua 5.1 runs the meaningful model and addon-lifecycle checks. No npm build or external addon libraries.

```sh
python3 scripts/check.py       # requires lua5.1 on PATH
python3 scripts/package.py --site
python3 -m http.server 8767 --directory _site
```

If Lua is unavailable, `python3 -m pip install lupa` and `python3 scripts/check.py --lupa` use Lupa's explicit Lua 5.1 runtime. This is a development-only option.

| Location | Purpose |
|---|---|
| `addon/MetalWars/` | The whole addon; its TOC is the load-order authority |
| `Core.lua` | Events, public-state guards, commands and session state |
| `Classes.lua` | The small warrior/paladin toolkit |
| `HUD.lua` | Movable panel and native cooldown widgets |
| `Blocks.lua` | Pure falling-block model, independently testable |
| `Game.lua` | Game UI and keyboard lifecycle |
| `docs/` | Static download/install page |
| `scripts/` | Checks and deterministic ZIP/site packaging |
| `tests/` | Block-model and addon-lifecycle regressions |

`dist/` and `_site/` are generated and ignored. An install ZIP always starts at `MetalWars/MetalWars.toc`; it contains no repository, reference-client source or developer dependencies.

## Publishing

GitHub Actions checks each push and pull request. A successful `main` build publishes the page **and a public, directly downloadable install ZIP** to GitHub Pages. The first successful `main` build for each new TOC version also creates a matching `v<version>` **prerelease** with install ZIPs and SHA-256 checksums. Existing release assets stay unchanged. Explicit `v*` tag pushes are also supported and must match the TOC version and packaged commit.

The one-time repository setting is **Settings → Pages → Source: GitHub Actions**. The workflow deliberately uses normal repository permissions; its `GITHUB_TOKEN` cannot enable Pages from scratch. If this setting has not been made, the build/package artifact still succeeds and the Pages job reports the setup problem. After enabling it, rerun the workflow.

Before a new release, update `MetalWars.toc`, `Core.lua`, `INSTALL.txt`, page version labels and `RELEASE_NOTES.md`; run the checks, commit and push:

```sh
git push origin main
```

Keep alpha releases marked as prereleases until the live-client checklist passes. CurseForge publication is a later step: create a project, select its then-current Forever game flavor, add the real project ID, and upload the same install ZIP. No fabricated project IDs, API keys or publishing integrations are checked in.

## Next useful work

1. Complete a real level-19 WSG pass on warrior and paladin; fix API/input issues before widening scope.
2. Confirm instance/flag IDs and immunity interactions in Forever, then improve flag return/capture cues using data the client actually exposes.
3. Refine the toolkit from matches: stance/shield visibility, consumable reminders and optional manual team callouts, without automatic casting or chat.
4. Add real screenshots, localization and a tested compatibility matrix; publish through CurseForge when the first release is ready.

MIT licensed. Independent project; not affiliated with Blizzard Entertainment. Flagstack uses original code and simple block graphics, with no external game assets.
