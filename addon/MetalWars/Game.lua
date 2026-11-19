-- Flagstack uses only its own frame's keys. It never changes character bindings.
local _, MW = ...
local Game = {}
MW.Game = Game
local Blocks = MW.Blocks
local CELL, LEFT, TOP = 18, 18, 80

local function label(parent, font, x, y, text)
    local value = parent:CreateFontString(nil, "OVERLAY", font)
    value:SetPoint("TOPLEFT", x, y)
    value:SetJustifyH("LEFT")
    value:SetText(text)
    return value
end

local function button(parent, x, text, callback)
    local value = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    value:SetSize(108, 24)
    value:SetPoint("BOTTOMLEFT", x, 48)
    value:SetText(text)
    value:SetScript("OnClick", callback)
    return value
end

function Game:Allowed()
    return not MW:IsInCombat() and not MW:IsDead()
end

function Game:ReleaseKeyboard()
    if not self.frame then return end
    self.frame:EnableKeyboard(false)
    -- SetPropagateKeyboardInput cannot be changed during combat lockdown.
    if not MW:IsInCombat() then self.frame:SetPropagateKeyboardInput(true) end
end

function Game:Pause(reason)
    if self.model then self.model.paused = true end
    self.reason = reason or "Paused - click Resume to continue."
    self:ReleaseKeyboard()
    if self.frame then self:Render() end
end

function Game:Interrupt(reason)
    self:Pause(reason or "Paused for the battleground.")
    if self.frame then self.frame:Hide() end
end

function Game:Resume()
    if not self:Allowed() then self:Interrupt("Paused for combat or death."); return end
    if self.model.over then self.reason = "Game over - click New game."; self:Render(); return end
    self.model.paused = false
    self.reason = "Playing - P pauses. Esc closes."
    self.frame:SetPropagateKeyboardInput(true)
    self.frame:EnableKeyboard(true)
    self:Render()
end

function Game:NewGame()
    if not self:Allowed() then self:Interrupt(); return end
    self.model:Reset()
    self:Pause("New game - click Resume to start.")
end

function Game:Render()
    local model = self.model
    if not model or not self.frame then return end
    if MW.db then MW.db.bestScore = math.max(tonumber(MW.db.bestScore) or 0, model.score) end
    for y = 1, Blocks.HEIGHT do
        for x = 1, Blocks.WIDTH do
            local kind = model.board[y][x]
            local color = kind and Blocks.Colors[kind]
            if color then
                self.cells[y][x]:SetColorTexture(color[1], color[2], color[3], 1)
            else
                self.cells[y][x]:SetColorTexture(0.08, 0.10, 0.14, 1)
            end
        end
    end
    local function drawPiece(piece, alpha)
        if not piece then return end
        local color = Blocks.Colors[piece.kind]
        for _, point in ipairs(model:Cells(piece)) do
            if point[2] > 0 and point[2] <= Blocks.HEIGHT then
                self.cells[point[2]][point[1]]:SetColorTexture(color[1], color[2], color[3], alpha)
            end
        end
    end
    drawPiece(model:Ghost(), 0.25)
    drawPiece(model.piece, 1)
    for _, texture in ipairs(self.nextCells) do texture:Hide() end
    local color = Blocks.Colors[model.next]
    for i, point in ipairs(Blocks.Shapes[model.next].rotations[1]) do
        local texture = self.nextCells[i]
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 222 + point[1] * CELL, -264 - point[2] * CELL)
        texture:SetColorTexture(color[1], color[2], color[3], 1)
        texture:Show()
    end
    self.score:SetText(tostring(model.score))
    self.lines:SetText(tostring(model.lines))
    self.level:SetText(tostring(model.level))
    self.best:SetText(tostring(MW.db and MW.db.bestScore or model.score))
    self.resume:SetText(model.paused and "Resume" or "Pause")
    if model.over then
        self.reason = "Game over - click New game."
        self:ReleaseKeyboard()
    end
    self.status:SetText(self.reason)
end

function Game:KeyDown(key)
    if not self:Allowed() then self:Interrupt("Paused for combat or death."); return end
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then
        self:Pause("Paused while typing - click Resume.")
        return
    end
    local handled = true
    if key == "ESCAPE" then self:Interrupt("Paused - click Resume to continue.")
    elseif key == "P" then self:Pause()
    elseif key == "LEFT" then self.model:Move(-1)
    elseif key == "RIGHT" then self.model:Move(1)
    elseif key == "UP" then self.model:Rotate()
    elseif key == "DOWN" then self.model:SoftDrop()
    elseif key == "SPACE" then self.model:HardDrop()
    else handled = false end
    self:Render()
    -- Consume this handled key even if it just paused/closed/ended the game.
    -- Capture is already disabled in those states, so subsequent keys are free.
    -- Set this AFTER Render/OnHide, whose release path resets propagation.
    if not MW:IsInCombat() then self.frame:SetPropagateKeyboardInput(not handled) end
