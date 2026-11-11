--!strict
-- Puzzle "Star Relay" (docs/PLAN.md §4.11). Daya masuk dari sisi Barat tile SOURCE
-- dan harus sampai ke tile TARGET lalu keluar lewat sisi Timur.

local RNG = require("./RNG")

export type Tile = { kind: string, rot: number }
export type Cell = { row: number, col: number }
export type Puzzle = {
	size: number,
	tiles: { { Tile } },
	source: Cell,
	target: Cell,
	solution: { { number } }?,
}

local PipePuzzle = {}

-- Arah: 1=N, 2=E, 3=S, 4=W.
local N, E, S, W = 1, 2, 3, 4
local DROW = { -1, 0, 1, 0 }
local DCOL = { 0, 1, 0, -1 }

local function opposite(d: number): number
	return (d + 1) % 4 + 1
end

-- Bukaan dasar (rot 0); rot r memutar searah jarum jam r kali.
local BASE: { [string]: { number } } = {
	I = { N, S },
	L = { N, E },
	T = { N, E, S },
	X = { N, E, S, W },
}
local KINDS = { "I", "L", "T", "X" }

local function openings(kind: string, rot: number): { boolean }
	local open = { false, false, false, false }
	local base = BASE[kind]
	if base == nil then
		return open
	end
	for _, d in base do
		open[(d - 1 + rot) % 4 + 1] = true
	end
	return open
end

local function tileOpen(tile: Tile, dir: number): boolean
	return openings(tile.kind, tile.rot)[dir]
end

function PipePuzzle.isSolved(puzzle: Puzzle): boolean
	local size = puzzle.size
	local src, tgt = puzzle.source, puzzle.target
	local srcTile = puzzle.tiles[src.row][src.col]
	if not tileOpen(srcTile, W) then
		return false
	end
	local visited: { [number]: boolean } = {}
	local function key(r: number, c: number): number
		return (r - 1) * size + c
	end
	local queue = { src }
	visited[key(src.row, src.col)] = true
	local head = 1
	while head <= #queue do
		local cur = queue[head]
		head += 1
		local tile = puzzle.tiles[cur.row][cur.col]
		for d = 1, 4 do
			if tileOpen(tile, d) then
				local nr, nc = cur.row + DROW[d], cur.col + DCOL[d]
				if
					nr >= 1
					and nr <= size
					and nc >= 1
					and nc <= size
					and not visited[key(nr, nc)]
				then
					local nt = puzzle.tiles[nr][nc]
					if tileOpen(nt, opposite(d)) then
						visited[key(nr, nc)] = true
						table.insert(queue, { row = nr, col = nc })
					end
				end
			end
		end
	end
	return visited[key(tgt.row, tgt.col)] == true and tileOpen(puzzle.tiles[tgt.row][tgt.col], E)
end

function PipePuzzle.rotate(puzzle: Puzzle, row: number, col: number)
	local tile = puzzle.tiles[row][col]
	tile.rot = (tile.rot + 1) % 4
end

-- Salinan puzzle dengan rotasi baru; nil jika input tidak valid.
function PipePuzzle.applyRotations(puzzle: Puzzle, rots: { { number } }): Puzzle?
	if type(rots) ~= "table" then
		return nil
	end
	local size = puzzle.size
	local copyTiles: { { Tile } } = {}
	for r = 1, size do
		local rowRots = rots[r]
		if type(rowRots) ~= "table" then
			return nil
		end
		local row: { Tile } = {}
		for c = 1, size do
			local rot = rowRots[c]
			if type(rot) ~= "number" or rot % 1 ~= 0 or rot < 0 or rot > 3 then
				return nil
			end
			row[c] = { kind = puzzle.tiles[r][c].kind, rot = rot }
		end
		copyTiles[r] = row
	end
	-- Tolak baris/kolom berlebih.
	if rots[size + 1] ~= nil then
		return nil
	end
	for r = 1, size do
		if (rots[r] :: { number })[size + 1] ~= nil then
			return nil
		end
	end
	return {
		size = size,
		tiles = copyTiles,
		source = { row = puzzle.source.row, col = puzzle.source.col },
		target = { row = puzzle.target.row, col = puzzle.target.col },
	}
end

