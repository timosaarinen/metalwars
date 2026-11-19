# Client compatibility and first live check

Research date: **19 November 2026**. MetalWars targets **World of Warcraft:
Forever 1.60.1, Interface 16001**. This scaffold has been checked against exported
API definitions; that is not an in-game compatibility certification.

## What the sources establish

| Item | Evidence and implementation consequence |
| --- | --- |
| Interface `16001` | Present in Deadly Boss Mods' published TOC [1]. Confirm the installed client with `/dump GetBuildInfo()` before changing our TOC. |
| Modern API family | The exported Forever UI contains `C_Spell`, `C_SpellBook`, `C_UnitAuras`, duration objects, and secret-value restrictions [2–5]. Use those APIs, even though Forever's gameplay resembles Classic. |
| Flavor detection | Current DBM detects `WOW_PROJECT_CAMELOT`, with numeric fallback `18` [1]. Early-beta claims that Forever always reports the Mainline project ID are not a reliable current detector. |
| Reference build | The source export was refreshed on 18 November for `1.60.1.70959`, according to its maintainer [2]. The export itself does not embed that build number; the maintainer reads it from the client's `.build.info`. |
| Installation folder | WowUp's source defines `_forever_` and identifies Forever by its install folder [6]. Use Battle.net's installation-location command to find the actual installation. |

The intended file layout after extracting the download is:

```text
World of Warcraft/_forever_/Interface/AddOns/MetalWars/MetalWars.toc
```

Restart the client after first installing the addon. When updating it, replace
the `MetalWars` addon folder; settings belong to WoW's `WTF` directory. Avoid
an extra nesting level such as `AddOns/MetalWars/MetalWars/MetalWars.toc`.

### Why there is no Classic-global compatibility layer

Forever's modern namespaces are the target. Falling back indiscriminately to
Classic-era globals such as `GetSpellInfo` or `UnitAura` would imply support for
different return shapes and restriction rules without testing them. It would
also conceal the absence of an expected Forever capability. Missing APIs should
produce an unavailable feature or a diagnostic, not an invented replacement.
Supporting another WoW flavor can be a separate, tested change.

## Cooldown display without reading restricted values

Blizzard's exported definitions document these signatures [3–4]:

```lua
C_Spell.GetSpellCooldownDuration(spellID, ignoreGCD) -- LuaDurationObject or nil
cooldown:SetCooldownFromDurationObject(duration, clearIfZero)
```

For a spell already confirmed as learned by
`C_SpellBook.IsSpellKnown(spellID)`, the display path is:

```lua
local duration = C_Spell.GetSpellCooldownDuration(spellID, true)
if duration then
    cooldown:SetCooldownFromDurationObject(duration)
else
    cooldown:Clear()
end
```

`true` requests a duration without the global cooldown. The native widget
renders the opaque duration object. Do not compare or calculate its remaining
time, inspect the widget to infer hidden readiness, or save restricted values.
Production callers should check capability availability and handle API errors
without interrupting the rest of the addon. A failed display is unavailable;
it does not establish that a spell is ready.

**No cooldown durations are hardcoded.** For example, Blizzard's Forever
paladin notes change Lay on Hands from one hour to twenty minutes [7]. The
client, learned rank, and current talents determine the display.

## WSG and flag information

The initial compatibility constants are WSG instance ID **489**, Warsong Flag
aura **23333**, and Silverwing Flag aura **23335**. These are established Classic
identifiers and are also reported by current Forever client-data sites. They
remain **pending a live Forever WSG check**: the research did not retrieve a
current Blizzard data-table export proving those three identifiers.

`GetInstanceInfo()` exposes the instance ID as its eighth result. Check the
instance type as well as the ID. Manual panel access remains useful if a future
client changes the map identifier.

`C_UnitAuras.GetPlayerAuraBySpellID` is explicitly documented as requiring a
non-secret aura and as subject to unit-aura restrictions [5]. Guard calls and
refuse secret results before comparisons. A restricted call, an error, or an
unreadable result must not become a confident “not carrying” state. A readable
flag aura can establish that the player is carrying; lack of a readable aura
does not always establish the opposite. Manual flag mode is a user-supplied
reminder, and must be labelled as such.

The first version should leave authoritative flag positions, carrier identity,
and capture readiness to the game's own UI. Check immunity behavior in-game
before treating any paladin flag-carrier reminder as a verified Forever rule.

## Level-19 warrior and paladin toolkit

These are candidate IDs for the early WSG toolkit, not a promise that every
character has trained every ability. Resolve names and icons through the client
and show only learned spells; rank availability and cooldowns remain client
data.

| Warrior | ID | Paladin | ID |
| --- | ---: | --- | ---: |
| Charge | 100 | Blessing of Freedom | 1044 |
| Hamstring | 1715 | Hammer of Justice | 853 |
| Shield Bash | 72 | Purify | 1152 |
| Disarm | 676 | Lay on Hands | 633 |
| Bloodrage | 2687 | Blessing of Protection | 1022 |
| Defensive Stance | 71 | Divine Protection, ranks 1 / 2 | 498 / 5573 |

