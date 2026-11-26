--------------------------------------------------------------------------------
-- ClassAlchemy.lua
--------------------------------------------------------------------------------
-- get widget from path "Parent.Child.Name"
local function ChildPath( widget, path )
    for part in string.gmatch( path, "[^.]+" ) do
        widget = widget:GetChildChecked( part )
    end
    
    return widget
end
--------------------------------------------------------------------------------
Class( "Alchemy", advWidgetBasicElement() )
--------------------------------------------------------------------------------
--- @param wtAlchemyV2 WidgetForm главная форма системного аддона
--- @return Alchemy
--------------------------------------------------------------------------------
function Alchemy:Init( wtAlchemyV2 )
    self._reactionSuccess = false
    self._taskRefItemPlaced = false
    
    self._wtRolls = ChildPath( wtAlchemyV2, "MainFrame.Alchemy.Game.View.Rolls" )
    self._wtRecipeName = ChildPath( wtAlchemyV2, "MainFrame.Alchemy.Game.View.Recipe.Name" )
    
    self._services = {
        view = ViewService(),
        recipe = RecipeService(),
        search = SearchService(),
    }
    
    self._services.search:Init( self._services.recipe )
    self._services.view:Init( common.GetLocalization(), self )
    
    advWidgetBasicElement.Init( self )
    
    if CONFIG.ENABLE_CUSTOM_LAYOUT then
        self:CustomStyle()
    end
    
    return self
end
--------------------------------------------------------------------------------
function Alchemy:Destroy()
    self:CancelDelayedCalls()
    return advWidgetBasicElement.Destroy( self )
end
--------------------------------------------------------------------------------
--- Сброс отложенных вызовов
function Alchemy:CancelDelayedCalls()
    if self._taskRefItemPlaced then
        common.CancelDelayedCall( self._taskRefItemPlaced )
        self._taskRefItemPlaced = false
    end
end
--------------------------------------------------------------------------------
--- Обновление состояния окна
function Alchemy:Update( active )
    if active then
        self._services.recipe:CreateRecipeCache()
        self._services.view:ShowGreetings()
        self._services.view:ScheduleResetMessageType()
    else
        self._reactionSuccess = false
        self:CancelDelayedCalls()
        self._services.view:CancelDelayedCalls()
        -- При следующем открытии сообщение "С возвращением!"
        self._services.view.messageType = CONFIG.MESSAGE_WELCOME_BACK
    end
    
    return advWidgetBasicElement.Update( self, active )
end
--------------------------------------------------------------------------------
--- Открытие окна алхимии
function Alchemy:OnStarted()
    DebugService.LogGeneral( "EVENT_ALCHEMY_STARTED", { "ShowGreetings:", self._services.view.messageType } )
    self:Activate( true )
end
--------------------------------------------------------------------------------
--- Закрытие окна алхимии или выход в меню рецептов
--- @param params table { isSuccess: boolean }
--------------------------------------------------------------------------------
function Alchemy:OnCanceled( params )
    -- Fix: 17.0.01.37 params.isSuccess: number(0/1)
    if not params.isSuccess or params.isSuccess == 0 then
        self:Activate( false )
    end
    
    DebugService.LogGeneral(
        "EVENT_ALCHEMY_CANCELED",
        { "params: { isSuccess: boolean }", params }
    )
end
--------------------------------------------------------------------------------
--- Подсказка "Возможно, есть рецепты"
function Alchemy:ShowPotentialRecipes()
    self._taskRefItemPlaced = false
    
    local countRecipe, filledDrumsCount = self._services.recipe:CountPotential()
    self._services.view:ShowPotentialRecipes( countRecipe, filledDrumsCount )
    
    DebugService.LogGeneral { "ShowPotentialRecipes:", countRecipe }
