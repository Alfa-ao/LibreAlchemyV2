--------------------------------------------------------------------------------
--[[
DnDManager.lua - ООП менеджер Drag & Drop для виджетов.

Класс DnDManager реализует следующие методы:
    self.Init
    self.Register            - Регистрация виджета с его дополнительными настройками.
    self.Unregister          - Удаление виджета из менеджера.
    self.SetEnabled          - Включение/отключение возможности перетаскивания.
    self.AllocateDnDID       - Генерация уникального DnD ID для виджета.
    self.GetWidgetID         - Поиск dndId по любому из связанных виджетов.
    self.IsDragActive        - Проверка наличия активного перетаскивания.
    self.UnregisterAllEvents - Полная дерегистрация всех событий.
]]
--------------------------------------------------------------------------------

--- @class DnDManager
--- @field _widgets table Хранилище зарегистрированных виджетов [ dndId ] = WidgetInfo
--- @field _activeDrag table|nil Текущее состояние активного перетаскивания
--- @field _eventHandlers table Ссылки на коллбэки для отписки от событий
--- @field _screenParams table Кэш параметров координат (разрешение экрана)
Class( "DnDManager", {
    __CONFIG_VERSION = "1.0.0-original",
    _opposite = {
        posX = "highPosX",
        posY = "highPosY",
        highPosX = "posX",
        highPosY = "posY",
    },
    _widgets = nil,
    _activeDrag = nil,
    _eventHandlers = nil,
    _screenParams = nil,
    _initialized = false,
    _options = nil,
} )

--------------------------------------------------------------------------------
--- Инициализация менеджера.
--- @param params table|nil
--------------------------------------------------------------------------------
function DnDManager:Init( params )
    params = type( params ) == "table" and params or {}
    
    assert( not self._initialized, "DnDManager:Init() has already been called. Re-initialization is not allowed." )
    
    self._initialized = true

    self._options = {
        configProvider = nil,
        defaultCursor = type( params.defaultCursor ) == "string"
            and params.defaultCursor
            or "default",
    }
    
    if type( params.configProvider ) == "table" then
        assert(
            type( params.configProvider.get ) == "function",
            "configProvider.get must be a function"
        )

        assert(
            type( params.configProvider.set ) == "function",
            "configProvider.set must be a function"
        )

        self._options.configProvider = params.configProvider
    else
        self._options.configProvider = {
            get = function()
                return userMods.GetGlobalConfigSection( common.GetAddonName() ) -- table|nil
            end,

            set = function( section )
                userMods.SetGlobalConfigSection( common.GetAddonName(), section )
            end,
        }
    end

    self._widgets = {}
    self._activeDrag = nil
    self._eventHandlers = {}
    self._screenParams = common.GetPosConverterParams()
    
    self:_RegisterAllEvents()
end

--------------------------------------------------------------------------------
--- @class DndRegisterOptions
--- @field wtReacting userdata|table|nil Виджет, на котором реагирует DnD.
--- @field saveToConfig boolean|nil Использовать конфиг для сохранения позиции.
--- @field lockedToParentArea boolean|nil Ограничивать ли перемещение областью родителя.
--- @field kbFlag number|nil Флаг клавиш KBF_*.
--- @field cursor string|nil Курсор во время перетаскивания. См. названия курсоров "Аллоды Онлайн/data/Packs/Interface.Mini.pak/Interface/System/Cursors"

