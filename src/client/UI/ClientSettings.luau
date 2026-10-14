--[[
	ClientSettings — configurações do jogador no cliente.

	Começa com Config.DefaultSettings e é atualizado pelo estado que o
	servidor manda (state.Settings, salvo no perfil). Os controladores leem
	ClientSettings.Get().X e podem ouvir ClientSettings.Changed.
	Para mudar: ClientSettings.Set("Music", false) — aplica na hora e pede
	ao servidor para salvar.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local ClientSettings = {}

local current: { [string]: any } = table.clone(Config.DefaultSettings)
local changed = Instance.new("BindableEvent")
ClientSettings.Changed = changed.Event

local started = false
local pendingSave = false

function ClientSettings.Get(): { [string]: any }
	return current
end

local function apply(new: { [string]: any })
	local any = false
	for key, value in new do
		if Config.DefaultSettings[key] ~= nil and current[key] ~= value then
			current[key] = value
			any = true
		end
	end
	if any then
		changed:Fire(current)
	end
end

function ClientSettings.Set(key: string, value: any)
	apply({ [key] = value })
	-- Junta várias mudanças seguidas num só pedido ao servidor.
	if not pendingSave then
		pendingSave = true
		task.delay(0.8, function()
			pendingSave = false
			Remotes.Get("RequestSettings"):FireServer(current)
		end)
	end
end

function ClientSettings.Start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local ok, state = pcall(function()
			return Remotes.GetFunction("GetInitialState"):InvokeServer()
		end)
		if ok and type(state) == "table" and type(state.Settings) == "table" then
			apply(state.Settings)
		end
	end)
	Remotes.Get("StateUpdated").OnClientEvent:Connect(function(state)
		if type(state) == "table" and type(state.Settings) == "table" and not pendingSave then
			apply(state.Settings)
		end
	end)
end

return ClientSettings
