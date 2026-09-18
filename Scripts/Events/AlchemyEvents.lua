--------------------------------------------------------------------------------
-- Events/AlchemyEvents.lua
-- Класс, отвечающий за обработку событий алхимии (EVENT_ALCHEMY_*).
--------------------------------------------------------------------------------

Class( "AlchemyEvents" )

--------------------------------------------------------------------------------
--- @param context table -- Набор всякого всяческого
--------------------------------------------------------------------------------
function AlchemyEvents:Init( context )
    self._state  = context.state
    self._search = context.search
    self._recipe = context.recipe
    self._debug  = context.debug
    self._view   = context.view
end

--------------------------------------------------------------------------------
-- Запланировать автоматический сброс типа сообщения к MESSAGE_NORMAL.
-- Необходимо, чтобы приветствие или поздравление задержалось отображением, а затем тригер возвращался к нормальному режиму.
--------------------------------------------------------------------------------
function AlchemyEvents:_ScheduleResetMessageType()
    if self._state.messageType == CONFIG.MESSAGE_NORMAL then
        return
    end
    
    if self._state.taskRefs.funcResetMessageType ~= nil then
        common.CancelDelayedCall( self._state.taskRefs.funcResetMessageType )
    end

    self._state.taskRefs.funcResetMessageType = common.DelayedCall( CONFIG.DELAY_MS_UPDATE, function()
        self._state.messageType = CONFIG.MESSAGE_NORMAL
        self._state.taskRefs.funcResetMessageType = nil
        ----------------------------------------
        self._debug:LogGeneral( "MESSAGE_TYPE change to default: <MESSAGE_NORMAL>" )
        ----------------------------------------
    end )
end

--------------------------------------------------------------------------------
-- Обработчик события EVENT_ALCHEMY_STARTED.
-- Срабатывает при открытии окна алхимии.
--------------------------------------------------------------------------------
function AlchemyEvents:OnStarted()
    ----------------------------------------
    self._debug:LogGeneral( "EVENT_ALCHEMY_STARTED" )
    ----------------------------------------
    
    _G.mainForm:Show( true )
    self._state.active = true

    -- Создает кэш всех доступных рецептов.
    self._recipe:CreateRecipeCache()

    -- Выводит HELLO сообщение в зависимости от предыдущего состояния
    self._view:ShowGreetings( self._state.messageType )
    ----------------------------------------
    self._debug:LogGeneral( "ShowGreetings:", self._state.messageType )
    ----------------------------------------
    
    -- Запланировать возврат к MESSAGE_NORMAL режиму
    self:_ScheduleResetMessageType()
end

--------------------------------------------------------------------------------
--- Обработчик события EVENT_ALCHEMY_CANCELED.
--- Срабатывает при закрытии окна алхимии или переход в меню рецептов.
--- true: вышли в меню рецептов.
--- false: закрыли окно алхимии и при прерывании (не забрал результат).
--- @param params table { isSuccess: boolean }
--------------------------------------------------------------------------------
function AlchemyEvents:OnCanceled( params )
    self._state:ResetPlace() -- Сбрасывает состояние слотов
    
    -- Fix: 17.0.01.37 isSuccess (number(0/1))
    if params.isSuccess == false or params.isSuccess == 0 or params.isSuccess == nil then
        _G.mainForm:Show( false )
        self._state:ResetActive() -- Сброс состояния при закрытии алхимки.
        
        -- При следующем открытии покажет сообщение "С возвращением!"
        self._state.messageType = CONFIG.MESSAGE_WELCOME_BACK
    end
    
    ----------------------------------------
    self._debug:LogGeneral(
        "EVENT_ALCHEMY_CANCELED",
        "isSuccess:",
        params.isSuccess,
        "Count place:",
        self._state.place.count
    )
    ----------------------------------------
end

