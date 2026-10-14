--[[
	LeaderboardService (servidor) — praça do centro e ranking de mel

	No centro da vila (entre as árvores-colmeia):
	- Praça redonda de madeira com uma fonte de mel brilhante.
	- Painel de dois lados:
	  · frente: "Este servidor" (mel total ganho de quem está jogando agora);
	  · verso: "Recordes" de todos os servidores (OrderedDataStore).
	Os recordes só funcionam com o jogo publicado e com acesso às APIs
	ligado; sem isso o verso mostra um aviso (e nada quebra).
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Levels = require(Shared.Levels)
local Log = require(Shared.Util.Log)

local PlayerDataService = require(script.Parent.PlayerDataService)
local WorldService = require(script.Parent.WorldService)

local LeaderboardService = {}

local GOLD = Color3.fromRGB(245, 190, 60)
local WOOD = Color3.fromRGB(140, 95, 55)
local DARK = Color3.fromRGB(70, 48, 30)

type Row = { Name: string, Value: number, Level: number?, Rebirths: number? }

local frontRows: { TextLabel } = {}
local backRows: { TextLabel } = {}
local backStatus: TextLabel
local orderedStore: OrderedDataStore? = nil
local nameCache: { [number]: string } = {}

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function cylinder(
	name: string,
	height: number,
	diameter: number,
	center: Vector3,
	color: Color3,
	parent: Instance
): Part
	local p = part(
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		parent
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if formatted:sub(1, 1) == "." then
		formatted = formatted:sub(2)
	end
	return formatted
end

-- Um lado do painel: título + linhas.
local function buildFace(board: BasePart, face: Enum.NormalId, title: string, rows: { TextLabel }): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(600, 400)
	gui.LightInfluence = 0.2
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(28, 22, 16)
	bg.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 6
	stroke.Parent = bg
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -40, 0, 56)
	header.Position = UDim2.fromOffset(20, 12)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBlack
	header.TextScaled = true
	header.TextColor3 = GOLD
	header.Text = title
	header.Parent = bg
	for i = 1, Config.Leaderboard.Size do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -60, 0, 28)
		row.Position = UDim2.fromOffset(30, 76 + (i - 1) * 31)
		row.BackgroundTransparency = 1
		row.Font = if i <= 3 then Enum.Font.GothamBold else Enum.Font.Gotham
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if i == 1
			then Color3.fromRGB(255, 215, 90)
			elseif i == 2 then Color3.fromRGB(220, 225, 235)
			elseif i == 3 then Color3.fromRGB(230, 160, 100)
			else Color3.fromRGB(250, 244, 230)
		row.Text = ""
		row.Parent = bg
		table.insert(rows, row)
	end
	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, -60, 0, 22)
	status.Position = UDim2.new(0, 30, 1, -30)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.TextScaled = true
	status.TextColor3 = Color3.fromRGB(200, 190, 170)
	status.Text = ""
	status.Parent = bg
	gui.Parent = board
	return status
end

local function render(rows: { TextLabel }, data: { Row })
	for i, label in rows do
		local entry = data[i]
		if entry then
			local medal = if i == 1 then "🥇" elseif i == 2 then "🥈" elseif i == 3 then "🥉" else `{i}.`
			local level = if entry.Level then `  · nv {entry.Level}` else ""
			if entry.Rebirths and entry.Rebirths > 0 then
				level ..= ` ⭐{entry.Rebirths}`
			end
			label.Text = `{medal}  {entry.Name}  —  {formatNumber(entry.Value)} mel{level}`
		else
			label.Text = ""
		end
	end
end

