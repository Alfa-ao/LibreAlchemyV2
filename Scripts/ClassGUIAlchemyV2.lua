--------------------------------------------------------------------------------
--[[
ClassGUIAlchemyV2.lua - Обертка для кастомизации стандартного интерфейса окна алхимии.
    Изменяет размеры и позиции стандартных элементов (колб, кнопок, горелок).

Класс GUIAlchemyV2 реализует следующие методы:
    self.Init - _wtRolls - Панель с колбами. _wtRecipeName - Виджет, откуда достаётся имя рецепта.
    self.CustomStyle - Всё что стилизуется в родном интерфейсе AlchemyV2.
    self.GetCurrentRecipeName - Получить имя рецепта, выбранного в AlchemyV2.
]]
--------------------------------------------------------------------------------

Class( "GUIAlchemyV2" )

local function ChildPath( widget, path )
    for part in string.gmatch( path, "[^.]+" ) do
        widget = widget:GetChildChecked( part )
    end
    return widget
end

--------------------------------------------------------------------------------
--- @param wtAlchemyV2 Widget
--------------------------------------------------------------------------------
function GUIAlchemyV2:Init( wtAlchemyV2 )
    self._wtRolls = ChildPath( wtAlchemyV2, "MainFrame.Alchemy.Game.View.Rolls" )
    self._wtRecipeName = ChildPath( wtAlchemyV2, "MainFrame.Alchemy.Game.View.Recipe.Name" )
end

--------------------------------------------------------------------------------
function GUIAlchemyV2:CustomStyle()
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
--- @return WString
--------------------------------------------------------------------------------
function GUIAlchemyV2:GetCurrentRecipeName()
    return self._wtRecipeName:GetWString()
end