--[[
	ClanService (servidor) — colônias (clãs)

	Uma colônia é um grupo com nome, salvo no perfil de cada membro
	(profile.Clan). Quem entra no servidor volta para a colônia sozinho.
	- Criar: nome de 3 a 16 letras, passa pelo filtro de texto do Roblox
	  (obrigatório para texto que outros veem) e custa Config.Clan.CreateCost.
	- Entrar: em qualquer colônia que já tenha alguém neste servidor
	  (até Config.Clan.MaxMembers online).
	- Sair: a qualquer momento.

	Vantagens:
	- Membros da mesma colônia não se atacam na zona de disputa.
	- Com outro membro online, cada entrega rende +HoneyBonus de mel.
	- Plaquinha com o nome da colônia em cima da abelha.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local Notifier = require(script.Parent.Parent.Lib.Notifier)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ClanService = {}

local lastRequest: { [Player]: number } = {}

local function clanOf(player: Player): string
	if not PlayerDataService.IsLoaded(player) then
		return ""
	end
	return PlayerDataService.Get(player).Clan
end

-- Membros online de uma colônia (comparação sem diferenciar maiúsculas).
local function membersOf(name: string): { Player }
	local list = {}
	if name == "" then
		return list
	end
	local key = string.lower(name)
	for _, player in Players:GetPlayers() do
		if string.lower(clanOf(player)) == key then
			table.insert(list, player)
		end
	end
	return list
end

function ClanService.SameClan(a: Player, b: Player): boolean
	local clan = clanOf(a)
	return clan ~= "" and string.lower(clan) == string.lower(clanOf(b))
end

-- Outro membro da colônia está neste servidor? (bônus de mel)
function ClanService.HasOnlineMate(player: Player): boolean
	return #membersOf(clanOf(player)) >= 2
end

function ClanService.Summary(player: Player)
	local mine = clanOf(player)
	local members = {}
	for _, member in membersOf(mine) do
		table.insert(members, member.DisplayName)
	end
	local seen, list = {}, {}
	for _, other in Players:GetPlayers() do
		local clan = clanOf(other)
		local key = string.lower(clan)
		if clan ~= "" and not seen[key] then
			seen[key] = true
			table.insert(list, { Name = clan, Count = #membersOf(clan) })
		end
	end
	table.sort(list, function(a, b)
		return a.Count > b.Count
	end)
	return {
		Name = mine,
		Members = members,
		BonusActive = #members >= 2,
		Bonus = Config.Clan.HoneyBonus,
		CreateCost = Config.Clan.CreateCost,
		List = list,
	}
end

-- Plaquinha com o nome da colônia em cima da abelha (os outros veem).
local function updateTag(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local tag = root:FindFirstChild("TagColonia") :: BillboardGui?
	local clan = clanOf(player)
	if clan == "" then
		if tag then
			tag:Destroy()
		end
		return
	end
	if not tag then
		local gui = Instance.new("BillboardGui")
		gui.Name = "TagColonia"
		gui.Size = UDim2.fromScale(10, 1.6)
		gui.StudsOffset = Vector3.new(0, 4.5, 0)
		gui.MaxDistance = 120
		gui.LightInfluence = 0
		gui.PlayerToHideFrom = player
		local text = Instance.new("TextLabel")
		text.Name = "Texto"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBold
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(255, 205, 80)
		text.TextStrokeTransparency = 0.3
		text.Parent = gui
		gui.Parent = root
		tag = gui
	end
	local label = (tag :: BillboardGui):FindFirstChild("Texto") :: TextLabel
	label.Text = `[{clan}] {player.DisplayName}`
end

-- Todos veem a lista de colônias: avisa todo mundo quando algo muda.
local function changedForEveryone()
	for _, player in Players:GetPlayers() do
		updateTag(player)
		Notifier.Changed(player)
	end
end

local function filterName(player: Player, raw: string): (string?, string?)
	local name = string.gsub(raw, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	name = string.gsub(name, "%s+", " ")
	local length = utf8.len(name) or #name
	if length < Config.Clan.NameMin or length > Config.Clan.NameMax then
		return nil, `O nome precisa ter de {Config.Clan.NameMin} a {Config.Clan.NameMax} letras.`
	end
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(name, player.UserId)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		-- No Studio sem publicar o filtro pode não existir: libera só para testar.
		-- No jogo publicado o filtro é obrigatório.
		if RunService:IsStudio() then
			return name, nil
		end
		return nil, "Não deu para verificar o nome agora. Tente de novo."
	end
	if string.find(result, "#", 1, true) then
		return nil, "Esse nome não é permitido. Escolha outro."
	end
	return result, nil
end

local function handle(player: Player, action: unknown, value: unknown)
	local now = os.clock()
	if now - (lastRequest[player] or 0) < 1 then
		return
	end
	lastRequest[player] = now
	if typeof(action) ~= "string" or not PlayerDataService.IsLoaded(player) then
		return
	end
	local profile = PlayerDataService.Get(player)

	if action == "Sair" then
		if profile.Clan == "" then
			return
		end
		Notifier.Notify(player, `Você saiu da colônia {profile.Clan}.`, "info")
		profile.Clan = ""
		changedForEveryone()
		return
	end

	if typeof(value) ~= "string" or #value > 64 then
		return
	end
	if profile.Clan ~= "" then
		Notifier.Notify(player, "Saia da sua colônia antes de entrar em outra.", "erro")
		return
	end

	if action == "Criar" then
		if profile.Honey < Config.Clan.CreateCost then
			Notifier.Notify(player, `Criar uma colônia custa {Config.Clan.CreateCost} mel.`, "erro")
			return
		end
		local name, problem = filterName(player, value)
		if not name then
			Notifier.Notify(player, problem or "Nome inválido.", "erro")
			return
		end
		if #membersOf(name) > 0 then
			Notifier.Notify(
				player,
				"Já existe uma colônia com esse nome aqui. Entre nela pela lista!",
				"erro"
			)
			return
		end
		profile.Honey -= Config.Clan.CreateCost
		profile.Clan = name
		Notifier.Notify(player, `Colônia {name} fundada! 🐝`, "ok")
		changedForEveryone()
	elseif action == "Entrar" then
		local members = membersOf(value)
		if #members == 0 then
			Notifier.Notify(player, "Essa colônia não tem ninguém neste servidor.", "erro")
			return
		end
		if #members >= Config.Clan.MaxMembers then
			Notifier.Notify(player, "Essa colônia está cheia neste servidor.", "erro")
			return
		end
		-- Usa a grafia de quem já está lá (o nome já passou pelo filtro).
		profile.Clan = clanOf(members[1])
		Notifier.Notify(player, `Você entrou na colônia {profile.Clan}!`, "ok")
		for _, member in members do
			Notifier.Notify(member, `{player.DisplayName} entrou na colônia!`, "ok")
		end
		changedForEveryone()
	end
end

function ClanService:Init() end

function ClanService:Start()
	Remotes.Get("RequestClan").OnServerEvent:Connect(handle)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(1) -- espera o corpo de abelha ser montado
			updateTag(player)
		end)
		task.spawn(function()
			PlayerDataService.WaitForProfile(player)
			changedForEveryone()
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		task.defer(changedForEveryone)
	end)
	Log.info("ClanService", "pronto")
end

return ClanService
