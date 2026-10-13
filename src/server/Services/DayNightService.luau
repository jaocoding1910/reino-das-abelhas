--[[
	DayNightService (servidor) — Etapa C (parte visual)

	Ciclo sincronizado pelo servidor: todos veem a mesma hora.
	- Dia: 6h → 18h em Config.DayNight.DayDuration segundos.
	- Noite: 18h → 6h em Config.DayNight.NightDuration segundos.
	- Transição gradual de luz e cor (Config.DayNight.TransitionDuration).
	- Aviso antes de anoitecer (Config.DayNight.WarnBeforeNight).

	O cliente lê:
	- Lighting.ClockTime (replica sozinho) para o relógio do HUD.
	- workspace:GetAttribute("IsNight") para "Noite • Perigo elevado".
	- Remotes WorldUpdated para avisos.

	Dica para testar rápido: em Config, use DayDuration = 60 e
	NightDuration = 40.
	Etapa C: predadores mais ativos à noite.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local MapBuilder = require(script.Parent.Parent.World.MapBuilder)

local DayNightService = {}

local DAY = {
	Ambient = Color3.fromRGB(140, 130, 120),
	OutdoorAmbient = Color3.fromRGB(150, 140, 130),
	Tint = Color3.fromRGB(255, 248, 235),
	Atmosphere = Color3.fromRGB(255, 228, 190),
	Brightness = 2.4,
}

-- Noite "mágica" da referência: roxa e clara o bastante para jogar,
-- com as lanternas, flores e luzinhas fazendo o brilho.
local NIGHT = {
	Ambient = Color3.fromRGB(105, 85, 160),
	OutdoorAmbient = Color3.fromRGB(120, 100, 190),
	Tint = Color3.fromRGB(205, 190, 255),
	Atmosphere = Color3.fromRGB(110, 85, 175),
	Brightness = 1.7,
}

local cycleStart = 0
local warned = false
local wasNight = false

-- Converte o tempo do ciclo em hora do relógio (0–24).
local function clockAt(elapsed: number): number
	local dayLength = Config.DayNight.DayDuration
	local nightLength = Config.DayNight.NightDuration
	local t = elapsed % (dayLength + nightLength)
	if t < dayLength then
		return 6 + (t / dayLength) * 12 -- 6h → 18h
	end
	return (18 + ((t - dayLength) / nightLength) * 12) % 24 -- 18h → 6h
end

-- 0 = dia pleno, 1 = noite plena, com rampa suave nas viradas.
local function nightFactor(clock: number): number
	local ramp = 1 -- horas de transição de cada lado
	local h = clock
	if h >= 6 + ramp and h <= 18 - ramp then
		return 0
	elseif h >= 18 + ramp or h <= 6 - ramp then
		return 1
	elseif h > 18 - ramp and h < 18 + ramp then
		return (h - (18 - ramp)) / (2 * ramp)
	end
	return 1 - (h - (6 - ramp)) / (2 * ramp)
end

-- Segundos até a próxima noite (para o aviso).
local function secondsUntilNight(elapsed: number): number
	local dayLength = Config.DayNight.DayDuration
	local t = elapsed % (dayLength + Config.DayNight.NightDuration)
	return if t < dayLength then dayLength - t else math.huge
end

local function apply(factor: number)
	local function lerp(a: Color3, b: Color3)
		return a:Lerp(b, factor)
	end
	Lighting.Ambient = lerp(DAY.Ambient, NIGHT.Ambient)
	Lighting.OutdoorAmbient = lerp(DAY.OutdoorAmbient, NIGHT.OutdoorAmbient)
	Lighting.Brightness = DAY.Brightness + (NIGHT.Brightness - DAY.Brightness) * factor

	local color = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if color then
		color.TintColor = lerp(DAY.Tint, NIGHT.Tint)
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Color = lerp(DAY.Atmosphere, NIGHT.Atmosphere)
	end
end

-- Liga/desliga o brilho noturno. Cada peça guarda a própria cor e o material
-- de dia (atributos DayColor/DayMaterial) para voltar ao normal de manhã.
local function setNightGlow(isNight: boolean)
	for _, item in CollectionService:GetTagged(MapBuilder.Tags.NightGlow) do
		if item:IsA("PointLight") or item:IsA("SpotLight") or item:IsA("SurfaceLight") then
			item.Enabled = isNight
		elseif item:IsA("BasePart") then
			if item:GetAttribute("DayColor") == nil then
				item:SetAttribute("DayColor", item.Color)
				item:SetAttribute("DayMaterial", item.Material.Name)
			end
			local nightColor = item:GetAttribute("NightColor")
			local dayColor = item:GetAttribute("DayColor")
			local dayMaterial = item:GetAttribute("DayMaterial")
			if isNight then
				item.Material = Enum.Material.Neon
				if typeof(nightColor) == "Color3" then
					item.Color = nightColor
				end
			else
				local ok, material = pcall(function()
					return (Enum.Material :: any)[dayMaterial]
				end)
				item.Material = if ok and material then material else Enum.Material.SmoothPlastic
				if typeof(dayColor) == "Color3" then
					item.Color = dayColor
				end
			end
		end
	end
end

function DayNightService.IsNight(): boolean
	return workspace:GetAttribute("IsNight") == true
end

function DayNightService:Init()
	-- Começa na hora configurada (ex.: 9h).
	local startClock = Config.DayNight.StartClockTime
	cycleStart = os.clock() - ((startClock - 6) / 12) * Config.DayNight.DayDuration
	workspace:SetAttribute("IsNight", false)
end

function DayNightService:Start()
	setNightGlow(false) -- guarda as cores de dia e apaga as luzes noturnas
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0

		local elapsed = os.clock() - cycleStart
		local clock = clockAt(elapsed)
		local factor = nightFactor(clock)
		Lighting.ClockTime = clock
		apply(factor)

		local isNight = factor >= 0.5
		if isNight ~= wasNight then
			wasNight = isNight
			workspace:SetAttribute("IsNight", isNight)
			setNightGlow(isNight)
			Remotes.Get("WorldUpdated"):FireAllClients(
				if isNight
					then "A noite chegou. Perigo elevado fora das colmeias!"
					else "Amanheceu! O campo está tranquilo.",
				if isNight then "erro" else "ok"
			)
			warned = false
		end

		if not isNight and not warned and secondsUntilNight(elapsed) <= Config.DayNight.WarnBeforeNight then
			warned = true
			Remotes.Get("WorldUpdated"):FireAllClients(
				`A noite chega em {math.floor(Config.DayNight.WarnBeforeNight)} segundos!`,
				"info"
			)
		end
	end)
	Log.info("DayNightService", "ciclo iniciado")
end

return DayNightService
