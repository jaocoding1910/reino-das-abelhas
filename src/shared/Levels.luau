--!strict
--[[
	Levels — converte XP total em nível (função pura, testável).

	O nível 1 começa com 0 XP. Para subir do nível n para o n+1 são
	necessários LevelBase × LevelGrowth^(n-1) pontos.
]]

local Config = require(script.Parent.Config)

local Levels = {}

-- XP necessária para passar do nível `level` para o seguinte.
function Levels.Requirement(level: number): number
	local p = Config.Progression
	return math.floor(p.LevelBase * p.LevelGrowth ^ (level - 1))
end

-- Retorna nível, XP dentro do nível e XP necessária para o próximo.
function Levels.FromXP(totalXP: number): (number, number, number)
	local level = 1
	local remaining = math.max(0, math.floor(totalXP))
	while level < Config.Progression.MaxLevel do
		local need = Levels.Requirement(level)
		if remaining < need then
			return level, remaining, need
		end
		remaining -= need
		level += 1
	end
	return level, 0, 0
end

return Levels
