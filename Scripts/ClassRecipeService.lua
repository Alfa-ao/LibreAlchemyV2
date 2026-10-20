--------------------------------------------------------------------------------
--[[
ClassRecipeService.lua - Сервис для работы с рецептами алхимии. 
Отвечает за кэширование списка всех доступных рецептов, фильтрацию по имеющимся компонентам и подсчет возможных рецептов.

Класс RecipeService реализует следующие методы:
	self.CreateRecipeCache	- Создание кэша с полным списком всех доступных рецептов.
	self.IsRecipeMatch		- Проверяет, соответствуют ли доступные компоненты требованиям конкретного рецепта.
	self.FilterByComponents - Фильтрует кэш рецептов, оставляя те, которые соответвуют по уникальным компонентам, без учета коррекций.
	self.CountPotential		- Считает количество возможных рецептов на основе, какие травы положены в слоты, без учета коррекций.
	self.BuildDrumShiftMap	- Метод для SearchService:FindBestRecipes
	self.ResetRecipeCache	- Сброс кэша рецептов.
]]
--------------------------------------------------------------------------------

Class( "RecipeService" )

-- [I] Сбор компонентов из барабанов.
local function collectDrumComponents( includeShifts, maxCorrections, drumsCount, drumSize )
    local availableComponents = {}
    local filledDrumsCount = 0
    local drumShiftMap = includeShifts and {} or nil
    
    for drumIdx = 0, drumsCount - 1 do
        if includeShifts then
            drumShiftMap[ drumIdx + 1 ] = {}
        end
        
        local drumInfo = avatar.GetAlchemyDrumInfo( drumIdx )
        if drumInfo and drumInfo.itemId ~= nil then
            filledDrumsCount = filledDrumsCount + 1
            local seenInDrum = {}
            local basePos = drumInfo.position or 0
            
            if includeShifts then
                for shift = -maxCorrections, maxCorrections do
                    local targetIndex = ( basePos + shift ) % drumSize
                    local comp = drumInfo.components[ targetIndex ]
                    drumShiftMap[ drumIdx + 1 ][ shift ] = comp
                    seenInDrum[ comp ] = true
                end
            else
                for _, comp in pairs( drumInfo.components ) do
                    seenInDrum[ comp ] = true
                end
            end
            
            for comp, _ in pairs( seenInDrum ) do
                availableComponents[ comp ] = ( availableComponents[ comp ] or 0 ) + 1
            end
        end
    end
    
    return availableComponents, filledDrumsCount, drumShiftMap
end

--------------------------------------------------------------------------------
function RecipeService:CreateRecipeCache()
    if self._recipeCache then
        return
    end
    
    self._recipeCache = {}
    local alchemyInfo = avatar.GetAlchemyInfo()
    
    self._drumsCount = alchemyInfo.drumsCount
    self._drumSize = alchemyInfo.drumSize
    
    for _, recipeId in pairs( alchemyInfo.recipes ) do
        local recipeInfo = avatar.GetRecipeInfo( recipeId )
        if recipeInfo then
            local recipe = {
				componentsCount = 0,      -- Общее количество компонентов, требуемых рецептом.
				name = recipeInfo.name,   -- Локализованное имя зелья/рецепта.
				score = recipeInfo.score, -- Необходимый уровень умения для крафта.
				requiredComponents = {},  -- Хеш-таблица требуемых компонентов: { ["Имя(userdata)"] = кол-во }.
            }
            
            for _, componentProperty in pairs( recipeInfo.components ) do
                recipe.requiredComponents[ componentProperty ] = ( recipe.requiredComponents[ componentProperty ] or 0 ) + 1
                recipe.componentsCount = recipe.componentsCount + 1
            end
            
            self._recipeCache[ #self._recipeCache + 1 ] = recipe
        end
    end
end

--------------------------------------------------------------------------------
--- @param recipe table структура рецепта из кэша self._recipeCache[].recipe.
--- @param availableComponents table хеш-таблица доступных компонентов { ["Имя(userdata)"] = кол-во }.
--- @param filledSlotsCount number количество заполненных слотов в ступке.
--- @return boolean
--------------------------------------------------------------------------------
function RecipeService:IsRecipeMatch( recipe, availableComponents, filledSlotsCount )
	if CONFIG.REQUIRED_COMPONENTS_COUNT and recipe.componentsCount ~= filledSlotsCount then
		return false
	end
	
	for componentProperty, neededCount in pairs( recipe.requiredComponents ) do
		-- Если доступного компонента меньше, чем требуется
		if ( availableComponents[ componentProperty ] or 0 ) < neededCount then
			return false
		end
	end
	
	return true
end

--------------------------------------------------------------------------------
--- @param availableComponents table Хеш-таблица доступных компонентов.
--- @param filledDrumsCount number Общее количество заполненных барабанов.
--- @return table filteredRecipes Массив подходящих рецептов.
--- @return number count Количество найденных рецептов.
--------------------------------------------------------------------------------
function RecipeService:FilterByComponents( availableComponents, filledDrumsCount )
    self:CreateRecipeCache()
    local filteredRecipes = {}
    local count = 0
	
    for _, recipe in pairs( self._recipeCache ) do
        if self:IsRecipeMatch( recipe, availableComponents, filledDrumsCount ) then
            filteredRecipes[ #filteredRecipes + 1 ] = recipe
            count = count + 1
        end
    end
	
    return filteredRecipes, count
end

--------------------------------------------------------------------------------
--- @return integer potentialCount количество возможных рецептов
--- @return integer filledDrumsCount количество заполненных слотов
--------------------------------------------------------------------------------
function RecipeService:CountPotential()
    self:CreateRecipeCache()
    
    local availableComponents, filledDrumsCount = collectDrumComponents( false, 0, self._drumsCount, self._drumSize )
    local potentialCount = 0
    
    for _, recipe in ipairs( self._recipeCache ) do
        if self:IsRecipeMatch( recipe, availableComponents, filledDrumsCount ) then
            potentialCount = potentialCount + 1
        end
    end
    
    return potentialCount, filledDrumsCount
end

--------------------------------------------------------------------------------
--- @return table drumShiftMap Карта сдвигов.
--- @return table availableComponents Хеш-таблица доступных компонентов.
--- @return number totalDrumsCount Общее количество заполненных барабанов.
--------------------------------------------------------------------------------
function RecipeService:BuildDrumShiftMap( maxCorrections )
    local availableComponents, totalDrumsCount, drumShiftMap = collectDrumComponents( 
        true, maxCorrections, self._drumsCount, self._drumSize
    )
    
    return drumShiftMap, availableComponents, totalDrumsCount
end

--------------------------------------------------------------------------------
function RecipeService:ResetRecipeCache()
    self._recipeCache = nil
end