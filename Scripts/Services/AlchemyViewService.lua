--------------------------------------------------------------------------------
-- Services/AlchemyViewService.lua
-- Сервис для управления GUI (View слой).
-- Форматирует и выводит сообщения в текстовый контейнер.
--------------------------------------------------------------------------------
Class( "AlchemyViewService" )

--------------------------------------------------------------------------------
--- @param context table
--------------------------------------------------------------------------------
function AlchemyViewService:Init( context )
    self._alchemy = context.alchemy
    self._textContainer = context.textContainer
    self._state = context.state
end

--------------------------------------------------------------------------------
--- Показывает GREETINGS / WELCOME_BACK сообщение.
--- @param messageType number CONFIG.MESSAGE_*
--------------------------------------------------------------------------------
function AlchemyViewService:ShowGreetings( messageType )
    if messageType == CONFIG.MESSAGE_WELCOME_BACK then
        self._textContainer:SetLines( GetAddonText( self._state.localization, "WELCOME_BACK" ) )
    elseif messageType == CONFIG.MESSAGE_GREETINGS then
        self._textContainer:SetLines( GetAddonText( self._state.localization, "GREETINGS" ) )
    end
end

--------------------------------------------------------------------------------
--- Показывает статус компонентов и количество возможных рецептов.
--- @param countRecipe number Количество найденных рецептов.
--- @param filledSlotsCount number Количество заполненных слотов.
--------------------------------------------------------------------------------
function AlchemyViewService:ShowPotentialRecipes( countRecipe, filledSlotsCount )
    if countRecipe > 0 then
        local vtCountRecipes = common.CreateValuedText {
            format = GetAddonText( self._state.localization, "COUNT_RECIPES" ),
            count  = countRecipe,
        }
        self._textContainer:SetLines( vtCountRecipes )
    elseif filledSlotsCount > 0 then
        self._textContainer:SetLines( GetAddonText( self._state.localization, "COMPONENTS_NOT_READY" ) )
    else
        self._textContainer:SetLines( GetAddonText( self._state.localization, "NOT_FOUND_RECIPES" ) )
    end
end

--------------------------------------------------------------------------------
--- Показывает результаты реакции (варки).
--- @param foundResults table Результаты поиска.
--- @param maxDisplay number Максимум строк для отображения.
--- @param drumsCount number Кол-во барабанов.
--------------------------------------------------------------------------------
function AlchemyViewService:ShowReactionResults( foundResults, maxDisplay, drumsCount )
    if #foundResults == 0 then
        self._textContainer:SetLines( GetAddonText( self._state.localization, "RESULT_GIBBERISH" ) )
    else
        local linesData = self:FormatResults( foundResults, maxDisplay, drumsCount )
        self._textContainer:SetLines( table.unpack( linesData ) )
    end
end

--------------------------------------------------------------------------------
--- Показывает поздравление с изменением списка рецептов.
--------------------------------------------------------------------------------
function AlchemyViewService:ShowCongratulation()
    self._textContainer:SetLines( GetAddonText( self._state.localization, "CONGRATULATION" ) )
end

--------------------------------------------------------------------------------
--- Показывает сообщение о получении предмета (для аватара).
--- @param potionName string Имя зелья.
--- @param count number Количество предметов.
--------------------------------------------------------------------------------
function AlchemyViewService:ShowItemTaken( potionName, count )
    local vtItem = common.CreateValuedText {
        format = GetAddonText( self._state.localization, "AVATAR_ITEM_TAKEN" ),
        name   = potionName,
        count  = count,
        class1 = "alchemy-yellow-text",
    }
    
    self._textContainer:SetLines( vtItem )
end

--------------------------------------------------------------------------------
--- Форматируется список найденных рецептов в общий ValuedText.
--- Результаты сортируются по убыванию уровня умения (score), при равенстве: по имени.
--- @param found table массив найденных результатов (см. AlchemySearchService:FindBestRecipes).
--- @param maxDisplay number максимальное количество строк для отображения (ТОП-N).
--- @param drumsCount number количество барабанов (для вывода сдвигов).
--- @return table linesData { ValuedText, ... }
--------------------------------------------------------------------------------
function AlchemyViewService:FormatResults( found, maxDisplay, drumsCount )
	-- Сортировка: сначала по уровню (score) убывания, затем по имени (name) убывания
	table.sort( found, function( a, b )
		if a.recipe.score == b.recipe.score then
			return a.recipe.name > b.recipe.name
		end
		return a.recipe.score > b.recipe.score
	end )
	
    -- Имя текущего зелья
    local currentRecipeName = self._alchemy:GetCurrentRecipeName()
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
            textValues[ "bulb" .. drumIndex ] = userMods.ToWString( string.format( "% d", -foundResult.shifts[ drumIndex ] ) )
        end
		
        table.insert( linesData, common.CreateValuedText( textValues ) )
    end
    
    return linesData
end

--------------------------------------------------------------------------------
--- Тоже самое что и FormatResults, но для дебага.
--- Формат записи: EVENT_ALCHEMY_REACTION_FINISHED:123,1,-1,0,0,0,зелье|123,...
--- @param found table массив найденных результатов (recipe и shifts).
--- @param maxDisplay number максимальное количество строк для отображения (ТОП-N).
--- @param drumsCount number количество барабанов (для вывода сдвигов).
--- @return string
--------------------------------------------------------------------------------
function AlchemyViewService:ResultsForLog( found, maxDisplay, drumsCount )
	local parts = {}
	
	for i = 1, math.min( #found, maxDisplay ) do
		local foundResult = found[ i ]
		
		local logStr = string.format( "%d,%d", foundResult.recipe.score, -foundResult.shifts[ 1 ] )
		
		for drumIndex = 2, drumsCount do
			logStr = logStr .. string.format( ",%d", -foundResult.shifts[ drumIndex ] )
		end
		
		logStr = logStr .. "," .. userMods.FromWString( foundResult.recipe.name )
		table.insert( parts, logStr )
	end
	
	return "EVENT_ALCHEMY_REACTION_FINISHED:" .. table.concat( parts, "|" )
end

--------------------------------------------------------------------------------
--- Центрирует панель с подсказкой.
--------------------------------------------------------------------------------
function AlchemyViewService:UpdateCenterPanel()
    self._textContainer:UpdateCenterPanel()
end