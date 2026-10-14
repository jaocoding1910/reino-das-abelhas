--[[
	Boosts — efeitos temporários das poções (só na sessão, não salvam).

	Não depende de nenhum serviço: InventoryService e ResourceService só
	perguntam "está ativo?" e o MerchantService liga os efeitos.
]]

local Boosts = {}

local active: { [Player]: { [string]: number } } = {} -- id → os.clock() em que acaba

-- Liga (ou estende) um efeito por `duration` segundos.
function Boosts.Start(player: Player, id: string, duration: number)
	local list = active[player] or {}
	active[player] = list
	local now = os.clock()
	list[id] = math.max(list[id] or now, now) + duration
end

function Boosts.Remaining(player: Player, id: string): number
	local list = active[player]
	local ends = list and list[id]
	return if ends then math.max(0, ends - os.clock()) else 0
end

function Boosts.IsActive(player: Player, id: string): boolean
	return Boosts.Remaining(player, id) > 0
end

function Boosts.Clear(player: Player)
	active[player] = nil
end

return Boosts
