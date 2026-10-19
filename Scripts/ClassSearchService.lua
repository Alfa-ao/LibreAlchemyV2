--------------------------------------------------------------------------------
--[[
ClassSearchService.lua - Сервис для поиска рецептов алхимии.
Анализирует компоненты в барабанах с учетом возможных сдвигов и поиск топовых подходящих рецептов.

Класс SearchService реализует следующие методы:
    self.Init
    self.FindBestRecipe      - Ищет лучший рецепт для конкретной карты из компонентов.
    self.FindBestRecipes     - Главный метод поиска: сбор данных, фильтрация и запуск алгоритма бэктрекинга.
    self.ExecuteBacktracking - Рекурсивный перебор возможных сдвигов по барабанам для поиска рецептов.
]]
--------------------------------------------------------------------------------

Class( "SearchService", {
    _foundSet = {},
    _drumsCount = 0,
    _maxCorrections = 0,
    _drumShiftMap = nil,
    _filteredRecipes = nil,
} )

-- [I] Добавление компонента по смещению
local function addComp( drumShiftMap, drumIdx, shift, offset, line )
    if not line then return nil end
    local comp = drumShiftMap[ drumIdx ][ shift + offset ]
    if comp then
        line[ comp ] = ( line[ comp ] or 0 ) + 1
        return comp
    end
    return nil
end

-- [I] Откат счётчика компонента
local function removeComp( line, comp )
    if not comp then return end
    line[ comp ] = line[ comp ] - 1
    if line[ comp ] == 0 then
        line[ comp ] = nil
    end
end

--------------------------------------------------------------------------------
--- @param recipeService table ClassRecipeService
--------------------------------------------------------------------------------
function SearchService:Init( recipeService )
    self._recipe = recipeService
end

--------------------------------------------------------------------------------
--- @return table drumRequiredComponents таблица уникальных компонентов по барабанам
--- @return number totalDrumsCount общее кол-во заполненных барабанов
--------------------------------------------------------------------------------
function SearchService:BuildDrumShiftMap()
    local drumRequiredComponents = {}
    AlchemyState.drumShiftMap = {}
    local totalDrumsCount = 0

    for drumIndex = 1, AlchemyState.drumsCount do
        AlchemyState.drumShiftMap[ drumIndex ] = {}
        local drumInfo = avatar.GetAlchemyDrumInfo( drumIndex - 1 )
        
        if drumInfo and drumInfo.itemId ~= nil then
            totalDrumsCount = totalDrumsCount + 1
            local uniqueDrumComponents = {}
            local basePos = drumInfo.position or 0
            
            for shift = -AlchemyState.maxCorrections, AlchemyState.maxCorrections do
                local targetIndex = ( basePos + shift ) % AlchemyState.drumSize
                local componentProperty = drumInfo.components[ targetIndex ]
                AlchemyState.drumShiftMap[ drumIndex ][ shift ] = componentProperty
                uniqueDrumComponents[ componentProperty ] = true
            end
            
            for componentProperty, _ in pairs( uniqueDrumComponents ) do
                drumRequiredComponents[ componentProperty ] = ( drumRequiredComponents[ componentProperty ] or 0 ) + 1
            end
        end
    end
    
    return drumRequiredComponents, totalDrumsCount
end

--------------------------------------------------------------------------------
--- @param componentMap table хеш-таблица компонентов { ["Имя(userdata)"] = кол-во }.
--- @param filteredRecipes table | nil массив структур рецептов для проверки.
--- @return table | nil bestRecipe структура лучшего подходящего рецепта { score: number, requiredComponents: table, name: string }
--------------------------------------------------------------------------------
function SearchService:FindBestRecipe( componentMap, filteredRecipes )
    if not filteredRecipes then return nil end
    local bestRecipe = nil
    local bestScore = -1

    for _, recipe in pairs( filteredRecipes ) do
        local isMatch = true
        for componentName, requiredCount in pairs( recipe.requiredComponents ) do
            if ( componentMap[ componentName ] or 0 ) < requiredCount then
                isMatch = false
                break
            end
        end
        if isMatch and recipe.score > bestScore then
            bestRecipe = recipe
        end
    end
    
    return bestRecipe
end

