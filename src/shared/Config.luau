--!strict
--[[
	Config — balanceamento central do Reino das Abelhas.

	TODO valor de jogo (custo, dano, tempo, chance) mora aqui.
	Servidor e cliente leem deste módulo; só o servidor decide resultados.
	Para ajustar o jogo, edite este arquivo e salve: o Rojo sincroniza na hora.
]]

local Config = {}

-- Raridades de favos -------------------------------------------------------
-- Ordem importa: usada em UI e em sorteios. Épico/lendário ficam para depois.
Config.RarityOrder = { "Comum", "Medio", "Raro" }

Config.Rarities = {
	Comum = {
		DisplayName = "Favo de Cera",
		Label = "Comum",
		BuildContribution = 1,
		Color = Color3.fromRGB(245, 235, 200),
		Shape = "Hexagono",
		Effect = "Nenhum",
	},
	Medio = {
		DisplayName = "Favo de Mel",
		Label = "Médio",
		BuildContribution = 3,
		Color = Color3.fromRGB(255, 176, 40),
		Shape = "HexagonoDuplo",
		Effect = "Brilho",
	},
	Raro = {
		DisplayName = "Favo Real",
		Label = "Raro",
		BuildContribution = 8,
		Color = Color3.fromRGB(170, 90, 255),
		Shape = "Cristal",
		Effect = "Particulas",
		-- Segundos removidos do tempo restante de uma célula em construção.
		BuildTimeReduction = 20,
	},
}

-- Coleta e transporte -----------------------------------------------------
Config.Collection = {
	MaxDistance = 14, -- studs entre abelha e recurso
	InteractTime = 0.8, -- segundos segurando para coletar
	NectarPerFlower = 3, -- néctar por flor coletada
	MinIntervalBetweenActions = 0.25, -- anti-spam no servidor
	FlowerRespawnTime = 30,
	CombRespawnTime = { Comum = 45, Medio = 120, Raro = 300 },
}

Config.Carry = {
	BaseCapacity = 10, -- unidades de carga
	NectarWeight = 1,
	CombWeight = { Comum = 1, Medio = 2, Raro = 3 },
	SpeedPenaltyPerWeight = 0.02, -- -2% de velocidade por unidade
	MaxSpeedPenalty = 0.35, -- nunca perde mais que 35%
}

Config.NectarToHoneyRate = 2 -- 1 néctar entregue = 2 de mel

-- Voo ---------------------------------------------------------------------
Config.Flight = {
	BaseSpeed = 28,
	VerticalSpeed = 18,
	Acceleration = 6,
	MaxAltitude = 600,
	-- Arrancada (Shift / botão "Arrancar"): mais rápida, gasta fôlego.
	SprintMultiplier = 1.5,
	StaminaMax = 100,
	StaminaDrainPerSecond = 28,
	StaminaRegenPerSecond = 18,
	StaminaRegenDelay = 0.8,
	-- Sensação: inclinação nas curvas e campo de visão com a velocidade.
	BankDegrees = 22, -- inclinação máxima do corpo nas curvas
	CameraRollDegrees = 5, -- inclinação leve da câmera (0 desliga)
	FieldOfView = 78,
	FieldOfViewBoost = 14, -- quanto o FOV abre na velocidade máxima
	ShowLegs = false, -- patinhas na parte de baixo da tela (true liga)
}

