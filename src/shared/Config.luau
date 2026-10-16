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
	InteractTime = 0.5, -- segundos segurando para coletar
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

-- Objetivo de longo prazo: título Rei/Rainha da Colmeia (salvo no perfil).
-- O progresso é a média das quatro metas (cada uma limitada a 100%).
Config.Crown = {
	Level = 20,
	Cells = 24,
	RareDelivered = 5,
	RoyalRequests = 3,
	RewardHoney = 2000,
}

-- Validação de deslocamento (anti teleporte para coleta remota).
-- Folga grande para não punir voo legítimo (arrancada, anéis, poções).
Config.Movement = {
	CheckInterval = 0.5,
	SpeedFactor = 3.4, -- × velocidade base × multiplicador do jogador
	Slack = 40, -- studs extras por verificação
	BlockSeconds = 2, -- coleta bloqueada depois de um salto suspeito
}

-- Cordilheira do horizonte (montada no cliente: SceneryController).
Config.Scenery = { Peaks = 24, RadiusMin = 1190, RadiusMax = 1260 }

-- Tour de apresentação (tecla T ou botão nas Configurações): a câmera passeia
-- pelos lugares principais com títulos na tela. Ótimo para gravar o vídeo.
Config.Tour = { ShotSeconds = 6.5, FadeSeconds = 0.6 }

-- Combo: coletar seguido (sem parar mais que Window segundos) dá néctar extra.
Config.Combo = {
	Window = 10, -- segundos para a próxima coleta manter o combo
	Max = 5, -- combo máximo (x5)
	NectarPerStep = 1, -- +1 néctar por degrau de combo (x5 = +4)
}

-- Entrega automática: chegou perto do pote com carga, entrega sozinho.
Config.AutoDeliver = { Distance = 16 }

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
	ShowLegs = false, -- (antigo) cilindros de pata; substituídos pelo Viewmodel
	Viewmodel = true,
	-- Pirueta lateral (duplo toque em A/D): giro de 360° com dash para o lado.
	RollDuration = 0.45,
	RollSpeed = 55, -- studs/s extras para o lado no início do giro
	RollStaminaCost = 20,
	RollCooldown = 0.8,
	RollDoubleTap = 0.3, -- segundos entre os dois toques -- patas peludas e carga na parte de baixo da tela (1ª pessoa)
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
	-- Penhascos com casinhas de favo, pontes e cachoeira (paisagem, sem coleta).
	-- O primeiro pilar de cada grupo é o mais alto (tem a cachoeira).
	CliffGroups = {
		{
			Center = Vector3.new(-900, 0, -150),
			Pillars = { Vector3.new(0, 0, 0), Vector3.new(55, 0, 95), Vector3.new(-25, 0, 185) },
		},
		{
			Center = Vector3.new(880, 0, 250),
			Pillars = { Vector3.new(0, 0, 0), Vector3.new(-40, 0, -100), Vector3.new(35, 0, -195) },
		},
	},
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
	NightRareChanceMultiplier = 2, -- favos raros renascem 2× mais rápido à noite
	NightRareHoneyBonus = 60, -- mel extra por favo raro ENTREGUE à noite
}

-- Saúde, derrota e penalidade ---------------------------------------------
Config.Health = {
	Max = 100,
	RespawnDelay = 5,
	SpawnProtection = 8, -- segundos; cancelado ao atacar
	DroppedCargoLifetime = 60,
	RegenPerSecondInSafeZone = 4, -- recupera vida em área protegida
}

-- Regra única de derrota: perde PARTE da carga (cai no chão para recuperar).
-- Colmeia, melhorias e mel depositado nunca são tocados.
Config.Defeat = {
	CargoLossFraction = 0.5, -- metade (arredondada para cima) de cada tipo carregado
}

