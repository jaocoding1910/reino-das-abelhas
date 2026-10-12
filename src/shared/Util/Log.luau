--!strict
-- Log — prints padronizados com prefixo do módulo. Liga/desliga em Config.Debug.

local Config = require(script.Parent.Parent.Config)

local Log = {}

function Log.info(tag: string, ...: any)
	if Config.Debug.Verbose then
		print(`[Abelhas:{tag}]`, ...)
	end
end

function Log.warn(tag: string, ...: any)
	warn(`[Abelhas:{tag}]`, ...)
end

return Log