--- @param wtMovable userdata|table Перемещаемый виджет.
--- @param options DndRegisterOptions|nil Настройки регистрации.
--- @param resizeHandles table|nil Таблица для растягивания.
--- @return number dndId ID зарегистрированного виджета.
--------------------------------------------------------------------------------
function DnDManager:Register( wtMovable, options, resizeHandles )
    assert( self._initialized, "DnDManager:Register() failed: call DnDManager:Init() before registering widgets" )
    
    self:_ValidateWidget( wtMovable, "wtMovable" )
    
    options = type( options ) == "table" and options or {}

    if options.wtReacting ~= nil then
        self:_ValidateWidget( options.wtReacting, "wtReacting" )
    else
        options.wtReacting = wtMovable
    end

    local dndId = self:AllocateDnDID( options.wtReacting )
    
    assert( not self._widgets[ dndId ], "DnDManager:Register() failed: widget is already registered, dndId = %s", dndId )
    
    options.cursor = type( options.cursor ) == "string"
            and options.cursor
            or self._options.defaultCursor

    local info = {
        dndId = dndId,
        wtMovable = wtMovable,
        wtReacting = options.wtReacting,
        enabled = true,
        saveToConfig = options.saveToConfig == true, -- По умолчанию false.
        lockedToParentArea = options.lockedToParentArea ~= false, -- По умолчанию true.
        kbFlag = type( options.kbFlag ) == "number" and options.kbFlag or false, -- По умолчанию false. Ограничения отключены.
        cursor = options.cursor, -- По умолчанию "default". Имена в нижнем регистре.
        configName = nil,
    }

    if info.saveToConfig then
        info.configName = "DnD:" .. self:_GetWidgetTreePath( wtMovable ) -- DnD:Main.Panel
        self:_LoadConfig( info )
    end
    
    local currentDNDState = options.wtReacting:DNDGetState()
    
    if currentDNDState == DND_STATE_DRAGGING or currentDNDState == DND_STATE_WAIT_DROP_CONFIRMATION then
        options.wtReacting:DNDCancelDrag()
    end
    
    assert( 
        options.wtReacting:DNDGetState() == DND_STATE_NOT_REGISTERED,
        "DnDManager:Register() failed: widget is already registered in DND system outside manager, dndId = %s, state = %s",
        dndId, currentDNDState
    )
    
    options.wtReacting:DNDRegister( dndId, true )
    
    self._widgets[ dndId ] = info
    
    if type( resizeHandles ) == "table" then
        assert( #resizeHandles <= 8, "DnDManager: Resize handles limit exceeded. Maximum 8, %d provided.", #resizeHandles )
        
        for _, handleData in ipairs( resizeHandles ) do
            self:_RegisterResizeHandle(
                handleData.wtHandle,
                handleData.allowX == true,
                handleData.allowY == true,
                handleData.limitsX,
                handleData.limitsY,
                handleData.callback,
                info
            )
        end
    end
    
    return dndId
end

--------------------------------------------------------------------------------
--- Регистрация виджета-ручки для изменения размера основного виджета.
--- @param wtHandle userdata|table Виджет-ручка для растягивания.
--- @param allowX boolean Разрешить изменение размера по оси X.
--- @param allowY boolean Разрешить изменение размера по оси Y.
--- @param limitsX table|nil Допустимые размеры по оси X { min = number, max = number }.
--- @param limitsY table|nil Допустимые размеры по оси Y { min = number, max = number }.
--- @param callback function|table|nil Функция или таблица с функцией обратного вызова после изменения размера.
--- @param baseInfo table Базовая информация об основном виджете для наследования настроек.
--------------------------------------------------------------------------------
function DnDManager:_RegisterResizeHandle( wtHandle, allowX, allowY, limitsX, limitsY, callback, baseInfo )
    self:_ValidateWidget( wtHandle, "wtHandle" )
    local dndId = self:AllocateDnDID( wtHandle )
    assert( self._widgets[ dndId ] == nil, "DnDManager: handle is already registered, dndId = %s", dndId )
    
    limitsX = type( limitsX ) == "table" and limitsX or {}
    limitsY = type( limitsY ) == "table" and limitsY or {}

    local handleInfo = {
        dndId = dndId,
        wtMovable = baseInfo.wtMovable,
        wtReacting = wtHandle,
        enabled = true,
        saveToConfig = baseInfo.saveToConfig,
        lockedToParentArea = baseInfo.lockedToParentArea,
        kbFlag = baseInfo.kbFlag,
        cursor = baseInfo.cursor,
        configName = baseInfo.configName,
        isResize = true,
        resizeX = allowX,
        resizeY = allowY,
        resizeCallback = callback,
        limitsX = {
            min = limitsX.min or 50,
            max = limitsX.max or 900,
        },
        limitsY = {
            min = limitsY.min or 50,
            max = limitsY.max or 500,
        },
    }

    local currentDNDState = wtHandle:DNDGetState()
    if currentDNDState == DND_STATE_DRAGGING or currentDNDState == DND_STATE_WAIT_DROP_CONFIRMATION then
        wtHandle:DNDCancelDrag()
    end
    
    assert( wtHandle:DNDGetState() == DND_STATE_NOT_REGISTERED, "DnDManager: handle already registered in DND system" )
    
    wtHandle:DNDRegister( dndId, true )

    self._widgets[ dndId ] = handleInfo
end

--------------------------------------------------------------------------------
--- Удаление виджета из менеджера
--- @param wtWidget userdata|table Виджет.
--------------------------------------------------------------------------------
function DnDManager:Unregister( wtWidget )
    self:_ValidateWidget( wtWidget, "wtWidget" )

    local dndId = self:GetWidgetID( wtWidget )

    if not dndId then
        return
    end

    local info = self._widgets[ dndId ]

    if not info then
        return
    end
    
    if self:IsDragActive() and self._activeDrag.info.dndId == dndId then
        if info.wtReacting:DNDGetState() ~= DND_STATE_NOT_REGISTERED then
            info.wtReacting:DNDCancelDrag()
        end

        self:_StopDragging( false )
    end

    if info.wtReacting:DNDGetState() ~= DND_STATE_NOT_REGISTERED then
        info.wtReacting:DNDUnregister()
    end

    self._widgets[ dndId ] = nil
end

--------------------------------------------------------------------------------
--- Включение/отключение возможности перетаскивания
--- @param wtWidget userdata|table Сам виджет
--- @param isEnabled boolean Включение/Выключение перетаскивание
--------------------------------------------------------------------------------
function DnDManager:SetEnabled( wtWidget, isEnabled )
    self:_ValidateWidget( wtWidget, "wtWidget" )

    local dndId = self:GetWidgetID( wtWidget )
    
    assert( dndId ~= nil, "DnDManager:SetEnabled() failed: widget is not registered" )
    
    local info = self._widgets[ dndId ]
    isEnabled = isEnabled == true
    
    if not isEnabled
        and self:IsDragActive()
        and self._activeDrag.info.dndId == dndId 
    then -- Если отключается виджет, отменить сначала перетаскивание.
        local currentDNDState = info.wtReacting:DNDGetState()

        if currentDNDState ~= DND_STATE_NOT_REGISTERED then
            info.wtReacting:DNDCancelDrag()
        end

        self:_StopDragging( false )
    end
    
    info.enabled = isEnabled
    info.wtReacting:DNDEnable( isEnabled )
end

--------------------------------------------------------------------------------
--- Генерирует уникальный DnD ID для виджета.
--- @param wtWidget userdata|table Виджет.
--- @return number
--------------------------------------------------------------------------------
function DnDManager:AllocateDnDID( wtWidget )
    return wtWidget:GetId() * DND_CONTAINER_STEP + DND_GENERIC_WIDGET_USER
end

--------------------------------------------------------------------------------
--- Ищет dndId по любому из связанных виджетов.
--- @param wtWidget userdata|table Виджет.
--- @return number|nil
--------------------------------------------------------------------------------
function DnDManager:GetWidgetID( wtWidget )
	for dndId, info in pairs( self._widgets ) do
		if info.wtReacting == wtWidget or info.wtMovable == wtWidget then
			return dndId
		end
	end
    
    return nil
end

--------------------------------------------------------------------------------
--- Активное перетаскивание считается активным с момента подтверждения
--- EVENT_DND_PICK_ATTEMPT и до EVENT_DND_DROP_ATTEMPT или EVENT_DND_DRAG_CANCELLED.
--- @return boolean active Возвращает true, если в данный момент есть активное перетаскивание.
--------------------------------------------------------------------------------
function DnDManager:IsDragActive()
    return self._activeDrag ~= nil and self._activeDrag.info ~= nil
end

--------------------------------------------------------------------------------
--- Дерегистрация всех событий.
--------------------------------------------------------------------------------
function DnDManager:UnregisterAllEvents()
    if not self._eventHandlers then
        return
    end
    
    advEvent.UnRegisterEventHandlers( self, self._eventHandlers )

    self._eventHandlers = {}
end

--------------------------------------------------------------------------------
--- Регистрация всех событий.
--------------------------------------------------------------------------------
function DnDManager:_RegisterAllEvents()
    self._eventHandlers = {
        { -- Попытка начать перетаскивание
            self.OnPickAttempt,
            "EVENT_DND_PICK_ATTEMPT"
        },
        { -- Перемещение курсора во время перетаскивания
            self.OnDragTo,
            "EVENT_DND_DRAG_TO"
        },
        { -- Отпускание кнопки мыши
            self.OnDropAttempt,
            "EVENT_DND_DROP_ATTEMPT"
        },
        { -- Завершение процесса перетаскивания
            self.OnDragCancelled,
            "EVENT_DND_DRAG_CANCELLED"
        },
        { -- Изменение разрешения экрана / масштаба
            self.OnPosConverterChanged,
            "EVENT_POS_CONVERTER_CHANGED"
        },
    }

    advEvent.RegisterEventHandlers( self, self._eventHandlers )
end

--------------------------------------------------------------------------------
--- @param params table Параметры события EVENT_DND_PICK_ATTEMPT.
--------------------------------------------------------------------------------
function DnDManager:OnPickAttempt( params )
    local dndId = params.srcId
    local info = self._widgets[ dndId ]

    if not info or not info.enabled or self:IsDragActive() then
        return
    end
    
    -- Проверка модификаторов клавиатуры (Ctrl, Shift и т.д.)
    if not self:_CheckKbFlag( info.kbFlag, params.kbFlags ) then
        return
    end

    local currentPlace = info.wtMovable:GetPlacementPlain()

    self._activeDrag = {
        info = info,
        -- Стартовая позиция мыши в начале перетаскивания.
        startMousePos = {
            x = params.posX,
            y = params.posY,
        },
        startPlacement = table.sclone( currentPlace ),
        limits = nil,
    }
    
    if info.lockedToParentArea then
        self._activeDrag.limits = self:_PrepareLimits( info, currentPlace )
    end

    common.SetCursor( info.cursor )
    info.wtReacting:DNDConfirmPickAttempt()
end

--------------------------------------------------------------------------------
--- Проверяет, является ли объект виджетом. Поддерживаются обычные Widget и TWidget.
--- @param widget userdata|table Виджет
--- @return boolean
--------------------------------------------------------------------------------
function DnDManager:_IsWidget( widget )
    if widget == nil then
        return false
    end

    if common.IsWidget( widget ) then
        return true
    end
    
    if type( widget ) ~= "table" or type( rawget( _G, "IsTWidget" ) ) ~= "function" then
        return false
    end

    local meta = getmetatable( widget )
    if not meta then
        return false
    end
    
    local _id = rawget( meta, "id" )
    local _widget = rawget( meta, "widget" )
    
    -- проверка на реальность виджета
    if _id and _widget and common.IsWidget( _widget ) then
        return GetTWidgetById( _id ) == widget
    end

    return false
end

--------------------------------------------------------------------------------
--- Валидация виджета
--- @param widget userdata|table Виджет
--- @param argName string Имя аргумента для сообщения об ошибке.
--------------------------------------------------------------------------------
function DnDManager:_ValidateWidget( widget, argName )
    assert( self:_IsWidget( widget ), "FATAL: Widget expected for %s, got %s", argName, apitype( widget ) )
end

--------------------------------------------------------------------------------
--- Проверяет, подходит ли флаг клавиш из события под требуемый модификатор KBF_*.
--- @param requiredKbFlag number|false|nil Требуемый флаг.
--- @param eventKbFlags number|nil Флаги из события.
--- @return boolean
--------------------------------------------------------------------------------
function DnDManager:_CheckKbFlag( requiredKbFlag, eventKbFlags )
    -- nil/false = без ограничений
    if requiredKbFlag == nil or requiredKbFlag == false then
        return true
    end

    eventKbFlags = eventKbFlags or KBF_NONE

    -- Требуется, чтобы модификаторы были не зажаты
    if requiredKbFlag == KBF_NONE then
        return eventKbFlags == KBF_NONE
    end

    -- Требуется конкретный модификатор Shift/Ctrl/Alt
    return bit.band( eventKbFlags, requiredKbFlag ) ~= 0
end

--------------------------------------------------------------------------------
--- @param params table Параметры события EVENT_DND_DROP_ATTEMPT.
--------------------------------------------------------------------------------
function DnDManager:OnDropAttempt( params )
    if not self:IsDragActive() then
        return
    end

    local state = self._activeDrag

    if params and params.srcId and params.srcId ~= state.info.dndId then
        return
    end

    self:_StopDragging( true )
end

--------------------------------------------------------------------------------
function DnDManager:OnDragCancelled()
    self:_StopDragging( false )
end

--------------------------------------------------------------------------------
--- @param success boolean Успешно ли завершено перетаскивание.
--------------------------------------------------------------------------------
function DnDManager:_StopDragging( success )
    if not self:IsDragActive() then
        self._activeDrag = nil
        return
    end

    local state = self._activeDrag

    if success then
        state.info.wtReacting:DNDConfirmDropAttempt()
        local finalPlacement = state.info.wtMovable:GetPlacementPlain()
        
        if state.info.isResize and state.info.resizeCallback then
            local cb = state.info.resizeCallback
            
            if type( cb ) == "table" and type( cb[1] ) == "table" and type( cb[2] ) == "function" then
                cb[2]( cb[1], finalPlacement )
            elseif type( cb ) == "function" then
                cb( finalPlacement )
            end
            
            finalPlacement = state.info.wtMovable:GetPlacementPlain()
        end

        if state.info.saveToConfig then
            self:_SaveConfig( state.info.configName, finalPlacement )
        end
    else
        state.info.wtMovable:SetPlacementPlain( state.startPlacement )
    end

    self._activeDrag = nil
    common.SetCursor( "default" )
end

--------------------------------------------------------------------------------
--- Возвращает виртуальный размер родителя виджета.
--- @param wtWidget userdata|table Виджет.
--- @return table ParentSize
--- @return table|nil ParentRect
--------------------------------------------------------------------------------
function DnDManager:_GetParentRealSize( wtWidget )
    local screen = self._screenParams

    local parent = wtWidget:GetParent()

    local ParentSize = {}
    local ParentRect

    if parent then
        ParentRect = parent:GetRealRect()

        ParentSize.sizeX =
            ( ParentRect.x2 - ParentRect.x1 )
            * screen.fullVirtualSizeX
            / screen.realSizeX

        ParentSize.sizeY =
            ( ParentRect.y2 - ParentRect.y1 )
            * screen.fullVirtualSizeY
            / screen.realSizeY
    else
        ParentRect = {
            x1 = 0,
            y1 = 0,
            x2 = screen.realSizeX,
            y2 = screen.realSizeY,
        }

        ParentSize.sizeX = screen.fullVirtualSizeX
        ParentSize.sizeY = screen.fullVirtualSizeY
    end

    return ParentSize, ParentRect
end

--------------------------------------------------------------------------------
--- Расчёт границ родителя ( limitMin, limitMax ) с учётом alignX / alignY
--- @param info table Информация о зарегистрированном виджете.
--- @param place table|nil WidgetPlacement. Если nil, берётся текущий placement виджета.
--- @return table limits { min = limitMin, max = limitMax }
--------------------------------------------------------------------------------
function DnDManager:_PrepareLimits( info, place )
    place = place or info.wtMovable:GetPlacementPlain()

    local screen = self._screenParams
    local ParentSize = self:_GetParentRealSize( info.wtMovable )

    local sizeX = place.sizeX or 0
    local sizeY = place.sizeY or 0

    local limitMin = {}
    local limitMax = {}
    
    -- X
    if place.alignX == WIDGET_ALIGN_LOW then
        limitMin.posX = 0
        limitMax.posX = ParentSize.sizeX - sizeX

    elseif place.alignX == WIDGET_ALIGN_HIGH then
        limitMin.highPosX = 0
        limitMax.highPosX = ParentSize.sizeX - sizeX

    elseif place.alignX == WIDGET_ALIGN_CENTER then
        limitMin.posX = sizeX / 2 - ParentSize.sizeX / 2
        limitMax.posX = ParentSize.sizeX / 2 - sizeX / 2

    elseif place.alignX == WIDGET_ALIGN_BOTH then
        limitMin.posX = 0
        limitMin.highPosX = 0

    elseif place.alignX == WIDGET_ALIGN_LOW_ABS then
        limitMin.posX = 0

        limitMax.posX =
            ( ParentSize.sizeX - sizeX )
            * screen.realSizeX
            / screen.fullVirtualSizeX
    end
    
    -- Y
    if place.alignY == WIDGET_ALIGN_LOW then
        limitMin.posY = 0
        limitMax.posY = ParentSize.sizeY - sizeY

    elseif place.alignY == WIDGET_ALIGN_HIGH then
        limitMin.highPosY = 0
        limitMax.highPosY = ParentSize.sizeY - sizeY

    elseif place.alignY == WIDGET_ALIGN_CENTER then
        limitMin.posY = sizeY / 2 - ParentSize.sizeY / 2
        limitMax.posY = ParentSize.sizeY / 2 - sizeY / 2

    elseif place.alignY == WIDGET_ALIGN_BOTH then
        limitMin.posY = 0
        limitMin.highPosY = 0

    elseif place.alignY == WIDGET_ALIGN_LOW_ABS then
        limitMin.posY = 0

        limitMax.posY =
            ( ParentSize.sizeY - sizeY )
            * screen.realSizeY
            / screen.fullVirtualSizeY
    end

    return {
        min = limitMin,
        max = limitMax,
    }
end

--------------------------------------------------------------------------------
--- Нормализация placement в пределах рассчитанных лимитов.
--- @param Place table WidgetPlacement.
--- @param limitMin table Минимальные лимиты.
--- @param limitMax table Максимальные лимиты.
--- @return table Place
--------------------------------------------------------------------------------
function DnDManager:_NormalizePlacement( Place, limitMin, limitMax )
    for k, v in pairs( Place ) do
        local targetVal = v
        local maxVal = limitMax[k]
        local minVal = limitMin[k]
        
        if maxVal and v > maxVal then
            targetVal = maxVal
        end
        
        if minVal and targetVal < minVal then
            targetVal = minVal
        end
        
        if targetVal ~= v then
            local oppKey = self._opposite[k]
            if oppKey and Place[oppKey] then
                Place[oppKey] = Place[oppKey] + v - targetVal
            end
            Place[k] = targetVal
        end
    end

    return Place
end

--------------------------------------------------------------------------------
--- Документация: EVENT_DND_DRAG_TO может прийти после окончания drag&drop.
--- @param params table
--------------------------------------------------------------------------------
function DnDManager:OnDragTo( params )
    if not self:IsDragActive() then
        return
    end

    local state = self._activeDrag

    if params.srcId ~= state.info.dndId then
        return
    end
    
    local dx = params.posX - state.startMousePos.x
    local dy = params.posY - state.startMousePos.y
    
    if state.info.isResize then
        self:_ProcessResize( state, dx, dy )
    else
        self:_ProcessDrag( state, dx, dy )
    end
    
    common.SetCursor( state.info.cursor )
end

--------------------------------------------------------------------------------
--- Обработка перемещения виджета.
--- @param state table Состояние активного перетаскивания.
--- @param dx number Смещение курсора по оси X.
--- @param dy number Смещение курсора по оси Y.
--------------------------------------------------------------------------------
function DnDManager:_ProcessDrag( state, dx, dy )
    local place = state.info.wtMovable:GetPlacementPlain()
    
    if place.alignX ~= WIDGET_ALIGN_LOW_ABS then
        dx = dx * self._screenParams.fullVirtualSizeX / self._screenParams.realSizeX
    end

    if place.alignY ~= WIDGET_ALIGN_LOW_ABS then
        dy = dy * self._screenParams.fullVirtualSizeY / self._screenParams.realSizeY
    end
    
    place.posX = math.floor( state.startPlacement.posX + dx )
    place.posY = math.floor( state.startPlacement.posY + dy )
    place.highPosX = math.floor( state.startPlacement.highPosX - dx )
    place.highPosY = math.floor( state.startPlacement.highPosY - dy )
    
    if state.info.lockedToParentArea and state.limits then
        place = self:_NormalizePlacement( place, state.limits.min, state.limits.max )
    end
    
    state.info.wtMovable:SetPlacementPlain( place )
end

--------------------------------------------------------------------------------
--- Обработка растягивания виджета.
--- @param state table Состояние активного перетаскивания.
--- @param dx number Смещение курсора по X.
--- @param dy number Смещение курсора по Y.
--------------------------------------------------------------------------------
function DnDManager:_ProcessResize( state, dx, dy )
    local info = state.info
    local plc = table.sclone( state.startPlacement )
    local handlePlc = info.wtReacting:GetPlacementPlain()

    local scaleX = ( plc.alignX ~= WIDGET_ALIGN_LOW_ABS ) and ( self._screenParams.fullVirtualSizeX / self._screenParams.realSizeX ) or 1
    local scaleY = ( plc.alignY ~= WIDGET_ALIGN_LOW_ABS ) and ( self._screenParams.fullVirtualSizeY / self._screenParams.realSizeY ) or 1

    local parentSize = state.info.lockedToParentArea and self:_GetParentRealSize( info.wtMovable ) or nil

    local axes = {
        { key = 'X', delta = dx * scaleX, resize = info.resizeX, limits = info.limitsX, pSize = parentSize and parentSize.sizeX },
        { key = 'Y', delta = dy * scaleY, resize = info.resizeY, limits = info.limitsY, pSize = parentSize and parentSize.sizeY }
    }
    
    for _, axis in ipairs( axes ) do
        if axis.resize then
            self:_ProcessResizeAxis( plc, handlePlc, axis.key, axis.delta, axis.limits, axis.pSize )
        end
    end

    info.wtMovable:SetPlacementPlain( plc )
end

--------------------------------------------------------------------------------
--- Метод обработки растягивания для одной оси.
--- @param plc table Текущий WidgetPlacementLua виджета.
--- @param handlePlc table WidgetPlacementLua виджета-ручки.
--- @param K string Буква оси ('X' или 'Y').
--- @param delta number Смещение курсора по оси с учётом масштаба.
--- @param limits table Допустимые размеры.
--- @param parentSize number|nil Размер родителя (для lockedToParentArea).
--------------------------------------------------------------------------------
function DnDManager:_ProcessResizeAxis( plc, handlePlc, K, delta, limits, parentSize )
    local sizeK = "size" .. K
    local posK = "pos" .. K
    local highPosK = "highPos" .. K
    local alignK = "align" .. K

    local handleAlign = handlePlc[ alignK ]
    local parentAlign = plc[ alignK ]

    local sizeDelta = 0
    if handleAlign == WIDGET_ALIGN_HIGH then
        sizeDelta = delta
    elseif handleAlign == WIDGET_ALIGN_LOW then
        sizeDelta = -delta
    end
    local oldSize = plc[ sizeK ] or 0
    local newSize = oldSize + sizeDelta
    
    local minSize = limits.min or 0
    local maxSize = limits.max or math.huge
    
    if newSize < minSize then
        newSize = minSize
    elseif newSize > maxSize then
        newSize = maxSize
    end

    local actualDelta = newSize - oldSize
    plc[ sizeK ] = newSize

    -- корректировка позиции относительно parent выравнивания
    if parentAlign == WIDGET_ALIGN_CENTER then
        if handleAlign == WIDGET_ALIGN_LOW then
            plc[ posK ] = ( plc[ posK ] or 0 ) - actualDelta / 2
        elseif handleAlign == WIDGET_ALIGN_HIGH then
            plc[ posK ] = ( plc[ posK ] or 0 ) + actualDelta / 2
        end
    else
        if handleAlign == WIDGET_ALIGN_LOW then
            plc[ posK ] = ( plc[ posK ] or 0 ) - actualDelta
        elseif handleAlign == WIDGET_ALIGN_HIGH then
            plc[ highPosK ] = ( plc[ highPosK ] or 0 ) - actualDelta
        end
    end

    -- ограничение границами родителя (lockedToParentArea)
    if parentSize then
        local left, right
        
        if parentAlign == WIDGET_ALIGN_LOW or parentAlign == WIDGET_ALIGN_LOW_ABS then
            left = plc[ posK ] or 0
            right = left + newSize
        elseif parentAlign == WIDGET_ALIGN_HIGH then
            right = parentSize - ( plc[ highPosK ] or 0 )
            left = right - newSize
        elseif parentAlign == WIDGET_ALIGN_CENTER then
            local center = parentSize / 2 + ( plc[ posK ] or 0 )
            left = center - newSize / 2
            right = center + newSize / 2
        end

        local clamped = false
        
        if handleAlign == WIDGET_ALIGN_LOW then
            if left < 0 then
                local diff = -left
                left = 0
                right = right - diff
                newSize = newSize - diff
                clamped = true
            end
        elseif handleAlign == WIDGET_ALIGN_HIGH then
            if right > parentSize then
                local diff = right - parentSize
                right = parentSize
                left = left - diff
                newSize = newSize - diff
                clamped = true
            end
        end

        -- если после ограничения границами родителя размер упал ниже минимального
        if newSize < minSize then
            local diff = minSize - newSize
            if handleAlign == WIDGET_ALIGN_LOW then
                right = right + diff
            else
                left = left - diff
            end
            newSize = minSize
            clamped = true
        end

        -- обратное преобразование абсолютных координат в pos / highPos
        if clamped then
            plc[ sizeK ] = newSize
            if parentAlign == WIDGET_ALIGN_LOW or parentAlign == WIDGET_ALIGN_LOW_ABS then
                plc[ posK ] = left
            elseif parentAlign == WIDGET_ALIGN_HIGH then
                plc[ highPosK ] = parentSize - right
            elseif parentAlign == WIDGET_ALIGN_CENTER then
                plc[ posK ] = ( left + right ) / 2 - parentSize / 2
            end
        end
    end
end

--------------------------------------------------------------------------------
function DnDManager:OnPosConverterChanged()
    if self:IsDragActive() then
        local currentDNDState = self._activeDrag.info.wtReacting:DNDGetState()
        if currentDNDState ~= DND_STATE_NOT_REGISTERED then
            self._activeDrag.info.wtReacting:DNDCancelDrag()
        end
    end
    
    self:_StopDragging( false )
    
    self._screenParams = common.GetPosConverterParams()
    
    for _, info in pairs( self._widgets ) do
        if info.lockedToParentArea then
            local place = info.wtMovable:GetPlacementPlain()
            local limits = self:_PrepareLimits( info, place )
            place = self:_NormalizePlacement( place, limits.min, limits.max )
            info.wtMovable:SetPlacementPlain( place )
        end
    end
end

--------------------------------------------------------------------------------
--- Сохранение WidgetPlacementLua в конфиг.
--- @param name string Имя ключа.
--- @param plc table WidgetPlacementLua.
--------------------------------------------------------------------------------
function DnDManager:_SaveConfig( name, plc )
	if not name then return end
    
    local config = self._options.configProvider.get() or {}
	config[ name ] = plc
    config.DnD_CONFIG_VERSION = self.__CONFIG_VERSION
    self._options.configProvider.set( config )
end

--------------------------------------------------------------------------------
--- Загрузка WidgetPlacementLua из конфига.
--- @param info table Информация о зарегистрированном виджете.
--------------------------------------------------------------------------------
function DnDManager:_LoadConfig( info )
	local config = self._options.configProvider.get() or {}
    
    if self.__CONFIG_VERSION ~= config.DnD_CONFIG_VERSION then
        return
    end
    
    config = config[ info.configName ]

    if not config or type( config ) ~= "table" then
        return
    end
    
    local plc = info.wtMovable:GetPlacementPlain()
    
    for k, v in pairs( config ) do
        plc[k] = v
    end
    
    if info.lockedToParentArea then
        local limits = self:_PrepareLimits( info, plc )
        plc = self:_NormalizePlacement( plc, limits.min, limits.max )
    end

    info.wtMovable:SetPlacementPlain( plc )
end

--------------------------------------------------------------------------------
--- Генерация уникального пути виджета для имени конфига
--- @param wtWidget userdata|table Виджет
--------------------------------------------------------------------------------
function DnDManager:_GetWidgetTreePath( wtWidget )
    local components = {}
    while wtWidget do
        table.insert( components, 1, wtWidget:GetName() )
        wtWidget = wtWidget:GetParent()
    end
    
    return table.concat( components, '.' )
end