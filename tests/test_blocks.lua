-- Run from the repository root: lua tests/test_blocks.lua
local MW = {}
assert(loadfile("addon/MetalWars/Blocks.lua"))("MetalWars", MW)
local Blocks = MW.Blocks
local checks = 0
local function check(value, message)
    assert(value, message)
    checks = checks + 1
end
local function newGame()
    local seed = 42
    return Blocks.New(function(upper)
        seed = (seed * 48271) % 2147483647
        return seed % upper + 1
    end)
end
local function occupied(game)
    local count = 0
    for y = 1, Blocks.HEIGHT do
        for x = 1, Blocks.WIDTH do if game.board[y][x] then count = count + 1 end end
    end
    return count
end

-- Every bag supplies each shape once, including the first active/next pieces.
local game = newGame()
local seen = {[game.piece.kind] = true, [game.next] = true}
for _ = 3, 7 do
    local kind = game:_Draw()
    check(not seen[kind], "seven-bag repeated a shape")
    seen[kind] = true
end
for kind = 1, 7 do check(seen[kind], "seven-bag omitted a shape") end

-- A ghost accurately predicts the locked cells and the next piece can spawn.
game = newGame()
local ghost, expected = game:Ghost(), {}
for _, point in ipairs(game:Cells(game:Ghost())) do expected[#expected + 1] = point end
local kind = game.piece.kind
check(game:HardDrop(), "hard drop failed")
for _, point in ipairs(expected) do check(game.board[point[2]][point[1]] == kind, "ghost disagrees with lock") end
check(occupied(game) == 4 and not game.over, "first piece did not lock cleanly")
check(game.score == ghost.y * 2, "hard-drop score is incorrect")

-- Complete four nearly full rows with a vertical I; all rows collapse together.
game = newGame()
for y = 17, 20 do
    for x = 1, 10 do if x ~= 5 then game.board[y][x] = 3 end end
end
game.piece = {kind = 1, rotation = 2, x = 3, y = 17}
check(game:Fits(game.piece), "four-line fixture is invalid")
game:HardDrop()
check(game.lines == 4 and game.score == 800, "four-line clear/scoring failed")
check(occupied(game) == 0 and #game.board == 20, "line clearing changed board shape")

-- Crossing a ten-line threshold updates level after scoring at the old level.
game = newGame()
game.lines = 9
for x = 1, 10 do if x < 4 or x > 7 then game.board[20][x] = 2 end end
game.piece = {kind = 1, rotation = 1, x = 4, y = 19}
game:HardDrop()
check(game.lines == 10 and game.level == 2 and game.score == 100, "level transition is incorrect")

-- A wall rotation kicks into the board; a fully blocked rotation is rejected.
game = newGame()
game.piece = {kind = 1, rotation = 2, x = -1, y = 5}
check(game:Fits(game.piece), "wall fixture is invalid")
check(game:Rotate() and game:Fits(game.piece), "wall kick failed")
for y = 1, 20 do for x = 1, 10 do game.board[y][x] = 1 end end
local before = game.piece.rotation
check(not game:Rotate() and game.piece.rotation == before, "blocked rotation moved piece")

-- A piece that locks above the top ends the game without writing off-board rows.
game = newGame()
game.piece = {kind = 4, rotation = 1, x = 4, y = 0}
game.board[2][4], game.board[2][5] = 1, 1
game:SoftDrop()
check(game.over and game.piece == nil, "top-out failed")
check(game.board[0] == nil and occupied(game) == 2, "top-out wrote off-board cells")

-- Pause freezes all gameplay, including elapsed time; a reset clears old results.
game = newGame()
game.paused = true
local x, y, rotation = game.piece.x, game.piece.y, game.piece.rotation
check(not game:Move(1) and not game:Rotate() and not game:SoftDrop() and not game:HardDrop(), "paused input changed game")
check(not game:Tick(10) and game.elapsed == 0, "paused tick advanced time")
check(game.piece.x == x and game.piece.y == y and game.piece.rotation == rotation, "paused piece changed")
game:Reset()
check(game.score == 0 and game.lines == 0 and not game.over and not game.paused, "reset retained game state")

-- A long UI stall is capped and cannot instantly consume a newly spawned piece.
game = newGame()
local startY = game.piece.y
check(not game:Tick(60) and game.piece.y == startY, "lag spike advanced too much")
for _ = 1, 3 do game:Tick(0.25) end
check(game.piece.y == startY + 1, "normal gravity did not advance")

print("Flagstack: " .. checks .. " checks passed")
