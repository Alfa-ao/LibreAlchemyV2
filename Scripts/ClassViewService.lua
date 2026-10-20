--------------------------------------------------------------------------------
--[[
ClassViewService.lua - Сервис для управления GUI.

Класс ViewService реализует следующие методы:
    self.Init
    self.ScheduleResetMessageType - Планирование сброса типа сообщения к нормальному режиму.
    self.ShowGreetings        - Вывод приветственного сообщения или "С возвращением!".
    self.ShowPotentialRecipes - Вывод статуса компонентов и количества возможных рецептов.
    self.ShowReactionResults  - Вывод результатов реакции в текстовый контейнер.
    self.ShowCongratulation   - Вывод сообщения поздравления.
    self.ShowItemTaken        - Вывод сообщения о получении предмета игроком.
    self.FormatResults        - Форматирование списка найденных рецептов для отображения.
    self.ResultsForLog        - Форматирование списка найденных рецептов для вывода в лог.
    self.UpdateCenterPanel    - Центрирование панели с текстовой подсказкой.
    self.CancelDelayedCalls   - Отмена отложенных вызовов при закрытии окна.
]]
--------------------------------------------------------------------------------

Class( "ViewService", {
    messageType = CONFIG.MESSAGE_GREETINGS, -- number Изначальный тип сообщения.
    _taskRefResetMessageType = nil
} )

--------------------------------------------------------------------------------
--- @param localization string Локализация "eng", "rus".
--- @param gui table ClassGUI
--------------------------------------------------------------------------------
function ViewService:Init( localization, gui )
    self._localization = localization
    self._gui = gui
    
    gui:PosCenterPanel()
end

--------------------------------------------------------------------------------
function ViewService:ScheduleResetMessageType()
    if self.messageType == CONFIG.MESSAGE_NORMAL then
        return
    end
    
    self:CancelDelayedCalls()

    self._taskRefResetMessageType = common.DelayedCall( CONFIG.DELAY_MS_UPDATE, function()
        self.messageType = CONFIG.MESSAGE_NORMAL
        self._taskRefResetMessageType = nil
        
        DebugService.LogGeneral( "MESSAGE_TYPE change to default: <MESSAGE_NORMAL>" )
    end )
end

--------------------------------------------------------------------------------
function ViewService:ShowGreetings()
    if self.messageType == CONFIG.MESSAGE_WELCOME_BACK then
        self._gui:SetLines( GetAddonText( self._localization, "WELCOME_BACK" ) )
    elseif self.messageType == CONFIG.MESSAGE_GREETINGS then
        self._gui:SetLines( GetAddonText( self._localization, "GREETINGS" ) )
    end
end

--------------------------------------------------------------------------------
--- Показывает статус компонентов и количество возможных рецептов.
--- @param countRecipe number Количество найденных рецептов.
--- @param filledSlotsCount number Количество заполненных слотов.
--------------------------------------------------------------------------------
function ViewService:ShowPotentialRecipes( countRecipe, filledSlotsCount )
    if countRecipe > 0 then
        local vtCountRecipes = common.CreateValuedText {
            format = GetAddonText( self._localization, "COUNT_RECIPES" ),
            count  = countRecipe,
        }
        self._gui:SetLines( vtCountRecipes )
    elseif filledSlotsCount > 0 then
        self._gui:SetLines( GetAddonText( self._localization, "COMPONENTS_NOT_READY" ) )
    else
        self._gui:SetLines( GetAddonText( self._localization, "NOT_FOUND_RECIPES" ) )
    end
end

--------------------------------------------------------------------------------
--- Показывает результаты реакции (варки).
--- @param foundResults table Результаты поиска.
--- @param maxDisplay number Максимум строк для отображения.
--- @param drumsCount number Кол-во барабанов.
--------------------------------------------------------------------------------
function ViewService:ShowReactionResults( foundResults, maxDisplay, drumsCount )
    if #foundResults == 0 then
        self._gui:SetLines( GetAddonText( self._localization, "RESULT_GIBBERISH" ) )
    else
        local linesData = self:FormatResults( foundResults, maxDisplay, drumsCount )
        self._gui:SetLines( table.unpack( linesData ) )
    end
