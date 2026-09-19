--------------------------------------------------------------------------------
-- Services/AlchemyRecipeService.lua
-- Сервис для работы с рецептами алхимии.
-- Отвечает за кэширование списка всех доступных рецептов, фильтрацию по
-- имеющимся компонентам и подсчет возможных рецептов.
--------------------------------------------------------------------------------

Class( "AlchemyRecipeService", {
	_state = nil, -- AlchemyState.
} )

--------------------------------------------------------------------------------
--- Инициализация сервиса.
--- @param state table AlchemyState
--------------------------------------------------------------------------------
function AlchemyRecipeService:Init( state )
	self._state = state
end

--------------------------------------------------------------------------------
--- Создается и сохраняется в кэш полный список всех доступных рецептов алхимии.
--- Выполняется один раз при открытии окна алхимии или при изменении списка рецептов.
--------------------------------------------------------------------------------
function AlchemyRecipeService:CreateRecipeCache()
	-- Если кэш уже создан, выход.
	if self._state.recipeCache ~= nil then
		--log(self._state.recipeCache)
		--[[ 
		table(12) {
			["active"] => boolean(true)
			...
			["recipes"] => table(250) {
				[6] => userdata(RecipeId) = {
					avatar.GetRecipeInfo = table(12) {
						["bindResult"] => boolean(false)
						["components"] => table(5) {
							[0] => userdata(ComponentPropertyId) = {
								avatar.GetComponentInfo = table(4) {
									["description"] => WString(0) ""
									["id"] => userdata(ComponentPropertyId) = *RECURSION*
									["image"] => userdata(UITextureId) = {}
									["name"] => WString(15) "Аспект акробата"
								}
							}
							[1] => userdata(ComponentPropertyId) = {
								avatar.GetComponentInfo = table(4) {
									["description"] => WString(0) ""
									["id"] => userdata(ComponentPropertyId) = *RECURSION*
									["image"] => userdata(UITextureId) = {}
									["name"] => WString(12) "Астральность"
								}
							}
							[2] => userdata(ComponentPropertyId) = {
								avatar.GetComponentInfo = table(4) {
									["description"] => WString(0) ""
									["id"] => userdata(ComponentPropertyId) = *RECURSION*
									["image"] => userdata(UITextureId) = {}
									["name"] => WString(20) "Аспект телохранителя"
								}
							}
							[3] => userdata(ComponentPropertyId) = {
								avatar.GetComponentInfo = table(4) {
									["description"] => WString(0) ""
									["id"] => userdata(ComponentPropertyId) = *RECURSION*
									["image"] => userdata(UITextureId) = {}
									["name"] => WString(14) "Биоморфичность"
								}
							}
							[4] => userdata(ComponentPropertyId) = {
								avatar.GetComponentInfo = table(4) {
									["description"] => WString(0) ""
									["id"] => userdata(ComponentPropertyId) = *RECURSION*
									["image"] => userdata(UITextureId) = {}
									["name"] => WString(13) "Царственность"
								}
							}
						}
						["defaultItem"] => number(28010)
						["description"] => userdata(ValuedText) = {
							ToWString = WString(100) "Увеличивает показатель решимости, может быть использовано совместно с эссенциями из Лавки Редкостей."
							userMods.FromValuedText = string(124) "<html>Увеличивает показатель решимости<f2p>, может быть использовано совместно с эссенциями из Лавки Редкостей</f2p>.</html>"
						}
						["id"] => userdata(RecipeId) = *RECURSION*
						["image"] => userdata(UITextureId) = {}
						["name"] => WString(30) "Королевское снадобье решимости"
						["nextRecipePoints"] => number(0)
						["resultItems"] => table(1) {
							[0] => number(28010)
						}
						["resultQuantity"] => number(1)
						["score"] => number(119)
						["skillId"] => userdata(SkillId) = {
							GetInfo = table(7) {
								["description"] => WString(261) "Ремесло, которое позволяет создавать зелья различного действия. С их помощью на некоторое время можно улучшить характеристики персонажа, восстановить здоровье, защититься от урона или злых чар противника, увеличить наносимый урон или наложить негативный эффект."
								["image"] => userdata(UITextureId) = {}
								["name"] => WString(7) "Алхимия"
								["sysName"] => string(7) "Alchemy"
								["sysType"] => string(22) "ENUM_SkillType_Alchemy"
								["type"] => number(1)
								["useLevels"] => boolean(true)
							}
						}
					}
				}
			}
		}
		 ]]
		return
	end
	
	self._state.recipeCache = {}
	
	-- alchemyInfo: table = { drumsCount, correctionCount, recipes (массив RecipeId) и т.д }.
	local alchemyInfo = avatar.GetAlchemyInfo()
	--log( alchemyInfo )
	--[[ 
	table(12) {
		["active"] => boolean(true)
		["correctionCount"] => number(5)
		["defaultResultCount"] => number(1)
		["drumSize"] => number(24) -- кол-во рандомных аспектов в одном барабане
		["drumsCount"] => number(5) -- кол-во доступных барабанов
		["finished"] => boolean(false)
		["id"] => SkillId
		["perComponentBonus"] => number(0)
		["perfectBonus"] => number(0)
		["reactionInited"] => boolean(false)
		["recipes"] => table(250) {
			[0] => RecipeId
			[1] => RecipeId
			[2] => RecipeId
			[3] => RecipeId
			[4] => RecipeId
			[5] => RecipeId
			...
			[249] => RecipeId
		}
		["unusedRollsBonus"] => number(0.5)
	}
	 ]]
	
	-- кол-во доступных барабанов
	self._state.drumsCount = alchemyInfo.drumsCount
	-- кол-во рандомных аспектов в одном барабане
	self._state.drumSize = alchemyInfo.drumSize

	-- Проходит по всем рецептам
	-- recipeId: userdata (RecipeId) - идентификатор ресурса рецепта
	for _, recipeId in pairs( alchemyInfo.recipes ) do
		local recipeInfo = avatar.GetRecipeInfo( recipeId )
		--log( recipeInfo )
		--[[ 
		table(12) {
			["bindResult"] => boolean(false)
			["components"] => table(2) {
				[0] => userdata(ComponentPropertyId) = {}
				[1] => userdata(ComponentPropertyId) = {}
			}
			["defaultItem"] => number(79835)
			["description"] => userdata(ValuedText) = {
				ToWString = WString(202) "Если верить рецепту, данное зелье делает выпившего невидимым, но эффект может быть нестабилен. Невозможно использовать в бою. Имеет общее время восстановления с защитными бальзамами и лечебными зельями."
			}
			["id"] => RecipeId
			["image"] => userdata(UITextureId) = {}
			["name"] => WString(27) "Дешёвый эликсир невидимости"
			["nextRecipePoints"] => number(0)
			["resultItems"] => table(1) {
				[0] => number(79835)
			}
			["resultQuantity"] => number(1)
			["score"] => number(10)
			["skillId"] => userdata(SkillId) = {
				GetInfo = table(7) {
					["description"] => WString(261) "Ремесло, которое позволяет создавать зелья различного действия. С их помощью на некоторое время можно улучшить характеристики персонажа, восстановить здоровье, защититься от урона или злых чар противника, увеличить наносимый урон или наложить негативный эффект."
					["image"] => userdata(UITextureId) = {}
					["name"] => WString(7) "Алхимия"
					["sysName"] => string(7) "Alchemy"
					["sysType"] => string(22) "ENUM_SkillType_Alchemy"
					["type"] => number(1)
					["useLevels"] => boolean(true)
				}
			}
		}
		 ]]
		
		if recipeInfo then
			local recipe = {
				componentsCount = 0,      -- Общее количество компонентов, требуемых рецептом.
				name = recipeInfo.name,   -- Локализованное имя зелья/рецепта.
				score = recipeInfo.score, -- Необходимый уровень умения для крафта.
				requiredComponents = {},  -- Хеш-таблица требуемых компонентов: { ["Имя"] = кол-во }.
			}

			-- Разбирает массив компонентов рецепта
			for _, componentProperty in pairs( recipeInfo.components ) do
				-- Увеличивается счетчик требуемого количества данного аспекта(компонента)
				recipe.requiredComponents[ componentProperty ] = ( recipe.requiredComponents[ componentProperty ] or 0 ) + 1
				-- Увеличивается общий счетчик компонентов в рецепте
				recipe.componentsCount = recipe.componentsCount + 1
			end

			-- Добавляет готовую структуру рецепта в общий кэш
			table.insert( self._state.recipeCache, recipe )
		end
	end
