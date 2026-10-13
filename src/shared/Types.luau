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
	-- Reservado para clãs (ainda não implementado).
	ClanId: string?,
}

local Types = {}

Types.PROFILE_VERSION = 1

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
	}
end

function Types.EmptyCargo(): Cargo
	return { Nectar = 0, Combs = { Comum = 0, Medio = 0, Raro = 0 } }
end

return Types