-- Mapa (gerado por código em World/MapBuilder) ---------------------------
Config.Map = {
	Seed = 2026, -- mesma semente = mesmo mapa sempre
	FlowerCount = 70,
	CombCount = 25, -- comuns, no campo
	MediumCombCount = 14, -- médios, no bosque (pés das árvores e cogumelos)
	RareCombCount = 6, -- raros, no alto das copas (difícil de chegar)
	TreeCount = 18,
	MushroomCount = 22,
	PlotCount = 8, -- colmeias = máximo de jogadores por servidor
	PlotRingRadius = 150,
	FieldRadius = { Min = 230, Max = 470 }, -- campo inicial (flores e favos comuns)
	ForestRadius = { Min = 500, Max = 820 }, -- bosque (favos médios e raros)
	SunflowerChance = 0.3, -- parte das flores vira girassol
	CrystalCount = 14, -- cristais roxos decorativos no bosque
	BridgeHeight = 72, -- altura das pontes entre as árvores-colmeia
	RoyalHive = {
		Position = Vector3.new(0, 0, -880), -- palácio da Colmeia Real (norte do mapa)
		PlateauHeight = 70,
		RareCombs = 3, -- favos raros extras nas torres
	},
}

-- Regiões (o servidor decide; o cliente só mostra o aviso) ------------------
-- Colmeias e Campo: protegidas (sem predadores e sem combate).
-- Bosque: predadores, sem combate.
-- Disputa: copas altas do bosque e a Colmeia Real (predadores e combate).
Config.Regions = {
	HiveRadius = 230, -- distância do centro até onde vai a área das colmeias
	SafeRadius = 490, -- até aqui (campo inicial) é protegido
	DisputeAltitude = 85, -- acima disso, no bosque, é zona de disputa
	RoyalRadius = 230, -- em volta da Colmeia Real é zona de disputa
}

-- Mundo e ciclo dia/noite -------------------------------------------------
Config.DayNight = {
	DayDuration = 12 * 60,
	NightDuration = 6 * 60,
	TransitionDuration = 30,
	WarnBeforeNight = 60,
	StartClockTime = 9, -- hora em que o servidor começa (9h da manhã)
	NightRareChanceMultiplier = 2, -- Etapa C
}

-- Saúde, derrota e penalidade ---------------------------------------------
Config.Health = {
	Max = 100,
	RespawnDelay = 5,
	SpawnProtection = 8, -- segundos; cancelado ao atacar
	DroppedCargoLifetime = 60,
	RegenPerSecondInSafeZone = 4, -- recupera vida em área protegida
}

Config.DeathPenalty = {
	Enabled = true,
	-- Só se a morte for causada por predador. Pontos percentuais em UMA célula inacabada.
	PredatorBuildProgressLoss = 5,
}

-- Combate entre jogadores (só em regiões de disputa) -----------------------
Config.Combat = {
	Damage = 15,
	Cooldown = 0.9,
	Range = 9, -- studs
	FrontDot = 0.2, -- o alvo precisa estar à frente (0 = 90°, 1 = reto)
}

-- Predadores --------------------------------------------------------------
Config.Predators = {
	Spider = {
		Count = 6,
		DetectionRange = 40,
		TerritoryRadius = 60,
		MoveSpeed = 20, -- studs por segundo perseguindo
		MaxClimb = 28, -- até que altura acima da teia ela alcança (fuja voando alto!)
		AttackRange = 9,
		AttackDamage = 20,
		AttackWindup = 1.0, -- tempo de aviso antes do golpe
		AttackCooldown = 2.5,
		WebRadius = 10, -- encostar na teia desacelera
		WebSlowMultiplier = 0.5,
		WebSlowDuration = 3,
		DayActivityMultiplier = 0.6, -- de dia enxerga menos
		NightActivityMultiplier = 1.6, -- à noite enxerga e corre mais
	},
	-- Louva-a-deus: espreita no alto dos cogumelos do bosque e dá o BOTE em linha
	-- reta. O bote vai até onde você estava no fim do aviso: desvie para escapar!
	LouvaDeus = {
		Count = 5,
		DetectionRange = 55,
		TerritoryRadius = 50,
		LungeDistance = 36, -- alcance máximo do bote
		LungeSpeed = 80, -- studs por segundo durante o bote
		ReturnSpeed = 20,
		AttackWindup = 0.9, -- tempo de aviso (braços erguidos, "!" vermelho)
		StrikeRadius = 7, -- distância da cabeça para acertar no fim do bote
		AttackDamage = 25,
		AttackCooldown = 3.5,
		DayActivityMultiplier = 0.5,
		NightActivityMultiplier = 1.4,
	},
}