end

--------------------------------------------------------------------------------
function ViewService:ShowCongratulation()
    self._gui:SetLines( GetAddonText( self._localization, "CONGRATULATION" ) )
end

--------------------------------------------------------------------------------
--- @param potionName string Имя зелья.
--- @param count number Количество предметов.
--------------------------------------------------------------------------------
function ViewService:ShowItemTaken( potionName, count )
    local vtItem = common.CreateValuedText {
        format = GetAddonText( self._localization, "AVATAR_ITEM_TAKEN" ),
        name   = potionName,
        count  = count,
        class1 = "alchemy-yellow-text",
    }
    
    self._gui:SetLines( vtItem )
end

--------------------------------------------------------------------------------
--- @param found table массив найденных результатов (см. SearchService:FindBestRecipes).
--- @param maxDisplay number максимальное количество строк для отображения (ТОП-N).
--- @param drumsCount number количество барабанов (для вывода сдвигов).
--- @return table linesData { ValuedText, ... }
--------------------------------------------------------------------------------
function ViewService:FormatResults( found, maxDisplay, drumsCount )
	table.sort( found, function( a, b )
		if a.recipe.score == b.recipe.score then
			return a.recipe.name > b.recipe.name
		end
		return a.recipe.score > b.recipe.score
	end )
	
    -- Имя текущего зелья
    local currentRecipeName = self._gui:GetCurrentRecipeName()
	-- Шаблон строки рецепта "level: N |N |N |N |N - name"
    local recipeLineFormat = GetAddonText( "template", "RECIPE_LINE" )
	-- Создание строк для ТОП-N рецептов
	local linesData = {}
    for i = 1, math.min( #found, maxDisplay ) do
        local foundResult = found[ i ]
        -- Таблица значений для подстановки в основной шаблон
        local textValues = {
            format = recipeLineFormat,
            level  = foundResult.recipe.score,
            name   = foundResult.recipe.name,
            class1 = currentRecipeName == foundResult.recipe.name and "alchemy-yellow-text" or nil
        }
        
        for drumIndex = 1, drumsCount do
			-- Форматируется сдвиг для отображения "% d" = " 1" or "-1". Функция не умеет работать с подобными форматами:
            -- common.FormatInt( -foundResult.shifts[ drumIndex ], "% d" )
            -- Бьётся: "UI::LuaCommonFormatInt: РфQx"
            textValues[ "bulb" .. drumIndex ] = ToWs( string.format( "% d", -foundResult.shifts[ drumIndex ] ) )
        end
		
        linesData[ #linesData + 1 ] = common.CreateValuedText( textValues )
    end
    
    return linesData
end

--------------------------------------------------------------------------------
--- @param found table массив найденных результатов (recipe и shifts).
--- @param maxDisplay number максимальное количество строк для отображения (ТОП-N).
--- @param drumsCount number количество барабанов (для вывода сдвигов).
--- @return string
--------------------------------------------------------------------------------
function ViewService:ResultsForLog( found, maxDisplay, drumsCount )
	local parts = {}
	
	for i = 1, math.min( #found, maxDisplay ) do
		local foundResult = found[ i ]
		
		local logStr = string.format( "%d,%d", foundResult.recipe.score, -foundResult.shifts[ 1 ] )
		
		for drumIndex = 2, drumsCount do
			logStr = logStr .. string.format( ",%d", -foundResult.shifts[ drumIndex ] )
		end
		
		logStr = logStr .. "," .. FromWs( foundResult.recipe.name )
		parts[ #parts + 1 ] = logStr
	end
	
	return "EVENT_ALCHEMY_REACTION_FINISHED:" .. table.concat( parts, "|" )
end

--------------------------------------------------------------------------------
function ViewService:CancelDelayedCalls()
    if self._taskRefResetMessageType then
        common.CancelDelayedCall( self._taskRefResetMessageType )
        self._taskRefResetMessageType = nil
    end
end