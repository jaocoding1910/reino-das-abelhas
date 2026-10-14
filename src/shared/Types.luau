--!strict
--[[
	Types — formatos de dados compartilhados.
	Mudou o perfil salvo? Atualize aqui e aumente ProfileVersion.
]]

export type Rarity = "Comum" | "Medio" | "Raro"

export type Cargo = {
	Nectar: number,
	Combs: { [Rarity]: number },
}

export type Cell = {
	Slot: number,
	Progress: number, -- 0 a 100
	Completed: boolean,
}

export type Profile = {
	ProfileVersion: number,
	Honey: number,
	HoneyEarned: number, -- total já ganho (para títulos)
	CombPoints: number, -- pontos de favo depositados, ainda não usados
	XP: number, -- experiência total (o nível é calculado a partir dela)
	HiveHoney: number, -- mel produzido pelas células, esperando ser recolhido
	QuestIndex: number,
	QuestProgress: number,
	QuestCycle: number,
	Upgrades: { [string]: number },
	Specialty: string?,
	Cosmetics: { string },
	EquippedCosmetics: { string },
	Title: string,
	ColonyName: string,
	Cells: { Cell },
	-- Antigo campo reservado (não usado; a colônia agora é "Clan").
	ClanId: string?,
	Clan: string, -- nome da colônia ("" = nenhuma)
	LastDailyDay: number, -- último dia em que recebeu a recompensa diária
	DailyStreak: number,
	Royal: RoyalQuest, -- pedido atual da Rainha (Kind "" = nenhum)
	RoyalNextAt: number, -- os.time() a partir do qual pode pedir de novo
	RoyalCompleted: number,
	Stats: { [string]: number }, -- contadores das conquistas
	Achievements: { [string]: boolean },
	Pets: { string },
	EquippedPet: string, -- "" = nenhum
	TutorialDone: boolean,
	Settings: Settings,
	Rebirths: number,
	Workers: number,
	Codes: { [string]: boolean },
	Daily: DailyState,
	Chests: { [string]: number }, -- id do baú → os.time() em que abriu
	BestRace: number, -- melhor tempo da corrida em segundos (0 = nunca)
	LastRaceReward: number,
	Crowned: boolean, -- conquistou o título Rei/Rainha da Colmeia
}

export type DailyQuest = {
	Kind: string,
	Text: string,
	Goal: number,
	Progress: number,
	Honey: number,
	Done: boolean,
}
export type DailyState = { Day: number, List: { DailyQuest } }

export type Settings = {
	Music: boolean,
	Sfx: number,
	Trail: boolean,
	CameraRoll: boolean,
	Quality: string,
	ThirdPerson: boolean,
	MusicLevel: number,
	Sensitivity: number,
	ReducedMotion: boolean,
}

export type RoyalQuest = {
	Kind: string,
	Text: string,
	Goal: number,
	Progress: number,
	Honey: number,
	XP: number,
}

local Types = {}

function Types.EmptyRoyal(): RoyalQuest
	return { Kind = "", Text = "", Goal = 0, Progress = 0, Honey = 0, XP = 0 }
end

Types.PROFILE_VERSION = 6

function Types.NewProfile(): Profile
	return {
		ProfileVersion = Types.PROFILE_VERSION,
		Honey = 0,
		HoneyEarned = 0,
		CombPoints = 0,
		XP = 0,
		HiveHoney = 0,
		QuestIndex = 1,
		QuestProgress = 0,
		QuestCycle = 0,
		Upgrades = { Velocidade = 0, Capacidade = 0, Resistencia = 0, Sorte = 0, Folego = 0 },
		Specialty = nil,
		Cosmetics = {},
		EquippedCosmetics = {},
		Title = "Abelha iniciante",
		ColonyName = "Minha Colônia",
		Cells = {},
		ClanId = nil,
		Clan = "",
		LastDailyDay = 0,
		DailyStreak = 0,
		Royal = Types.EmptyRoyal(),
		RoyalNextAt = 0,
		RoyalCompleted = 0,
		Stats = {},
		Achievements = {},
		Pets = {},
		EquippedPet = "",
		TutorialDone = false,
		Settings = {
			Music = true,
			Sfx = 0.8,
			Trail = true,
			CameraRoll = true,
			Quality = "Alta",
			ThirdPerson = false,
			MusicLevel = 0.6,
			Sensitivity = 1,
			ReducedMotion = false,
		},
		Rebirths = 0,
		Workers = 0,
		Codes = {},
		Daily = { Day = 0, List = {} },
		Chests = {},
		BestRace = 0,
		LastRaceReward = 0,
		Crowned = false,
	}
end

function Types.EmptyCargo(): Cargo
	return { Nectar = 0, Combs = { Comum = 0, Medio = 0, Raro = 0 } }
end

-- Tira uma fração de cada tipo da carga (arredonda para cima, nunca mais do
-- que existe). Muda `cargo` e devolve o que saiu. Usado na derrota.
function Types.SplitCargo(cargo: Cargo, fraction: number): Cargo
	local lost = Types.EmptyCargo()
	fraction = math.clamp(fraction, 0, 1)
	lost.Nectar = math.min(cargo.Nectar, math.ceil(cargo.Nectar * fraction))
	cargo.Nectar -= lost.Nectar
	for _, rarity: Rarity in { "Comum", "Medio", "Raro" } :: { Rarity } do
		local amount = cargo.Combs[rarity] or 0
		local out = math.min(amount, math.ceil(amount * fraction))
		lost.Combs[rarity] = out
		cargo.Combs[rarity] = amount - out
	end
	return lost
end

return Types