-- Melhorias compradas com mel ----------------------------------------------
Config.UpgradeOrder = { "Velocidade", "Capacidade", "Resistencia" }

Config.Upgrades = {
	-- Velocidade: +6% de velocidade de voo por nível.
	Velocidade = {
		DisplayName = "Velocidade",
		MaxLevel = 5,
		BaseCost = 60,
		CostGrowth = 1.6,
		BonusPerLevel = 0.06,
	},
	-- Capacidade: +2 de carga por nível.
	Capacidade = {
		DisplayName = "Capacidade",
		MaxLevel = 5,
		BaseCost = 80,
		CostGrowth = 1.6,
		BonusPerLevel = 2,
	},
	-- Resistência: +10 de vida por nível (vale a partir da Etapa C).
	Resistencia = {
		DisplayName = "Resistência",
		MaxLevel = 5,
		BaseCost = 100,
		CostGrowth = 1.7,
		BonusPerLevel = 10,
	},
}

-- Especialidades: escolha grátis na primeira vez; trocar custa mel.
Config.SpecialtyOrder = { "Veloz", "Transportadora", "Guardia" }
Config.SpecialtyChangeCost = 100
Config.Specialties = {
	Veloz = {
		DisplayName = "Veloz",
		Description = "+15% voo · -20% carga",
		SpeedMultiplier = 1.15,
		CapacityMultiplier = 0.8,
		HealthMultiplier = 1,
	},
	Transportadora = {
		DisplayName = "Transportadora",
		Description = "+35% carga · -10% voo",
		SpeedMultiplier = 0.9,
		CapacityMultiplier = 1.35,
		HealthMultiplier = 1,
	},
	Guardia = {
		DisplayName = "Guardiã",
		Description = "+30% vida · -8% voo",
		SpeedMultiplier = 0.92,
		CapacityMultiplier = 1,
		HealthMultiplier = 1.3,
	},
}

-- Colmeia -----------------------------------------------------------------
Config.Hive = {
	InitialCells = 3,
	Rings = 3, -- anéis hexagonais: 1 + 6 + 12 + 18 = 37 células
	MaxCells = 37,
	CellCombCost = 10, -- pontos de favo para levar uma célula de 0% a 100%
	CellHoneyCost = 50, -- mel pago para iniciar a célula
	CellSide = 4.2, -- tamanho do lado do hexágono (studs); a parede tem ~62 studs
	CellBuildTime = 60, -- reservado: tempo de acabamento (favo raro reduz)
	-- Produção passiva: cada célula concluída fabrica mel sozinha.
	HoneyPerCellPerMinute = 2,
	StoragePerCell = 25, -- mel guardado por célula até você recolher
}

-- Progressão --------------------------------------------------------------
Config.Titles = {
	{ Name = "Abelha iniciante", RequiredCells = 0, RequiredHoney = 0 },
	{ Name = "Coletora", RequiredCells = 5, RequiredHoney = 500 },
	{ Name = "Construtora", RequiredCells = 12, RequiredHoney = 2000 },
	{ Name = "Líder", RequiredCells = 24, RequiredHoney = 6000 },
	{ Name = "Rei da Colmeia", RequiredCells = 37, RequiredHoney = 15000 },
}

