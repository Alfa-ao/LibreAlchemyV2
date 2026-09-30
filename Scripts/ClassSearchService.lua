--------------------------------------------------------------------------------
-- ClassSearchService.lua
-- Сервис для поиска оптимальных комбинаций рецептов алхимии.
--------------------------------------------------------------------------------

Class( "SearchService" )

--------------------------------------------------------------------------------
--- @param recipeService table AlchemyRecipeService Сервис для работы с рецептами (кэширование и фильтрация).
--- @param mapper table DrumShiftMapper Маппер сдвигов барабанов.
--- @param algorithm table BacktrackingSearchAlgorithm Алгоритм поиска.
--------------------------------------------------------------------------------
function SearchService:Init( recipeService, mapper, algorithm )
	self._recipe = recipeService
	self._mapper = mapper
	self._foundSet = {} -- Хеш-таблица для отслеживания уникальных найденных рецептов (используется внутри алгоритма).
	self._algorithm = algorithm
end

--------------------------------------------------------------------------------
--- Собирает данные, строит карту сдвигов, фильтрует рецепты и запускает алгоритм поиска для нахождения оптимальных комбинаций.
--- @return table foundResults найдено список рецептов
--------------------------------------------------------------------------------
function SearchService:FindBestRecipes()
	local alchemyInfo = avatar.GetAlchemyInfo()
	
	-- Обновляет максимальную коррекцию (сдвиг) на основе данных первого барабана
	local firstDrumInfo = avatar.GetAlchemyDrumInfo( 0 )
	
	if firstDrumInfo and firstDrumInfo.maxCorrectionsPerColumn and firstDrumInfo.maxCorrectionsPerColumn > 0 then
		AlchemyState.maxCorrections = firstDrumInfo.maxCorrectionsPerColumn
	end
	
	local totalCorrections = alchemyInfo.correctionCount or 0 -- Доступное количество коррекций (сдвигов барабанов)
	AlchemyState.drumsCount = alchemyInfo.drumsCount or AlchemyState.drumsCount

	-- Определяет доступность линий (строк) результата в интерфейсе алхимии (сдвиги -1, 0, 1)
	local linesAvailability = {
		minusOne = avatar.IsAlchemyLineAvailable( -1 ) and {} or nil,
		zero     = {},
		plusOne  = avatar.IsAlchemyLineAvailable( 1 ) and {} or nil,
	}

	-- Строит карту сдвигов для каждого барабана
	local drumRequiredComponents, totalDrumsCount = self._mapper:BuildMap()
	
	--log(drumRequiredComponents, totalDrumsCount)
	--[[ 
	table(5) {
		[Аспект акробата(ComponentPropertyId)] => number(1)
		[Время(ComponentPropertyId)] => number(1)
		[Звериное чутьё(ComponentPropertyId)] => number(1)
		[Исцеление(ComponentPropertyId)] => number(1)
		[Ослепление(ComponentPropertyId)] => number(1)
	}
	----------------------
	number(2)
	 ]]
	-- Фильтрует глобальный кэш рецептов, оставляя только подходящие по компонентам
	self._recipe:FilterByComponents( drumRequiredComponents, totalDrumsCount )

	-- Запускает алгоритм поиска для перебора вариантов с учетом коррекций и доступных линий
	local foundResults = self._algorithm:Execute( totalCorrections, linesAvailability )
    
	--log( foundResults )
    --[[ 
    table(1) {
        [1] => table(2) {
            ["recipe"] => table(4) {
                ["componentsCount"] => number(5)
                ["name"] => WString(19) "Мастеровой кристалл"
                ["requiredComponents"] => table(2) {
                    [Астральность(ComponentPropertyId)] => number(3)
                    [Царственность(ComponentPropertyId)] => number(2)
                }
                ["score"] => number(116)
            }
            ["shifts"] => table(5) {
                [1] => number(1)
                [2] => number(0)
                [3] => number(0)
                [4] => number(0)
                [5] => number(-1)
            }
        }
    }
     ]]
    
	return foundResults
end