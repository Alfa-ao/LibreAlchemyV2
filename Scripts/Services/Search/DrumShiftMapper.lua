--------------------------------------------------------------------------------
-- Services/Search/DrumShiftMapper.lua
--------------------------------------------------------------------------------

Class( "DrumShiftMapper" )

--------------------------------------------------------------------------------
--- @param state table AlchemyState
--------------------------------------------------------------------------------
function DrumShiftMapper:Init( state )
	self._state = state
end

--------------------------------------------------------------------------------
--- Метод: Строит карту возможных сдвигов для каждого барабана.
--- Определяет, какие компоненты можно получить на каждом барабане при разных сдвигах.
--- @return table drumRequiredComponents таблица уникальных компонентов по барабанам
--- @return number totalDrumsCount общее кол-во заполненных барабанов
--------------------------------------------------------------------------------
function DrumShiftMapper:BuildMap()
	-- Таблица { [имя_компонента] = количество_барабанов }. 
	-- Считает, в скольких барабанах встречается каждый уникальный компонент.
	local drumRequiredComponents = {}
	
	-- Инициализируем карту сдвигов в состоянии. 
	-- Таблица: { [индекс_барабана] = { [сдвиг] = "имя_компонента" } }
    self._state.drumShiftMap = {}
	
	-- Счетчик барабанов, в которые положены предметы (itemId ~= nil).
    local totalDrumsCount = 0

    -- Проходит по всем доступным барабанам (от 1 до drumsCount)
	for drumIndex = 1, self._state.drumsCount do
		self._state.drumShiftMap[ drumIndex ] = {} -- Создает пустую таблицу для сдвигов текущего барабана
		local drumInfo = avatar.GetAlchemyDrumInfo( drumIndex - 1 ) -- Получает информацию о барабане
		
		-- Проверяет, что барабан существует и в него положен предмет
		if drumInfo and drumInfo.itemId ~= nil then
			totalDrumsCount = totalDrumsCount + 1
            local uniqueDrumComponents = {}        -- Таблица { [имя_компонента(ComponentPropertyId)] = true }.
			local basePos = drumInfo.position or 0 -- Текущая позиция барабана.
			
			-- Перебирается все возможные сдвиги
			for shift = -self._state.maxCorrections, self._state.maxCorrections do
				-- Вычисляется индекс компонента
				local targetIndex = ( basePos + shift ) % self._state.drumSize
				
				local componentProperty = drumInfo.components[ targetIndex ] -- ID компонента (ComponentPropertyId)
				-- Записывает в карту сдвигов: какой компонент получится при данном сдвиге
				self._state.drumShiftMap[ drumIndex ][ shift ] = componentProperty
				uniqueDrumComponents[ componentProperty ] = true
			end
			
			-- Добавляет уникальные компоненты этого барабана в общий счетчик требуемых компонентов
			for componentProperty, _ in pairs( uniqueDrumComponents ) do
				drumRequiredComponents[ componentProperty ] = ( drumRequiredComponents[ componentProperty ] or 0 ) + 1
			end
		end
	end
	
	-- Возвращает таблицу уникальных компонентов по барабанам и общее кол-во заполненных барабанов
	return drumRequiredComponents, totalDrumsCount
end