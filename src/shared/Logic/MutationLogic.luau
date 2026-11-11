--!strict
-- Aturan mutasi (docs/PLAN.md §1.4): mult ditambahkan, maksimal 3, tanpa duplikat.

local Mutations = require("../Config/Mutations")
local RNG = require("./RNG")

local MutationLogic = {}

function MutationLogic.mult(muts: { string }): number
	local total = 1
	for _, name in muts do
		local m = Mutations.list[name]
		if m then
			total += m.mult - 1
		end
	end
	return total
end

function MutationLogic.canAdd(muts: { string }, name: string): boolean
	if Mutations.list[name] == nil or #muts >= Mutations.maxPerItem then
		return false
	end
	return table.find(muts, name) == nil
end

function MutationLogic.add(muts: { string }, name: string): { string }
	local copy = table.clone(muts)
	if MutationLogic.canAdd(muts, name) then
		table.insert(copy, name)
	end
	return copy
end

function MutationLogic.rollOnHatch(rng: RNG.RNG, luckMult: number?): { string }
	local luck = luckMult or 1
	local result = {}
	for _, name in Mutations.order do
		local chance = Mutations.list[name].hatchChance
		if chance ~= nil and #result < Mutations.maxPerItem and rng:chance(chance * luck) then
			table.insert(result, name)
		end
	end
	return result
end

function MutationLogic.format(muts: { string }): string
	return table.concat(muts, " + ")
end

return MutationLogic
