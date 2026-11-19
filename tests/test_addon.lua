-- Lifecycle regression harness, not a replacement for live Forever validation.
-- Run from the repository root: lua tests/test_addon.lua
local MW, frames, checks = {}, {}, 0
local state = {class = "WARRIOR", combat = false, dead = false, wsg = false}
local function check(value, message) assert(value, message); checks = checks + 1 end
local function opaque()
    local value = newproxy(true)
    local function forbidden() error("opaque client value was inspected") end
    for _, name in ipairs({"__index", "__newindex", "__tostring", "__add", "__sub", "__lt", "__le", "__eq"}) do
        getmetatable(value)[name] = forbidden
    end
    return value
end
local secret, duration = opaque(), opaque()
function issecretvalue(value) return rawequal(value, secret) end

-- Only this explicit visual-method whitelist is inert. Missing APIs fail loudly.
local Frame = {}
for name in ("SetSize SetPoint ClearAllPoints SetFrameStrata SetClampedToScreen SetMovable EnableMouse " ..
    "RegisterForDrag SetBackdrop SetBackdropColor SetBackdropBorderColor StartMoving StopMovingOrSizing " ..
    "SetHeight SetWidth SetJustifyH SetJustifyV SetAllPoints SetDrawEdge SetHideCountdownNumbers " ..
    "SetDesaturated SetAlpha SetTextColor SetColorTexture SetSpacing SetOwner SetSpellByID AddLine"):gmatch("%S+") do
    Frame[name] = function() end
end
function Frame:SetScript(name, callback) self.scripts[name] = callback end
function Frame:RegisterEvent(name) self.events[name] = true end
function Frame:UnregisterEvent(name) self.events[name] = nil end
function Frame:SetText(value) self.text = value end
function Frame:SetTexture(value) self.textureValue = value end
function Frame:GetCenter() return 0, 0 end
function Frame:EnableKeyboard(value) self.keyboard = value end
function Frame:SetPropagateKeyboardInput(value)
    assert(not state.combat, "keyboard propagation changed in combat")
    self.propagate = value
end
function Frame:Clear() self.duration = nil end
function Frame:SetCooldownFromDurationObject(value)
    assert(rawequal(value, duration), "cooldown received an unexpected value")
    self.duration = value
end
function Frame:IsShown() return self.shown end
function Frame:SetShown(value)
    local changed = self.shown ~= value
    self.shown = value
    local callback = self.scripts[value and "OnShow" or "OnHide"]
    if changed and callback then callback(self) end
