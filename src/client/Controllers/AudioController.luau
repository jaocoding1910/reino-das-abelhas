--!strict
--[[
	AudioController (cliente)
	Etapa: E

	Som de asas, ambiente diurno/noturno e alertas de predadores.

	A fazer:
	- Usar assets licenciados ou placeholders identificados.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Util.Log)

local AudioController = {}

function AudioController:Init()
	-- Preparar estado interno aqui.
end

function AudioController:Start()
	Log.info("AudioController", "pronto")
end

return AudioController
