--!nonstrict
-- Akses karakter/root berdasarkan userId, baik pemain nyata maupun bot uji (pemain virtual).

local Players = game:GetService("Players")

local Actors = {}

local bots = {} -- [userId] = Model

function Actors.registerBot(userId: number, model: Model)
	bots[userId] = model
end

function Actors.unregisterBot(userId: number)
	bots[userId] = nil
end

function Actors.isBot(userId: number): boolean
	return bots[userId] ~= nil
end

function Actors.getPlayer(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

function Actors.getCharacter(userId: number): Model?
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player.Character
	end
	return bots[userId]
end

function Actors.getRoot(userId: number): BasePart?
	local character = Actors.getCharacter(userId)
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return character.PrimaryPart
end

function Actors.getHumanoid(userId: number): Humanoid?
	local character = Actors.getCharacter(userId)
	return character and character:FindFirstChildOfClass("Humanoid")
end

function Actors.getName(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player.Name
	end
	local bot = bots[userId]
	return bot and bot.Name or `User{userId}`
end

return Actors
