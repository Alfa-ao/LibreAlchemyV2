--------------------------------------------------------------------------------
-- Events/AvatarEvents.lua
-- Класс, отвечающий за обработку событий персонажа (EVENT_AVATAR_*).
--------------------------------------------------------------------------------

Class( "AvatarEvents", {
    _wtMovable = nil
} )

--------------------------------------------------------------------------------
--- @param context table -- Набор всякого всяческого
--------------------------------------------------------------------------------
function AvatarEvents:Init( context )
    self._alchemy = context.alchemy
    self._dnd = context.dnd
    self._view = context.view
    
    advEvent.RegisterEventHandlers( false, self:GetActiveEventHandlers() )
    
    if avatar.IsExist() then
        self:OnAvatarCreated()
    end
end

--------------------------------------------------------------------------------
--- Обработчик события EVENT_AVATAR_CREATED.
--- Выполняется при входе персонажа в игру.
--------------------------------------------------------------------------------
function AvatarEvents:OnAvatarCreated()
    self._view:UpdateCenterPanel()
    
    if CONFIG.ENABLE_CUSTOM_LAYOUT then
        -- Применение кастомного расположения элементов окна алхимии.
        self._alchemy:InitCustomLayout()
    end
    
    -- Окно с подсказкой становится перетаскиваемым.
    self._dnd:Register( self._wtMovable, { saveToConfig = CONFIG.DND.SAVE } )
end

--------------------------------------------------------------------------------
--- Обработчик события EVENT_AVATAR_ITEM_TAKEN.
--- Срабатывает при получении предмета. Если это действие (крафта),
--- и реакция была успешной, выводит поздравление с названием и количеством зелий.
--- @param params table { actionType: string, itemObject: ValuedObjectLua }
--------------------------------------------------------------------------------
function AvatarEvents:OnItemTaken( params )
    -----------------DEBUG------------------
    DebugService.LogGeneral( "EVENT_AVATAR_ITEM_TAKEN", { 
        "params: { actionType: string, itemObject: ValuedObjectLua }", params 
    } )
    ------------------END-------------------
    
    if params.actionType == EnumTakeItemActionType.CRAFT and AlchemyState.reactionSuccess then
        -- Информация о созданном предмете по его ID.
        local info = itemLib.GetItemInfo( params.itemObject:GetId() )
        if not info or not info.name then return end
        -- Количество предметов в стаке.
        local count = itemLib.GetStackInfo( params.itemObject:GetId() ).count
        
        self._view:ShowItemTaken( info.name, count )
    end
end

--------------------------------------------------------------------------------
--- @return table handlers
--------------------------------------------------------------------------------
function AvatarEvents:GetActiveEventHandlers()
    return {
        { -- Инициализация логики. Когда игрок уже в игре, только тогда необходимо применинить следующую логику.
            function() self:OnAvatarCreated() end,
            "EVENT_AVATAR_CREATED"
        },
        { -- Всё что попало в сумку игрока от крафта алхимки.
            function( params ) self:OnItemTaken( params ) end,
            "EVENT_AVATAR_ITEM_TAKEN"
        },
    }
end