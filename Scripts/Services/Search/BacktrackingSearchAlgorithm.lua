--------------------------------------------------------------------------------
-- Services/Search/BacktrackingSearchAlgorithm.lua
--------------------------------------------------------------------------------

Class( "BacktrackingSearchAlgorithm" )

-- Helper: добавить компонент по смещению.
local function addComp( step, line, offset )
	if not line then return nil end
	local comp = step.state.drumShiftMap[ step.drumIdx ][ step.shift + offset ]
	if comp then
		line[ comp ] = ( line[ comp ] or 0 ) + 1
		return comp
	end
	return nil
end

-- Helper: откатить счётчик компонента
local function removeComp( line, comp )
	if not comp then return end
	line[ comp ] = line[ comp ] - 1
	if line[ comp ] == 0 then
		line[ comp ] = nil
	end
end

--------------------------------------------------------------------------------
--- Инициализация алгоритма поиска.
--- @param evaluator table RecipeEvaluator
--------------------------------------------------------------------------------
function BacktrackingSearchAlgorithm:Init( evaluator )
	self._evaluator = evaluator
end

--------------------------------------------------------------------------------
--- @param state table Глобальное состояние.
--- @param totalCorrections number Доступное количество коррекций (сдвигов барабанов)
--- @param linesAvailability table Доступность линий (строк) результата в интерфейсе алхимии (сдвиги -1, 0, 1)
--- @return table foundResults
--------------------------------------------------------------------------------
function BacktrackingSearchAlgorithm:Execute( state, totalCorrections, linesAvailability )
	local foundResults = {}
	local foundSet = {}

	-- Локальная рекурсивная функция
	local function recursiveSearch( drumIdx, shiftsLeft, currentShifts, lineZero, lineMinusOne, linePlusOne )
		local filteredRecipes = state.filteredRecipes
		
		-- Если уже нашлись все возможные отфильтрованные рецепты, дальше искать нет смысла
		if filteredRecipes and #filteredRecipes > 0 and #foundResults >= #filteredRecipes then 
			return 
		end
		
		-- Обработка нескольких барабанов рекурсивно, если они есть
		if drumIdx > 0 then
			-- Если для текущего барабана нет возможных сдвигов (он пустой или не инициализирован)
			if next( state.drumShiftMap[ drumIdx ] ) == nil then
				currentShifts[ drumIdx ] = 0 -- Фиксируется сдвиг 0
				-- К следующему (предыдущему по индексу) барабану
				recursiveSearch( drumIdx - 1, shiftsLeft, currentShifts, lineZero, lineMinusOne, linePlusOne )
				currentShifts[ drumIdx ] = nil -- Откатывает состояние
				return
			end
			
			-- Вычисляет максимальный сдвиг для текущего барабана
			local maxShift = math.min( shiftsLeft, state.maxCorrections )
			
			-- Перебирает все возможные сдвиги для текущего барабана
			for shift = -maxShift, maxShift do 
				local nextLeft = shiftsLeft - math.abs( shift ) -- Очки коррекции, которые останутся для следующих барабанов.
				local step = {
                    state = state,
                    drumIdx = drumIdx,
                    shift = shift
                }
				
				local addedZero  = addComp( step, lineZero, 0 )
				local addedMinus = addComp( step, lineMinusOne, -1 )
				local addedPlus  = addComp( step, linePlusOne, 1 )

				if addedZero or addedMinus or addedPlus then
					currentShifts[ drumIdx ] = shift
					recursiveSearch( drumIdx - 1, nextLeft, currentShifts, lineZero, lineMinusOne, linePlusOne )
					currentShifts[ drumIdx ] = nil
					
					removeComp( lineZero, addedZero )
					removeComp( lineMinusOne, addedMinus )
					removeComp( linePlusOne, addedPlus )
				end
			end
		else
			local function registerLine( componentMap )
				if not componentMap then return end
				local bestRecipe = self._evaluator:FindBestRecipe( componentMap, filteredRecipes )
				if bestRecipe and not foundSet[ bestRecipe.name ] then
					foundSet[ bestRecipe.name ] = true
					table.insert( foundResults, {
						recipe = bestRecipe,
						shifts = table.sclone( currentShifts ),
					} )
				end
			end
			
			registerLine( lineZero )
			registerLine( lineMinusOne )
			registerLine( linePlusOne )
		end
	end
	
	-- Запуск перебора
	for shiftsLeft = 0, totalCorrections do
		recursiveSearch(
			state.drumsCount, 
			shiftsLeft, 
			{}, 
			linesAvailability.zero, 
			linesAvailability.minusOne, 
			linesAvailability.plusOne
		)
	end
	
	return foundResults
end