end
function Frame:Show() self:SetShown(true) end
function Frame:Hide() self:SetShown(false) end
local function frame()
    local value = setmetatable({scripts = {}, events = {}, shown = true}, {__index = Frame})
    frames[#frames + 1] = value
    return value
end
function Frame:CreateTexture() return frame() end
function Frame:CreateFontString() return frame() end
function CreateFrame() return frame() end
UIParent, GameTooltip = frame(), frame()
SlashCmdList, DEFAULT_CHAT_FRAME = {}, {AddMessage = function(_, message) assert(type(message) == "string") end}
function GetInstanceInfo() return "Warsong Gulch", state.wsg and "pvp" or "none", 0, "", 0, 0, false, state.wsg and 489 or 0 end
function UnitClass() return "Class", state.class end
function UnitLevel() return 19 end
function GetBuildInfo() return "1.60.1", "70959", "", 16001 end
function GetCurrentKeyBoardFocus() return state.focus end
function UnitAffectingCombat() return state.combat end
function UnitIsDeadOrGhost() return state.dead end
C_RestrictedActions = {InCombatLockdown = function() return state.combat end}
local known = {[100] = true, [72] = true, [1044] = true, [498] = true}
C_SpellBook = {IsSpellKnown = function(id) return known[id] or false end}
C_Spell = {GetSpellTexture = function() return 134400 end, GetSpellCooldownDuration = function() return duration end}
C_UnitAuras = {GetPlayerAuraBySpellID = function() return state.aura end}
local function fire(event, ...)
    for _, value in ipairs(frames) do
        if value.events[event] and value.scripts.OnEvent then value.scripts.OnEvent(value, event, ...) end
    end
end
for line in io.lines("addon/MetalWars/MetalWars.toc") do
    if line:match("%.lua$") then assert(loadfile("addon/MetalWars/" .. line))("MetalWars", MW) end
end
fire("ADDON_LOADED", "AnotherAddon")
check(MW.db == nil, "initialized for another addon")
fire("ADDON_LOADED", "MetalWars")
check(type(SlashCmdList.METALWARS) == "function" and MW.db.bestScore == 0, "initialization failed")
check(not MW.HUD.frame:IsShown(), "automatic HUD shown outside WSG")
check(MW.HUD.icons[1].spellID == 100 and MW.HUD.icons[2].spellID == nil, "spellbook filtering failed")
check(rawequal(MW.HUD.icons[1].cooldown.duration, duration), "opaque duration was not forwarded")

state.wsg = true; fire("PLAYER_ENTERING_WORLD")
check(MW.inWSG and MW.HUD.frame:IsShown(), "WSG entry did not show HUD")
local function play()
    MW.Game:Toggle(); MW.Game:Resume()
    check(MW.Game.frame:IsShown() and MW.Game.frame.keyboard, "game did not capture deliberate resume")
end
local function released(message)
    check(not MW.Game.frame:IsShown() and not MW.Game.frame.keyboard and MW.Game.model.paused, message)
end
MW.Game:Toggle()
check(MW.Game.model.paused and not MW.Game.frame.keyboard, "opening game captured keyboard")
MW.Game:Resume()
fire("UNIT_COMBAT", "party1", "WOUND", secret)
fire("UNIT_COMBAT", secret)
check(MW.Game.frame:IsShown() and MW.Game.frame.keyboard, "unrelated unit interrupted game")
fire("UNIT_COMBAT", "player", "WOUND", secret); released("player combat did not release keyboard")
play(); state.combat = true; fire("PLAYER_REGEN_DISABLED"); released("combat entry did not release keyboard")
MW.Game:Toggle(); released("game opened in combat")
state.combat = false; fire("PLAYER_REGEN_ENABLED")
play(); MW.manualCarrier = true; state.dead = true; fire("PLAYER_DEAD"); released("death did not release keyboard")
check(not MW.manualCarrier, "death retained stale manual flag state")
MW.Game:Toggle(); released("game opened while dead")
state.dead = false; fire("PLAYER_ALIVE")
play(); fire("CHAT_MSG_BG_SYSTEM_HORDE", secret); released("WSG objective did not interrupt")
state.wsg = false; fire("PLAYER_ENTERING_WORLD")
play(); fire("CHAT_MSG_BG_SYSTEM_NEUTRAL", secret)
check(MW.Game.frame:IsShown(), "objective message interrupted outside WSG")
state.wsg = true; fire("ZONE_CHANGED_NEW_AREA"); released("world transition retained controls")
MW:Command("hide"); fire("UNIT_AURA", "player")
check(not MW.HUD.frame:IsShown(), "manual HUD hide was lost on aura refresh")
MW:Command("auto"); check(MW.HUD.frame:IsShown(), "auto HUD did not return inside WSG")
state.wsg = false; fire("PLAYER_ENTERING_WORLD")
check(not MW.HUD.frame:IsShown(), "auto HUD did not hide outside WSG")
MW:Command("show"); check(MW.HUD.frame:IsShown(), "manual HUD show failed")

state.wsg = true; fire("PLAYER_ENTERING_WORLD")
state.aura = secret; check(MW:CarrierState() == "unknown", "secret aura was interpreted")
C_UnitAuras.GetPlayerAuraBySpellID = function() error("restricted") end
check(MW:CarrierState() == "unknown", "restricted aura did not degrade safely")
C_UnitAuras = nil; check(MW:CarrierState() == "unknown", "missing aura API claimed flag absence")
MW:Command("flag"); check(MW:CarrierState() == "manual", "manual carrier fallback failed")
local getDuration = C_Spell.GetSpellCooldownDuration
for _, unavailable in ipairs({function() error("restricted") end, function() return secret end}) do
    C_Spell.GetSpellCooldownDuration = unavailable; fire("SPELL_UPDATE_COOLDOWN")
    check(MW.HUD.icons[1].status.text == "?" and MW.HUD.icons[1].cooldown.duration == nil, "restricted cooldown retained misleading data")
end
C_Spell.GetSpellCooldownDuration = nil; fire("SPELL_UPDATE_COOLDOWN")
check(MW.HUD.icons[1].status.text == "?", "missing cooldown API did not degrade safely")
C_Spell.GetSpellCooldownDuration = getDuration
known[100] = secret; fire("SPELLS_CHANGED")
check(MW.HUD.icons[1].spellID == nil, "secret known-spell result was interpreted")
state.class = "PALADIN"; fire("PLAYER_ENTERING_WORLD"); fire("SPELLS_CHANGED")
check(MW.HUD.icons[1].spellID == 1044 and MW.HUD.icons[6].spellID == 498, "paladin learned-rank lookup failed")
local combatAPI, deadAPI, restrictedAPI = UnitAffectingCombat, UnitIsDeadOrGhost, C_RestrictedActions
UnitAffectingCombat = function() return secret end
MW.Game:Toggle(); released("secret combat state allowed keyboard capture")
UnitAffectingCombat = nil; MW.Game:Toggle(); released("missing combat API allowed keyboard capture")
UnitAffectingCombat = combatAPI; C_RestrictedActions = nil
MW.Game:Toggle(); released("missing lockdown API allowed keyboard capture")
C_RestrictedActions = restrictedAPI; UnitIsDeadOrGhost = nil
MW.Game:Toggle(); released("missing death API allowed keyboard capture")
UnitIsDeadOrGhost = deadAPI
play(); state.focus = {}; MW.Game.frame.scripts.OnUpdate(MW.Game.frame, 0.1)
check(MW.Game.model.paused and not MW.Game.frame.keyboard, "chat focus retained keyboard capture")
state.focus = nil; MW.Game:Resume(); MW.Game:KeyDown("P")
check(not MW.Game.frame.keyboard and MW.Game.frame.propagate == false, "pause key leaked to a WoW binding")
MW.Game:Resume(); MW.Game:KeyDown("ESCAPE")
check(not MW.Game.frame:IsShown() and not MW.Game.frame.keyboard and MW.Game.frame.propagate == false,
    "close key leaked to a WoW binding")
play(); MW.Game.model:Reset()
MW.Game.model.piece = {kind = 4, rotation = 1, x = 4, y = 0}
MW.Game.model.board[2][4] = 1
MW.Game:KeyDown("SPACE")
check(MW.Game.model.over and not MW.Game.frame.keyboard and MW.Game.frame.propagate == false,
    "game-over drop key leaked to a WoW binding")
print("Addon lifecycle: " .. checks .. " checks passed")
