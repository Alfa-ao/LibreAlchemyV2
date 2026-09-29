--------------------------------------------------------------------------------
-- DebugService.lua
-- Сервис для управления отладочным логированием аддона.
-- Доболнительно создается log для упрощенности.
--------------------------------------------------------------------------------

Global( "DebugService", {} )

local _var_dump_exists = type( rawget( _G, "var_dump" ) ) == "function"

Global( "log", function( ... ) 
	( _var_dump_exists and var_dump or LogInfo )( ... )
end )

local _categories = {}

--------------------------------------------------------------------------------
--- @param categories table Таблица состояния категорий логирования (category - имя категории, значение - boolean).
--------------------------------------------------------------------------------
function DebugService.Init( categories )
	_categories = type( categories ) == "table" and categories or {}
	
	for category, _ in pairs( _categories ) do
        local methodName = "Log" .. category
        DebugService[ methodName ] = function( ... )
            DebugService.Log( category, ... )
        end
    end
end

--------------------------------------------------------------------------------
--- Включить или выключить конкретную категорию логирования.
--- @param category string имя категории
--- @param isEnabled boolean 
--------------------------------------------------------------------------------
function DebugService.SetEnabled( category, isEnabled )
	if _categories[category] ~= nil then
		_categories[category] = isEnabled
	end
end

--------------------------------------------------------------------------------
--- Проверка, включена ли указанная категория логирования.
--- @param category string Имя категории
--- @return boolean
--------------------------------------------------------------------------------
function DebugService.IsEnabled( category )
	return _categories[category] == true
end

--------------------------------------------------------------------------------
--- Преорбразовывает в строку и выводит её в лог.
--- @param category string Категория логирования
--- @param ... any
--------------------------------------------------------------------------------
function DebugService.Log( category, ... )
	if not DebugService.IsEnabled( category ) then
		return
	end
	
	local args = {}
	
	for i, v in ipairs { ... }  do
		if type( v ) == "function" then
			args[i] = v() -- Если дебаг блок в функции
		elseif not _var_dump_exists and apitype( v ) == "WString" then
			args[i] = string.format( "WString( %s )", userMods.FromWString( v ) )
		else
			args[i] = v
		end
	end
	
	log( table.unpack( args ) )
end