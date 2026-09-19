--------------------------------------------------------------------------------
-- Scripts/Services/AlchemySearchService.lua
-- Сервис для поиска оптимальных рецептов алхимии.
--------------------------------------------------------------------------------

Class( "AlchemySearchService" )

--------------------------------------------------------------------------------
--- Инициализация сервиса поиска.
--- Проверяет, что переданный алгоритм реализует требуемый интерфейс.
--- @param state table AlchemyState Ссылка на глобальное состояние аддона.
--- @param recipeService table AlchemyRecipeService Сервис для работы с рецептами (кэширование и фильтрация).
--- @param mapper table DrumShiftMapper Маппер сдвигов барабанов.
--- @param algorithm table BacktrackingSearchAlgorithm Алгоритм поиска.
--------------------------------------------------------------------------------
function AlchemySearchService:Init( state, recipeService, mapper, algorithm )
	self._state = state
	self._recipe = recipeService
	self._mapper = mapper
	self._foundSet = {} -- Хеш-таблица для отслеживания уникальных найденных рецептов (используется внутри алгоритма).
	self._algorithm = algorithm
end

--------------------------------------------------------------------------------
--- Главная точка входа для поиска лучших рецептов.
--- Собирает данные, строит карту сдвигов, фильтрует рецепты
--- и запускает алгоритм поиска для нахождения оптимальных комбинаций.
--- @return table -- найдено список рецептов
--------------------------------------------------------------------------------
function AlchemySearchService:FindBestRecipes()
	local alchemyInfo = avatar.GetAlchemyInfo()
	
	-- Обновляет максимальную коррекцию (сдвиг) на основе данных первого барабана
	local firstDrumInfo = avatar.GetAlchemyDrumInfo( 0 )
	
	if firstDrumInfo and firstDrumInfo.maxCorrectionsPerColumn and firstDrumInfo.maxCorrectionsPerColumn > 0 then
		self._state.maxCorrections = firstDrumInfo.maxCorrectionsPerColumn
	end
	
	local totalCorrections = alchemyInfo.correctionCount or 0 -- Доступное количество коррекций (сдвигов барабанов)
	self._state.drumsCount = alchemyInfo.drumsCount or self._state.drumsCount

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
		[Аспект акробата] => number(1)
		[Время] => number(1)
		[Звериное чутьё] => number(1)
		[Исцеление] => number(1)
		[Ослепление] => number(1)
	}
	----------------------
	number(2)
	 ]]
	-- Фильтрует глобальный кэш рецептов, оставляя только подходящие по компонентам
	self._recipe:FilterByComponents( drumRequiredComponents, totalDrumsCount )

	-- Запускает алгоритм поиска для перебора вариантов с учетом коррекций и доступных линий
	self._state.foundResults = self._algorithm:Execute( self._state, totalCorrections, linesAvailability )
    
	--log( self._state.foundResults )
    --[[ 
    table(1) {
        [1] => table(2) {
            ["recipe"] => table(4) {
                ["componentsCount"] => number(5)
                ["name"] => WString(19) "Мастеровой кристалл"
                ["requiredComponents"] => table(2) {
                    [Астральность] => number(3)
                    [Царственность] => number(2)
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
    
	return self._state.foundResults
end