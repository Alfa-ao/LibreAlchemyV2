--------------------------------------------------------------------------------
-- Events/AlchemyAvatarEvents.lua
-- Класс, отвечающий за обработку событий персонажа (EVENT_AVATAR_*).
--------------------------------------------------------------------------------

Class( "AlchemyAvatarEvents", {
    _wtMovable = nil,
} )

--------------------------------------------------------------------------------
--- @param context table -- Набор всякого всяческого
--------------------------------------------------------------------------------
function AlchemyAvatarEvents:Init( context )
    self._state = context.state
    self._alchemy = context.alchemy
    self._debug = context.debug
    self._dnd = context.dnd
    self._view = context.view
end

--------------------------------------------------------------------------------
--- Обработчик события EVENT_AVATAR_CREATED.
--- Выполняется при входе персонажа в игру.
--------------------------------------------------------------------------------
function AlchemyAvatarEvents:OnAvatarCreated()
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
function AlchemyAvatarEvents:OnItemTaken( params )
    -----------------DEBUG------------------
    self._debug:LogGeneral( "EVENT_AVATAR_ITEM_TAKEN", { 
        "params: { actionType: string, itemObject: ValuedObjectLua }", params 
    } )
    ------------------END-------------------
    
    if params.actionType == EnumTakeItemActionType.CRAFT and self._state.reactionSuccess then
        -- Информация о созданном предмете по его ID.
        local info = itemLib.GetItemInfo( params.itemObject:GetId() )
        if not info or not info.name then return end
        -- Количество предметов в стаке.
        local count = itemLib.GetStackInfo( params.itemObject:GetId() ).count
        
        self._view:ShowItemTaken( info.name, count )
    end
end