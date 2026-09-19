--------------------------------------------------------------------------------
-- Services/Search/RecipeEvaluator.lua
-- Оценщик рецептов (RecipeEvaluator).
-- Отвечает за выбор наиболее приоритетного (с максимальным score) рецепта
-- из списка отфильтрованных, на основе накопленной карты компонентов.
--------------------------------------------------------------------------------

Class( "RecipeEvaluator", {} )

--------------------------------------------------------------------------------
--- Найти топовый (наиболее приоритетный) рецепт для накопленных компонентов.
--- Лучшим считается рецепт, который полностью собирается из доступных компонентов
--- и имеет максимальный уровень умения (score).
--- @param componentMap table хеш-таблица накопленных компонентов { ["Имя"] = кол-во }.
--- @param filteredRecipes table | nil массив структур рецептов для проверки.
--- @return table | nil -- { score: number, requiredComponents: table, name: string }
--------------------------------------------------------------------------------
function RecipeEvaluator:FindBestRecipe( componentMap, filteredRecipes )
	if not filteredRecipes then
		return nil
	end
	
	local bestRecipe = nil
	local bestScore = -1

	-- Перебирает все подходящие по базовым компонентам рецепты
	for _, recipe in pairs( filteredRecipes ) do
		local isMatch = true
		
		-- Проверяет, хватает ли накопленных компонентов для данного рецепта
		for componentName, requiredCount in pairs( recipe.requiredComponents ) do
			if ( componentMap[ componentName ] or 0 ) < requiredCount then
				isMatch = false
				break
			end
		end
		
		-- Если рецепт полностью собирается и его score выше текущего максимума, сохраняет его
		if isMatch and recipe.score > bestScore then
			bestRecipe = recipe
		end
	end

	return bestRecipe
end