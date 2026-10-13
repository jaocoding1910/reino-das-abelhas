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

Types.PROFILE_VERSION = 2

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
		Upgrades = { Velocidade = 0, Capacidade = 0, Resistencia = 0 },
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
	}
end

function Types.EmptyCargo(): Cargo
	return { Nectar = 0, Combs = { Comum = 0, Medio = 0, Raro = 0 } }
end

return Types
