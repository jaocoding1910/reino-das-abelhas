--!strict
--[[
	Notifier — ponte sem dependências entre os serviços e o HUD.

	- Notify(player, texto, tipo): mensagem na tela do jogador.
	- Changed(player): "algo mudou, atualize o HUD". O StateService
	  escuta Changed e envia o estado completo.

	Assim nenhum serviço precisa importar o StateService (sem ciclos).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local Notifier = {}

local changed = Instance.new("BindableEvent")
Notifier.OnChanged = changed.Event :: RBXScriptSignal

-- kind: "ok" | "erro" | "info"
function Notifier.Notify(player: Player, text: string, kind: string)
	if player.Parent then
		Remotes.Get("Notify"):FireClient(player, text, kind)
	end
end

function Notifier.Changed(player: Player)
	changed:Fire(player)
end

return Notifier
