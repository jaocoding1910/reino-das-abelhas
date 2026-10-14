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

	5. Trava de sessão: o perfil salvo guarda {_Sessao = {Job, At}}. Outro
	   servidor só carrega para escrita quando a trava é deste servidor, está
	   vencida (Config.Data.SessionLockSeconds) ou foi liberada ao sair.
	   Se a outra sessão não liberar a tempo, o jogador entra SEM salvar e é
	   avisado — o perfil verdadeiro nunca é sobrescrito por uma cópia velha.
	   Ao salvar, se outra sessão tomou a trava, este servidor para de salvar.

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
-- Valida configurações vindas do save ou do cliente (nunca confiar no formato).
function PlayerDataService.CleanSettings(raw: any, base: Types.Settings): Types.Settings
	local out = table.clone(base)
	if type(raw) ~= "table" then
		return out
	end
	for _, key in { "Music", "Trail", "CameraRoll", "ThirdPerson", "ReducedMotion" } do
		if type(raw[key]) == "boolean" then
			(out :: any)[key] = raw[key]
		end
	end
	if type(raw.Sfx) == "number" and raw.Sfx == raw.Sfx then
		out.Sfx = math.clamp(raw.Sfx, 0, 1)
	end
	if type(raw.MusicLevel) == "number" and raw.MusicLevel == raw.MusicLevel then
		out.MusicLevel = math.clamp(raw.MusicLevel, 0, 1)
	end
	if type(raw.Sensitivity) == "number" and raw.Sensitivity == raw.Sensitivity then
		out.Sensitivity = math.clamp(raw.Sensitivity, 0.25, 3)
	end
	if raw.Quality == "Alta" or raw.Quality == "Media" or raw.Quality == "Baixa" then
		out.Quality = raw.Quality
	end
	return out
end

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
	if type(data.Stats) == "table" then
		for _, key in Config.StatKeys do
			if type(data.Stats[key]) == "number" then
				profile.Stats[key] = data.Stats[key]
			end
		end
	end
	if type(data.Achievements) == "table" then
		for _, info in Config.Achievements do
			if data.Achievements[info.Id] == true then
				profile.Achievements[info.Id] = true
			end
		end
	end
	if type(data.Pets) == "table" then
		for _, id in data.Pets do
			if type(id) == "string" and Config.Pets[id] and not table.find(profile.Pets, id) then
				table.insert(profile.Pets, id)
			end
		end
	end
	if not table.find(profile.Pets, profile.EquippedPet) then
		profile.EquippedPet = ""
	end
	if type(data.Codes) == "table" then
		for code in Config.Codes do
			if data.Codes[code] == true then
				profile.Codes[code] = true
			end
		end
	end
	if type(data.Chests) == "table" then
		for id, at in data.Chests do
			if type(id) == "string" and type(at) == "number" then
				profile.Chests[id] = at
			end
		end
	end
	if
		type(data.Daily) == "table"
		and type(data.Daily.Day) == "number"
		and type(data.Daily.List) == "table"
	then
		local list = {}
		for _, q in data.Daily.List do
			if type(q) == "table" and type(q.Kind) == "string" and type(q.Goal) == "number" then
				table.insert(list, {
					Kind = q.Kind,
					Text = if type(q.Text) == "string" then q.Text else "",
					Goal = q.Goal,
					Progress = tonumber(q.Progress) or 0,
					Honey = tonumber(q.Honey) or 0,
					Done = q.Done == true,
				})
			end
		end
		profile.Daily = { Day = data.Daily.Day, List = list }
	end
	profile.Workers = math.clamp(math.floor(profile.Workers), 0, Config.Workers.Max)
	profile.Rebirths = math.max(0, math.floor(profile.Rebirths))
	if type(data.Settings) == "table" then
		profile.Settings = PlayerDataService.CleanSettings(data.Settings, profile.Settings)
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

local function lockIsForeign(raw: any): boolean
	if type(raw) ~= "table" or type(raw._Sessao) ~= "table" then
		return false
	end
	local lock = raw._Sessao
	local at = tonumber(lock.At) or 0
	return lock.Job ~= game.JobId and os.time() - at < Config.Data.SessionLockSeconds
end

-- Lê o perfil e marca a trava desta sessão numa única operação atômica.
local function acquire(player: Player): (boolean, any, boolean)
	local locked = false
	local data = nil
	local ok, err = withRetries(`carregar {player.Name}`, function()
		locked = false
		return (store :: DataStore):UpdateAsync(keyFor(player), function(old)
			if lockIsForeign(old) then
				locked = true
				return nil -- não escreve nada
			end
			data = old
			local out = if type(old) == "table" then table.clone(old) else {}
			out._Sessao = { Job = game.JobId, At = os.time() }
			return out
		end)
	end)
	if not ok then
		Log.warn("PlayerDataService", "falha ao carregar:", err)
	end
	return ok, data, locked
end

local function load(player: Player)
	local profile: Types.Profile
	local ok, data = false, nil
	local lockedElsewhere = false
	if store then
		for attempt = 1, Config.Data.SessionWaitAttempts do
			local locked
			ok, data, locked = acquire(player)
			lockedElsewhere = ok and locked
			if not lockedElsewhere or not player.Parent then
				break
			end
			Log.warn(
				"PlayerDataService",
				`{player.Name}: perfil aberto em outro servidor (tentativa {attempt})`
			)
			task.wait(5)
		end
		if lockedElsewhere then
			ok = false
		end
	end

	if ok then
		profile = PlayerDataService.Migrate(data)
		canSave[player] = true
	else
		profile = Types.NewProfile()
		canSave[player] = false
		task.delay(6, function()
			local message = if lockedElsewhere
				then "Seu perfil ainda está aberto em outro servidor. Esta sessão NÃO será salva (seu progresso está seguro)."
				elseif
					store
				then "Não foi possível carregar seu progresso. Esta sessão NÃO será salva (seu progresso antigo está seguro)."
				else "MODO TESTE: sem DataStore (Studio sem acesso à API). Nada desta sessão será salvo."
			Notifier.Notify(player, message, "erro")
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

-- `release` = true ao sair: grava e libera a trava para outro servidor.
function PlayerDataService.Save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile or not canSave[player] or not store then
		return false
	end
	local stolen = false
	local ok = withRetries(`salvar {player.Name}`, function()
		stolen = false
		return (store :: DataStore):UpdateAsync(keyFor(player), function(old)
			if lockIsForeign(old) then
				stolen = true
				return nil -- outra sessão é a dona agora: não sobrescreve
			end
			local out = table.clone(profile) :: any
			out._Sessao = if release then nil else { Job = game.JobId, At = os.time() }
			return out
		end)
	end)
	if stolen then
		canSave[player] = false
		Log.warn(
			"PlayerDataService",
			`{player.Name}: outra sessão assumiu o perfil; este servidor parou de salvar`
		)
		return false
	end
	return ok
end

-- Perfil do jogador. Antes de carregar, devolve um perfil padrão só para
-- leitura (não guardado), para ninguém quebrar nos primeiros segundos.
function PlayerDataService.Get(player: Player): Types.Profile
	return profiles[player] or Types.NewProfile()
end

-- Este perfil está sendo salvo de verdade? (false = modo de teste)
function PlayerDataService.CanSave(player: Player): boolean
	return canSave[player] == true and store ~= nil
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
		PlayerDataService.Save(player, true)
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
				PlayerDataService.Save(player, true)
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
