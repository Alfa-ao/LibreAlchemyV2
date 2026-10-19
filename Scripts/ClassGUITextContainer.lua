--------------------------------------------------------------------------------
--[[
ClassGUITextContainer.lua - Обвертка для управления текстовым контейнером (TextContainer) и его родителем (Panel).

Класс GUITextContainer реализует следующие методы:
    self.Init
    self.SetLines           - Устанавливает набор строк в текстовый контейнер. Полностью очищает контейнер перед добавлением.
    self.UpdateSizePanel    - Обновляет размер Panel под высоту текста + отступы.
    self.PosCenterPanel     - Центрирует окно с подсказкой.
    self.GetEventHandlers   - EVENT_POS_CONVERTER_CHANGED
]]
--------------------------------------------------------------------------------

Class( "GUITextContainer" )

--------------------------------------------------------------------------------
--- @param wtParent Widget | TWidget
--- @param name string 
--------------------------------------------------------------------------------
function GUITextContainer:Init( wtParent, name )
    self._wtParent = wtParent
    self._wtTextContainer = wtParent:GetChildChecked( name )
    
    advEvent.RegisterEventHandlers( self, self:GetEventHandlers() )
end

--------------------------------------------------------------------------------
--- @param ... ValuedText | WString | string
--------------------------------------------------------------------------------
function GUITextContainer:SetLines( ... )
    self._wtTextContainer:RemoveItems()
	
	for _, line in ipairs { ... }  do
		self._wtTextContainer:PushBackText( line )
	end
	
    self:UpdateSizePanel()
end

--------------------------------------------------------------------------------
function GUITextContainer:UpdateSizePanel()
    self._wtTextContainer:ForceReposition()
    
    local contentPlc = self._wtTextContainer.wt__Border.wt__Content:GetPlacementPlain()
    
    local ouTextPlc = self._wtTextContainer:GetPlacementPlain()
    ouTextPlc.posX = CONFIG.GUI.PADDING
    ouTextPlc.posY = CONFIG.GUI.PADDING
    self._wtTextContainer:SetPlacementPlain( ouTextPlc )
    
    -- Ширина: отступ слева (posX) и справа + фиксированная ширина текста
    local targetSizeX = CONFIG.GUI.PADDING * 2 + ouTextPlc.sizeX
    -- Высота: отступ сверху (posY) и снизу + высота текста
    local targetSizeY = CONFIG.GUI.PADDING * 2 + contentPlc.posY + contentPlc.sizeY

    -- Новый размер для Panel
    local panelPlc = self._wtParent:GetPlacementPlain()
    
    
    if panelPlc.alignX == WIDGET_ALIGN_CENTER then
        -- Позиционирование от центра: окно смещается вниз от центра Y
        panelPlc.posY = panelPlc.posY - panelPlc.sizeY / 2 + targetSizeY / 2
    end
    
    panelPlc.sizeX = targetSizeX
    panelPlc.sizeY = targetSizeY
    self._wtParent:SetPlacementPlain( panelPlc )
end

--------------------------------------------------------------------------------
function GUITextContainer:PosCenterPanel()
    local pco = common.GetPosConverterParams()
    local plc = self._wtParent:GetPlacementPlain()
    
    plc.posX = CONFIG.GUI.POS_X
    plc.posY = CONFIG.GUI.SIZE_Y / 2 + plc.sizeY / 2
    
    self._wtParent:SetPlacementPlain( plc )
end

--------------------------------------------------------------------------------
--- @return table handlers
--------------------------------------------------------------------------------
function GUITextContainer:GetEventHandlers()
    return {
        { -- Обновляет размеры Panel при изменении масштаба/размера окна игры.
            self.UpdateSizePanel,
            "EVENT_POS_CONVERTER_CHANGED"
        },
    }
end