Warrior guidance should keep shield and stance requirements visible. Paladin
guidance should distinguish Freedom from immunity and Purify from higher-level
Cleanse. Avoid copying a Classic rotation guide wholesale: Blizzard documents
Forever-specific changes to Judgement, Seal of Fury, and Holy Strike [7].
Consecration is explicitly learned at level 20 in that source, so it is outside
this level-19 starter scope. Pummel, Execute, Divine Shield, and Flash of Light
are also outside the intended starter list; no generic max-level rotation is
implied.

## First live test checklist

- **Installation and reload:** enable Lua errors with
  `/console scriptErrors 1`, log in with only MetalWars enabled, record
  `/dump GetBuildInfo()`, and check load, `/reload`, saved positions, and settings.
- **Warrior:** use a level-19 warrior with the relevant trained spells. Check
  learned-only icons, client-localized names, Charge and Bloodrage cooldown
  sweeps, stance changes, and shield-dependent tooltips. Test both outside and
  inside combat; confirm that the addon never casts or changes targets.
- **Paladin:** verify the same display behavior for Freedom, Hammer of Justice,
  Purify, and Lay on Hands. Check both trained Divine Protection ranks where
  applicable. Ensure cooldown display follows the client and does not substitute
  a hardcoded Classic duration.
- **WSG detection:** enter a 10–19 match, record `/dump GetInstanceInfo()`, check
  automatic panel visibility, and leave/re-enter. Ensure manual panel access
  still works outside the detected instance.
- **Flag state:** observe pickup, death/drop, return, capture, and a UI reload
  while carrying. Compare the addon with Blizzard's objective display. Check
  manual flag mode and its reset behavior. An unreadable/restricted aura must
  appear as unknown rather than confirmed absent.
- **Flagstack interruption:** start and pause a game, then enter combat, take
  damage, die, receive a WSG objective announcement, and change zones. Check
  that interruption pauses the game and relinquishes its input immediately;
  returning to safety must not silently resume it. Check normal WoW movement,
  chat, Escape, close/reopen, score persistence, and deliberate resume.
- **Secret-value resilience:** repeat the cooldown and aura checks during an
  actual PvP encounter with Lua errors enabled. If an API is blocked, the rest
  of the addon and WoW controls must continue to function.

Record the exact client build, addon commit, class, locale, observed result,
and any Lua error in a GitHub issue. A successful offline test or API-source
review cannot replace these live checks.

## Source references

1. Deadly Boss Mods, pinned revision `fe2708e6d1280633060c08092c2d5db03647f576`:
   [TOC](https://github.com/DeadlyBossMods/DeadlyBossMods/blob/fe2708e6d1280633060c08092c2d5db03647f576/DBM-Core/DBM-Core.toc)
   and [flavor detection](https://github.com/DeadlyBossMods/DeadlyBossMods/blob/fe2708e6d1280633060c08092c2d5db03647f576/DBM-Core/modules/objects/GameVersion.lua).
2. Exported Blizzard Forever UI, pinned revision `0723e3af9e304e1fee7e34c45f97d666d14dfc6d`:
   [export provenance and version](https://github.com/reckhou/WoWBlzCode/blob/0723e3af9e304e1fee7e34c45f97d666d14dfc6d/README.md),
   [function index](https://github.com/reckhou/WoWBlzCode/blob/0723e3af9e304e1fee7e34c45f97d666d14dfc6d/index/Forever/functions.txt),
   and [event index](https://github.com/reckhou/WoWBlzCode/blob/0723e3af9e304e1fee7e34c45f97d666d14dfc6d/index/Forever/events.txt).
3. Blizzard's exported [spell API definitions](https://github.com/reckhou/WoWBlzCode/blob/0723e3af9e304e1fee7e34c45f97d666d14dfc6d/Forever/BlizzardInterfaceCode/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua).
4. Blizzard's exported [cooldown widget API definitions](https://github.com/reckhou/WoWBlzCode/blob/0723e3af9e304e1fee7e34c45f97d666d14dfc6d/Forever/BlizzardInterfaceCode/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPICooldownDocumentation.lua).
5. Blizzard's exported [unit aura API definitions](https://github.com/reckhou/WoWBlzCode/blob/0723e3af9e304e1fee7e34c45f97d666d14dfc6d/Forever/BlizzardInterfaceCode/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua).
6. WowUp, pinned revision `2edf395096d8e1780f6deeec9a47b2ab5fd9c745`:
   [installation-folder constants](https://github.com/WowUp/WowUp/blob/2edf395096d8e1780f6deeec9a47b2ab5fd9c745/wowup-electron/src/common/constants.ts)
   and [client identification](https://github.com/WowUp/WowUp/blob/2edf395096d8e1780f6deeec9a47b2ab5fd9c745/wowup-electron/app/services/warcraft/warcraft-platform.mac.ts).
7. Blizzard, [World of Warcraft: Forever Class Deep Dives — Paladin](https://news.blizzard.com/en-gb/article/24302099/world-of-warcraft-forever-class-deep-dives-paladin).
8. Blizzard, [Combat Philosophy and Addon Disarmament in Midnight](https://news.blizzard.com/en-us/article/24246290/combat-philosophy-and-addon-disarmament-in-midnight).
   This explains the design of secret values; the Forever API export above is
   the evidence that the restrictions exist in the target client.
