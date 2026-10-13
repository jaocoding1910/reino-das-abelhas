--[[
	PlayerDataService (servidor) — perfil e salvamento (DataStore)

	O que é salvo: mel, pontos de favo, XP, melhorias, acessórios,
	título, nome da colônia e células da colmeia.
	O que NUNCA é salvo: a carga transportada.

	Regras de segurança:
	1. Carregar com novas tentativas (Config.Data.MaxRetries).
	2. Se TODAS falharem, a sessão fica SEM salvar: o jogador joga com um
	   perfil temporário, e o perfil verdadeiro no DataStore não é
	   sobrescrito com dados vazios. O jogador é avisado.
	3. Salvar ao sair, a cada Config.Data.AutosaveInterval e no fechamento
	   do servidor (game:BindToClose).
	4. Desconectar durante a expedição: a carga é perdida. Como carga não é
	   salva, sair e voltar nunca duplica recursos.

	Limitação conhecida (documentada): não há trava de sessão entre
	servidores. Entrar em outro servidor antes do salvamento terminar pode
	carregar dados alguns segundos antigos.

	No Studio: Arquivo → Publicar no Roblox, depois Configurações do jogo
	→ Segurança → "Permitir acesso do Studio aos serviços de API".
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Types = require(Shared.Types)

local Notifier = require(script.Parent.Parent.Lib.Notifier)

local PlayerDataService = {}

local store: DataStore? = nil
local profiles: { [Player]: Types.Profile } = {}
local canSave: { [Player]: boolean } = {}
local loaded = Instance.new("BindableEvent")

local function keyFor(player: Player): string
	return `jogador_{player.UserId}`
end

-- Preenche campos que faltam (perfis antigos) com os valores padrão.
function PlayerDataService.Migrate(data: any): Types.Profile
	local profile = Types.NewProfile()
	if type(data) ~= "table" then
		return profile
	end
	local target = profile :: any
	for key, default in pairs(target) do
		if type(data[key]) == type(default) and type(default) ~= "table" then
			target[key] = data[key]
		end
	end
	if type(data.Upgrades) == "table" then
		for name in pairs(profile.Upgrades) do
			if type(data.Upgrades[name]) == "number" then
				profile.Upgrades[name] = data.Upgrades[name]
			end
		end
	end
	for _, listName in { "Cosmetics", "EquippedCosmetics" } do
		if type(data[listName]) == "table" then
			local list = {}
			for _, item in data[listName] do
				if type(item) == "string" and Config.Cosmetics[item] then
					table.insert(list, item)
				end
			end
			target[listName] = list
		end
	end
	if type(data.Royal) == "table" then
		local r = data.Royal
		if type(r.Kind) == "string" and type(r.Goal) == "number" then
			profile.Royal = {
				Kind = r.Kind,
				Text = if type(r.Text) == "string" then r.Text else "",
				Goal = r.Goal,
				Progress = tonumber(r.Progress) or 0,
				Honey = tonumber(r.Honey) or 0,
				XP = tonumber(r.XP) or 0,
			}
		end
	end
	if type(data.Cells) == "table" then
		local cells = {}
		for _, cell in data.Cells do
			if type(cell) == "table" and type(cell.Slot) == "number" then
				table.insert(cells, {
					Slot = cell.Slot,
					Progress = math.clamp(tonumber(cell.Progress) or 0, 0, 100),
					Completed = cell.Completed == true,
				})
			end
		end
		profile.Cells = cells
	end
	if type(data.Specialty) == "string" then
		profile.Specialty = data.Specialty
	end
	profile.ProfileVersion = Types.PROFILE_VERSION
	return profile
end

local function withRetries(label: string, fn: () -> any): (boolean, any)
	local lastError = nil
	for attempt = 1, Config.Data.MaxRetries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		Log.warn("PlayerDataService", `{label} falhou (tentativa {attempt}):`, result)
		task.wait(attempt)
	end
	return false, lastError
end

local function load(player: Player)
	local profile: Types.Profile
	local ok, data = false, nil
	if store then
		ok, data = withRetries(`carregar {player.Name}`, function()
			return (store :: DataStore):GetAsync(keyFor(player))
		end)
	end

	if ok then
		profile = PlayerDataService.Migrate(data)
		canSave[player] = true
	else
		profile = Types.NewProfile()
		canSave[player] = false
		task.delay(6, function()
			Notifier.Notify(
				player,
				"Não foi possível carregar seu progresso. Esta sessão NÃO será salva (seu progresso antigo está seguro).",
				"erro"
			)
		end)
	end

	if profile.ColonyName == "Minha Colônia" then
		profile.ColonyName = `Colônia de {player.DisplayName}`
	end
	if not player.Parent then
		return
	end
	profiles[player] = profile
	loaded:Fire(player)
end

function PlayerDataService.Save(player: Player): boolean
	local profile = profiles[player]
	if not profile or not canSave[player] or not store then
		return false
	end
	local ok = withRetries(`salvar {player.Name}`, function()
		return (store :: DataStore):UpdateAsync(keyFor(player), function()
			return profile
		end)
	end)
	return ok
end

-- Perfil do jogador. Antes de carregar, devolve um perfil padrão só para
-- leitura (não guardado), para ninguém quebrar nos primeiros segundos.
function PlayerDataService.Get(player: Player): Types.Profile
	return profiles[player] or Types.NewProfile()
end

function PlayerDataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Espera o perfil carregar (ou o jogador sair). Retorna nil se saiu.
function PlayerDataService.WaitForProfile(player: Player): Types.Profile?
	while player.Parent and not profiles[player] do
		loaded.Event:Wait()
	end
	return profiles[player]
end

function PlayerDataService:Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.DataStoreName)
	end)
	if ok then
		store = result
	else
		Log.warn("PlayerDataService", "DataStore indisponível; nada será salvo:", result)
	end
end

function PlayerDataService:Start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataService.Save(player)
		profiles[player] = nil
		canSave[player] = nil
	end)

	-- Autosave.
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveInterval)
			for player in profiles do
				task.spawn(PlayerDataService.Save, player)
			end
		end
	end)

	-- Servidor fechando: salva todo mundo em paralelo e espera terminar.
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				PlayerDataService.Save(player)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)

	Log.info("PlayerDataService", if store then "pronto (DataStore)" else "pronto (sem DataStore)")
end

return PlayerDataService