-- Missões em sequência ------------------------------------------------------
-- Kind: Nectar, Comb, CombMedio, CombRaro, Mel (entregue), Celula, Melhoria.
-- Ao terminar a lista, as missões a partir de RepeatFrom repetem com metas maiores.
Config.Quests = {
	{ Kind = "Nectar", Goal = 15, Text = "Colete néctar nas flores", Honey = 30, XP = 40 },
	{ Kind = "Comb", Goal = 3, Text = "Pegue favos no campo", Honey = 30, XP = 40 },
	{ Kind = "Mel", Goal = 60, Text = "Entregue mel na colmeia", Honey = 40, XP = 50 },
	{ Kind = "Celula", Goal = 1, Text = "Construa uma célula nova", Honey = 60, XP = 80 },
	{ Kind = "Melhoria", Goal = 1, Text = "Compre uma melhoria", Honey = 50, XP = 60 },
	{ Kind = "CombMedio", Goal = 2, Text = "Pegue favos médios no bosque", Honey = 80, XP = 100 },
	{ Kind = "Nectar", Goal = 50, Text = "Colete muito néctar", Honey = 80, XP = 100 },
	{ Kind = "CombRaro", Goal = 1, Text = "Traga um favo raro", Honey = 150, XP = 200 },
	{ Kind = "Celula", Goal = 3, Text = "Expanda a colmeia", Honey = 200, XP = 250 },
	{ Kind = "Mel", Goal = 400, Text = "Encha a colmeia de mel", Honey = 250, XP = 300 },
}
Config.QuestRepeatFrom = 6
Config.QuestRepeatGrowth = 0.5 -- +50% na meta e na recompensa a cada volta

-- Arte: cores dos modelos 3D importados (o jogo recolore cada peça pelo nome).
-- Uma peça "Corpo_3" usa a entrada "Corpo".
Config.Art = {
	BeeYawDegrees = 0, -- se a abelha importada voar de costas, use 180
	-- Abelhas operárias (só visual, no cliente): voam entre a colmeia e as flores.
	WorkerBeesPerHive = 3,
	WorkerBeesRoyal = 5,
	WorkerBeeLength = 2.6,
	Palette = {
		-- Abelha
		Corpo = { Color = Color3.fromRGB(255, 196, 40) },
		Listra = { Color = Color3.fromRGB(35, 28, 24) },
		Pelo = { Color = Color3.fromRGB(255, 214, 110), Material = Enum.Material.Fabric },
		Cabeca = { Color = Color3.fromRGB(35, 28, 24) },
		OlhoBranco = { Color = Color3.fromRGB(250, 250, 250) },
		Pupila = { Color = Color3.fromRGB(20, 18, 16) },
		Brilho = { Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon },
		Bochecha = { Color = Color3.fromRGB(255, 140, 160) },
		Antena = { Color = Color3.fromRGB(35, 28, 24) },
		Ferrao = { Color = Color3.fromRGB(35, 28, 24) },
		Pata = { Color = Color3.fromRGB(35, 28, 24) },
		AsaE = { Color = Color3.fromRGB(225, 240, 255), Material = Enum.Material.Glass, Transparency = 0.45 },
		AsaD = { Color = Color3.fromRGB(225, 240, 255), Material = Enum.Material.Glass, Transparency = 0.45 },
		-- Plantas
		Caule = { Color = Color3.fromRGB(85, 150, 60) },
		Folha = { Color = Color3.fromRGB(75, 160, 70), Material = Enum.Material.Grass },
		Petala = { Color = Color3.fromRGB(250, 250, 245) },
		PetalaInterna = { Color = Color3.fromRGB(255, 240, 200) },
		Miolo = { Color = Color3.fromRGB(255, 185, 40), Material = Enum.Material.Sand },
		MioloBorda = { Color = Color3.fromRGB(150, 100, 40) },
		Pe = { Color = Color3.fromRGB(240, 230, 210) },
		Chapeu = { Color = Color3.fromRGB(200, 60, 70) },
		Pinta = { Color = Color3.fromRGB(250, 250, 240) },
		Tronco = { Color = Color3.fromRGB(105, 75, 50), Material = Enum.Material.Wood },
		Copa = { Color = Color3.fromRGB(65, 135, 60), Material = Enum.Material.Grass },
		CopaClara = { Color = Color3.fromRGB(95, 165, 70), Material = Enum.Material.Grass },
		Cristal = { Color = Color3.fromRGB(160, 90, 255), Material = Enum.Material.Neon, Transparency = 0.1 },
	},
}