local function buildPlaza(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Praca"
	folder.Parent = parent

	local floor = cylinder("Praca", 1.2, 52, Vector3.new(0, 0.6, 0), WOOD, folder)
	floor.Material = Enum.Material.WoodPlanks
	local border = cylinder("Borda", 1.4, 54, Vector3.new(0, 0.5, 0), GOLD, folder)
	border.Material = Enum.Material.SmoothPlastic

	-- Fonte de mel: bacia, coluna, prato e jato.
	local basin = cylinder("Bacia", 3, 16, Vector3.new(0, 2.2, 0), Color3.fromRGB(200, 150, 70), folder)
	basin.Material = Enum.Material.Marble
	local honey =
		cylinder("MelDaFonte", 0.6, 14, Vector3.new(0, 3.6, 0), Color3.fromRGB(255, 170, 40), folder)
	honey.Material = Enum.Material.Neon
	honey.CanCollide = false
	cylinder("Coluna", 7, 2.4, Vector3.new(0, 7, 0), Color3.fromRGB(200, 150, 70), folder).Material =
		Enum.Material.Marble
	local plate = cylinder("Prato", 1, 7, Vector3.new(0, 10.5, 0), GOLD, folder)
	plate.Reflectance = 0.2
	local jet = part("Jato", Vector3.one, CFrame.new(0, 11.5, 0), Color3.new(1, 1, 1), folder)
	jet.Transparency = 1
	jet.CanCollide = false
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(255, 185, 50))
	spray.LightEmission = 0.6
	spray.Rate = 40
	spray.Lifetime = NumberRange.new(1, 1.4)
	spray.Speed = NumberRange.new(9, 12)
	spray.SpreadAngle = Vector2.new(18, 18)
	spray.Acceleration = Vector3.new(0, -24, 0)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	spray.Parent = jet
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 190, 80)
	glow.Range = 30
	glow.Brightness = 1.5
	glow.Parent = honey

	-- Painel de dois lados, de frente para quem vem da direção +Z.
	local boardCF = CFrame.new(0, 13, 18)
	for side = -1, 1, 2 do
		part("Poste", Vector3.new(1.6, 24, 1.6), CFrame.new(side * 16, 12, 18), DARK, folder)
	end
	local board = part("Painel", Vector3.new(30, 20, 1), boardCF, DARK, folder)
	local roof = part("Telhado", Vector3.new(34, 1.4, 4), boardCF * CFrame.new(0, 10.8, 0), GOLD, folder)
	roof.Reflectance = 0.1

	-- Front = -Z (vê quem está na fonte); Back = +Z.
	local frontStatus = buildFace(board, Enum.NormalId.Front, "🏆 Mais mel · este servidor", frontRows)
	frontStatus.Text = "Mel total ganho de quem está jogando agora"
	backStatus = buildFace(board, Enum.NormalId.Back, "🌍 Recordes de todos os servidores", backRows)
	backStatus.Text = "Carregando…"
end

local function refreshServer()
	local data: { Row } = {}
	for _, player in Players:GetPlayers() do
		if PlayerDataService.IsLoaded(player) then
			local profile = PlayerDataService.Get(player)
			table.insert(data, {
				Name = player.DisplayName,
				Value = profile.HoneyEarned,
				Level = (Levels.FromXP(profile.XP)),
				Rebirths = profile.Rebirths,
			})
		end
	end
	table.sort(data, function(a, b)
		return a.Value > b.Value
	end)
	render(frontRows, data)
end

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and type(name) == "string" then name else `Abelha {userId}`
	nameCache[userId] = result
	return result
end

local function pushScores()
	local store = orderedStore
	if not store then
		return
	end
	for _, player in Players:GetPlayers() do
		if PlayerDataService.IsLoaded(player) then
			local value = math.floor(PlayerDataService.Get(player).HoneyEarned)
			if value > 0 then
				pcall(function()
					store:SetAsync(tostring(player.UserId), value)
				end)
			end
		end
	end
end

local function refreshGlobal()
	local store = orderedStore
	if not store then
		backStatus.Text = "Publique o jogo e ligue o acesso às APIs para ver os recordes."
		return
	end
	pushScores()
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, Config.Leaderboard.Size)
	end)
	if not ok or not pages then
		backStatus.Text = "Recordes indisponíveis agora."
		return
	end
	local data: { Row } = {}
	for _, entry in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(data, { Name = nameFor(userId), Value = entry.value })
		end
	end
	render(backRows, data)
	backStatus.Text = "Atualiza a cada minuto e meio"
end

function LeaderboardService:Init() end

function LeaderboardService:Start()
	buildPlaza(WorldService.GetMap().Folder)
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.Leaderboard.StoreName)
	end)
	if ok then
		orderedStore = store
	end

	task.spawn(function()
		while true do
			refreshServer()
			task.wait(Config.Leaderboard.Refresh)
		end
	end)
	task.spawn(function()
		task.wait(10)
		while true do
			refreshGlobal()
			task.wait(Config.Leaderboard.GlobalRefresh)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local store = orderedStore
		if store and PlayerDataService.IsLoaded(player) then
			local value = math.floor(PlayerDataService.Get(player).HoneyEarned)
			if value > 0 then
				pcall(function()
					store:SetAsync(tostring(player.UserId), value)
				end)
			end
		end
	end)
	Log.info("LeaderboardService", "praça e ranking prontos")
end

return LeaderboardService
