--!nonstrict
-- Helper pembuat UI deklaratif:
--   UIBuilder.create("TextLabel", { Name = "Cash", Text = "$0", [UIBuilder.Children] = { ... } })
-- Properti biasa langsung diset; key khusus Children berisi daftar anak; Parent diset terakhir.

local UIBuilder = {}

UIBuilder.Children = {} -- tabel unik dipakai sebagai key khusus

function UIBuilder.create(className: string, props: { [any]: any }?, children: { Instance }?)
	local instance = Instance.new(className)
	local parent
	local kids = children

	for key, value in props or {} do
		if key == UIBuilder.Children then
			kids = value
		elseif key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end

	for _, child in kids or {} do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

return UIBuilder
