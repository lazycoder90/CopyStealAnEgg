local PipePuzzle = require("../../src/shared/Logic/PipePuzzle")
local RNG = require("../../src/shared/Logic/RNG")

local function manual(kinds, rots, source, target)
	local tiles = {}
	for r = 1, #kinds do
		tiles[r] = {}
		for c = 1, #kinds[r] do
			tiles[r][c] = { kind = kinds[r][c], rot = rots[r][c] }
		end
	end
	return { size = #kinds, tiles = tiles, source = source, target = target }
end

return function(t)
	-- Puzzle manual 3x3: garis lurus di baris 2 dari barat ke timur
	local p = manual({
		{ "L", "L", "L" },
		{ "I", "I", "I" },
		{ "L", "L", "L" },
	}, {
		{ 0, 0, 0 },
		{ 1, 1, 1 },
		{ 0, 0, 0 },
	}, { row = 2, col = 1 }, { row = 2, col = 3 })
	t.eq(PipePuzzle.isSolved(p), true, "garis lurus selesai")
	PipePuzzle.rotate(p, 2, 2)
	t.eq(p.tiles[2][2].rot, 2, "rotate +1")
	t.eq(PipePuzzle.isSolved(p), false, "I rot 2 = vertikal -> putus")
	PipePuzzle.rotate(p, 2, 2)
	t.eq(p.tiles[2][2].rot, 3, "rotate lagi")
	t.eq(PipePuzzle.isSolved(p), true, "I rot 3 = horizontal")
	PipePuzzle.rotate(p, 2, 2)
	t.eq(p.tiles[2][2].rot, 0, "rotate wrap")
	t.eq(PipePuzzle.isSolved(p), false, "rot 0 = vertikal -> putus")

	-- Source tanpa bukaan barat
	local q = manual(
		{ { "I", "I" }, { "I", "I" } },
		{ { 0, 0 }, { 0, 0 } },
		{ row = 1, col = 1 },
		{ row = 1, col = 2 }
	)
	t.eq(PipePuzzle.isSolved(q), false, "source tanpa W")

	-- Target tanpa bukaan timur
	local u = manual(
		{ { "L", "L" }, { "X", "X" } },
		{ { 1, 2 }, { 0, 0 } },
		{ row = 1, col = 1 },
		{ row = 1, col = 2 }
	)
	-- L rot1={E,S}: tidak ada W
	t.eq(PipePuzzle.isSolved(u), false, "L rot1 tidak punya W")
	local v = manual(
		{ { "T", "T" }, { "X", "X" } },
		{ { 3, 3 }, { 0, 0 } },
		{ row = 1, col = 1 },
		{ row = 1, col = 2 }
	)
	-- T rot3 = {W,N,E}: source W ok, E ok; target W,N,E -> terhubung, E terbuka
	t.eq(PipePuzzle.isSolved(v), true, "T-T terhubung")
	local w = manual(
		{ { "T", "L" }, { "X", "X" } },
		{ { 3, 2 }, { 0, 0 } },
		{ row = 1, col = 1 },
		{ row = 1, col = 2 }
	)
	-- L rot2 = {S,W}: terhubung dari barat, tapi tak ada E
	t.eq(PipePuzzle.isSolved(w), false, "target tanpa E")

	-- Generate
	local rng = RNG.new(31337)
	local allUnsolved, allSolvable, wellFormed = true, true, true
	for _ = 1, 200 do
		local puzzle = PipePuzzle.generate(rng)
		if puzzle.size ~= 5 or puzzle.source.col ~= 1 or puzzle.target.col ~= 5 then
			wellFormed = false
		end
		if PipePuzzle.isSolved(puzzle) then
			allUnsolved = false
		end
		local solved = PipePuzzle.applyRotations(puzzle, puzzle.solution :: any)
		if solved == nil or not PipePuzzle.isSolved(solved) then
			allSolvable = false
		end
	end
	t.truthy(wellFormed, "ukuran/source/target")
	t.truthy(allUnsolved, "200 puzzle awal belum selesai")
	t.truthy(allSolvable, "solusi menyelesaikan 200 puzzle")

	local small = PipePuzzle.generate(rng, 3)
	t.eq(small.size, 3, "ukuran kustom")
	t.eq(#small.tiles, 3, "baris")
	t.eq(
		PipePuzzle.isSolved(PipePuzzle.applyRotations(small, small.solution :: any) :: any),
		true,
		"3x3 solvable"
	)

	-- Deterministik
	local a, b = PipePuzzle.generate(RNG.new(5)), PipePuzzle.generate(RNG.new(5))
	local same = a.source.row == b.source.row and a.target.row == b.target.row
	for r = 1, 5 do
		for c = 1, 5 do
			if
				a.tiles[r][c].kind ~= b.tiles[r][c].kind
				or a.tiles[r][c].rot ~= b.tiles[r][c].rot
			then
				same = false
			end
		end
	end
	t.truthy(same, "generate deterministik")

	-- applyRotations: salinan dan validasi
	local puzzle = PipePuzzle.generate(rng)
	local sol = puzzle.solution :: { { number } }
	local copy = PipePuzzle.applyRotations(puzzle, sol) :: any
	t.truthy(copy ~= puzzle and copy.tiles ~= puzzle.tiles, "salinan")
	t.eq(copy.solution, nil, "salinan tanpa solusi")
	local function mut(f)
		local rots = {}
		for r = 1, 5 do
			rots[r] = table.clone(sol[r])
		end
		f(rots)
		return PipePuzzle.applyRotations(puzzle, rots)
	end
	t.eq(
		mut(function(r)
			r[1][1] = 4
		end),
		nil,
		"rot 4 ditolak"
	)
	t.eq(
		mut(function(r)
			r[2][2] = -1
		end),
		nil,
		"rot negatif ditolak"
	)
	t.eq(
		mut(function(r)
			r[3][3] = 1.5
		end),
		nil,
		"rot pecahan ditolak"
	)
	t.eq(
		mut(function(r)
			r[3][3] = "1"
		end),
		nil,
		"rot string ditolak"
	)
	t.eq(
		mut(function(r)
			r[3][3] = 0 / 0
		end),
		nil,
		"rot NaN ditolak"
	)
	t.eq(
		mut(function(r)
			r[5] = nil
		end),
		nil,
		"baris kurang ditolak"
	)
	t.eq(
		mut(function(r)
			r[1][5] = nil
		end),
		nil,
		"kolom kurang ditolak"
	)
	t.eq(
		mut(function(r)
			r[6] = { 0, 0, 0, 0, 0 }
		end),
		nil,
		"baris lebih ditolak"
	)
	t.eq(
		mut(function(r)
			r[1][6] = 0
		end),
		nil,
		"kolom lebih ditolak"
	)
	t.eq(PipePuzzle.applyRotations(puzzle, {} :: any), nil, "kosong ditolak")
	t.eq(PipePuzzle.applyRotations(puzzle, 5 :: any), nil, "bukan tabel ditolak")
	t.truthy(mut(function() end) ~= nil, "valid diterima")
end
