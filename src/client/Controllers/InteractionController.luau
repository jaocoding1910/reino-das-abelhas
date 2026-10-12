--!strict
--[[
	InteractionController (cliente)
	Etapa: A

	Detecta o recurso ou construção mais próximo e mostra o prompt de ação.

	A fazer:
	- Segurar E (ou botão) por Config.Collection.InteractTime e então pedir ao servidor.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Util.Log)

local InteractionController = {}

function InteractionController:Init()
	-- Preparar estado interno aqui.
end

function InteractionController:Start()
	Log.info("InteractionController", "pronto")
end

return InteractionController
