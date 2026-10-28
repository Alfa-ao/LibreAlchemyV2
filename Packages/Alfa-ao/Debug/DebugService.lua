--------------------------------------------------------------------------------
-- DebugService.lua
-- Сервис для управления отладочным логированием аддона.
-- Дополнительно создается log для упрощенности.
--[[

local config = { DEBUG = false, DEBUG_REACTION = true }

-- Создаются две функции: DebugService.LogGeneral и DebugService.LogReaction
DebugService:Init { General = config.DEBUG, Reaction = config.DEBUG_REACTION }

-- Вывод в mods.txt
DebugService.LogGeneral( 111, mainForm ) -- игнорируется
DebugService.LogReaction( 222 ) -- выведет: 222


-- Дополнительно для быстроты и удобства:
log( 111, 222, {}, mainForm )

]]
--------------------------------------------------------------------------------

Global( "DebugService", {} )



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
function DebugService:Init( categories )
	self._categories = type( categories ) == "table" and categories or {}
	
	for category, _ in pairs( self._categories ) do
        local methodName = "Log" .. category
        DebugService[ methodName ] = function( ... )
            DebugService:Log( category, ... )
        end
    end
	
	advEvent.RegisterEventHandlers( false, self:GetEventHandlers() )
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
--- Проверка, включена ли указанная категория логирования.
--- @param category string Имя категории
--- @return boolean
--------------------------------------------------------------------------------
function DebugService:IsEnabled( category )
	return self._categories[category] == true
end



--------------------------------------------------------------------------------
--- Преорбразовывает в строку и выводит её в лог.
--- @param category string Категория логирования
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
		elseif not ( _console_api or _var_dump_exists ) and apitype( v ) == "WString" then
			args[i] = string.format( "WString( %s )", FromWs( v ) )
		else
			args[i] = v
		end
	end
	
	log( table.unpack( args ) )
end



--------------------------------------------------------------------------------
--- @return table handlers
--------------------------------------------------------------------------------
function DebugService:GetEventHandlers()
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