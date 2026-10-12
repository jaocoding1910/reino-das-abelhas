--[[
	InputController (cliente) — Etapa A

	Traduz teclado, controle e toque em intenções de voo.
	O movimento horizontal vem dos controles padrão do Roblox
	(WASD, analógico, joystick de toque) via Humanoid.MoveDirection.

	PC:       Espaço sobe · Ctrl esquerdo ou Q desce · E coleta/entrega · clique ataca
	Controle: A sobe · B desce · X interage · R2 ataca
	Celular:  botões "Subir", "Descer" e "Atacar" na tela · toque nos avisos para coletar

	Ataque: o cliente só AVISA o servidor ("ataquei"). Alvo, alcance,
	dano e zona de disputa são decididos lá.
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local InputController = {}

local up = false
local down = false

-- -1 (descer), 0 (parado) ou 1 (subir).
function InputController.GetVertical(): number
	return (if up then 1 else 0) - (if down then 1 else 0)
end

local function bindHold(
	actionName: string,
	title: string,
	position: UDim2,
	setter: (boolean) -> (),
	...: Enum.KeyCode
)
	ContextActionService:BindActionAtPriority(actionName, function(_, state)
		if state == Enum.UserInputState.Begin then
			setter(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			setter(false)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.ContextActionPriority.High.Value, ...)

	-- Botão de toque (só aparece em celular/tablet).
	ContextActionService:SetTitle(actionName, title)
	ContextActionService:SetPosition(actionName, position)
end

function InputController:Init()
	bindHold("AbelhaSubir", "Subir", UDim2.new(1, -95, 1, -170), function(value)
		up = value
	end, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

	bindHold("AbelhaDescer", "Descer", UDim2.new(1, -170, 1, -95), function(value)
		down = value
	end, Enum.KeyCode.LeftControl, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
end

local lastAttack = 0

local function attack()
	-- Fora da zona de disputa o servidor recusaria; nem envia (evita spam de aviso).
	if game:GetService("Players").LocalPlayer:GetAttribute("Region") ~= "Disputa" then
		return
	end
	local now = os.clock()
	if now - lastAttack < Config.Combat.Cooldown then
		return
	end
	lastAttack = now
	Remotes.Get("RequestAttack"):FireServer()
end

function InputController:Start()
	ContextActionService:BindAction("AbelhaAtacar", function(_, state)
		if state == Enum.UserInputState.Begin then
			attack()
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("AbelhaAtacar", "Atacar")
	ContextActionService:SetPosition("AbelhaAtacar", UDim2.new(1, -170, 1, -170))

	Log.info("InputController", "pronto")
end

return InputController
