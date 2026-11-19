-- Flagstack: a small, dependency-free falling-block model. No WoW API calls.
local _, MW = ...
local Blocks = {}
MW.Blocks = Blocks
Blocks.__index = Blocks
Blocks.WIDTH, Blocks.HEIGHT = 10, 20

Blocks.Colors = {
    {0.20, 0.82, 0.91}, {0.32, 0.49, 0.94}, {1.00, 0.58, 0.20},
    {0.98, 0.81, 0.24}, {0.39, 0.83, 0.45}, {0.73, 0.43, 0.92},
    {0.94, 0.32, 0.36},
}

local shapes = {
    {size = 4, cells = {{0, 1}, {1, 1}, {2, 1}, {3, 1}}}, -- I
    {size = 3, cells = {{0, 0}, {0, 1}, {1, 1}, {2, 1}}}, -- J
    {size = 3, cells = {{2, 0}, {0, 1}, {1, 1}, {2, 1}}}, -- L
    {size = 2, cells = {{0, 0}, {1, 0}, {0, 1}, {1, 1}}}, -- O
    {size = 3, cells = {{1, 0}, {2, 0}, {0, 1}, {1, 1}}}, -- S
    {size = 3, cells = {{1, 0}, {0, 1}, {1, 1}, {2, 1}}}, -- T
    {size = 3, cells = {{0, 0}, {1, 0}, {1, 1}, {2, 1}}}, -- Z
}

-- Rotation is deliberately simple: square rotation plus small wall/floor kicks.
-- This does not claim to implement a licensed ruleset or SRS.
for _, shape in ipairs(shapes) do
    shape.rotations = {shape.cells}
    for rotation = 2, 4 do
        local cells = {}
        for i, point in ipairs(shape.rotations[rotation - 1]) do
            cells[i] = {shape.size - 1 - point[2], point[1]}
        end
        shape.rotations[rotation] = cells
    end
end
Blocks.Shapes = shapes

local function copyPiece(piece)
    return {kind = piece.kind, rotation = piece.rotation, x = piece.x, y = piece.y}
end

function Blocks.New(random)
    local self = setmetatable({random = random or math.random}, Blocks)
    self:Reset()
    return self
end

function Blocks:_Draw()
    if #self.bag == 0 then
        for i = 1, 7 do self.bag[i] = i end
        for i = 7, 2, -1 do
            local j = self.random(i)
            self.bag[i], self.bag[j] = self.bag[j], self.bag[i]
        end
    end
    return table.remove(self.bag)
end

function Blocks:Reset()
    self.board = {}
    for y = 1, Blocks.HEIGHT do self.board[y] = {} end
    self.bag = {}
    self.score, self.lines, self.level = 0, 0, 1
    self.elapsed, self.paused, self.over = 0, false, false
    self.next = self:_Draw()
    self:_Spawn()
end

function Blocks:Cells(piece)
    piece = piece or self.piece
    local result = {}
    if piece then
        for i, point in ipairs(shapes[piece.kind].rotations[piece.rotation]) do
            result[i] = {piece.x + point[1], piece.y + point[2]}
        end
    end
    return result
end

function Blocks:Fits(piece)
    for _, point in ipairs(shapes[piece.kind].rotations[piece.rotation]) do
        local x, y = piece.x + point[1], piece.y + point[2]
        if x < 1 or x > Blocks.WIDTH or y > Blocks.HEIGHT then return false end
        if y > 0 and self.board[y][x] then return false end
    end
    return true
end

function Blocks:_Spawn()
    self.piece = {kind = self.next, rotation = 1, x = 4, y = 0}
    self.next = self:_Draw()
    self.elapsed = 0
    if not self:Fits(self.piece) then
        self.over, self.piece = true, nil
    end
end

function Blocks:_Move(dx, dy)
    local candidate = copyPiece(self.piece)
    candidate.x, candidate.y = candidate.x + dx, candidate.y + dy
    if not self:Fits(candidate) then return false end
    self.piece = candidate
    return true
end

function Blocks:Move(dx)
    if self.paused or self.over then return false end
    return self:_Move(dx, 0)
end

function Blocks:Rotate()
    if self.paused or self.over then return false end
    if self.piece.kind == 4 then return true end
    local candidate = copyPiece(self.piece)
    candidate.rotation = candidate.rotation % 4 + 1
    local kicks = {{0, 0}, {-1, 0}, {1, 0}, {-2, 0}, {2, 0}, {0, -1}}
    for _, kick in ipairs(kicks) do
        candidate.x, candidate.y = self.piece.x + kick[1], self.piece.y + kick[2]
        if self:Fits(candidate) then
            self.piece = candidate
            return true
        end
    end
    return false
end

function Blocks:_Lock()
    local cells = self:Cells()
    for _, point in ipairs(cells) do
        if point[2] < 1 then
            self.over, self.piece = true, nil
            return
        end
    end
    for _, point in ipairs(cells) do self.board[point[2]][point[1]] = self.piece.kind end

    local cleared, y = 0, Blocks.HEIGHT
    while y > 0 do
        local full = true
        for x = 1, Blocks.WIDTH do
            if not self.board[y][x] then full = false; break end
        end
        if full then
            table.remove(self.board, y)
            table.insert(self.board, 1, {})
            cleared = cleared + 1
        else
            y = y - 1
        end
    end
    local points = {100, 300, 500, 800}
    self.score = self.score + (points[cleared] or 0) * self.level
    self.lines = self.lines + cleared
    self.level = math.floor(self.lines / 10) + 1
    self:_Spawn()
end

function Blocks:SoftDrop()
    if self.paused or self.over then return false end
    if self:_Move(0, 1) then self.score = self.score + 1 else self:_Lock() end
    return true
end

function Blocks:Ghost()
    if not self.piece then return nil end
    local ghost = copyPiece(self.piece)
    while true do
        ghost.y = ghost.y + 1
        if not self:Fits(ghost) then ghost.y = ghost.y - 1; return ghost end
    end
end

function Blocks:HardDrop()
    if self.paused or self.over then return false end
    local ghost = self:Ghost()
    self.score = self.score + 2 * (ghost.y - self.piece.y)
    self.piece = ghost
    self:_Lock()
    return true
end

function Blocks:Tick(elapsed)
    if self.paused or self.over then return false end
    -- A stalled UI never races through several seconds of falling blocks.
    self.elapsed = self.elapsed + math.min(math.max(elapsed, 0), 0.25)
    local interval = math.max(0.10, 0.8 - (self.level - 1) * 0.06)
    local changed = false
    while self.elapsed >= interval and not self.over do
        self.elapsed = self.elapsed - interval
        if not self:_Move(0, 1) then self:_Lock() end
        changed = true
    end
    return changed
end
