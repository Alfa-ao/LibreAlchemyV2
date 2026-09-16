--------------------------------------------------------------------------------
-- Services/Search/DrumShiftMapper.lua
--------------------------------------------------------------------------------

Class( "DrumShiftMapper", {
	_state         = nil,
	_recipeService = nil,
} )

--------------------------------------------------------------------------------
--- @param state table AlchemyState
--- @param recipeService table AlchemyRecipeService
--------------------------------------------------------------------------------
function DrumShiftMapper:Init( state, recipeService )
	self._state         = state
	self._recipeService = recipeService
end

--------------------------------------------------------------------------------
--- Метод: Строит карту возможных сдвигов для каждого барабана.
--- Определяет, какие компоненты можно получить на каждом барабане при разных сдвигах.
--- @return table drumRequiredComponents таблица уникальных компонентов по барабанам
--- @return number totalDrumsCount общее кол-во заполненных барабанов
--------------------------------------------------------------------------------
function DrumShiftMapper:BuildMap()
	local drumRequiredComponents = {} -- Таблица { [имя_компонента] = количество_барабанов }. 
                                      -- Считает, в скольких барабанах встречается каждый уникальный компонент.
    self._state.drumShiftMap = {}     -- Инициализируем карту сдвигов в состоянии. 
                                      -- Структура: { [индекс_барабана] = { [сдвиг] = "имя_компонента" } }
    local totalDrumsCount = 0         -- number (int). Счетчик барабанов, в которые реально положены предметы (itemId ~= nil).

    -- Проходит по всем доступным барабанам (от 1 до drumsCount)
	for drumIndex = 1, self._state.drumsCount do
		self._state.drumShiftMap[ drumIndex ] = {} -- Создает пустую таблицу для сдвигов текущего барабана
		local drumInfo = avatar.GetAlchemyDrumInfo( drumIndex - 1 ) -- Получает информацию о барабане
		
		-- Проверяет, что барабан существует и в него положен предмет
		if drumInfo and drumInfo.itemId ~= nil then
			totalDrumsCount = totalDrumsCount + 1 -- Увеличивает счетчик заполненных барабанов
            local uniqueDrumComponents = {}       -- Таблица { [имя_компонента] = 1 }. Хранит уникальные компоненты ВНУТРИ одного барабана.
            local componentCount = table.nkeys( drumInfo.components ) -- number (int). Общее количество компонентов в предмете барабана.
            
            -- Защита от барабанов без компонентов (предмет есть, но компонентов нет)
			if componentCount > 0 then
				local basePos = drumInfo.position or 0 -- number (int). Текущая позиция барабана (индекс компонента, который сейчас "в окне").
				
				-- Перебирает все возможные сдвиги от -maxCorrections до +maxCorrections
				for shift = -self._state.maxCorrections, self._state.maxCorrections do
					-- Вычисляет индекс компонента с учетом сдвига и зацикленности барабана
                    local targetIndex = ( basePos + shift ) % componentCount
					
                    local componentId = drumInfo.components[ targetIndex ] -- ID компонента (userdata/ResourceId)
					
					if componentId then
						-- Получает string имя компонента через сервис рецептов (кэш имён компонентов)
						local componentName = self._recipeService:GetComponentName( componentId )
						if componentName then
							-- Записывает в карту сдвигов: какой компонент получится при данном сдвиге
                            self._state.drumShiftMap[ drumIndex ][ shift ] = componentName
                            -- ОтМечает компонент как уникальный для этого барабана
                            uniqueDrumComponents[ componentName ] = 1
						end
					end
				end
			end
			
			-- Добавляет уникальные компоненты этого барабана в общий счетчик требуемых компонентов
			for componentName, _ in pairs( uniqueDrumComponents ) do
				drumRequiredComponents[ componentName ] = ( drumRequiredComponents[ componentName ] or 0 ) + 1
			end
		end
	end
	
	-- Возвращает таблицу уникальных компонентов по барабанам и общее кол-во заполненных барабанов
	return drumRequiredComponents, totalDrumsCount
end