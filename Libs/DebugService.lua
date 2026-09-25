--------------------------------------------------------------------------------
-- DebugService.lua
-- Сервис для управления отладочным логированием аддона.
--------------------------------------------------------------------------------

Class( "DebugService" )

-- Use var_dump if exists
local VAR_DUMP_EXISTS = apitype( rawget( _G, "var_dump" ) ) == "function"

Global( "log", function( ... )
    if VAR_DUMP_EXISTS then
        var_dump( ... )
    else
        LogInfo( ... )
    end
end )

--------------------------------------------------------------------------------
--- Инициализация сервиса отладки.
--- @param categories table Таблица состояния категорий логирования (category - имя категории, значение - boolean).
--------------------------------------------------------------------------------
function DebugService:Init( categories )
	self._categories = type( categories ) == "table" and categories or {}
end

--------------------------------------------------------------------------------
--- Включить или выключить конкретную категорию логирования.
--- @param category string имя категории
--- @param isEnabled boolean 
--------------------------------------------------------------------------------
function DebugService:SetEnabled( category, isEnabled )
	if self._categories[category] ~= nil then
		self._categories[category] = isEnabled
	end
end

--------------------------------------------------------------------------------
--- Проверить, включена ли указанная категория логирования.
--- @param category string имя категории
--- @return boolean
--------------------------------------------------------------------------------
function DebugService:IsEnabled( category )
	return self._categories[category] == true
end

--------------------------------------------------------------------------------
--- Формирует строку сообщения и выводит её в лог.
--- @param category string категория логирования
--- @param ... any
--------------------------------------------------------------------------------
function DebugService:Log( category, ... )
	if not self:IsEnabled( category ) then
		return
	end
	
	local args = {}
	
	for i, v in ipairs { ... }  do
		if type( v ) == "function" then
			args[i] = v() -- Если дебаг блок в функции
		elseif not VAR_DUMP_EXISTS and apitype( v ) == "WString" then
			args[i] = string.format( "WString( %s )", userMods.FromWString( v ) )
		elseif not VAR_DUMP_EXISTS then
			args[i] = tostring( v )
		else
			args[i] = v
		end
	end
	
	log( table.unpack( args ) )
end