local _, MW = ...
local HUD = {}
MW.HUD = HUD

local function text(parent, font, x, y, width)
    local label = parent:CreateFontString(nil, "OVERLAY", font)
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    return label
end

local function button(parent, label, x, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(108, 23)
    b:SetPoint("BOTTOMLEFT", x, 10)
    b:SetText(label)
    b:SetScript("OnClick", callback)
    return b
end

function HUD:ResetPosition()
    local f = self.frame
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", -210, 170)
end

function HUD:Init()
    if self.frame then return end
    local f = CreateFrame("Frame", "MetalWarsHUD", UIParent, "BackdropTemplate")
    self.frame = f
    f:SetSize(376, 232)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.055, 0.06, 0.07, 0.96)
    f:SetBackdropBorderColor(0.5, 0.3, 0.18, 1)
    self:ResetPosition()
    local pos = MW.db.position
    if type(pos) == "table" and type(pos.x) == "number" and type(pos.y) == "number" then
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)
    end

    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(30)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() if not MW:IsInCombat() then f:StartMoving() end end)
    header:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local x, y = f:GetCenter()
        local ux, uy = UIParent:GetCenter()
        MW.db.position = { x = x - ux, y = y - uy }
    end)
    text(header, "GameFontNormal", 12, -9, 300):SetText("|cffea9650METALWARS|r  /  WSG 19")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetSize(28, 28)
    close:SetScript("OnClick", function() MW.forceHUD = false; f:Hide() end)

    self.context = text(f, "GameFontHighlightSmall", 12, -36, 352)
    self.carrier = text(f, "GameFontNormalSmall", 12, -55, 352)
    self.hint = text(f, "GameFontHighlightSmall", 12, -78, 352)
    self.hint:SetHeight(30)
    self.hint:SetJustifyV("TOP")
    self.footer = text(f, "GameFontDisableSmall", 12, -173, 352)
    self.footer:SetHeight(26)
    self.footer:SetText("Cooldown display only. Check range, resources and stance on your action bars.")
    button(f, "Flagstack", 12, function() MW.Game:Toggle() end)
    self.flagButton = button(f, "Flag reminder", 130, function() MW:ToggleFlag() end)
    button(f, "Auto HUD", 248, function() MW.forceHUD = nil; HUD:Refresh() end)

    self.icons = {}
    for i = 1, 6 do
        local icon = CreateFrame("Button", nil, f)
        icon:SetSize(40, 40)
        icon:SetPoint("TOPLEFT", 14 + (i - 1) * 59, -113)
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints()
        icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        icon.cooldown:SetAllPoints()
        icon.cooldown:SetDrawEdge(true)
        icon.cooldown:SetHideCountdownNumbers(false)
        icon.label = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        icon.label:SetPoint("TOP", icon, "BOTTOM", 0, -3)
        icon.label:SetWidth(57)
        icon.status = icon:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        icon.status:SetPoint("CENTER")
        icon:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.spellID then GameTooltip:SetSpellByID(self.spellID)
            else GameTooltip:SetText(self.entry.label .. " — not learned") end
            GameTooltip:AddLine(self.entry.note, 0.9, 0.75, 0.55, true)
            GameTooltip:AddLine("Display only; use your normal action bar.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.icons[i] = icon
    end
    f:SetScript("OnShow", function() HUD:RefreshCooldowns() end)
    self:RefreshSpells()
    self:Refresh()
end

function HUD:RefreshSpells()
    if not self.frame then return end
    local profile = MW.Classes[MW.class]
    for i, icon in ipairs(self.icons) do
        local entry = profile and profile.spells[i]
        if entry then
            icon.entry = entry
            icon.spellID = MW:KnownSpell(entry)
            icon.texture:SetTexture(MW:Read(C_Spell and C_Spell.GetSpellTexture,
                icon.spellID or entry.ids[1]) or 134400)
            icon.texture:SetDesaturated(not icon.spellID)
            icon.texture:SetAlpha(icon.spellID and 1 or 0.35)
            icon.label:SetText(entry.label)
            icon:Show()
        else
            icon:Hide()
        end
    end
    self.hint:SetText(profile and profile.hint or "Warrior and paladin tools first. Flag reminders and Flagstack work for every class.")
    self:RefreshCooldowns()
end

function HUD:RefreshCooldowns()
    if not self.icons then return end
    for _, icon in ipairs(self.icons) do
        if icon.entry then
            icon.cooldown:Clear()
            icon.status:SetText(icon.spellID and "" or "—")
            if icon.spellID then
                local getDuration = C_Spell and C_Spell.GetSpellCooldownDuration
                local ok, duration = false, nil
                if getDuration then ok, duration = pcall(getDuration, icon.spellID, true) end
                if ok and MW:IsPlain(duration) then
                    if duration then
                        -- Pass the opaque object straight to Blizzard's widget.
                        -- Never compare, subtract or format hidden timing values.
                        local drawn = pcall(icon.cooldown.SetCooldownFromDurationObject, icon.cooldown, duration)
                        if not drawn then icon.status:SetText("?") end
                    end
                else
                    icon.status:SetText("?")
                end
            end
        end
    end
end

function HUD:Refresh()
    if not self.frame then return end
    local level = type(MW.level) == "number" and MW.level or 0
    local bracket = level >= 10 and level <= 19 and "10–19 bracket" or "built for level 19"
    self.context:SetText((MW.inWSG and "Warsong Gulch" or "Outside WSG / manual view") .. "  ·  " .. bracket)
    local state = MW:CarrierState()
    if state == "manual" or state == "observed" then
        self.carrier:SetText("|cffffbb55FLAG CARRIER" .. (state == "manual" and " (manual)" or " (aura observed)") .. " — stay aware.|r")
    elseif state == "unknown" then
        self.carrier:SetText("Flag state unconfirmed. /mw flag enables a manual reminder.")
    else
        self.carrier:SetText("Enter WSG for the automatic HUD. /mw flag for a carrier reminder.")
    end
    for _, icon in ipairs(self.icons) do
        local caution = icon.entry and icon.entry.caution and (state == "manual" or state == "observed")
        icon.label:SetTextColor(caution and 1 or 0.9, caution and 0.48 or 0.78, caution and 0.2 or 0.5)
    end
    self.flagButton:SetText(MW.manualCarrier and "Flag mode: ON" or "Flag reminder")
    local visible = MW.forceHUD
    if visible == nil then visible = MW.inWSG end
    self.frame:SetShown(visible)
    self:RefreshCooldowns()
end