end

--------------------------------------------------------------------------------
--- Проверить, соответствуют ли доступные компоненты требованиям конкретного рецепта.
--- @param recipe table структура рецепта из кэша (содержит componentsCount, requiredComponents).
--- @param availableComponents table хеш-таблица доступных компонентов { ["Имя"] = кол-во }.
--- @param filledSlotsCount number количество заполненных слотов (барабанов) в ступке.
--- @return boolean
--------------------------------------------------------------------------------
function AlchemyRecipeService:IsRecipeMatch( recipe, availableComponents, filledSlotsCount )
	--log(recipe)
	--[[ 
	table(4) {
		["componentsCount"] => number(5)
		["name"] => WString(19) "Мастеровой кристалл"
		["requiredComponents"] => table(2) {
			[Астральность] => number(3)
			[Царственность] => number(2)
		}
		["score"] => number(116)
	}
	 ]]
	-- Количество заполненных слотов должно совпадать с требуемым кол-вом компонентов
	if CONFIG.REQUIRED_COMPONENTS_COUNT and recipe.componentsCount ~= filledSlotsCount then
		return false
	end
	
	-- Проверяет наличие каждого требуемого компонента
	for componentProperty, neededCount in pairs( recipe.requiredComponents ) do
		-- Если доступного компонента меньше, чем требуется
		if ( availableComponents[ componentProperty ] or 0 ) < neededCount then
			return false
		end
	end
	
	return true
