--!nonstrict
-- Pembuat model placeholder gaya blok dari bentuk dasar (dipakai server untuk telur/guardian dan
-- klien untuk pet). Jika kelak ada aset final di ReplicatedStorage.Assets, fungsi make* akan memakainya
-- (Assets.Creatures/<id>, Assets.Eggs/<id>) dan jatuh ke placeholder bila tidak ada.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(script.Parent.Config.Rarities)
local Types = require(script.Parent.Types)

local ModelFactory = {}

local Attr = Types.Attr

function ModelFactory.rarityColor(rarity: number): Color3
	local rgb = Rarities.get(rarity).rgb
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- Warna stabil per spesies (hash id -> hue), pastel.
function ModelFactory.speciesColor(id: string, saturation: number?, value: number?): Color3
	local h = 7
	for i = 1, #id do
		h = (h * 31 + string.byte(id, i)) % 360
	end
	return Color3.fromHSV(h / 360, saturation or 0.45, value or 0.95)
end

local MUTATION_TINT = {
	Pearl = Color3.fromRGB(240, 240, 255),
	Amber = Color3.fromRGB(255, 176, 60),
	Starlit = Color3.fromRGB(150, 130, 255),
	Moonlit = Color3.fromRGB(150, 190, 255),
	Orbital = Color3.fromRGB(110, 230, 200),
	Prism = Color3.fromRGB(255, 130, 220),
}

local function newPart(
	model: Model,
	name: string,
	size: Vector3,
	color: Color3,
	props: { [string]: any }?
)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props or {} do
		part[k] = v
	end
	part.Parent = model
	return part
end

local function addSphereMesh(part: BasePart)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

-- Diameter telur (stud) dari berat.
function ModelFactory.eggDiameter(kg: number): number
	return math.clamp(1.6 + (math.max(kg, 0) ^ (1 / 3)) * 0.55, 1.6, 7)
end

-- Telur: badan elips + bintik warna aksen zona. Model tidak ter-scale; pakai setEggScale.
-- creature: Config/Creatures entry. Atribut identitas diberi oleh pemanggil.
function ModelFactory.makeEgg(creature, kg: number, accent: Color3?): Model
	local model = Instance.new("Model")
	model.Name = "Egg"

	local d = ModelFactory.eggDiameter(kg)
	local base = ModelFactory.speciesColor(creature.id, 0.35, 1)
	local body = newPart(model, "Body", Vector3.new(d, d * 1.25, d), base)
	addSphereMesh(body)
	model.PrimaryPart = body

	local spotColor = accent or ModelFactory.rarityColor(creature.rarity)
	local offsets = {
		Vector3.new(0.32, 0.18, 0.4),
		Vector3.new(-0.38, 0.05, 0.36),
		Vector3.new(0.05, -0.28, 0.46),
		Vector3.new(-0.1, 0.4, -0.38),
	}
	for i, o in offsets do
		local spot =
			newPart(model, "Spot" .. i, Vector3.new(d * 0.22, d * 0.22, d * 0.22), spotColor)
		addSphereMesh(spot)
		spot.CFrame = body.CFrame * CFrame.new(o.X * d * 0.9, o.Y * d * 1.1, o.Z * d * 0.9)
		weld(body, spot)
	end

	if creature.rarity >= 5 then
		local light = Instance.new("PointLight")
		light.Color = ModelFactory.rarityColor(creature.rarity)
		light.Range = 8 + creature.rarity
		light.Brightness = 1.5
		light.Parent = body
	end

	body:SetAttribute(Attr.Rarity, creature.rarity)
	return model
end

-- Skala 0..1+ menurut progres tumbuh; dipanggil berulang (aman).
function ModelFactory.setEggScale(model: Model, scale: number)
	if model.PrimaryPart then
		model:ScaleTo(math.max(scale, 0.05))
	end
end

-- Makhluk/pet: badan + kepala + mata + telinga + ekor. Semua Anchored (digerakkan lewat PivotTo).
function ModelFactory.makeCreature(creature, kg: number, muts: { string }?): Model
	local model = Instance.new("Model")
	model.Name = creature.name

	local s = math.clamp(0.9 * (math.max(kg, 0.05) ^ (1 / 3)), 0.9, 6)
	local color = ModelFactory.speciesColor(creature.id, 0.5, 0.95)
	if muts and #muts > 0 and MUTATION_TINT[muts[1]] then
		color = color:Lerp(MUTATION_TINT[muts[1]], 0.45)
	end
	local dark = Color3.new(color.R * 0.55, color.G * 0.55, color.B * 0.55)

	local body = newPart(model, "Body", Vector3.new(s * 1.2, s * 0.9, s * 1.7), color)
	model.PrimaryPart = body
	local head = newPart(model, "Head", Vector3.new(s * 0.95, s * 0.85, s * 0.9), color)
	head.CFrame = body.CFrame * CFrame.new(0, s * 0.45, -s * 1.05)
	weld(body, head)
	for _, side in { -1, 1 } do
		local eye = newPart(
			model,
			"Eye",
			Vector3.new(s * 0.16, s * 0.2, s * 0.1),
			Color3.fromRGB(25, 25, 30)
		)
		eye.CFrame = head.CFrame * CFrame.new(side * s * 0.25, s * 0.08, -s * 0.46)
		weld(head, eye)
		local ear = newPart(model, "Ear", Vector3.new(s * 0.28, s * 0.4, s * 0.2), dark)
		ear.CFrame = head.CFrame * CFrame.new(side * s * 0.34, s * 0.58, 0)
		weld(head, ear)
	end
	local tail = newPart(model, "Tail", Vector3.new(s * 0.25, s * 0.25, s * 0.6), dark)
	tail.CFrame = body.CFrame * CFrame.new(0, s * 0.15, s * 1.1)
	weld(body, tail)

	body:SetAttribute(Attr.Rarity, creature.rarity)
	return model
end

-- Mencari aset final (jika ada) lalu menyalinnya; nil bila tidak ada.
function ModelFactory.findAsset(category: string, id: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(category)
	local found = folder and folder:FindFirstChild(id)
	if found and found:IsA("Model") then
		return found:Clone()
	end
	return nil
end

return ModelFactory