-- Rainha Abelha (Colmeia Real): pedidos especiais com recompensa maior -------
Config.Royal = {
	TalkDistance = 60, -- precisa estar perto dela para aceitar/entregar
	Cooldown = 10 * 60, -- segundos entre um pedido entregue e o próximo
	LevelScale = 0.08, -- +8% de meta e recompensa por nível acima do 1
	Requests = {
		{
			Kind = "CombRaro",
			Text = "Traga favos raros para o tesouro real",
			Goal = 2,
			Honey = 400,
			XP = 260,
		},
		{
			Kind = "CombMedio",
			Text = "Favos médios do bosque para os salões",
			Goal = 6,
			Honey = 260,
			XP = 160,
		},
		{
			Kind = "Nectar",
			Text = "Néctar fresco para o banquete da corte",
			Goal = 60,
			Honey = 220,
			XP = 130,
		},
		{
			Kind = "Mel",
			Text = "Encha os potes: entregue mel na sua colmeia",
			Goal = 300,
			Honey = 320,
			XP = 190,
		},
		{ Kind = "Comb", Text = "Favos de cera para reformar o palácio", Goal = 15, Honey = 240, XP = 140 },
	},
}

-- Recompensa diária: entre todo dia para aumentar a sequência (7 dias e repete).
Config.Daily = {
	UtcOffsetHours = -3, -- o "dia" vira à meia-noite de Brasília
	Honey = { 50, 75, 100, 150, 200, 300, 500 },
	XPPerDay = 25,
}

-- Colônias (clãs): grupos com nome. Mesma colônia não se ataca, e com outro
-- membro online cada entrega rende mais mel.
Config.Clan = {
	CreateCost = 100,
	NameMin = 3,
	NameMax = 16,
	MaxMembers = 8,
	HoneyBonus = 0.10, -- +10% de mel na entrega com outro membro no servidor
}

-- Ranking na praça do centro.
Config.Leaderboard = {
	Size = 10,
	Refresh = 5, -- segundos (ranking deste servidor)
	GlobalRefresh = 90, -- segundos (recordes de todos os servidores; precisa publicar)
	StoreName = "RankingMel_v1",
}

-- Sons: cole aqui IDs de áudio da Loja do Criador (ex.: "rbxassetid://123").
-- Vazio = sem som (o jogo funciona normalmente).
Config.Sounds = {
	Asas = "", -- zumbido em loop (volume acompanha a velocidade)
	Coleta = "",
	Entrega = "",
	Nivel = "",
	Dano = "",
	Clique = "",
	AmbienteDia = "", -- loop
	AmbienteNoite = "", -- loop
}

-- Nível e experiência ------------------------------------------------------
Config.Progression = {
	XP = {
		NectarPerUnit = 1,
		Comb = { Comum = 5, Medio = 15, Raro = 40 },
		CellCompleted = 60,
		HoneyDelivered = 0.2, -- XP por unidade de mel entregue
	},
	LevelBase = 100, -- XP do nível 1 para o 2
	LevelGrowth = 1.35, -- cada nível pede 35% a mais
	MaxLevel = 99,
}

-- Acessórios cosméticos (sem Robux; comprados com mel) -----------------------
Config.CosmeticOrder = { "Oculos", "Chapeu", "Lenco" }
Config.Cosmetics = {
	Oculos = { DisplayName = "Óculos de voo", Price = 150 },
	Chapeu = { DisplayName = "Chapéu", Price = 200 },
	Lenco = { DisplayName = "Lenço vermelho", Price = 120 },
}

-- Salvamento --------------------------------------------------------------
Config.Data = {
	DataStoreName = "ReinoDasAbelhas_v1",
	AutosaveInterval = 120,
	MaxRetries = 3,
}

-- Depuração ---------------------------------------------------------------
Config.Debug = {
	Verbose = true, -- logs extras no Output
}

return Config