end
--------------------------------------------------------------------------------
--- Размещение / извлечение предмета из слота
--- @param params table { placed: boolean, slot: number }
--------------------------------------------------------------------------------
function Alchemy:OnItemPlaced( params )
    if not params.placed then
        self._reactionSuccess = false
    end
    
    DebugService.LogGeneral(
        "EVENT_ALCHEMY_ITEM_PLACED",
        function()
            if params.placed then return "DEBUG_INSERT_BAR" end
            return "DEBUG_REMOVED_BAR"
        end,
        { "params: { placed: boolean, slot: number }", params }
    )
    
    -- Блокировка сообщения ShowPotentialRecipes
    if self._services.view.messageType ~= CONFIG.MESSAGE_NORMAL or self._reactionSuccess then
        return
    end
    
    self:CancelDelayedCalls()
    
    self._taskRefItemPlaced = common.DelayedCall( CONFIG.DELAY_MS_UPDATE, function()
        self:ShowPotentialRecipes()
    end )
end
--------------------------------------------------------------------------------
--- Запуск варки зелья
function Alchemy:OnReactionFinished()
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
-- Изменение списка существующих рецептов
function Alchemy:OnRecipesChanged()
    DebugService.LogGeneral( "EVENT_ALCHEMY_RECIPES_CHANGED" )
    
    self._services.recipe:ResetRecipeCache()
	if not mainForm:IsVisible() then return end
    
    self._services.view:ShowCongratulation()
    self._services.view.messageType = CONFIG.MESSAGE_WELCOME_BACK
    self._services.view:ScheduleResetMessageType()
end
--------------------------------------------------------------------------------
--- Получение предмета в инвентарь от крафта
--- @param params table { actionType: string, itemObject: ValuedObjectLua }
--------------------------------------------------------------------------------
function Alchemy:OnItemTaken( params )
    if params.actionType ~= "ENUM_TakeItemActionType_Craft" then
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
--- Перезапуск state алхимии
function Alchemy:OnAddonLoadStateChanged()
    common.StateReloadManagedAddon( CONFIG.SYSTEM_ADDON_NAME )
end
--------------------------------------------------------------------------------
function Alchemy:GetPassiveEventHandlers()
    return {
        { self.OnStarted, "EVENT_ALCHEMY_STARTED" }, -- Окно алхимки открывается.
        { self.OnCanceled, "EVENT_ALCHEMY_CANCELED" }, -- Окно алхимки закрывается / вышли из варки в меню.
        { self.OnItemPlaced, "EVENT_ALCHEMY_ITEM_PLACED" }, -- При каждом изменении слота для компонентов уведомляет, что в такой-то слот был вставлен/вынут компонент.
        { self.OnReactionFinished, "EVENT_ALCHEMY_REACTION_FINISHED" }, -- Уведомляет о начале (финиширует, но проигрывается анимация интерфейса) варки зелья.
        { self.OnRecipesChanged, "EVENT_ALCHEMY_RECIPES_CHANGED" }, -- Уведомляет об необходимости обновить список рецептов.
        { self.OnAddonLoadStateChanged, "EVENT_ADDON_LOAD_STATE_CHANGED", {
            name = ADDON_NAME, -- Совпадение с именем
            state = ADDON_STATE_UNLOADING -- Совпадение с состоянием
        }, { cfilter = true } },
    }
end
--------------------------------------------------------------------------------
function Alchemy:GetActiveEventHandlers()
    return {
        { self.OnItemTaken, "EVENT_AVATAR_ITEM_TAKEN" }, -- Всё что попало в сумку игрока от крафта алхимки.
    }