end

function Game:Init()
    if self.frame then return end
    local frame = CreateFrame("Frame", "MetalWarsFlagstack", UIParent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(390, 526)
    frame:SetPoint("CENTER", UIParent, "CENTER", 210, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() if self:Allowed() then frame:StartMoving() end end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    frame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    frame:SetBackdropColor(0.025, 0.035, 0.055, 0.97)
    frame:SetBackdropBorderColor(0.35, 0.42, 0.53, 1)
    label(frame, "GameFontNormalLarge", 18, -18, "FLAGSTACK")
    label(frame, "GameFontDisableSmall", 162, -23, "METALWARS / SIDE GAME")
    self.status = label(frame, "GameFontHighlightSmall", 18, -51, "")
    self.status:SetWidth(350)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() self:Interrupt() end)

    self.cells = {}
    for y = 1, Blocks.HEIGHT do
        self.cells[y] = {}
        for x = 1, Blocks.WIDTH do
            local texture = frame:CreateTexture(nil, "ARTWORK")
            texture:SetSize(CELL - 2, CELL - 2)
            texture:SetPoint("TOPLEFT", LEFT + (x - 1) * CELL, -TOP - (y - 1) * CELL)
            self.cells[y][x] = texture
        end
    end
    label(frame, "GameFontDisableSmall", 222, -80, "SCORE")
    self.score = label(frame, "GameFontNormalLarge", 222, -99, "0")
    label(frame, "GameFontDisableSmall", 222, -135, "LINES / LEVEL")
    self.lines = label(frame, "GameFontHighlight", 222, -154, "0")
    self.level = label(frame, "GameFontHighlight", 290, -154, "1")
    label(frame, "GameFontDisableSmall", 222, -190, "PERSONAL BEST")
    self.best = label(frame, "GameFontHighlight", 222, -209, "0")
    label(frame, "GameFontDisableSmall", 222, -245, "NEXT")
    self.nextCells = {}
    for i = 1, 4 do
        local texture = frame:CreateTexture(nil, "ARTWORK")
        texture:SetSize(CELL - 2, CELL - 2)
        self.nextCells[i] = texture
    end
    local controls = label(frame, "GameFontHighlightSmall", 222, -338,
        "Left / Right: move\nUp: rotate\nDown: soft drop\nSpace: hard drop\nP: pause\nEsc: close")
    controls:SetSpacing(6)
    controls:SetWidth(151)

    self.resume = button(frame, 18, "Resume", function()
        if self.model.paused then self:Resume() else self:Pause() end
    end)
    button(frame, 141, "New game", function() self:NewGame() end)
    button(frame, 264, "Close", function() self:Interrupt() end)
    local footnote = label(frame, "GameFontDisableSmall", 18, -491,
        "Combat, damage and WSG objective alerts close the game.\nYour character stays in the battleground.")
    footnote:SetWidth(354)
    footnote:SetSpacing(3)

    frame:SetScript("OnKeyDown", function(_, key) self:KeyDown(key) end)
    frame:SetScript("OnKeyUp", function()
        if not MW:IsInCombat() then frame:SetPropagateKeyboardInput(true) end
    end)
    frame:SetScript("OnHide", function()
        self:ReleaseKeyboard()
        frame:StopMovingOrSizing()
        if self.model then self.model.paused = true end
    end)
    frame:SetScript("OnUpdate", function(_, elapsed)
        if not self:Allowed() then self:Interrupt("Paused for combat or death."); return end
        if self.model and not self.model.paused then
            if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then
                self:Pause("Paused while typing - click Resume.")
            elseif self.model:Tick(elapsed) then
                self:Render()
            end
        end
    end)
    self.model = Blocks.New()
    self:Pause("Click Resume to start. The battlefield comes first.")
    frame:Hide()
end

function Game:Toggle()
    if not self:Allowed() then
        self:Interrupt("Paused for combat or death.")
        MW:Print("Flagstack is available while alive and out of combat.")
        return
    end
    self:Init()
    if self.frame:IsShown() then self:Interrupt(); return end
    self:Pause(self.model.over and "Game over - click New game." or "Click Resume when ready.")
    self.frame:Show()
end
