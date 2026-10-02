--------------------------------------------------------------------------------
-- ClassAlchemyEvents.lua
-- Класс, отвечающий за обработку событий алхимии (EVENT_ALCHEMY_*).
--------------------------------------------------------------------------------

Class( "AlchemyEvents", {
    reactionSuccess = false -- true: чтобы при получении предмета показать поздравление с кол-вом полученного предмета.
} )

--------------------------------------------------------------------------------
--- @param services table
--------------------------------------------------------------------------------
function AlchemyEvents:Init( services )
    self._services = services
    advEvent.RegisterEventHandlers( false, self:GetActiveEventHandlers() )
end



--------------------------------------------------------------------------------
-- Обработчик события EVENT_ALCHEMY_STARTED.
-- Срабатывает при открытии окна алхимии.
--------------------------------------------------------------------------------
function AlchemyEvents:OnStarted()
    _G.mainForm:Show( true )

    -- Создается кэш всех доступных рецептов.
    self._services.recipe:CreateRecipeCache()

    -- Выводит HELLO сообщение в зависимости от предыдущего состояния
    self._services.view:ShowGreetings()
    -----------------DEBUG------------------
    DebugService.LogGeneral( "EVENT_ALCHEMY_STARTED", { "ShowGreetings:", self._services.view.messageType } )
    ------------------END-------------------
    
    -- Запланировать возврат к режиму MESSAGE_NORMAL
    self._services.view:ScheduleResetMessageType()
end



--------------------------------------------------------------------------------
--- Обработчик события EVENT_ALCHEMY_CANCELED.
--- Срабатывает при закрытии окна алхимии или переход в меню рецептов.
--- true: вышли в меню рецептов.
--- false: закрыли окно алхимии и при прерывании (не забрал результат).
--- @param params table { isSuccess: boolean }
--------------------------------------------------------------------------------
function AlchemyEvents:OnCanceled( params )
    -- Fix: 17.0.01.37 isSuccess (number(0/1))
    if not params.isSuccess or params.isSuccess == 0 then
        _G.mainForm:Show( false )
        self.reactionSuccess = false -- Сброс флага успешной реакции
        
        AlchemyState.CancelAllDelayedCalls()
        
        -- При следующем открытии покажет сообщение "С возвращением!"
        self._services.view.messageType = CONFIG.MESSAGE_WELCOME_BACK
    end
    
    -----------------DEBUG------------------
    DebugService.LogGeneral(
        "EVENT_ALCHEMY_CANCELED",
        { "params: { isSuccess: boolean }", params }
    )
    ------------------END-------------------
end



--------------------------------------------------------------------------------
--- Обработчик события EVENT_ALCHEMY_ITEM_PLACED.
--- Срабатывает при размещении или извлечении предмета из слота рецепта.
--- @param params table { placed: boolean, slot: number }
--------------------------------------------------------------------------------
function AlchemyEvents:OnItemPlaced( params )
    if not params.placed then
        self.reactionSuccess = false
    end
    
    -----------------DEBUG------------------
    DebugService.LogGeneral( 
        "EVENT_ALCHEMY_ITEM_PLACED",
        function ()
            if params.placed then return "DEBUG_INSERT_BAR" end
            return "DEBUG_REMOVED_BAR"
        end, 
        { "params: { placed: boolean, slot: number }", params }
    )
    ------------------END-------------------
    
    -- Если сейчас не стандартный режим отображения, то текст не обновляется.
    -- Автоматически переключится через {CONFIG.DELAY_MS_UPDATE}.
    if self._services.view.messageType ~= CONFIG.MESSAGE_NORMAL then
        return
    end
    
    
    local function funcGetMessage()
        AlchemyState.taskRefs.funcAlchemyItemPlaced = nil
        
        -- Если находимся в меню, то показывает "Возможно N рецептов"
        if not self.reactionSuccess then
            -- Кол-во возможных рецептов (countRecipe) и кол-во требуемых слотов (filledDrumsCount)
            local countRecipe, filledDrumsCount = self._services.recipe:CountPotential()
            
            self._services.view:ShowPotentialRecipes( countRecipe, filledDrumsCount )
            -----------------DEBUG------------------
            DebugService.LogGeneral( { "ShowPotentialRecipes:", countRecipe } )
            ------------------END-------------------
        end
    end
    
    -- Отменяется предыдущий таймер, если он уже был запланирован
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
    -- Запускается алгоритм поиска подходящих рецептов
    local found = self._services.search:FindBestRecipes()
    self._services.view:ShowReactionResults( found, CONFIG.MAX_DISPLAY_RESULTS, AlchemyState.drumsCount )
    
    -- Если ничего не найдено
    if #found == 0 then
        -----------------DEBUG------------------
        DebugService.LogReaction( "EVENT_ALCHEMY_REACTION_FINISHED:{empty}" )
        ------------------END-------------------
        self.reactionSuccess = false
    else
        -----------------DEBUG------------------
        DebugService.LogReaction( function()
            return self._services.view:ResultsForLog( found, CONFIG.MAX_DISPLAY_RESULTS, AlchemyState.drumsCount )
        end )
        ------------------END-------------------
        self.reactionSuccess = true
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
    
    -- Сбрасывается кэш рецептов для обновления
    self._services.recipe:ResetRecipeCache()
	
	-- Заглушка если алхимка не открыта, но взяли допустим рецепт из Айрина и добавили зелье в рецепт.
	if not _G.mainForm:IsVisible() then return end
	
    -- Поздравить игрока.
    self._services.view:ShowCongratulation()
    
    -- Отрубить сообщения в EVENT_ALCHEMY_ITEM_PLACED
    -- поздравление (работаем дальше с алхимкой) или Приветсвие (переоткрыли окно)
    self._services.view.messageType = CONFIG.MESSAGE_WELCOME_BACK
    
    -- Запланировать возврат к MESSAGE_NORMAL режиму
    self._services.view:ScheduleResetMessageType()
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
        { -- Уведомляет о начале(финиширует, но проигрывается анимация интерфейса) варки зелья.
            function() self:OnReactionFinished() end,
            "EVENT_ALCHEMY_REACTION_FINISHED"
        },
        { -- Уведомляет об необходимости обновить список рецептов.
            function() self:OnRecipesChanged() end,
            "EVENT_ALCHEMY_RECIPES_CHANGED"
        },
    }
end