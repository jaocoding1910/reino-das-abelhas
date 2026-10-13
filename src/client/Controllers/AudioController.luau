--[[
	AudioController (cliente)

	Sons do jogo, todos configurados em Config.Sounds:
	- Asas: zumbido em loop; volume e tom acompanham a velocidade do voo.
	- AmbienteDia / AmbienteNoite: loops que trocam suavemente com o ciclo.
	- Coleta, Entrega, Nivel, Dano: tocam com os eventos do servidor (Effect).
	- Clique: qualquer botão da interface.

	Os IDs começam VAZIOS de propósito: o projeto não inclui áudios de
	terceiros. Para ligar um som, cole o ID de um áudio que você tem direito
	de usar (Toolbox → Áudio, ou um áudio enviado por você) em Config.Sounds,
	por exemplo Asas = "rbxassetid://1234567890". Som vazio = silêncio, sem erro.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local FlightController = require(script.Parent.FlightController)

local AudioController = {}

local player = Players.LocalPlayer
local sounds: { [string]: Sound } = {}

local VOLUMES = {
	Asas = 0.35,
	Coleta = 0.6,
	Entrega = 0.7,
	Nivel = 0.8,
	Dano = 0.7,
	Clique = 0.4,
	AmbienteDia = 0.3,
	AmbienteNoite = 0.3,
}
local LOOPS = { Asas = true, AmbienteDia = true, AmbienteNoite = true }

local EFFECT_SOUNDS = {
	coleta = "Coleta",
	entrega = "Entrega",
	nivel = "Nivel",
	dano = "Dano",
}

local function normalize(id: string): string
	if id == "" then
		return ""
	end
	if string.match(id, "^%d+$") then
		return "rbxassetid://" .. id
	end
	return id
end

local function create(name: string): Sound?
	local id = normalize((Config.Sounds :: any)[name] or "")
	if id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = if LOOPS[name] then 0 else VOLUMES[name] or 0.5
	sound.Looped = LOOPS[name] == true
	sound.Parent = SoundService
	sounds[name] = sound
	return sound
end

function AudioController.Play(name: string)
	local sound = sounds[name]
	if sound then
		-- Pequena variação de tom para não cansar o ouvido.
		sound.PlaybackSpeed = 0.94 + math.random() * 0.12
		sound:Play()
	end
end

local function hookButtons(gui: Instance)
	local function hook(item: Instance)
		if item:IsA("GuiButton") then
			item.Activated:Connect(function()
				AudioController.Play("Clique")
			end)
		end
	end
	for _, item in gui:GetDescendants() do
		hook(item)
	end
	gui.DescendantAdded:Connect(hook)
end

function AudioController:Init()
	local count = 0
	for name in VOLUMES do
		if create(name) then
			count += 1
		end
	end
	Log.info("AudioController", `{count} sons configurados`)
end

function AudioController:Start()
	Remotes.Get("Effect").OnClientEvent:Connect(function(kind, _position, userId)
		local name = EFFECT_SOUNDS[kind]
		if name and userId == player.UserId then
			AudioController.Play(name)
		end
	end)

	if sounds.Clique then
		hookButtons(player:WaitForChild("PlayerGui"))
	end

	for _, loop in { "Asas", "AmbienteDia", "AmbienteNoite" } do
		local sound = sounds[loop]
		if sound then
			sound:Play()
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		local k = math.clamp(dt * 3, 0, 1)
		local wings = sounds.Asas
		if wings then
			local speed = FlightController.State.SpeedFraction
			local target = VOLUMES.Asas * (0.35 + 0.65 * math.clamp(speed, 0, 1.5) / 1.5)
			wings.Volume += (target - wings.Volume) * k
			wings.PlaybackSpeed = 0.9 + 0.35 * math.clamp(speed, 0, 1.5) / 1.5
		end
		local night = workspace:GetAttribute("IsNight") == true
		local day, nightSound = sounds.AmbienteDia, sounds.AmbienteNoite
		if day then
			day.Volume += ((if night then 0 else VOLUMES.AmbienteDia) - day.Volume) * k * 0.3
		end
		if nightSound then
			nightSound.Volume += ((if night then VOLUMES.AmbienteNoite else 0) - nightSound.Volume) * k * 0.3
		end
	end)
	Log.info("AudioController", "pronto")
end

return AudioController
