--------------------------------------------------------------------------------
-- GUI/WidgetTextContainer.lua
-- Обвертка для управления текстовым контейнером (TextContainer) и его родителем.
--------------------------------------------------------------------------------

Class( "WidgetTextContainer", {
    _wtTextContainer = nil,
} )

--------------------------------------------------------------------------------
--- Инициализация.
--------------------------------------------------------------------------------
function WidgetTextContainer:Init()
    self._wtParent = self._wtTextContainer:GetParent()
end

--------------------------------------------------------------------------------
--- Установить набор строк в текстовый контейнер.
--- Полностью очищает контейнер перед добавлением новых строк.
--- @param ... ValuedText | WString | string
--------------------------------------------------------------------------------
function WidgetTextContainer:SetLines( ... )
    self._wtTextContainer:RemoveItems()
	
	for _, line in ipairs { ... }  do
		self._wtTextContainer:PushBackText( line )
	end
	
    -- Выдать высоту текста и подстроить под него сам Panel
    local exactHeight = self:GetExactTextHeight()
    self:UpdateSizePanel( exactHeight )
end

--------------------------------------------------------------------------------
--- Динамически подстраивает размер Panel под переданную высоту текста + отступы.
--- @param textHeight number
--------------------------------------------------------------------------------
function WidgetTextContainer:UpdateSizePanel( textHeight )
    -- Новый отступ от Panel для ouText
    local ouTextPlc = self._wtTextContainer:GetPlacementPlain()
    ouTextPlc.posX = CONFIG.GUI.PADDING
    ouTextPlc.posY = CONFIG.GUI.PADDING
    self._wtTextContainer:SetPlacementPlain( ouTextPlc )
    
    -- Ширина: отступ слева (posX) и справа + фиксированная ширина текста
    local targetSizeX = CONFIG.GUI.PADDING * 2 + ouTextPlc.sizeX
    -- Высота: отступ сверху (posY) и снизу + высота текста
    local targetSizeY = CONFIG.GUI.PADDING * 2 + textHeight

    -- Новый размер для Panel
    local panelPlc = self._wtParent:GetPlacementPlain()
    -- Позицирование от центра: окно смещается вниз от центра Y
    panelPlc.posY = panelPlc.posY - panelPlc.sizeY / 2 + targetSizeY / 2
    panelPlc.sizeX = targetSizeX
    panelPlc.sizeY = targetSizeY
    self._wtParent:SetPlacementPlain( panelPlc )
end

--------------------------------------------------------------------------------
--- Возвращает пиксельную высоту текстового контента.
--- Использует внутренний ouText -> __Border -> __Content.
--- @return number
--------------------------------------------------------------------------------
function WidgetTextContainer:GetExactTextHeight()
    self._wtTextContainer:ForceReposition()
    
    local content = self._wtTextContainer:GetChildChecked( "__Border" ):GetChildChecked( "__Content" )
    local contentPlc = content:GetPlacementPlain()
    return contentPlc.posY + contentPlc.sizeY
end

--------------------------------------------------------------------------------
--- Центрирует окно с подсказкой.
--------------------------------------------------------------------------------
function WidgetTextContainer:UpdateCenterPanel()
    local pco = common.GetPosConverterParams()
    local plc = self._wtParent:GetPlacementPlain()
    
    plc.posX = CONFIG.GUI.POS_X
    plc.posY = CONFIG.GUI.SIZE_Y / 2 + plc.sizeY / 2
    
    self._wtParent:SetPlacementPlain( plc )
end