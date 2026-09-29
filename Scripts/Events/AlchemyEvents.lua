--------------------------------------------------------------------------------
-- Events/AlchemyEvents.lua
-- Класс, отвечающий за обработку событий алхимии (EVENT_ALCHEMY_*).
--------------------------------------------------------------------------------

Class( "AlchemyEvents" )

--------------------------------------------------------------------------------
--- @param context table -- Набор всякого всяческого
--------------------------------------------------------------------------------
function AlchemyEvents:Init( context )
    self._search = context.search
    self._recipe = context.recipe
    self._view   = context.view
    
    advEvent.RegisterEventHandlers( false, self:GetActiveEventHandlers() )
end

--------------------------------------------------------------------------------
-- Обработчик события EVENT_ALCHEMY_STARTED.
-- Срабатывает при открытии окна алхимии.
--------------------------------------------------------------------------------
function AlchemyEvents:OnStarted()
    _G.mainForm:Show( true )
    AlchemyState.active = true

    -- Создает кэш всех доступных рецептов.
    self._recipe:CreateRecipeCache()

    -- Выводит HELLO сообщение в зависимости от предыдущего состояния
    self._view:ShowGreetings( AlchemyState.messageType )
    -----------------DEBUG------------------
    DebugService.LogGeneral( "EVENT_ALCHEMY_STARTED", { "ShowGreetings:", AlchemyState.messageType } )
    ------------------END-------------------
    
    -- Запланировать возврат к MESSAGE_NORMAL режиму
    self._view:ScheduleResetMessageType()
end

--------------------------------------------------------------------------------
--- Обработчик события EVENT_ALCHEMY_CANCELED.
--- Срабатывает при закрытии окна алхимии или переход в меню рецептов.
--- true: вышли в меню рецептов.
--- false: закрыли окно алхимии и при прерывании (не забрал результат).
--- @param params table { isSuccess: boolean }
--------------------------------------------------------------------------------
function AlchemyEvents:OnCanceled( params )
    AlchemyState.ResetPlace() -- Сбрасывает состояние слотов
    
    -- Fix: 17.0.01.37 isSuccess (number(0/1))
    if not params.isSuccess or params.isSuccess == 0 then
        _G.mainForm:Show( false )
        AlchemyState.ResetActive() -- Сброс состояния при закрытии алхимки.
        
        -- При следующем открытии покажет сообщение "С возвращением!"
        AlchemyState.messageType = CONFIG.MESSAGE_WELCOME_BACK
    end
    
    -----------------DEBUG------------------
    DebugService.LogGeneral(
        "EVENT_ALCHEMY_CANCELED",
        { "params: { isSuccess: boolean }", params },
        { "Count place:", AlchemyState.place.count }
    )
    ------------------END-------------------
end

--------------------------------------------------------------------------------
--- Обработчик события EVENT_ALCHEMY_ITEM_PLACED.
--- Срабатывает при размещении или извлечении предмета из слота рецепта.
--- @param params table { placed: boolean, slot: number }
--------------------------------------------------------------------------------
function AlchemyEvents:OnItemPlaced( params )
    -- Обновляет состояние слотов
    AlchemyState.place.placed = params.placed

    -- Логика подсчета заполненных слотов
    if params.placed then
        AlchemyState.place.count = AlchemyState.place.count + 1
    else
        AlchemyState.InvalidateReaction()
        AlchemyState.place.count = AlchemyState.place.count - 1
    end
    
    -----------------DEBUG------------------
    DebugService.LogGeneral( 
        "EVENT_ALCHEMY_ITEM_PLACED",
        function ()
            if params.placed then return "DEBUG_INSERT_BAR" end
            return "DEBUG_REMOVED_BAR"
        end, 
        { "params: { placed: boolean, slot: number }", params },
        { "Count place:", AlchemyState.place.count }
    )
    ------------------END-------------------
    
    -- Если сейчас не стандартный режим отображения, текст не обновляется.
    -- Автоматически переключится.
    if AlchemyState.messageType ~= CONFIG.MESSAGE_NORMAL then
        return
    end
    
    
    local funcGetMessage = function()
        AlchemyState.taskRefs.funcAlchemyItemPlaced = nil
        
        -- Если находимся в МЕНЮ, то показывает "ВОзможно N рецептов"
        if not AlchemyState.reactionSuccess then
            -- Кол-во возможных рецептов (countRecipe) и кол-во требуемых слотов (filledDrumsCount)
            local countRecipe, filledDrumsCount = self._recipe:CountPotential()
            
            self._view:ShowPotentialRecipes( countRecipe, filledDrumsCount )
            -----------------DEBUG------------------
            DebugService.LogGeneral( { "ShowPotentialRecipes:", countRecipe } )
            ------------------END-------------------
        end
    end
    
    -- Отменяет предыдущий таймер, если он уже был запланирован
    if AlchemyState.taskRefs.funcAlchemyItemPlaced ~= nil then
        common.CancelDelayedCall( AlchemyState.taskRefs.funcAlchemyItemPlaced )
    end

    -- Запланировать новый отложенный вызов и сохранить его идентификатор
    AlchemyState.taskRefs.funcAlchemyItemPlaced = common.DelayedCall( CONFIG.DELAY_MS_UPDATE, funcGetMessage )