-- Jalur acak tanpa memotong diri dari source ke target (DFS acak dengan backtracking).
local function randomPath(rng: RNG.RNG, size: number, src: Cell, tgt: Cell): { Cell }
	local used: { [number]: boolean } = {}
	local path: { Cell } = {}
	local function key(r: number, c: number): number
		return (r - 1) * size + c
	end
	local function dfs(r: number, c: number): boolean
		used[key(r, c)] = true
		table.insert(path, { row = r, col = c })
		if r == tgt.row and c == tgt.col then
			return true
		end
		local dirs = rng:shuffle({ 1, 2, 3, 4 })
		for _, d in dirs do
			local nr, nc = r + DROW[d], c + DCOL[d]
			if nr >= 1 and nr <= size and nc >= 1 and nc <= size and not used[key(nr, nc)] then
				if dfs(nr, nc) then
					return true
				end
			end
		end
		table.remove(path)
		used[key(r, c)] = nil
		return false
	end
	dfs(src.row, src.col)
	return path
end

-- Semua (kind, rot) yang bukaannya mencakup 'required'.
local function candidates(required: { number }): { Tile }
	local out: { Tile } = {}
	for _, kind in KINDS do
		for rot = 0, 3 do
			local open = openings(kind, rot)
			local ok = true
			for _, d in required do
				if not open[d] then
					ok = false
					break
				end
			end
			if ok then
				table.insert(out, { kind = kind, rot = rot })
			end
		end
	end
	return out
end

-- Tile minimal (I atau L) untuk dua bukaan; dipakai sebagai cadangan agar selalu bisa diacak.
local function minimalTile(a: number, b: number): Tile
	for _, kind in { "I", "L" } do
		for rot = 0, 3 do
			local open = openings(kind, rot)
			if open[a] and open[b] then
				return { kind = kind, rot = rot }
			end
		end
	end
	error("tidak mungkin")
end

function PipePuzzle.generate(rng: RNG.RNG, size: number?): Puzzle
	local n = size or 5
	assert(n >= 2, "ukuran puzzle minimal 2")
	local src: Cell = { row = rng:int(1, n), col = 1 }
	local tgt: Cell = { row = rng:int(1, n), col = n }
	local path = randomPath(rng, n, src, tgt)

	-- Bukaan wajib tiap sel jalur.
	local required: { { number } } = {}
	for i, cell in path do
		local req = {}
		if i == 1 then
			table.insert(req, W)
		else
			local prev = path[i - 1]
			for d = 1, 4 do
				if cell.row + DROW[d] == prev.row and cell.col + DCOL[d] == prev.col then
					table.insert(req, d)
				end
			end
		end
		if i == #path then
			table.insert(req, E)
		else
			local nxt = path[i + 1]
			for d = 1, 4 do
				if cell.row + DROW[d] == nxt.row and cell.col + DCOL[d] == nxt.col then
					table.insert(req, d)
				end
			end
		end
		required[i] = req
	end

	local tiles: { { Tile } } = {}
	local solution: { { number } } = {}
	for r = 1, n do
		tiles[r] = {}
		solution[r] = {}
		for c = 1, n do
			tiles[r][c] = { kind = KINDS[rng:int(1, 4)], rot = rng:int(0, 3) }
			solution[r][c] = tiles[r][c].rot
		end
	end
	for i, cell in path do
		local options = candidates(required[i])
		local pick = options[rng:int(1, #options)]
		tiles[cell.row][cell.col] = { kind = pick.kind, rot = pick.rot }
		solution[cell.row][cell.col] = pick.rot
	end

	local puzzle: Puzzle =
		{ size = n, tiles = tiles, source = src, target = tgt, solution = solution }

	-- Acak rotasi sampai belum terpecahkan. Setelah banyak percobaan gagal (jalur semua X),
	-- paksa tile source menjadi I/L yang sensitif rotasi.
	local attempts = 0
	repeat
		attempts += 1
		if attempts == 50 then
			local req = required[1]
			local m = minimalTile(req[1], req[2])
			tiles[src.row][src.col] = { kind = m.kind, rot = m.rot }
			solution[src.row][src.col] = m.rot
		end
		for r = 1, n do
			for c = 1, n do
				tiles[r][c].rot = rng:int(0, 3)
			end
		end
	until not PipePuzzle.isSolved(puzzle)

	return puzzle
end

return PipePuzzle
