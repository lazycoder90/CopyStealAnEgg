local Check = require("../../src/shared/Util/Check")

return function(t)
	t.eq(Check.finite(1), true, "finite 1")
	t.eq(Check.finite(0 / 0), false, "NaN")
	t.eq(Check.finite(math.huge), false, "inf")
	t.eq(Check.finite(-math.huge), false, "-inf")
	t.eq(Check.finite("1"), false, "string bukan finite")

	local int = Check.int(1, 5)
	t.eq(int(3), true, "int 3")
	t.eq(int(3.5), false, "int pecahan")
	t.eq(int(0), false, "int di bawah min")
	t.eq(int(6), false, "int di atas max")
	t.eq(int(0 / 0), false, "int NaN")

	local num = Check.num(0, 1)
	t.eq(num(0.5), true, "num ok")
	t.eq(num(2), false, "num di luar")

	t.eq(Check.bool(true), true, "bool")
	t.eq(Check.bool(1), false, "bool salah tipe")

	local str = Check.str(3)
	t.eq(str("abc"), true, "str ok")
	t.eq(str("abcd"), false, "str kepanjangan")

	t.eq(Check.uid("moss_pup"), true, "uid id spesies")
	t.eq(Check.uid("a1-B2_c3"), true, "uid guid")
	t.eq(Check.uid(""), false, "uid kosong")
	t.eq(Check.uid("bad id"), false, "uid spasi")
	t.eq(Check.uid(string.rep("a", 41)), false, "uid kepanjangan")
	t.eq(Check.uid(5), false, "uid bukan string")

	local enum = Check.enum({ "a", "b" })
	t.eq(enum("a"), true, "enum ok")
	t.eq(enum("c"), false, "enum tidak ada")

	-- args
	local v = Check.args(Check.uid, Check.int(1, 10), Check.optional(Check.bool))
	t.eq(v("egg1", 5), true, "args tanpa opsional")
	t.eq(v("egg1", 5, true), true, "args dengan opsional")
	t.eq(v("egg1", 5, nil), true, "args opsional nil")
	t.eq(v("egg1", 5, "x"), false, "args opsional salah tipe")
	t.eq(v("egg1"), false, "args kurang")
	t.eq(v("egg1", 5, true, 9), false, "args kelebihan ditolak")
	t.eq(v("bad id", 5), false, "args elemen salah")
	t.eq(Check.args()(), true, "args kosong ok")
	t.eq(Check.args()(1), false, "args kosong tolak ekstra")
end
