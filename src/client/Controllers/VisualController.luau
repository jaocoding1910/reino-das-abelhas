--[[
	VisualController (cliente)

	Animações só visuais, rodando no cliente (não pesam no servidor):
	- Favos coletáveis girando e flutuando (tag "FavoFlutuante").
	- Asas de todas as abelhas batendo (tag "AsaAbelha").
	- Explosões de partículas dos eventos do servidor (Remotes "Effect"):
	  coleta, entrega, dano, derrota, ataque e subida de nível.

	Só anima o que está perto da câmera, para poupar o celular.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local Debris = game:GetService("Debris")

local VisualController = {}

local COMB_TAG = "FavoFlutuante"
local WING_TAG = "AsaAbelha"
local COMB_RANGE = 220
local WING_RANGE = 250

type CombEntry = { Model: Model, Base: CFrame, Phase: number }

local combs: { [Model]: CombEntry } = {}
local wings: { [Weld]: true } = {}

local function addComb(instance: Instance)
	if instance:IsA("Model") then
		combs[instance] = {
			Model = instance,
			Base = instance:GetPivot(),
			Phase = math.random() * math.pi * 2,
		}
	end
end

local function addWing(instance: Instance)
	if instance:IsA("Weld") then
		wings[instance] = true
	end
end

local function track(tag: string, add: (Instance) -> (), remove: (Instance) -> ())
	for _, instance in CollectionService:GetTagged(tag) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
end

function VisualController:Init()
	track(COMB_TAG, addComb, function(instance)
		combs[instance :: Model] = nil
	end)
	track(WING_TAG, addWing, function(instance)
		wings[instance :: Weld] = nil
	end)
end

local EFFECTS = {
	coleta = { Color = Color3.fromRGB(255, 215, 90), Count = 18, Size = 0.6, Speed = 8 },
	entrega = { Color = Color3.fromRGB(255, 190, 60), Count = 35, Size = 0.9, Speed = 12 },
	dano = { Color = Color3.fromRGB(255, 70, 70), Count = 14, Size = 0.7, Speed = 10 },
	derrota = { Color = Color3.fromRGB(255, 120, 80), Count = 45, Size = 1.1, Speed = 16 },
	ataque = { Color = Color3.fromRGB(255, 255, 255), Count = 8, Size = 0.5, Speed = 14 },
	nivel = { Color = Color3.fromRGB(255, 230, 120), Count = 60, Size = 1, Speed = 20 },
}

local function burst(kind: string, position: Vector3)
	local info = EFFECTS[kind]
	if not info or typeof(position) ~= "Vector3" then
		return
	end
	if (position - workspace.CurrentCamera.CFrame.Position).Magnitude > 300 then
		return
	end
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(info.Color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(info.Speed * 0.5, info.Speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, info.Size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Parent = holder
	holder.Parent = workspace.CurrentCamera
	emitter:Emit(info.Count)
	Debris:AddItem(holder, 1.5)
end

function VisualController:Start()
	Remotes.Get("Effect").OnClientEvent:Connect(burst)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local cameraPosition = workspace.CurrentCamera.CFrame.Position

		for _, entry in combs do
			if (entry.Base.Position - cameraPosition).Magnitude < COMB_RANGE then
				local bob = math.sin(now * 2 + entry.Phase) * 0.6
				entry.Model:PivotTo(
					entry.Base * CFrame.new(0, bob, 0) * CFrame.Angles(0, now * 1.2 + entry.Phase, 0)
				)
			end
		end

		for weld in wings do
			local wing = weld.Part1
			if wing and (wing.Position - cameraPosition).Magnitude < WING_RANGE then
				local base = weld:GetAttribute("BaseC0")
				local side = weld:GetAttribute("Side")
				if typeof(base) == "CFrame" and typeof(side) == "number" then
					weld.C0 = base * CFrame.Angles(0, 0, math.sin(now * 38) * 0.45 * side)
				end
			end
		end
	end)
	Log.info("VisualController", "pronto")
end

return VisualController
