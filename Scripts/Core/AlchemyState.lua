--------------------------------------------------------------------------------
-- Core/AlchemyState.lua
-- Хранилище изменяемого состояния аддона.
--------------------------------------------------------------------------------

Global( "AlchemyState", {
    -- Флаги состояния
    active = false,             -- boolean - Активно ли окно алхимии.
    reactionSuccess = false,    -- boolean - Была ли реакция успешной (найден рецепт).
    messageType = 0,            -- number (int) - Тип отображаемого сообщения (см. AlchemyConfig.MESSAGE_*).
    localization = nil,         -- Локализация (rus, eng) common.GetLocalization.

    -- Кэш данных и результаты поиска
    --recipeCache = nil,          -- ?table - Кэш списка всех доступных игроку рецептов алхимии.
    filteredRecipes = nil,      -- ?table - Отфильтрованный список рецептов (по компонентам в барабанах).
    drumShiftMap = nil,         -- ?table - Карта сдвигов: [индекс_барабана][сдвиг] = "имя_компонента".
    --foundResults = nil,         -- ?table - Таблица найденных вариантов (рецепт + сдвиги барабанов).
    
    -- Параметры ступки (барабанов)
    drumSize = 0,               -- Количество аспектов (компонентов) в одном барабане.
    drumsCount = 0,             -- number (int) - Кол-во слотов, доступных в ступке.
    maxCorrections = 5,         -- number (int) - Максимальная коррекция (сдвиг) в колбе. 
                                -- GetAlchemyDrumInfo( 0 ).maxCorrectionsPerColumn выводит 5 
                                -- только тогда, когда пошёл процесс варки. Во всех остальных случаях (-1).
    
    -- Состояние слотов
    place = {
        placed = nil,           -- ?boolean - Флаг изменения состояния слота (true - положен, false - вынут).
        count = 0,              -- number (int) - Текущее количество заполненных слотов.
    },
    
    taskRefs = {}               -- table - Хранилище ссылок на запланированные отложенные вызовы.
} )

--------------------------------------------------------------------------------
-- Методы сброса состояния
--------------------------------------------------------------------------------

-- Сброс состояния слотов к начальным значениям.
function AlchemyState.ResetPlace()
    AlchemyState.place.placed = nil
    AlchemyState.place.count = 0
end
--------------------------------------------------------------------------------

-- Сброс состояния при выходе и переключение для повторного открытия
function AlchemyState.ResetActive()
    AlchemyState.reactionSuccess = false -- Сбрасываем флаг успешной реакции
    AlchemyState.active = false          -- Помечаем аддон как неактивный
    
    AlchemyState.CancelAllDelayedCalls()
end

--------------------------------------------------------------------------------

-- Сброс кэша поиска.
--[[ function AlchemyState.ResetSearchCache()
    AlchemyState.filteredRecipes = nil
    AlchemyState.drumShiftMap = nil
    --AlchemyState.foundResults = nil
end ]]

--------------------------------------------------------------------------------

-- Сброс кэша всех доступных рецептов.
--[[ function AlchemyState.ResetRecipeCache()
    AlchemyState.recipeCache = nil
end ]]

--------------------------------------------------------------------------------
-- Вызывается, когда слоты изменяются (предмет вынут), делая старый результат недействительным.
--------------------------------------------------------------------------------
function AlchemyState.InvalidateReaction()
    AlchemyState.reactionSuccess = false
    --AlchemyState.foundResults = nil
end

--------------------------------------------------------------------------------
-- Отмена всех запланированных отложенных вызовов и очистка хранилища ссылок.
--------------------------------------------------------------------------------
function AlchemyState.CancelAllDelayedCalls()
    for _, functionRef in pairs( AlchemyState.taskRefs ) do
        if functionRef ~= nil then
            common.CancelDelayedCall( functionRef )
        end
    end
    
    -- Полная очистка таблицы ссылок
    AlchemyState.taskRefs = {}
end