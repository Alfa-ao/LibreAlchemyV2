--------------------------------------------------------------------------------
--[[
ClassEventHandlers.lua - Сервис для обработки событий.

Класс EventHandlers реализует следующие методы:
    self.Init
    self.OnStarted          - Обработка EVENT_ALCHEMY_STARTED. Открытие окна алхимии.
    self.OnCanceled         - Обработка EVENT_ALCHEMY_CANCELED. Закрытие окна алхимии или выход в меню рецептов.
    self.OnItemPlaced       - Обработка EVENT_ALCHEMY_ITEM_PLACED. Размещение или извлечение предмета из слота.
    self.OnReactionFinished - Обработка EVENT_ALCHEMY_REACTION_FINISHED. Запуск процесса варки зелья.
    self.OnRecipesChanged   - Обработка EVENT_ALCHEMY_RECIPES_CHANGED. Изменение списка доступных рецептов.
    self.OnItemTaken        - Обработка EVENT_AVATAR_ITEM_TAKEN. Получение предмета в инвентарь.
    self.CancelDelayedCalls - Отмена всех запланированных отложенных вызовов.
    self.GetEventHandlers   - Получение списка обработчиков для регистрации в системе событий.
]]
--------------------------------------------------------------------------------

Class( "EventHandlers", {
    _reactionSuccess = false, -- true: чтобы при получении предмета показать поздравление с кол-вом полученного предмета.
    _taskRefItemPlaced = nil,
} )

--------------------------------------------------------------------------------
--- @param services table
--------------------------------------------------------------------------------
function EventHandlers:Init( services )
    self._services = services
    
    advEvent.RegisterEventHandlers( self, self:GetEventHandlers() )
end

--------------------------------------------------------------------------------
function EventHandlers:OnStarted()
    DebugService.LogGeneral( "EVENT_ALCHEMY_STARTED", { "ShowGreetings:", self._services.view.messageType } )
    
    mainForm:Show( true )
    
    self._services.recipe:CreateRecipeCache()
    self._services.view:ShowGreetings()
    self._services.view:ScheduleResetMessageType()
end

--------------------------------------------------------------------------------
--- @param params table { isSuccess: boolean }
--------------------------------------------------------------------------------
function EventHandlers:OnCanceled( params )
    -- Fix: 17.0.01.37 isSuccess (number(0/1))
    if not params.isSuccess or params.isSuccess == 0 then
        mainForm:Show( false )
        self._reactionSuccess = false
        
        self:CancelDelayedCalls()
        self._services.view:CancelDelayedCalls()
        
        -- При следующем открытии покажет сообщение "С возвращением!"
        self._services.view.messageType = CONFIG.MESSAGE_WELCOME_BACK
    end
    
    DebugService.LogGeneral(
        "EVENT_ALCHEMY_CANCELED",
        { "params: { isSuccess: boolean }", params }
    )
end

--------------------------------------------------------------------------------
--- @param params table { placed: boolean, slot: number }
--------------------------------------------------------------------------------
function EventHandlers:OnItemPlaced( params )
    if not params.placed then
        self._reactionSuccess = false
    end
    
    DebugService.LogGeneral( 
        "EVENT_ALCHEMY_ITEM_PLACED",
        function ()
            if params.placed then return "DEBUG_INSERT_BAR" end
            return "DEBUG_REMOVED_BAR"
        end, 
        { "params: { placed: boolean, slot: number }", params }
    )
    
    -- Блокировка ShowPotentialRecipes сообщения.
    if self._services.view.messageType ~= CONFIG.MESSAGE_NORMAL or self._reactionSuccess then
        return
    end
    
    self:CancelDelayedCalls()
    
    local function ShowPotentialRecipes()
        self._taskRefItemPlaced = nil
        
        local countRecipe, filledDrumsCount = self._services.recipe:CountPotential()
        self._services.view:ShowPotentialRecipes( countRecipe, filledDrumsCount )
        
        DebugService.LogGeneral( { "ShowPotentialRecipes:", countRecipe } )
    end
	
    self._taskRefItemPlaced = common.DelayedCall( CONFIG.DELAY_MS_UPDATE, ShowPotentialRecipes )
end

--------------------------------------------------------------------------------
function EventHandlers:OnReactionFinished()
    local found, drumsCount = self._services.search:FindBestRecipes()
    self._services.view:ShowReactionResults( found, CONFIG.MAX_DISPLAY_RESULTS, drumsCount )
    
    if #found == 0 then
        -- Бормотуха
        DebugService.LogReaction( "EVENT_ALCHEMY_REACTION_FINISHED:{empty}" )
    else
        DebugService.LogReaction( function()
            return self._services.view:ResultsForLog( found, CONFIG.MAX_DISPLAY_RESULTS, drumsCount )
        end )
    end
    
    self._reactionSuccess = true
end

--------------------------------------------------------------------------------
function EventHandlers:OnRecipesChanged()
    DebugService.LogGeneral( "EVENT_ALCHEMY_RECIPES_CHANGED" )
    
    self._services.recipe:ResetRecipeCache()
	if not mainForm:IsVisible() then return end
    self._services.view:ShowCongratulation()
    
    self._services.view.messageType = CONFIG.MESSAGE_WELCOME_BACK
    self._services.view:ScheduleResetMessageType()
end

--------------------------------------------------------------------------------
--- @param params table { actionType: string, itemObject: ValuedObjectLua }
--------------------------------------------------------------------------------
function EventHandlers:OnItemTaken( params )
    if not ( mainForm:IsVisible() and EnumTakeItemActionType.CRAFT:Equals( params.actionType ) ) then
        return
    end
    
    DebugService.LogGeneral( "EVENT_AVATAR_ITEM_TAKEN", { 
        "params: { actionType: string, itemObject: ValuedObjectLua }", params 
    } )
    
    -- Информация о созданном предмете по его ID.
    local info = itemLib.GetItemInfo( params.itemObject:GetId() )
    if not info or not info.name then return end
    -- Количество предметов в стаке.
    local count = itemLib.GetStackInfo( params.itemObject:GetId() ).count
    
    self._services.view:ShowItemTaken( info.name, count )
end

--------------------------------------------------------------------------------
function EventHandlers:CancelDelayedCalls()
    if self._taskRefItemPlaced then
        common.CancelDelayedCall( self._taskRefItemPlaced )
        self._taskRefItemPlaced = nil
    end
end

--------------------------------------------------------------------------------
--- @return table handlers
--------------------------------------------------------------------------------
function EventHandlers:GetEventHandlers()
    return {
        { -- Окно алхимки открывается.
            self.OnStarted,
            "EVENT_ALCHEMY_STARTED"
        },
        { -- Окно алхимки закрывается / вышли из варки в меню.
            self.OnCanceled,
            "EVENT_ALCHEMY_CANCELED"
        },
        { -- При каждом изменении слота для компонентов уведомляет, что в такой-то слот был вставлен/вынут компонент.
            self.OnItemPlaced,
            "EVENT_ALCHEMY_ITEM_PLACED"
        },
        { -- Уведомляет о начале (финиширует, но проигрывается анимация интерфейса) варки зелья.
            self.OnReactionFinished,
            "EVENT_ALCHEMY_REACTION_FINISHED"
        },
        { -- Уведомляет об необходимости обновить список рецептов.
            self.OnRecipesChanged,
            "EVENT_ALCHEMY_RECIPES_CHANGED"
        },
        
        { -- Всё что попало в сумку игрока от крафта алхимки.
            self.OnItemTaken,
            "EVENT_AVATAR_ITEM_TAKEN",
        },
    }
end