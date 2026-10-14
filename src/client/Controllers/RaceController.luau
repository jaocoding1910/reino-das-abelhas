--[[
	RaceController (cliente) — anéis de impulso e cronômetro da corrida

	- Passar por qualquer anel (tag "AnelImpulso") dá um impulso de voo
	  (FlightController.Boost) e um brilho. É só sensação de voo: quem
	  decide a corrida é o servidor (RaceService).
	- Durante a corrida: o próximo anel fica azul e pulsa, e um cronômetro
	  aparece no canto direito ("🏁 3/12 · 12,4 s").
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Parent.UI.Theme)
local W = require(script.Parent.Parent.UI.Widgets)
local AudioController = require(script.Parent.AudioController)
local FlightController = require(script.Parent.FlightController)

local RaceController = {}

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 200, 60)
local NEXT = Color3.fromRGB(90, 210, 255)

type Ring = { Model: Model, Index: number, Center: Vector3, LastBoost: number }

local rings: { Ring } = {}
local race = { Active = false, Next = 0, Total = Config.Rings.Count, Start = 0, Best = 0 }
local chip: Frame
local chipText: TextLabel
local scale: UIScale

local function addRing(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local center = model:GetAttribute("Centro")
	local index = model:GetAttribute("Indice")
	if typeof(center) == "Vector3" and typeof(index) == "number" then
		table.insert(rings, { Model = model, Index = index, Center = center, LastBoost = 0 })
	end
end

local function paint(ring: Ring, color: Color3)
	for _, part in ring.Model:GetChildren() do
		if part:IsA("BasePart") and part.Name == "Segmento" then
			part.Color = color
		end
	end
end

local function onRace(info: any)
	if type(info) ~= "table" then
		return
	end
	if info.Active then
		if not race.Active then
			race.Start = os.clock() - (info.Elapsed or 0)
		end
		race.Active = true
		race.Next = info.Next or race.Next
		race.Total = info.Total or race.Total
		if info.Best then
			race.Best = info.Best
		end
	else
		race.Active = false
		race.Next = 0
		if info.Best then
			race.Best = info.Best
		end
		if info.TimedOut then
			chipText.Text = "🏁 Tempo esgotado! Volte à largada."
			task.delay(3, function()
				if not race.Active then
					chip.Visible = false
				end
			end)
			return
		end
		if info.Finished then
			chipText.Text = string.format("🏁 Chegada! %.1f s", info.Finished)
			task.delay(4, function()
				if not race.Active then
					chip.Visible = false
				end
			end)
			return
		end
		chip.Visible = false
	end
end

function RaceController:Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD_Corrida"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	scale = Instance.new("UIScale")
	scale.Parent = gui
	chip = W.Panel("Corrida", UDim2.fromOffset(240, 40), UDim2.new(1, -12, 0, 244), Vector2.new(1, 0), gui)
	chip.Visible = false
	local stroke = chip:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = NEXT
	end
	chipText = W.Text("Texto", "", UDim2.new(1, -16, 1, -10), UDim2.fromOffset(8, 5), chip, {
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Colors.Text,
	})
	gui.Parent = player:WaitForChild("PlayerGui")
end

function RaceController:Start()
	for _, model in CollectionService:GetTagged("AnelImpulso") do
		addRing(model)
	end
	CollectionService:GetInstanceAddedSignal("AnelImpulso"):Connect(addRing)
	Remotes.Get("RaceUpdate").OnClientEvent:Connect(onRace)

	local lastNext = -1
	RunService.RenderStepped:Connect(function()
		local viewport = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(viewport.X / 1366, viewport.Y / 768), 0.55, 1)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local now = os.clock()
		if root then
			for _, ring in rings do
				if
					(root.Position - ring.Center).Magnitude <= Config.Rings.Radius + 1.5
					and now - ring.LastBoost > 1
				then
					ring.LastBoost = now
					FlightController.Boost(Config.Rings.BoostMultiplier, Config.Rings.BoostDuration)
					AudioController.Play("Coleta")
				end
			end
		end
		-- Próximo anel em azul (e pulsando) durante a corrida.
		local target = if race.Active then race.Next else 0
		if target ~= lastNext then
			lastNext = target
			for _, ring in rings do
				paint(ring, if ring.Index == target then NEXT else GOLD)
			end
		end
		if race.Active then
			chip.Visible = true
			local elapsed = now - race.Start
			local best = if race.Best > 0 then string.format(" · recorde %.1f", race.Best) else ""
			chipText.Text = string.format("🏁 %d/%d · %.1f s%s", race.Next - 1, race.Total, elapsed, best)
		end
	end)
	Log.info("RaceController", `{#rings} anéis`)
end

return RaceController