--------------------------------------------------------------------------------
--- @return table foundResults список найденных рецептов (recipe и shifts).
--------------------------------------------------------------------------------
function SearchService:FindBestRecipes()
    local alchemyInfo = avatar.GetAlchemyInfo()
    
    self._drumsCount = alchemyInfo.drumsCount or 0 -- (HELP) 5
    self._maxCorrections = avatar.GetAlchemyDrumInfo( 0 ).maxCorrectionsPerColumn or 0 -- (HELP) 5
    
    local drumShiftMap, drumRequiredComponents, totalDrumsCount = self._recipe:BuildDrumShiftMap( self._maxCorrections )
    self._drumShiftMap = drumShiftMap
    
    local filteredRecipes = self._recipe:FilterByComponents( drumRequiredComponents, totalDrumsCount )
    self._filteredRecipes = filteredRecipes
    
    local linesAvailability = {
        plusOne  = avatar.IsAlchemyLineAvailable( 1 ) and {} or nil,
        zero     = {},
        minusOne = avatar.IsAlchemyLineAvailable( -1 ) and {} or nil,
    }
    
    return self:ExecuteBacktracking( alchemyInfo.correctionCount or 0, linesAvailability )
end

--------------------------------------------------------------------------------
--- @param totalCorrections number Общее количество доступных коррекций.
--- @param linesAvailability table Таблица доступности линий алхимии (plusOne, zero, minusOne).
--- @return table foundResults Массив найденных результатов { { recipe: table, shifts: table }, ... }
--------------------------------------------------------------------------------
function SearchService:ExecuteBacktracking( totalCorrections, linesAvailability )
    local foundResults = {}
    local foundSet = {}
    local currentShifts = {}
    
    local function recursiveSearch( drumIdx, shiftsLeft, lineZero, lineMinusOne, linePlusOne )
        if self._filteredRecipes and #foundResults >= #self._filteredRecipes then
            return
        end
        
        if drumIdx > 0 then
            if next( self._drumShiftMap[ drumIdx ] ) == nil then
                currentShifts[ drumIdx ] = 0
                recursiveSearch( drumIdx - 1, shiftsLeft, lineZero, lineMinusOne, linePlusOne )
                currentShifts[ drumIdx ] = nil
                return
            end
            
            local maxShift = math.min( shiftsLeft, self._maxCorrections )
            
            for shift = -maxShift, maxShift do
                local nextLeft = shiftsLeft - math.abs( shift )
                
                local addedZero = addComp( self._drumShiftMap, drumIdx, shift, 0, lineZero )
                local addedMinus = addComp( self._drumShiftMap, drumIdx, shift, -1, lineMinusOne )
                local addedPlus = addComp( self._drumShiftMap, drumIdx, shift, 1, linePlusOne )
                
                if addedZero or addedMinus or addedPlus then
                    currentShifts[ drumIdx ] = shift
                    recursiveSearch( drumIdx - 1, nextLeft, lineZero, lineMinusOne, linePlusOne )
                    currentShifts[ drumIdx ] = nil
                    removeComp( lineZero, addedZero )
                    removeComp( lineMinusOne, addedMinus )
                    removeComp( linePlusOne, addedPlus )
                end
            end
        else
            local function registerLine( componentMap )
                if not componentMap then
                    return
                end
                
                local bestRecipe = self:FindBestRecipe( componentMap, self._filteredRecipes )
                
                if bestRecipe and not foundSet[ bestRecipe.name ] then
                    foundSet[ bestRecipe.name ] = true
                    local shiftsCopy = {}
                    
                    for i = 1, self._drumsCount do
                        shiftsCopy[ i ] = currentShifts[ i ] or 0
                    end
                    
                    table.insert( foundResults, {
                        recipe = bestRecipe,
                        shifts = shiftsCopy,
                    } )
                end
            end
            
            registerLine( lineZero )
            registerLine( lineMinusOne )
            registerLine( linePlusOne )
        end
    end
    
    for shiftsLeft = 0, totalCorrections do
        recursiveSearch(
            self._drumsCount, shiftsLeft, linesAvailability.zero, linesAvailability.minusOne, linesAvailability.plusOne
        )
    end
    return foundResults
end