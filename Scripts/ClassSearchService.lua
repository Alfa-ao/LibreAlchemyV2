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
    _drumsCount = 1,
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
--- @param componentMap table хеш-таблица компонентов { ["Имя(userdata)"] = кол-во }.
--- @param filteredRecipes table | nil массив структур рецептов для проверки.
--- @return table | nil bestRecipe структура лучшего подходящего рецепта { score: number, requiredComponents: table, name: string }
--------------------------------------------------------------------------------
local function FindBestRecipe( componentMap, filteredRecipes )
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
--- @param recipeService table ClassRecipeService
--------------------------------------------------------------------------------
function SearchService:Init( recipeService )
    self._recipe = recipeService
end

--------------------------------------------------------------------------------
--- @return table foundResults список найденных рецептов (recipe и shifts).
--- @return number drumsCount
--------------------------------------------------------------------------------
function SearchService:FindBestRecipes()
    local alchemyInfo = avatar.GetAlchemyInfo()
    
    self._drumsCount = alchemyInfo.drumsCount or self._drumsCount
    local firstDrumInfo = avatar.GetAlchemyDrumInfo( 0 )
    self._maxCorrections = firstDrumInfo and firstDrumInfo.maxCorrectionsPerColumn or 0
    
    local drumShiftMap, drumRequiredComponents, totalDrumsCount = self._recipe:BuildDrumShiftMap( self._maxCorrections )
    self._drumShiftMap = drumShiftMap
    
    local filteredRecipes = self._recipe:FilterByComponents( drumRequiredComponents, totalDrumsCount )
    self._filteredRecipes = filteredRecipes
    
    local linesAvailability = {
        plusOne  = avatar.IsAlchemyLineAvailable( 1 ) and {} or nil,
        zero     = {},
        minusOne = avatar.IsAlchemyLineAvailable( -1 ) and {} or nil,
    }
    
    return self:ExecuteBacktracking( alchemyInfo.correctionCount or 0, linesAvailability ), self._drumsCount
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
    
    local drumShiftMap = self._drumShiftMap
    local filteredRecipes = self._filteredRecipes
    local maxCorrections = self._maxCorrections
    local drumsCount = self._drumsCount
    
    local function recursiveSearch( drumIdx, shiftsLeft, lineZero, lineMinusOne, linePlusOne )
        if filteredRecipes and #foundResults >= #filteredRecipes then
            return
        end
        
        if drumIdx > 0 then
            if next( drumShiftMap[ drumIdx ] ) == nil then
                currentShifts[ drumIdx ] = 0
                recursiveSearch( drumIdx - 1, shiftsLeft, lineZero, lineMinusOne, linePlusOne )
                currentShifts[ drumIdx ] = nil
                return
            end
            
            local maxShift = math.min( shiftsLeft, maxCorrections )
            
            for shift = -maxShift, maxShift do
                local nextLeft = shiftsLeft - math.abs( shift )
                
                local addedZero = addComp( drumShiftMap, drumIdx, shift, 0, lineZero )
                local addedMinus = addComp( drumShiftMap, drumIdx, shift, -1, lineMinusOne )
                local addedPlus = addComp( drumShiftMap, drumIdx, shift, 1, linePlusOne )
                
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
                
                local bestRecipe = FindBestRecipe( componentMap, filteredRecipes )
                
                if bestRecipe and not foundSet[ bestRecipe.name ] then
                    foundSet[ bestRecipe.name ] = true
                    local shiftsCopy = {}
                    
                    for i = 1, drumsCount do
                        shiftsCopy[ i ] = currentShifts[ i ] or 0
                    end
                    
                    foundResults[ #foundResults + 1 ] = {
                        recipe = bestRecipe,
                        shifts = shiftsCopy,
                    }
                end
            end
            
            registerLine( lineZero )
            registerLine( lineMinusOne )
            registerLine( linePlusOne )
        end
    end
    
    for shiftsLeft = 0, totalCorrections do
        recursiveSearch(
            drumsCount, shiftsLeft, linesAvailability.zero, linesAvailability.minusOne, linesAvailability.plusOne
        )
    end
    
    return foundResults
end