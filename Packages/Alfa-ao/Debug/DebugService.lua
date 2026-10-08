--------------------------------------------------------------------------------
-- DebugService.lua
-- Сервис для управления отладочным логированием аддона.
-- Дополнительно создается log для упрощенности.
--[[

local config = { DEBUG = false, DEBUG_REACTION = true }

-- Создаются две функции: DebugService.LogGeneral и DebugService.LogReaction
DebugService.Init { General = config.DEBUG, Reaction = config.DEBUG_REACTION }

-- Вывод в mods.txt
DebugService.LogGeneral( 111, _G.mainForm ) -- игнорируется
DebugService.LogReaction( 222 ) -- выведет: 222


-- Дополнительно для быстроты и удобства:
log( 111, 222, {}, _G.mainForm )

]]
--------------------------------------------------------------------------------

Global( "DebugService", {} )

local _categories = {}



-- Подключена ли библиотека (var_dump).
local _var_dump_exists = type( rawget( _G, "var_dump" ) ) == "function"

local _oldOptionReturnDump = _var_dump_exists and __CONFIG_VAR_DUMP.DEBUG.returnDump or false

-- Активация Console инструмента. Автоматически переключается.
local _console_api = false

-- [P] Дополнительная функция log( ... ). Можно юзать везде для удобства.
Global( "log", function( ... )
	if _console_api then
		common.SendEvent( "CONSOLE_USERADDON_SEND_DATA", {
			data = _var_dump_exists and var_dump( ... ) or { ... },
			action = "highlight"
		} )
	else
		( _var_dump_exists and var_dump or LogInfo )( ... )
	end
end )



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
	advEvent.RegisterEventHandlers( false, DebugService.GetActiveEventHandlers() )
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
		elseif not ( _console_api or _var_dump_exists ) and apitype( v ) == "WString" then
			args[i] = string.format( "WString( %s )", userMods.FromWString( v ) )
		else
			args[i] = v
		end
	end
	
	log( table.unpack( args ) )
end



--------------------------------------------------------------------------------
--- @return table handlers
--------------------------------------------------------------------------------
function DebugService.GetActiveEventHandlers()
    return {
        {
            function()
                _console_api = true
				
				if _var_dump_exists then
					__CONFIG_VAR_DUMP.DEBUG.returnDump = true
				end
            end,
            "CONSOLE_USERADDON_SEND_PING"
        },
		{
            function()
                _console_api = false
				
				if _var_dump_exists then
					__CONFIG_VAR_DUMP.DEBUG.returnDump = _oldOptionReturnDump
				end
            end,
            "CONSOLE_USERADDON_DISABLE"
        },
    }
end