--------------------------------------------------------------------------------
--- Обработчик события EVENT_ALCHEMY_ITEM_PLACED.
--- Срабатывает при размещении или извлечении предмета из слота рецепта.
--- @param params table { placed: boolean, slot: number }
--------------------------------------------------------------------------------
function AlchemyEvents:OnItemPlaced( params )
    ----------------------------------------
    self._debug:LogGeneral( "EVENT_ALCHEMY_ITEM_PLACED", function ()
        if params.placed then
            return "DEBUG_INSERT_BAR"
        end
        
        return "DEBUG_REMOVED_BAR"
    end, "slot:", params.slot, "placed:", params.placed )
    ----------------------------------------
    
    -- Обновляет состояние слотов
    self._state.place.placed = params.placed

    -- Логика подсчета заполненных слотов
    if params.placed then
        self._state.place.count = self._state.place.count + 1
    else
        --self._state.reactionSuccess = false
        self._state:InvalidateReaction()
        self._state.place.count = self._state.place.count - 1
    end
    
    ----------------------------------------
    self._debug:LogGeneral( "Count place:", self._state.place.count )
    ----------------------------------------
    
    -- Если сейчас не стандартный режим отображения, текст не обновляется.
    -- Автоматически переключится.
    if self._state.messageType ~= CONFIG.MESSAGE_NORMAL then
        return
    end
    
    
    local funcGetMessage = function()
        self._state.taskRefs.funcAlchemyItemPlaced = nil
        
        -- Если находимся в МЕНЮ, то показывает "ВОзможно N рецептов"
        if not self._state.reactionSuccess then
            -- Кол-во возможных рецептов (countRecipe) и кол-во требуемых слотов (filledDrumsCount)
            local countRecipe, filledDrumsCount = self._recipe:CountPotential()
            
            self._view:ShowPotentialRecipes( countRecipe, filledDrumsCount )
            ----------------------------------------
            self._debug:LogGeneral( "ShowPotentialRecipes:", countRecipe )
            ----------------------------------------
        end
    end
    
    -- Отменяет предыдущий таймер, если он уже был запланирован
    if self._state.taskRefs.funcAlchemyItemPlaced ~= nil then
        common.CancelDelayedCall( self._state.taskRefs.funcAlchemyItemPlaced )
    end

    -- Запланировать новый отложенный вызов и сохранить его идентификатор
    self._state.taskRefs.funcAlchemyItemPlaced = common.DelayedCall( CONFIG.DELAY_MS_UPDATE, funcGetMessage )
end

--------------------------------------------------------------------------------
-- Обработчик события EVENT_ALCHEMY_REACTION_FINISHED.
-- Срабатывает сразу после начала процесса варки (нажатие кнопки "варить").
--------------------------------------------------------------------------------
function AlchemyEvents:OnReactionFinished()
    ----------------------------------------
    self._debug:LogGeneral( "EVENT_ALCHEMY_REACTION_FINISHED" )
    ----------------------------------------
    
    -- Запускает алгоритм поиска подходящих рецептов
    local found = self._search:FindBestRecipes()
    self._view:ShowReactionResults( found, CONFIG.MAX_DISPLAY_RESULTS, self._state.drumsCount )
    
    -- Если ничего не найдено
    if #found == 0 then
        ----------------------------------------
        self._debug:LogReaction( "EVENT_ALCHEMY_REACTION_FINISHED:{empty}" )
        ----------------------------------------
        self._state:InvalidateReaction()
    else
        ----------------------------------------
        -- Log: EVENT_ALCHEMY_REACTION_FINISHED:123,1,-1,0,0,0,зелье|123,...
        self._debug:LogReaction( function()
            return self._view:ResultsForLog( found, CONFIG.MAX_DISPLAY_RESULTS, self._state.drumsCount )
        end )
        ----------------------------------------
        -- Присваивается метка реакции как успешная (чтобы при получении предмета показать поздравление с кол-вом полученного предмета)
        self._state.reactionSuccess = true
    end
end

--------------------------------------------------------------------------------
-- Обработчик события EVENT_ALCHEMY_RECIPES_CHANGED.
-- Срабатывает, когда список рецептов изменился.
--------------------------------------------------------------------------------
function AlchemyEvents:OnRecipesChanged()
    ----------------------------------------
    self._debug:LogGeneral( "EVENT_ALCHEMY_RECIPES_CHANGED" )
    ----------------------------------------
    
    -- Сбрасывает кэш рецептов для обновления
    self._state:ResetRecipeCache()
	
	-- Заглушка если алхимка не открыта, но взяли допустим рецепт из Айрина и добавили зелье в рецепт.
	if not self._state.active then return end
	
    -- Поздравить игрока.
    self._view:ShowCongratulation()
    
    -- Отрубить сообщения в EVENT_ALCHEMY_ITEM_PLACED
    -- поздравление (работаем дальше с алхимкой) или Приветсвие (переоткрыли окно)
    self._state.messageType = CONFIG.MESSAGE_WELCOME_BACK
    
    -- Запланировать возврат к MESSAGE_NORMAL режиму
    self:_ScheduleResetMessageType()
end