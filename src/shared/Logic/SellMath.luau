--!strict
-- Hitung nilai jual, filter, dan urutan untuk panel Sell (murni; server menghitung ulang semuanya).

local Creatures = require("../Config/Creatures")
local PetMath = require("./PetMath")

export type Item = {
	uid: string,
	id: string,
	kg: number,
	muts: { string },
	value: number,
	income: number,
	rarity: number,
	name: string,
}

local SellMath = {}

function SellMath.eggValue(id: string, kg: number, muts: { string }?): number
	return PetMath.sellEggValue(id, kg, muts or {})
end

function SellMath.petValue(id: string, kg: number, muts: { string }?): number
	return PetMath.sellPetValue(id, kg, muts or {})
end

-- Pet boleh dijual jika tidak aktif dan tidak terkunci.
function SellMath.petSellable(pet: any): boolean
	return pet ~= nil and pet.eq ~= true and pet.lock ~= true
end

-- Telur boleh dijual jika di kantong, atau ditaruh dan tidak sedang dibekukan (dicuri).
function SellMath.eggSellable(egg: any, frozen: boolean): boolean
	if egg == nil or frozen then
		return false
	end
	return egg.loc == "pocket" or egg.loc == "placed"
end

-- Nilai satu item menurut jenisnya.
function SellMath.value(kind: string, item: any): number
	if kind == "eggs" then
		return SellMath.eggValue(item.id, item.kg, item.muts)
	end
	return SellMath.petValue(item.id, item.kg, item.muts)
end

-- Total nilai daftar item {id, kg, muts}.
function SellMath.total(kind: string, items: { any }): number
	local sum = 0
	for _, item in items do
		sum += SellMath.value(kind, item)
	end
	return sum
end

-- Membangun daftar item yang bisa dijual dari tabel data (uid -> data).
-- isFrozen(uid) opsional (klien tidak tahu: nil dianggap tidak beku).
function SellMath.list(kind: string, collection: any, isFrozen: ((string) -> boolean)?): { Item }
	local out = {}
	for uid, entry in collection or {} do
		local sellable
		if kind == "eggs" then
			sellable = SellMath.eggSellable(entry, isFrozen ~= nil and isFrozen(uid))
		else
			sellable = SellMath.petSellable(entry)
		end
		local creature = if sellable then Creatures.byId[entry.id] else nil
		if creature then
			local muts = entry.muts or {}
			table.insert(out, {
				uid = uid,
				id = entry.id,
				kg = entry.kg,
				muts = muts,
				value = SellMath.value(kind, entry),
				income = PetMath.petIncome(entry.id, entry.kg, muts),
				rarity = creature.rarity,
				name = creature.name,
			})
		end
	end
	return out
end

-- Urutkan berdasarkan "weight" atau "value"; asc = naik. Tie-break: uid (deterministik).
function SellMath.sort(list: { Item }, by: string, ascending: boolean)
	table.sort(list, function(a, b)
		local av, bv
		if by == "weight" then
			av, bv = a.kg, b.kg
		else
			av, bv = a.value, b.value
		end
		if av ~= bv then
			if ascending then
				return av < bv
			end
			return av > bv
		end
		return a.uid < b.uid
	end)
end

-- Ada item terpilih dengan rarity >= minRarity? selected = { [uid] = true }.
function SellMath.hasValuable(
	list: { Item },
	selected: { [string]: boolean },
	minRarity: number
): boolean
	for _, item in list do
		if selected[item.uid] and item.rarity >= minRarity then
			return true
		end
	end
	return false
end

-- Total dan jumlah item terpilih.
function SellMath.selectedTotals(list: { Item }, selected: { [string]: boolean }): (number, number)
	local sum, count = 0, 0
	for _, item in list do
		if selected[item.uid] then
			sum += item.value
			count += 1
		end
	end
	return sum, count
end

-- Filter nama (huruf kecil, substring); query kosong = semua.
function SellMath.matches(name: string, query: string): boolean
	if query == "" then
		return true
	end
	return string.find(string.lower(name), string.lower(query), 1, true) ~= nil
end

return SellMath