end
--------------------------------------------------------------------------------
--- Применение кастомного стиля для окна алхимки
function Alchemy:CustomStyle()
    -- Bar(01/02/03/04/05).RollTube.(ActionUp/ActionDown)
    for i = 1, 5 do
        local bar = self._wtRolls:GetChildChecked( "Bar0" .. i )
        local rollTube = bar:GetChildChecked( "RollTube" )
        local actionDown = rollTube:GetChildChecked( "ActionDown" )
        local plcActionDown = actionDown:GetPlacementPlain()
        
        -- позиция верхней кнопки
        rollTube:GetChildChecked( "ActionUp" ):SetPlacementPlain { posY = CONFIG.GUI.ACTION_UP_POS_Y }
        -- позиция нижней кнопки
        actionDown:SetPlacementPlain { posY = CONFIG.GUI.ACTION_UP_POS_Y + plcActionDown.sizeY }
        -- размер основной колбы вместе с BackLayer текстурой
        rollTube:SetPlacementPlain { sizeY = CONFIG.GUI.ROLL_TUBE_EXTRA_SIZE + plcActionDown.sizeY }
        -- блок - основная колба и горелка под колбой
        bar:SetPlacementPlain { sizeY = CONFIG.GUI.BAR_EXTRA_SIZE + plcActionDown.sizeY }
        -- цифра над горелкой
        bar:GetChildChecked( "CorrectionCount" ):SetPlacementPlain { sizeY = CONFIG.GUI.CORRECTION_COUNT_EXTRA_SIZE }
    end
    
    -- блок с пятью колбами
    self._wtRolls:SetPlacementPlain{
        sizeY = CONFIG.GUI.BAR_EXTRA_SIZE + CONFIG.GUI.ROLLS_EXTRA_SIZE,
        highPosY = CONFIG.GUI.ROLLS_HIGH_POS_Y_OFFSET - CONFIG.GUI.ROLLS_EXTRA_SIZE,
    }
end
--------------------------------------------------------------------------------
--- @return WString name имя зелья
--------------------------------------------------------------------------------
function Alchemy:GetCurrentRecipeName()
    return self._wtRecipeName:GetWString()
end
--------------------------------------------------------------------------------
--- Установка строк текстового контейнера
--- @param ... ValuedText | WString | string
--------------------------------------------------------------------------------
function Alchemy:SetLines( ... )
    self.wtTextContainer:RemoveItems()
    
    for _, line in ipairs { ... } do
        self.wtTextContainer:PushBackText( line )
    end
    
    self.wtTextContainer:ForceReposition()
    self:UpdateSizePanel()
    DnDManager:UpdateSavedPlacement( self.wtTextContainer )
end
--------------------------------------------------------------------------------
--- Обновление размеров панели при смене масштаба / размера окна
function Alchemy:UpdateSizePanel()
    local containerPlc = self.wtTextContainer:GetPlacementPlain()
    
    if containerPlc.sizeX < CONFIG.GUI.CONTAINER_SIZE_X then
        containerPlc.posX = containerPlc.posX + CONFIG.GUI.CONTAINER_SIZE_X / 2 - containerPlc.sizeX / 2
        containerPlc.sizeX = CONFIG.GUI.CONTAINER_SIZE_X
        self.wtTextContainer:SetPlacementPlain( containerPlc )
        self.wtTextContainer:ForceReposition()
    end
    
    local borderPlc = self.wtTextContainer.wt__Border:GetPlacementPlain()
    local contentPlc = self.wtTextContainer.wt__Border.wt__Content:GetPlacementPlain()
    local targetSizeY = borderPlc.posY + borderPlc.highPosY + contentPlc.sizeY -- Border + высота контента
    
    if containerPlc.alignY == WIDGET_ALIGN_CENTER then
        -- окно смещается вниз от центра Y
        containerPlc.posY = containerPlc.posY - containerPlc.sizeY / 2 + targetSizeY / 2
    end
    
    containerPlc.sizeY = targetSizeY
    self.wtTextContainer:SetPlacementPlain( containerPlc )
end
--------------------------------------------------------------------------------
--- Начальное центрирование панели подсказки
function Alchemy:PosCenterPanel()
    local plc = self.wtTextContainer:GetPlacementPlain()
    self.wtTextContainer:SetPlacementPlain{
        posX = CONFIG.GUI.POS_X,
        posY = CONFIG.GUI.SIZE_Y / 2 + plc.sizeY / 2,
    }
end