--[[
	Bootstrap do cliente (StarterPlayerScripts.Client).

	O cliente cuida de entrada, câmera, voo local e interface.
	Ele só PEDE ações ao servidor pelos Remotes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loader = require(Shared.Util.Loader)

-- Configurações do jogador (som, trilha, qualidade): começam antes de tudo.
require(script.UI.ClientSettings).Start()

Loader.Run("Cliente", script.Controllers, {
	"InputController", -- A: teclado, mouse e botões de toque
	"FlightController", -- A: voo suave, subida e descida
	"CameraController", -- A: primeira pessoa confortável, terceira pessoa (V)
	"ViewmodelController", -- patas peludas e carga na parte de baixo da tela
	"InteractionController", -- A: segurar para coletar, entregar, construir
	"AudioController", -- sons (antes dos painéis, que tocam sons)
	"SocialController", -- Rainha, colônias e recompensa diária
	"HUDController", -- A–E: painéis da interface, relógio e loja de melhorias
	"VisualController", -- favos girando, asas batendo, partículas
	"WorkerBeeController", -- abelhas operárias voando (só visual)
	"GuideController", -- trilha dourada até o objetivo (tecla G)
	"PetController", -- mascotes voando junto dos donos
	"RaceController", -- anéis de impulso e cronômetro da corrida
	"OnboardingController", -- tutorial com a Rainha e configurações (P)
})
