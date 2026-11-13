--!nonstrict
-- Uji peta: tidak ada permukaan atas sebidang yang saling tumpang tindih (penyebab z-fighting/kedip),
-- lantai Coop selalu di atas lantai hub.
-- Jalankan: ServerStorage.TestBridge:Invoke("test.run", "Map")

local Tolerance = 0.03
local MinOverlap = 0.5 -- stud persegi

local function axisAligned(p: BasePart): boolean
	local c = p.CFrame
	local function ok(v: Vector3)
		return math.abs(v.Y) < 1e-3 or math.abs(v.Y - 1) < 1e-3 or math.abs(v.Y + 1) < 1e-3
	end
	return ok(c.RightVector) and ok(c.LookVector) and math.abs(c.UpVector.Y) > 0.999
end

local function topAndFootprint(p: BasePart)
	local half = p.Size / 2
	return p.Position.Y + half.Y,
		p.Position.X - half.X,
		p.Position.X + half.X,
		p.Position.Z - half.Z,
		p.Position.Z + half.Z
end

local function collect(root: Instance, out)
	for _, d in root:GetDescendants() do
		if
			d:IsA("Part")
			and d.Shape == Enum.PartType.Block
			and d.Transparency < 1
			and axisAligned(d)
		then
			table.insert(out, d)
		end
	end
end

return function(T)
	local parts = {}
	for _, name in { "Map", "Plots" } do
		local root = workspace:FindFirstChild(name)
		T.check("folder " .. name .. " ada", root ~= nil)
		if root then
			collect(root, parts)
		end
	end

	local bad = {}
	for i = 1, #parts do
		local a = parts[i]
		local aTop, ax0, ax1, az0, az1 = topAndFootprint(a)
		for j = i + 1, #parts do
			local b = parts[j]
			local bTop, bx0, bx1, bz0, bz1 = topAndFootprint(b)
			if math.abs(aTop - bTop) < Tolerance then
				local ox = math.min(ax1, bx1) - math.max(ax0, bx0)
				local oz = math.min(az1, bz1) - math.max(az0, bz0)
				if ox > 0 and oz > 0 and ox * oz > MinOverlap then
					table.insert(bad, a:GetFullName() .. " x " .. b:GetFullName())
				end
			end
		end
	end
	T.check(
		"tidak ada permukaan atas sebidang tumpang tindih",
		#bad == 0,
		table.concat(bad, "; ", 1, math.min(#bad, 5))
	)

	local hub = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("HubFloor")
	local plots = workspace:FindFirstChild("Plots")
	if hub and plots then
		local hubTop = hub.Position.Y + hub.Size.Y / 2
		for _, plot in plots:GetChildren() do
			local floor = plot.PrimaryPart
			if floor then
				T.check(
					plot.Name .. " lantai >= 0.1 di atas hub",
					floor.Position.Y + floor.Size.Y / 2 - hubTop >= 0.1
				)
			end
		end
	end
end