-- Penalidade antiga na célula em construção: desligada (regra única acima).
Config.DeathPenalty = {
	Enabled = false,
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
Config.UpgradeOrder = { "Velocidade", "Capacidade", "Resistencia", "Sorte", "Folego" }

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
	-- Sorte: +6% de chance por nível de coletar em dobro.
	Sorte = {
		DisplayName = "Sorte",
		MaxLevel = 5,
		BaseCost = 120,
		CostGrowth = 1.7,
		BonusPerLevel = 0.06,
	},
	-- Fôlego: +20 de fôlego máximo da arrancada por nível.
	Folego = {
		DisplayName = "Fôlego",
		MaxLevel = 5,
		BaseCost = 90,
		CostGrowth = 1.6,
		BonusPerLevel = 20,
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
	{ Kind = "RaroEntregue", Goal = 1, Text = "Leve um favo raro até a sua colmeia", Honey = 150, XP = 200 },
	{ Kind = "Rainha", Goal = 1, Text = "Cumpra um pedido da Rainha", Honey = 180, XP = 220 },
	{ Kind = "Celula", Goal = 3, Text = "Expanda a colmeia", Honey = 200, XP = 250 },
	{ Kind = "Mel", Goal = 400, Text = "Encha a colmeia de mel", Honey = 250, XP = 300 },
}
Config.QuestRepeatFrom = 6
Config.QuestRepeatGrowth = 0.5 -- +50% na meta e na recompensa a cada volta

-- Arte: cores dos modelos 3D importados (o jogo recolore cada peça pelo nome).
-- Uma peça "Corpo_3" usa a entrada "Corpo".
Config.Art = {
	BeeYawDegrees = 180, -- o modelo do pacote olha para +Z; 180 deixa a cabeça na frente (-Z)
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

-- Poções do Besouro mercador (temporárias, compradas com mel) ----------------
Config.PotionOrder = { "Velocidade", "Dobro", "Mochila" }
Config.Potions = {
	Velocidade = {
		DisplayName = "Poção de Velocidade",
		Icon = "⚡",
		Description = "+30% de velocidade de voo",
		Price = 120,
		Duration = 180,
		SpeedBonus = 0.3,
	},
	Dobro = {
		DisplayName = "Néctar em Dobro",
		Icon = "🌼",
		Description = "Cada flor dá o dobro de néctar",
		Price = 150,
		Duration = 180,
		NectarMultiplier = 2,
	},
	Mochila = {
		DisplayName = "Mochila Extra",
		Icon = "🎒",
		Description = "+6 de espaço na carga",
		Price = 100,
		Duration = 240,
		CapacityBonus = 6,
	},
}

-- Trocas do Besouro: favos da CARGA viram mel ou poção.
Config.Trades = {
	{
		Id = "ComumMel",
		Text = "5 favos de cera → 70 mel",
		Rarity = "Comum",
		Amount = 5,
		Honey = 70,
		Potion = "",
	},
	{
		Id = "MedioPocao",
		Text = "3 favos médios → Poção de Velocidade",
		Rarity = "Medio",
		Amount = 3,
		Honey = 0,
		Potion = "Velocidade",
	},
	{
		Id = "RaroMel",
		Text = "1 favo raro → 300 mel",
		Rarity = "Raro",
		Amount = 1,
		Honey = 300,
		Potion = "",
	},
}
Config.Merchant = { TalkDistance = 40, Position = Vector3.new(-20, 4, -12) }

-- Evento: chuva de pólen (flores douradas dão mais néctar) -------------------
Config.Events = {
	FirstPollenAfter = 120, -- segundos depois do servidor abrir
	PollenInterval = 420, -- entre um evento e outro
	PollenDuration = 90,
	GoldenFlowers = 8,
	GoldenMultiplier = 3,
}

-- Mascotes: abelhinhas que seguem você (só visual) ---------------------------
Config.PetOrder = { "Dourada", "Azul", "Rosa" }
Config.Pets = {
	Dourada = { DisplayName = "Abelhinha Dourada", Price = 300, Color = Color3.fromRGB(255, 200, 40) },
	Azul = { DisplayName = "Abelhinha Azul", Price = 300, Color = Color3.fromRGB(90, 160, 255) },
	Rosa = { DisplayName = "Abelhinha Rosa", Price = 300, Color = Color3.fromRGB(255, 130, 190) },
}

-- Conquistas: Stat = contador salvo no perfil (profile.Stats) ----------------
Config.Achievements = {
	{
		Id = "PrimeiroNectar",
		Name = "Primeiro gole",
		Desc = "Colete néctar pela primeira vez",
		Icon = "🌼",
		Stat = "Nectar",
		Goal = 1,
		Honey = 20,
	},
	{
		Id = "Coletora",
		Name = "Coletora",
		Desc = "Colete 300 de néctar",
		Icon = "🍯",
		Stat = "Nectar",
		Goal = 300,
		Honey = 150,
	},
	{
		Id = "MestreNectar",
		Name = "Mestre do néctar",
		Desc = "Colete 3.000 de néctar",
		Icon = "🏆",
		Stat = "Nectar",
		Goal = 3000,
		Honey = 800,
	},
	{
		Id = "PrimeiroFavo",
		Name = "Favo na mão",
		Desc = "Colete um favo",
		Icon = "🔶",
		Stat = "Comb",
		Goal = 1,
		Honey = 20,
	},
	{
		Id = "CacadoraRaros",
		Name = "Caçadora de raros",
		Desc = "Colete 5 favos raros",
		Icon = "💎",
		Stat = "CombRaro",
		Goal = 5,
		Honey = 500,
	},
	{
		Id = "Construtora",
		Name = "Construtora",
		Desc = "Termine 5 células",
		Icon = "🔨",
		Stat = "Celula",
		Goal = 5,
		Honey = 200,
	},
	{
		Id = "Arquiteta",
		Name = "Arquiteta",
		Desc = "Termine 20 células",
		Icon = "🏛️",
		Stat = "Celula",
		Goal = 20,
		Honey = 1000,
	},
	{
		Id = "DoceFortuna",
		Name = "Doce fortuna",
		Desc = "Entregue 2.000 de mel",
		Icon = "💰",
		Stat = "Mel",
		Goal = 2000,
		Honey = 400,
	},
	{
		Id = "Turbinada",
		Name = "Turbinada",
		Desc = "Compre 5 melhorias",
		Icon = "⚡",
		Stat = "Melhoria",
		Goal = 5,
		Honey = 300,
	},
	{
		Id = "AmigaDaRainha",
		Name = "Amiga da Rainha",
		Desc = "Cumpra 3 pedidos da Rainha",
		Icon = "👑",
		Stat = "Rainha",
		Goal = 3,
		Honey = 600,
	},
	{
		Id = "Colonizadora",
		Name = "Colonizadora",
		Desc = "Entre ou funde uma colônia",
		Icon = "🐝",
		Stat = "Colonia",
		Goal = 1,
		Honey = 100,
	},
	{
		Id = "Freguesa",
		Name = "Freguesa",
		Desc = "Faça 3 trocas com o Besouro",
		Icon = "🐞",
		Stat = "Troca",
		Goal = 3,
		Honey = 200,
	},
}
Config.StatKeys = {
	"Nectar",
	"Comb",
	"CombMedio",
	"CombRaro",
	"Mel",
	"Celula",
	"Melhoria",
	"Rainha",
	"Colonia",
	"Troca",
	"RaroEntregue",
	"RaroNoturno",
}

-- Clima ------------------------------------------------------------------
-- Chuva: flores renascem mais rápido. Neblina: predadores enxergam menos.
Config.Weather = {
	MinDuration = 150,
	MaxDuration = 270,
	Chances = { Limpo = 0.6, Chuva = 0.25, Neblina = 0.15 },
	RainRespawnMultiplier = 0.5,
	FogPredatorVision = 0.6,
}

-- Lugares novos do bosque ----------------------------------------------------
Config.Places = {
	Cave = { Position = Vector3.new(-600, 0, 400), Radius = 42 },
	Lake = { Position = Vector3.new(600, 0, -320), Radius = 70 },
}

-- Libélulas do lago: patrulham em círculo e dão rasantes em linha reta.
Config.Predators.Libelula = {
	Count = 2,
	PatrolRadius = 45,
	PatrolHeight = 14,
	PatrolSpeed = 1.1, -- radianos por segundo
	DetectionRange = 60,
	TerritoryRadius = 110,
	AttackWindup = 0.8,
	DashSpeed = 120,
	DashOvershoot = 20,
	StrikeRadius = 7,
	AttackDamage = 18,
	AttackCooldown = 3,
	DayActivityMultiplier = 0.8,
	NightActivityMultiplier = 1.3,
}

-- Vespa Gigante: chefe que aparece à noite na Colmeia Real ------------------
Config.Boss = {
	BaseHealth = 250,
	HealthPerPlayer = 150,
	HitDamage = 15, -- dano de cada ataque de abelha (clique) na vespa
	HitRange = 18,
	AttackInterval = 4,
	AttackWindup = 1.2,
	DiveSpeed = 90,
	StrikeRadius = 9,
	AttackDamage = 30,
	TargetRange = 140,
	OrbitRadius = 60,
	OrbitHeight = 45,
	RewardHoney = 400,
	RewardXP = 250,
}

-- Colmeia que evolui: enfeites novos conforme as células prontas.
Config.HiveTiers = {
	{ Cells = 5, Name = "Potes dourados" },
	{ Cells = 12, Name = "Coroa da colmeia" },
	{ Cells = 24, Name = "Aura de mel" },
	{ Cells = 37, Name = "Colmeia lendária" },
}

Config.TutorialReward = 100

-- Configurações do jogador (salvas no perfil).
Config.DefaultSettings = {
	Music = true,
	MusicLevel = 0.6, -- 0 a 1 (volume dos ambientes)
	Sensitivity = 1, -- 0.5 a 2 (mouse)
	ReducedMotion = false, -- sem inclinação, sem FOV de velocidade, sem balanço
	Sfx = 0.8, -- 0 a 1
	Trail = true,
	CameraRoll = true,
	Quality = "Alta", -- "Alta" ou "Baixa"
	ThirdPerson = false, -- câmera atrás da abelha (tecla V)
}

-- Renascer: recomeça a colmeia em troca de um bônus de mel PERMANENTE.
Config.Rebirth = {
	MinLevel = 10,
	BaseCost = 3000, -- mel; o custo cresce a cada renascimento
	CostGrowth = 1.8,
	HoneyBonus = 0.25, -- +25% de mel por renascimento (entregas e produção)
}

-- Operárias contratadas: produzem mel sozinhas na sua colmeia.
Config.Workers = {
	Max = 10,
	BaseCost = 250,
	CostGrowth = 1.45,
	HoneyPerMinute = 3,
	StorageEach = 20,
}

-- Amigos: jogar com um amigo do Roblox no servidor rende mais mel.
Config.FriendBonus = 0.10

-- Missões diárias: 3 sorteadas por dia; o prêmio entra sozinho ao completar.
Config.DailyQuests = {
	Count = 3,
	Pool = {
		{ Kind = "Nectar", Text = "Colete 60 de néctar", Goal = 60, Honey = 150 },
		{ Kind = "Comb", Text = "Colete 10 favos", Goal = 10, Honey = 150 },
		{ Kind = "CombMedio", Text = "Colete 4 favos médios", Goal = 4, Honey = 200 },
		{ Kind = "Mel", Text = "Entregue 250 de mel", Goal = 250, Honey = 200 },
		{ Kind = "Celula", Text = "Termine 1 célula", Goal = 1, Honey = 180 },
		{ Kind = "Bau", Text = "Abra 2 baús do tesouro", Goal = 2, Honey = 200 },
		{ Kind = "Corrida", Text = "Complete a corrida de anéis", Goal = 1, Honey = 250 },
		{ Kind = "Troca", Text = "Faça 1 troca com o Besouro", Goal = 1, Honey = 120 },
	},
}

-- Códigos (digite nas Configurações). Chave em MAIÚSCULAS.
Config.Codes = {
	BEMVINDO = { Honey = 250 },
	ZUMBIDO = { Honey = 500 },
	ASAS = { Potion = "Velocidade" },
	FAVODEMEL = { Honey = 1000 },
}

-- Baús do tesouro escondidos pelo mapa (cada jogador abre de novo depois do tempo).
Config.Chests = {
	Count = 10,
	Cooldown = 20 * 60,
	MinHoney = 60,
	MaxHoney = 220,
	PotionChance = 0.2,
}

-- Ilha nas Nuvens: flores especiais (dão mais néctar) lá no alto.
Config.SkyIsland = {
	Position = Vector3.new(150, 200, 365), -- entre duas árvores-colmeia (caminho livre)
	Radius = 55,
	Flowers = 8,
	NectarMultiplier = 2,
}

-- Anéis de impulso: atravessar dá velocidade. Também formam a corrida
-- da praça até a Ilha nas Nuvens (na ordem).
Config.Rings = {
	Count = 12,
	Radius = 9,
	BoostMultiplier = 1.8,
	BoostDuration = 1.6,
	RaceHoney = 120,
	RaceCooldown = 10 * 60, -- prêmio de corrida no máximo a cada X segundos
	RaceTimeout = 90,
}

-- Flor arco-íris: aparece de vez em quando; quem pegar primeiro ganha muito néctar.
Config.Rainbow = {
	FirstAfter = 180,
	Interval = 300,
	Duration = 120,
	NectarMultiplier = 8,
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
Config.CosmeticOrder = { "Oculos", "Chapeu", "Lenco", "Coroa", "Aureola", "Laco" }
Config.Cosmetics = {
	Oculos = { DisplayName = "Óculos de voo", Price = 150 },
	Chapeu = { DisplayName = "Chapéu", Price = 200 },
	Lenco = { DisplayName = "Lenço vermelho", Price = 120 },
	Coroa = { DisplayName = "Coroa dourada", Price = 1500 },
	Aureola = { DisplayName = "Auréola de luz", Price = 900 },
	Laco = { DisplayName = "Laço rosa", Price = 250 },
}

-- Salvamento --------------------------------------------------------------
Config.Data = {
	DataStoreName = "ReinoDasAbelhas_v1",
	AutosaveInterval = 60,
	MaxRetries = 3,
	-- Trava de sessão: um perfil aberto em outro servidor há menos de
	-- SessionLockSeconds não é carregado para escrita (evita sobrescrever).
	SessionLockSeconds = 150,
	SessionWaitAttempts = 6, -- tentativas de 5 s esperando a outra sessão salvar
}

-- Depuração ---------------------------------------------------------------
Config.Debug = {
	Verbose = true, -- logs extras no Output
}

return Config
