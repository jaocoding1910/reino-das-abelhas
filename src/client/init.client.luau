--[[
	Bootstrap do cliente (StarterPlayerScripts.Client).

	O cliente cuida de entrada, câmera, voo local e interface.
	Ele só PEDE ações ao servidor pelos Remotes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loader = require(Shared.Util.Loader)

Loader.Run("Cliente", script.Controllers, {
	"InputController", -- A: teclado, mouse e botões de toque
	"FlightController", -- A: voo suave, subida e descida
	"CameraController", -- A: primeira pessoa confortável, patas discretas
	"InteractionController", -- A: segurar para coletar, entregar, construir
	"HUDController", -- A–E: painéis da interface, relógio e loja de melhorias
	"VisualController", -- favos girando, asas batendo, partículas
	"WorkerBeeController", -- abelhas operárias voando (só visual)
	"GuideController", -- trilha dourada até o objetivo (tecla G)
	"AudioController", -- E: asas, ambiente, alertas
})
