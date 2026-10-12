--[[
	WorldService (servidor) — Etapa A

	Monta o mapa no Init (antes de qualquer Start) e guarda os dados
	para os outros serviços: lotes de colmeia, flores e favos.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Util.Log)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)

local WorldService = {}

WorldService.Map = nil :: MapBuilder.MapData?

function WorldService.GetMap(): MapBuilder.MapData
	assert(WorldService.Map, "WorldService ainda não montou o mapa")
	return WorldService.Map :: MapBuilder.MapData
end

function WorldService:Init()
	WorldService.Map = MapBuilder.Build()
end

function WorldService:Start()
	local map = WorldService.GetMap()
	Log.info("WorldService", `mapa pronto: {#map.Plots} colmeias, {#map.Flowers} flores, {#map.Combs} favos`)
end

return WorldService
