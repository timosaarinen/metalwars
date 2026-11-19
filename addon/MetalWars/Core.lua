local addonName, MW = ...

MW.version = "0.1.0"
MW.interface = 16001
MW.manualCarrier = false -- Session-only: never restore a stale flag claim on login.
MW.forceHUD = nil

function MW:IsPlain(value)
    return not (issecretvalue and issecretvalue(value))
end

-- For public scalar metadata only. Opaque cooldown objects have their own path.
function MW:Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and self:IsPlain(value) then return value end
end

function MW:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffea9650MetalWars|r " .. message)
end

function MW:IsInCombat()
    if self.combat then return true end
    local locked = self:Read(C_RestrictedActions and C_RestrictedActions.InCombatLockdown)
    local fighting = self:Read(UnitAffectingCombat, "player")
    -- Fail closed if the client cannot tell us whether keyboard capture is safe.
    return locked ~= false or fighting ~= false
end

function MW:IsDead()
    if self.dead then return true end
    local dead = self:Read(UnitIsDeadOrGhost, "player")
    return dead ~= false
end

function MW:RefreshContext()
    local info = { pcall(GetInstanceInfo) }
    self.instanceID = nil
    self.inWSG = false
    if info[1] and self:IsPlain(info[3]) and self:IsPlain(info[9]) then
        self.instanceID = info[9]
        self.inWSG = info[3] == "pvp" and info[9] == 489
    end
    local ok, _, class = pcall(UnitClass, "player")
    self.class = ok and self:IsPlain(class) and class or nil
    self.level = self:Read(UnitLevel, "player")
end

function MW:CarrierState()
    if self.manualCarrier then return "manual" end
    if not self.inWSG then return "outside" end
    local getAura = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if not getAura then return "unknown" end
    for _, id in ipairs({ 23333, 23335 }) do
        local ok, aura = pcall(getAura, id)
        if ok and self:IsPlain(aura) and aura ~= nil then return "observed" end
    end
    -- A hidden/missing aura is not proof that the player has no flag.
    return "unknown"
end

function MW:InterruptGame(reason)
    if self.Game then self.Game:Interrupt(reason) end
end

function MW:ToggleFlag()
    self.manualCarrier = not self.manualCarrier
    if self.manualCarrier then self.forceHUD = true end
    self:Print(self.manualCarrier and "Manual flag reminder on." or "Manual flag reminder off.")
    self.HUD:Refresh()
end

function MW:Command(input)
    local command = (input or ""):lower():match("^%s*(%S*)")
    if command == "" or command == "show" then
        self.forceHUD = command == "show" or not self.HUD.frame:IsShown()
        self.HUD:Refresh()
    elseif command == "auto" then
        self.forceHUD = nil
        self.HUD:Refresh()
        self:Print("HUD follows Warsong Gulch again.")
    elseif command == "hide" then
        self.forceHUD = false
        self.HUD:Refresh()
    elseif command == "blocks" or command == "game" then
        self.Game:Toggle()
    elseif command == "flag" then
        self:ToggleFlag()
    elseif command == "reset" then
        self.db.position = nil
        self.HUD:ResetPosition()
        self:Print("HUD position reset.")
    elseif command == "status" then
        local build = { pcall(GetBuildInfo) }
        local function plain(value)
            return self:IsPlain(value) and tostring(value or "unknown") or "restricted"
        end
        self:Print("v" .. self.version .. "; client " .. plain(build[2]) ..
            "; build " .. plain(build[3]) .. "; interface " .. plain(build[5]))
        self:Print("Class " .. plain(self.class) .. "; level " .. plain(self.level) ..
            "; instance " .. plain(self.instanceID) .. "; flag " .. self:CarrierState())
        self:Print("Cooldown API: " .. (C_Spell and C_Spell.GetSpellCooldownDuration and "available" or "missing") ..
            ". Source-checked alpha; live Forever validation pending.")
    else
        self:Print("/mw — toggle HUD; /mw auto — WSG visibility; /mw blocks — Flagstack")
        self:Print("/mw flag — manual carrier reminder; /mw reset — move HUD home; /mw status — diagnostics")
        self:Print("Drag the HUD header. Cooldown icons are informational; use your normal action bars.")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        MetalWarsDB = type(MetalWarsDB) == "table" and MetalWarsDB or {}
        MW.db = MetalWarsDB
        if type(MW.db.bestScore) ~= "number" then MW.db.bestScore = 0 end
        MW:RefreshContext()
        MW.HUD:Init()
        SLASH_METALWARS1, SLASH_METALWARS2 = "/mw", "/metalwars"
        SlashCmdList.METALWARS = function(text) MW:Command(text) end
        events:UnregisterEvent("ADDON_LOADED")
        for _, name in ipairs({
            "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "UPDATE_BATTLEFIELD_STATUS",
            "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES",
            "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD", "PLAYER_ALIVE",
            "PLAYER_UNGHOST", "UNIT_AURA", "UNIT_COMBAT", "PLAYER_LOGOUT",
            "CHAT_MSG_BG_SYSTEM_ALLIANCE", "CHAT_MSG_BG_SYSTEM_HORDE", "CHAT_MSG_BG_SYSTEM_NEUTRAL",
        }) do
            events:RegisterEvent(name)
        end
        MW:Print("v" .. MW.version .. " alpha loaded. /mw help — WSG tools + Flagstack.")
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        MW.combat = true
        MW:InterruptGame("Combat — back to the battlefield.")
    elseif event == "PLAYER_REGEN_ENABLED" then
        MW.combat = false
    elseif event == "PLAYER_DEAD" then
        MW.dead = true
        MW.manualCarrier = false
        MW:InterruptGame("You died — check the battlefield.")
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        MW.dead = false
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        MW.manualCarrier = false
        MW.combat, MW.dead = false, false
        MW:InterruptGame("World changed — game paused.")
        MW:RefreshContext()
    elseif event == "PLAYER_LOGOUT" then
        MW:InterruptGame("Logging out.")
        return
    elseif event == "UNIT_COMBAT" then
        if MW:IsPlain(arg1) and arg1 == "player" then
            -- No inspection of the (potentially secret) damage amount.
            MW:InterruptGame("Player combat event — check the battlefield.")
        end
        return
    elseif event:match("^CHAT_MSG_BG_SYSTEM_") then
        if MW.inWSG then
            -- Pause for every objective message; do not parse localized/hidden chat.
            MW:InterruptGame("Battleground update — check the flags.")
        end
        return
    elseif event == "UNIT_AURA" then
        if not MW:IsPlain(arg1) or arg1 ~= "player" then return end
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" then
        MW.HUD:RefreshCooldowns()
        return
    elseif event == "SPELLS_CHANGED" then
        MW.HUD:RefreshSpells()
    else
        MW:RefreshContext()
    end
    MW.HUD:Refresh()
end)