end

--------------------------------------------------------------------------------
--- used AlchemySearchService:FindBestRecipes
--- Отфильтровать глобальный кэш рецептов, оставляя только те, которым соответствуют
--- уникальные компоненты, лежащие в барабанах (без учета сдвигов/коррекций).
--- @param availableComponents table { ["ИмяКомпонента"] = кол-во_слотов_с_этим_компонентом }.
--- @param filledDrumsCount number общее количество барабанов, в которые положены предметы.
--- @return integer count кол-во рецептов с подходящими компонентами
--------------------------------------------------------------------------------
function AlchemyRecipeService:FilterByComponents( availableComponents, filledDrumsCount )
	-- Проверить кэш.
	self:CreateRecipeCache()
	
	self._state.filteredRecipes = {}
	local count = 0
	
	for _, recipe in pairs( self._state.recipeCache ) do
		if self:IsRecipeMatch( recipe, availableComponents, filledDrumsCount ) then
			table.insert( self._state.filteredRecipes, recipe )
			count = count + 1
		end
	end
	
	return count
end

--------------------------------------------------------------------------------
--- used AlchemyEvents:OnItemPlaced
--- Подсчитать количество возможных рецептов на основе того, какие
--- предметы положены в слоты (без учета сдвигов).
--- @return integer potentialCount количество возможных рецептов
--- @return integer filledDrumsCount количество заполненных слотов
--------------------------------------------------------------------------------
function AlchemyRecipeService:CountPotential() -- ФУНКЦИЯ проверена.
	-- Проверить кэш.
	self:CreateRecipeCache()
	
	local potentialCount = 0
	local filledDrumsCount = 0
	local availableComponents = {} -- Какие и кол-во аспектов(компонентов) за все вложенные в слоты(барабаны)

	-- Проходит по всем слотам(барабанам).
	for drumIdx = 0, self._state.drumsCount - 1 do
		
		-- Выводит рандомную ленту компонентов(аспектов) (24шт) из предмета(травы) конкретного барабана.
		local drumInfo = avatar.GetAlchemyDrumInfo( drumIdx )
		--log(drumInfo)
		-- Если предмет положен в слот барабана ["itemId"] => number(12345)
		if drumInfo.itemId ~= nil then
			filledDrumsCount = filledDrumsCount + 1
			
			-- Хеш-таблица (за 1 барабан) [Аспект теста(ComponentPropertyId)] => true
			local seenInDrum = {}
			
			-- Собирается список аспектов(компонентов) какие есть из рандом листа
			-- 0 => apitype(ComponentPropertyId)
			for _, componentProperty in pairs( drumInfo.components ) do
				seenInDrum[ componentProperty ] = true -- Из (24шт) делается уникальность
			end
			
			-- Кол-во повторных аспектов
			for componentProperty, _ in pairs( seenInDrum ) do
				-- Плюсуется то что найденно во всех барабанах
				availableComponents[ componentProperty ] = ( availableComponents[ componentProperty ] or 0 ) + 1
			end
		end
	end
	--log(availableComponents)
	--[[ 
	table(5) {
		[Астральность] => number(3)
		[Биоморфичность] => number(5)
		[Призрачность] => number(2)
		[Технологичность] => number(3)
		[Царственность] => number(2)
	}
	
	переделано на:
	
	table(5) {
		[userdata: 0x44281800] => number(2)
		[userdata: 0x44281088] => number(5)
		[userdata: 0x44280e78] => number(3)
		[userdata: 0x442817c0] => number(2)
		[userdata: 0x44280ef8] => number(3)
	}
	 ]]
	-- Проверяет, сколько рецептов из кэша удовлетворяют собранному набору
	for _, recipe in pairs( self._state.recipeCache ) do
		if self:IsRecipeMatch( recipe, availableComponents, filledDrumsCount ) then
			potentialCount = potentialCount + 1
		end
	end

	-- Возвращает количество возможных рецептов и количество заполненных слотов
	return potentialCount, filledDrumsCount
end