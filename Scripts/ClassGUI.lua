--------------------------------------------------------------------------------
--[[
ClassGUI.lua - Общий слой для работы с нативным виджетом и кастомизацией.

Класс GUI реализует следующие методы:
    self.Init
    self.CustomStyle          - Применение кастомного стиля к окну алхимии.
    self.GetCurrentRecipeName - Получение имени текущего рецепта.
    self.SetLines             - Установка строк в текстовый контейнер.
    self.UpdateSizePanel      - Обновляет размеры Panel при изменении масштаба/размера окна.
    self.PosCenterPanel       - Центрирование панели подсказки.
]]
--------------------------------------------------------------------------------

Class( "GUI" )

local function ChildPath( widget, path )
    for part in string.gmatch( path, "[^.]+" ) do
        widget = widget:GetChildChecked( part )
    end
    
    return widget
end

--------------------------------------------------------------------------------
--- @param wtAlchemyV2 Widget
--- @param wtPanel Widget | TWidget
--- @param wtTextContainer Widget | TWidget
--------------------------------------------------------------------------------
function GUI:Init( wtAlchemyV2, wtPanel, wtTextContainer )
    self._wtRolls = ChildPath( wtAlchemyV2, "MainFrame.Alchemy.Game.View.Rolls" )
    self._wtRecipeName = ChildPath( wtAlchemyV2, "MainFrame.Alchemy.Game.View.Recipe.Name" )
    
    self._wtParent = wtPanel
    self._wtTextContainer = wtTextContainer
    
    self:CustomStyle()
end

--------------------------------------------------------------------------------
function GUI:CustomStyle()
    if not CONFIG.ENABLE_CUSTOM_LAYOUT then
        return
    end
    
    local listBars = {}
    for i = 1, 5 do
        listBars[ i ] = self._wtRolls:GetChildChecked( "Bar0" .. i )
    end
    
    -- Bar(01/02/03/04/05).RollTube.(ActionUp/ActionDown)
    for _, bar in ipairs( listBars ) do
        local rollTube = bar:GetChildChecked( "RollTube" )
        local actionUp = rollTube:GetChildChecked( "ActionUp" )
        local actionDown = rollTube:GetChildChecked( "ActionDown" )
        local correctionCount = bar:GetChildChecked( "CorrectionCount" )
        
        -- Отвечает за: Позицию верхней кнопки.
        local plcActionUp = actionUp:GetPlacementPlain()
        plcActionUp.posY = CONFIG.GUI.ACTION_UP_POS_Y
        actionUp:SetPlacementPlain( plcActionUp )
        
        -- Отвечает за: Позицию нижней кнопки.
        local plcActionDown = actionDown:GetPlacementPlain()
        plcActionDown.posY = CONFIG.GUI.ACTION_UP_POS_Y + plcActionDown.sizeY
        actionDown:SetPlacementPlain( plcActionDown )
        
        -- Отвечает за: Размер основной колбы совместно с BackLayer текстурой.
        local plcRollTube = rollTube:GetPlacementPlain()
        plcRollTube.sizeY = CONFIG.GUI.ROLL_TUBE_EXTRA_SIZE + plcActionDown.sizeY
        rollTube:SetPlacementPlain( plcRollTube )
        
        -- Отвечает за: Контейнер (Основная колба + Горелка под колбой)
        local plcBar = bar:GetPlacementPlain()
        plcBar.sizeY = CONFIG.GUI.BAR_EXTRA_SIZE + plcActionDown.sizeY
        bar:SetPlacementPlain( plcBar )
        
        -- Отвечает за: Цифра над горелкой
        local plcCorrectionCount = correctionCount:GetPlacementPlain()
        plcCorrectionCount.sizeY = CONFIG.GUI.CORRECTION_COUNT_EXTRA_SIZE
        correctionCount:SetPlacementPlain( plcCorrectionCount )
    end
    
    -- Отвечает за: Контейнер c 5ю колбами (Иконки над колбой + Основная колба + Горелка под колбой)
    local plcRolls = self._wtRolls:GetPlacementPlain()
    plcRolls.sizeY = CONFIG.GUI.BAR_EXTRA_SIZE + CONFIG.GUI.ROLLS_EXTRA_SIZE
    plcRolls.highPosY = CONFIG.GUI.ROLLS_HIGH_POS_Y_OFFSET - CONFIG.GUI.ROLLS_EXTRA_SIZE
    self._wtRolls:SetPlacementPlain( plcRolls )
end

--------------------------------------------------------------------------------
--- @return WString name Имя зелья
--------------------------------------------------------------------------------
function GUI:GetCurrentRecipeName()
    return self._wtRecipeName:GetWString()
end

--------------------------------------------------------------------------------
--- @param ... ValuedText | WString | string
--------------------------------------------------------------------------------
function GUI:SetLines( ... )
    self._wtTextContainer:RemoveItems()
	
	for _, line in ipairs { ... }  do
		self._wtTextContainer:PushBackText( line )
	end
	
    self:UpdateSizePanel()
end

--------------------------------------------------------------------------------
function GUI:UpdateSizePanel()
    local panelPlc = self._wtParent:GetPlacementPlain()
    local ouTextPlc = self._wtTextContainer:GetPlacementPlain()
    
    ouTextPlc.posX = CONFIG.GUI.PADDING
    ouTextPlc.posY = CONFIG.GUI.PADDING
    
    if panelPlc.sizeX > ( CONFIG.GUI.CONTAINER_SIZE_X + CONFIG.GUI.PADDING * 2 ) then
        ouTextPlc.sizeX = panelPlc.sizeX - CONFIG.GUI.PADDING * 2
    else
        ouTextPlc.sizeX = CONFIG.GUI.CONTAINER_SIZE_X
    end
    
    self._wtTextContainer:SetPlacementPlain( ouTextPlc )
    self._wtTextContainer:ForceReposition()
    
    local contentPlc = self._wtTextContainer.wt__Border.wt__Content:GetPlacementPlain()
    
    -- Ширина: отступ слева (posX) и справа + фиксированная ширина текста
    local targetSizeX = CONFIG.GUI.PADDING * 2 + ouTextPlc.sizeX
    -- Высота: отступ сверху (posY) и снизу + высота текста
    local targetSizeY = CONFIG.GUI.PADDING * 2 + contentPlc.posY + contentPlc.sizeY
    
    if panelPlc.alignY == WIDGET_ALIGN_CENTER then
        -- Позиционирование от центра: окно смещается вниз от центра Y
        panelPlc.posY = panelPlc.posY - panelPlc.sizeY / 2 + targetSizeY / 2
    end
    
    panelPlc.sizeX = targetSizeX
    panelPlc.sizeY = targetSizeY
    self._wtParent:SetPlacementPlain( panelPlc )
end

--------------------------------------------------------------------------------
function GUI:PosCenterPanel()
    local plc = self._wtParent:GetPlacementPlain()
    
    plc.posX = CONFIG.GUI.POS_X
    plc.posY = CONFIG.GUI.SIZE_Y / 2 + plc.sizeY / 2
    
    self._wtParent:SetPlacementPlain( plc )
end
