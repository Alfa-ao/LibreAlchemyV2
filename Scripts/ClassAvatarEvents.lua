--------------------------------------------------------------------------------
-- ClassAvatarEvents.lua
-- Класс, отвечающий за обработку событий персонажа (EVENT_AVATAR_*).
--------------------------------------------------------------------------------

Class( "AvatarEvents" )

--------------------------------------------------------------------------------
--- @param view table ClassViewService
--------------------------------------------------------------------------------
function AvatarEvents:Init( view )
    self._view = view
    advEvent.RegisterEventHandlers( false, self:GetActiveEventHandlers() )
end



--------------------------------------------------------------------------------
--- Обработчик события EVENT_AVATAR_ITEM_TAKEN.
--- Срабатывает при получении предмета.
--- @param params table { actionType: string, itemObject: ValuedObjectLua }
--------------------------------------------------------------------------------
function AvatarEvents:OnItemTaken( params )
    -----------------DEBUG------------------
    DebugService.LogGeneral( "EVENT_AVATAR_ITEM_TAKEN", { 
        "params: { actionType: string, itemObject: ValuedObjectLua }", params 
    } )
    ------------------END-------------------
    
    -- Информация о созданном предмете по его ID.
    local info = itemLib.GetItemInfo( params.itemObject:GetId() )
    if not info or not info.name then return end
    -- Количество предметов в стаке.
    local count = itemLib.GetStackInfo( params.itemObject:GetId() ).count
    
    self._view:ShowItemTaken( info.name, count )
end



--------------------------------------------------------------------------------
--- @return table handlers
--------------------------------------------------------------------------------
function AvatarEvents:GetActiveEventHandlers()
    return {
        { -- Всё что попало в сумку игрока от крафта алхимки.
            function( params )
                if params.actionType == EnumTakeItemActionType.CRAFT and _G.mainForm:IsVisible() then
                    self:OnItemTaken( params )
                end
            end,
            "EVENT_AVATAR_ITEM_TAKEN",
        },
    }
end