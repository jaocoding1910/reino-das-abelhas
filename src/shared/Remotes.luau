--!strict
--[[
	Remotes — lista única de canais cliente ↔ servidor.

	O servidor cria a pasta ReplicatedStorage.Remotes no início.
	O cliente espera por ela. Para adicionar um canal: inclua o nome
	em EVENTS ou FUNCTIONS e use Remotes.Get("Nome").

	Regra de segurança: o cliente só PEDE ações. Nunca envie dano,
	quantidade ou recompensa decididos no cliente.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

-- Coleta, entrega e construção usam ProximityPrompt (o servidor recebe
-- o Triggered direto do motor), por isso não precisam de RemoteEvent.
local EVENTS = {
	"RequestUpgrade", -- cliente → servidor: comprar melhoria X
	"RequestCosmetic", -- cliente → servidor: comprar/equipar acessório X
	"RequestHiveAction", -- cliente → servidor: "Entregar", "Expandir" ou "ColetarMel" pelo painel
	"RequestSpecialty", -- cliente → servidor: escolher especialidade X
	"RequestAttack", -- cliente → servidor: atacar (servidor valida alvo e alcance)
	"StateUpdated", -- servidor → cliente: inventário, saúde, título
	"WorldUpdated", -- servidor → todos: dia/noite, avisos
	"Notify", -- servidor → cliente: mensagens na tela
	"Effect", -- servidor → todos: efeitos visuais (acerto, coleta, derrota)
	"RequestRoyal", -- cliente → servidor: "Aceitar" ou "Receber" pedido da Rainha
	"RequestClan", -- cliente → servidor: "Criar" (nome), "Entrar" (nome) ou "Sair"
	"DailyReward", -- servidor → cliente: recompensa diária (sequência, mel)
	"RequestShop", -- cliente → servidor: "Pocao" (id) ou "Troca" (id) no Besouro
	"RequestPet", -- cliente → servidor: "Comprar"/"Equipar"/"Guardar" mascote
	"RequestSettings", -- cliente → servidor: salvar configurações (tabela validada)
	"RequestTutorial", -- cliente → servidor: "Concluir" ou "Pular"
	"RequestRebirth", -- cliente → servidor: renascer
	"RequestWorker", -- cliente → servidor: contratar operária
	"RequestCode", -- cliente → servidor: resgatar código (texto)
	"RaceUpdate", -- servidor → cliente: corrida (anel atual, tempo)
}

local FUNCTIONS = {
	"GetInitialState", -- cliente pede o estado completo ao entrar
}

local Remotes = {}

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder :: Folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

-- Chamado uma vez pelo servidor no bootstrap.
function Remotes.Setup()
	assert(RunService:IsServer(), "Remotes.Setup só pode rodar no servidor")
	local folder = getFolder()
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Remotes.Get(name: string): RemoteEvent
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Remotes.GetFunction(name: string): RemoteFunction
	return getFolder():WaitForChild(name) :: RemoteFunction
end

return Remotes
