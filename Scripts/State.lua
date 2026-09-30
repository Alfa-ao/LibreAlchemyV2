--------------------------------------------------------------------------------
-- State.lua
-- Хранилище изменяемого состояния аддона.
--------------------------------------------------------------------------------

Global( "AlchemyState", {
    -- Кэш данных и результаты поиска
    filteredRecipes = nil,      -- ?table - Отфильтрованный список рецептов (по компонентам в барабанах).
    drumShiftMap = nil,         -- ?table - Карта сдвигов: [индекс_барабана][сдвиг] = "имя_компонента".
    
    -- Параметры ступки (барабанов)
    drumSize = 0,               -- Количество аспектов (компонентов) в одном барабане.
    drumsCount = 0,             -- number (int) - Кол-во слотов, доступных в ступке.
    maxCorrections = 5,         -- number (int) - Максимальная коррекция (сдвиг) в колбе. 
                                -- GetAlchemyDrumInfo( 0 ).maxCorrectionsPerColumn выводит 5 
                                -- только тогда, когда пошёл процесс варки. Во всех остальных случаях (-1).
    
    taskRefs = {}               -- table - Хранилище ссылок на запланированные отложенные вызовы.
} )

-- Отмена всех запланированных отложенных вызовов и очистка хранилища ссылок.
function AlchemyState.CancelAllDelayedCalls()
    for _, functionRef in pairs( AlchemyState.taskRefs ) do
        if functionRef ~= nil then
            common.CancelDelayedCall( functionRef )
        end
    end
    
    -- Полная очистка таблицы ссылок
    AlchemyState.taskRefs = {}
end