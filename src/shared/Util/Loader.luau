--!strict
--[[
	Loader — inicia módulos em duas fases, na ordem informada.

	1. Init(): prepara estado; não depende de outros módulos rodando.
	2. Start(): liga conexões e loops; todos já passaram por Init.

	Um erro em um módulo é registrado e os outros continuam,
	para o jogo não travar inteiro por causa de uma parte.
]]

local Log = require(script.Parent.Log)

export type Module = {
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
}

local Loader = {}

function Loader.Run(tag: string, folder: Instance, order: { string }): { [string]: Module }
	local modules: { [string]: Module } = {}

	for _, name in order do
		local moduleScript = folder:FindFirstChild(name)
		if not moduleScript or not moduleScript:IsA("ModuleScript") then
			Log.warn(tag, `módulo não encontrado: {name}`)
			continue
		end
		local ok, result = pcall(require, moduleScript)
		if ok then
			modules[name] = result :: Module
		else
			Log.warn(tag, `erro ao carregar {name}:`, result)
		end
	end

	for _, phase in { "Init", "Start" } do
		for _, name in order do
			local module = modules[name]
			local fn = module and (module :: any)[phase]
			if fn then
				local ok, err = pcall(fn, module)
				if not ok then
					Log.warn(tag, `{name}:{phase} falhou:`, err)
				end
			end
		end
	end

	Log.info(tag, `{#order} módulos iniciados`)
	return modules
end

return Loader