end

--------------------------------------------------------------------------------
-- Обработчик события EVENT_ALCHEMY_REACTION_FINISHED.
-- Срабатывает сразу после начала процесса варки (нажатие кнопки "варить").
--------------------------------------------------------------------------------
function AlchemyEvents:OnReactionFinished()
    -- Запускает алгоритм поиска подходящих рецептов
    local found = self._search:FindBestRecipes()
    self._view:ShowReactionResults( found, CONFIG.MAX_DISPLAY_RESULTS, AlchemyState.drumsCount )
    
    -- Если ничего не найдено
    if #found == 0 then
        -----------------DEBUG------------------
        DebugService.LogReaction( "EVENT_ALCHEMY_REACTION_FINISHED:{empty}" )
        ------------------END-------------------
        AlchemyState.InvalidateReaction()
    else
        -----------------DEBUG------------------
        DebugService.LogReaction( function()
            return self._view:ResultsForLog( found, CONFIG.MAX_DISPLAY_RESULTS, AlchemyState.drumsCount )
        end )
        ------------------END-------------------
        -- Присваивается метка реакции как успешная (чтобы при получении предмета показать поздравление с кол-вом полученного предмета)
        AlchemyState.reactionSuccess = true
    end
end

--------------------------------------------------------------------------------
-- Обработчик события EVENT_ALCHEMY_RECIPES_CHANGED.
-- Срабатывает, когда список рецептов изменился.
--------------------------------------------------------------------------------
function AlchemyEvents:OnRecipesChanged()
    -----------------DEBUG------------------
    DebugService.LogGeneral( "EVENT_ALCHEMY_RECIPES_CHANGED" )
    ------------------END-------------------
    
    -- Сбрасывает кэш рецептов для обновления
    self._recipe:ResetRecipeCache()
	
	-- Заглушка если алхимка не открыта, но взяли допустим рецепт из Айрина и добавили зелье в рецепт.
	if not AlchemyState.active then return end
	
    -- Поздравить игрока.
    self._view:ShowCongratulation()
    
    -- Отрубить сообщения в EVENT_ALCHEMY_ITEM_PLACED
    -- поздравление (работаем дальше с алхимкой) или Приветсвие (переоткрыли окно)
    AlchemyState.messageType = CONFIG.MESSAGE_WELCOME_BACK
    
    -- Запланировать возврат к MESSAGE_NORMAL режиму
    self._view:ScheduleResetMessageType()
end

--------------------------------------------------------------------------------
--- @return table handlers
--------------------------------------------------------------------------------
function AlchemyEvents:GetActiveEventHandlers()
    return {
        { -- Окно алхимки открывается. Инициализируется HELLO сообщение и кэш рецептов.
            function() self:OnStarted() end,
            "EVENT_ALCHEMY_STARTED"
        },
        { -- Окно алхимки закрывается / вышли из варки в меню.
            function( params ) self:OnCanceled( params ) end,
            "EVENT_ALCHEMY_CANCELED"
        },
        { -- При каждом изменении слота для компонентов уведомляет, что в такой-то слот был вставлен/вынут компонент.
            function( params ) self:OnItemPlaced( params ) end,
            "EVENT_ALCHEMY_ITEM_PLACED"
        },
        { -- Уведомляет о начале варки зелья. Хоть и название события говорит о другом...
            function() self:OnReactionFinished() end,
            "EVENT_ALCHEMY_REACTION_FINISHED"
        },
        { -- Уведомляет об необходимости обновить список рецептов.
            function() self:OnRecipesChanged() end,
            "EVENT_ALCHEMY_RECIPES_CHANGED"
        },
    }
end