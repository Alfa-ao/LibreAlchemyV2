--------------------------------------------------------------------------------
-- src/DnDManager.lua
-- ООП менеджер Drag & Drop для виджетов.
-- Требует зависимость: "/Mods/SampleCommon/CoreScripts/ClassesImplementation.lua"
--------------------------------------------------------------------------------

--- @class DnDManager
--- @field _widgets table Хранилище зарегистрированных виджетов [ dndId ] = WidgetInfo
--- @field _activeDrag table|nil Текущее состояние активного перетаскивания
--- @field _eventHandlers table Ссылки на коллбэки для отписки от событий
--- @field _screenParams table Кэш параметров координат (разрешение экрана)
Class( "DnDManager", {
    __CONFIG_VERSION = "1.0.0",
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
        -- true (по умолчанию): менеджер сам зарегистрирует события.
        -- false: события регистрируются вручную через OnPickAttempt, OnDragTo и т.д.
        autoRegisterEvents = params.autoRegisterEvents ~= false,

        -- nil: использовать дефолтный конфиг.
        -- table: использовать кастомный configProvider.
        configProvider = nil,
        
        -- Курсор по умолчанию для виджетов, у которых cursor не задан явно.
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
    
    if self._options.autoRegisterEvents then
        self:_RegisterAllEvents()
    end
end



--------------------------------------------------------------------------------
--- @class DndRegisterOptions
--- @field wtReacting userdata|table|nil Виджет, на котором реагирует DnD.
--- @field saveToConfig boolean|nil Использовать конфиг для сохранения позиции.
--- @field lockedToParentArea boolean|nil Ограничивать ли перемещение областью родителя.
--- @field padding table|nil Отступы { T, R, B, L }.
--- @field kbFlag number|nil Флаг клавиш KBF_*.
--- @field cursor string|nil Курсор во время перетаскивания. См. названия курсоров "Аллоды Онлайн/data/Packs/Interface.Mini.pak/Interface/System/Cursors"

--- Регистрация виджета.
--- @param wtMovable userdata|table Перемещаемый виджет.
--- @param options DndRegisterOptions|nil Настройки регистрации.
--- @return number dndId ID зарегистрированного виджета.
--------------------------------------------------------------------------------
function DnDManager:Register( wtMovable, options )
    assert(
        self._initialized,
        "DnDManager:Register() failed: call DnDManager:Init() before registering widgets"
    )
    
    self:_ValidateWidget( wtMovable, "wtMovable" ) -- всемогучая проверочка "это виджет?"
    
    options = type( options ) == "table" and options or {}

    if options.wtReacting ~= nil then
        self:_ValidateWidget( options.wtReacting, "wtReacting" ) -- всемогучая проверочка "это виджет?"
    else
        options.wtReacting = wtMovable
    end

    local dndId = self:AllocateDnDID( options.wtReacting )
    
    -- Если виджет уже зарегистрирован, выбрасывает ошибку.
    assert( self._widgets[ dndId ] == nil, "DnDManager:Register() failed: widget is already registered, dndId = %s", dndId )
    
    local cursor = type( options.cursor ) == "string"
            and options.cursor
            or self._options.defaultCursor

    local info = {
        dndId = dndId,
        wtMovable = wtMovable,
        wtReacting = options.wtReacting,
        enabled = true,
        saveToConfig = options.saveToConfig == true,              -- По умолчанию false.
        lockedToParentArea = options.lockedToParentArea ~= false, -- По умолчанию true.
        kbFlag = type( options.kbFlag ) == "number" and options.kbFlag or false,     -- По умолчанию false. Ограничения отключены.
        cursor = cursor,                                          -- По умолчанию "default". Имена в нижнем регистре.
        padding = self:_NormalizePadding( options.padding ),      -- { T, R, B, L }
        configName = nil,
    }

    if info.saveToConfig then
        info.configName = "DnD:" .. self:_GetWidgetTreePath( wtMovable ) -- DnD:Main.Panel2
        self:_LoadConfig( info )
    end

    -- Сохраняет начальное положение после применения конфига.
    info.initialPlacement = wtMovable:GetPlacementPlain()
    
    local currentDNDState = options.wtReacting:DNDGetState()
    
    -- Вдруг виджет в момент регистрации находится в состоянии DND_STATE_DRAGGING или DND_STATE_WAIT_DROP_CONFIRMATION
    if currentDNDState == DND_STATE_DRAGGING or currentDNDState == DND_STATE_WAIT_DROP_CONFIRMATION then
        options.wtReacting:DNDCancelDrag()
    end
    
    -- Если виджет уже зарегистрирован в DND-системе, но не менеджером.
    assert( 
        options.wtReacting:DNDGetState() == DND_STATE_NOT_REGISTERED,
        "DnDManager:Register() failed: widget is already registered in DND system outside manager, dndId = %s, state = %s",
        dndId, currentDNDState
    )
    
    -- isDragOnly = true.
    options.wtReacting:DNDRegister( dndId, true )
    
    self._widgets[ dndId ] = info

    return dndId
end



--------------------------------------------------------------------------------
--- Удаление виджета из менеджера
--- @param wtWidget userdata|table Виджет.
--------------------------------------------------------------------------------
function DnDManager:Unregister( wtWidget )
    self:_ValidateWidget( wtWidget, "wtWidget" ) -- всемогучая проверочка "это виджет?"

    local dndId = self:GetWidgetID( wtWidget )

    if not dndId then
        return
    end

    local info = self._widgets[ dndId ]

    if not info then
        return
    end

    -- Если виджет прямо сейчас тащат, принудительно отменяется drag.
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
--- @param wtWidget any Сам виджет
--- @param isEnabled boolean Включение/Выключение перетаскивание
--------------------------------------------------------------------------------
function DnDManager:SetEnabled( wtWidget, isEnabled )
    self:_ValidateWidget( wtWidget, "wtWidget" ) -- всемогучая проверочка "это виджет?"

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
--- Событие: попытка начать перетаскивание.
--- @param params table Параметры события EVENT_DND_PICK_ATTEMPT.
--------------------------------------------------------------------------------
function DnDManager:OnPickAttempt( params )
    self:_HandlePickAttempt( params )
end



--------------------------------------------------------------------------------
--- Событие: перемещение курсора во время перетаскивания.
--- @param params table Параметры события EVENT_DND_DRAG_TO.
--------------------------------------------------------------------------------
function DnDManager:OnDragTo( params )
    self:_HandleDragTo( params )
end



--------------------------------------------------------------------------------
--- Событие: попытка завершить перетаскивание.
--- @param params table Параметры события EVENT_DND_DROP_ATTEMPT.
--------------------------------------------------------------------------------
function DnDManager:OnDropAttempt( params )
    self:_HandleDropAttempt( params )
end



--------------------------------------------------------------------------------
--- Событие: отмена перетаскивания.
--- EVENT_DND_DRAG_CANCELLED.
--------------------------------------------------------------------------------
function DnDManager:OnDragCancelled()
    self:_HandleDragCancelled()
end



--------------------------------------------------------------------------------
--- Событие: изменение параметров экрана / масштабирования UI.
--- EVENT_POS_CONVERTER_CHANGED.
--------------------------------------------------------------------------------
function DnDManager:OnPosConverterChanged()
    self:_HandlePosConverterChanged()
end



--------------------------------------------------------------------------------
--- Полная дерегистрация всех событий.
--------------------------------------------------------------------------------
function DnDManager:UnregisterAllEvents()
    if not self._eventHandlers then
        return
    end

    for eventName, callback in pairs( self._eventHandlers ) do
        common.UnRegisterEventHandler( callback, eventName )
    end

    self._eventHandlers = {}
end



--------------------------------------------------------------------------------
--- Регистрация всех глобальных событий.
--- Вызывается только если autoRegisterEvents == true.
--------------------------------------------------------------------------------
function DnDManager:_RegisterAllEvents()
    self._eventHandlers = {}

    self._eventHandlers[ "EVENT_DND_PICK_ATTEMPT" ] = function( params )
        self:OnPickAttempt( params )
    end

    self._eventHandlers[ "EVENT_DND_DRAG_TO" ] = function( params )
        self:OnDragTo( params )
    end

    self._eventHandlers[ "EVENT_DND_DROP_ATTEMPT" ] = function( params )
        self:OnDropAttempt( params )
    end

    self._eventHandlers[ "EVENT_DND_DRAG_CANCELLED" ] = function()
        self:OnDragCancelled()
    end

    self._eventHandlers[ "EVENT_POS_CONVERTER_CHANGED" ] = function()
        self:OnPosConverterChanged()
    end

    for eventName, callback in pairs( self._eventHandlers ) do
        common.RegisterEventHandler( callback, eventName )
    end
end



--------------------------------------------------------------------------------
--- Событие: попытка начать перетаскивание.
--- @param params table Параметры события EVENT_DND_PICK_ATTEMPT.
--------------------------------------------------------------------------------
function DnDManager:_HandlePickAttempt( params )
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

        -- Стартовая позиция мыши в момент начала перетаскивания.
        startMousePos = {
            x = params.posX,
            y = params.posY,
        },

        resetPlacement = table.sclone( currentPlace ),
        currentPlacement = table.sclone( currentPlace ),

        limits = nil,
    }

    if info.lockedToParentArea then
        self._activeDrag.limits = self:_PrepareLimits( info, currentPlace )
    end

    common.SetCursor( info.cursor )

    info.wtReacting:DNDConfirmPickAttempt()
end



--------------------------------------------------------------------------------
--- Проверяет, является ли объект виджетом.
--- Поддерживаются обычные Widget и TWidget.
--- @param widget any Проверяемый объект.
--- @return boolean
--------------------------------------------------------------------------------
function DnDManager:_IsWidget( widget )
    if widget == nil then
        return false
    end

    if common.IsWidget( widget ) then
        return true
    end

    local isTWidget = rawget( _G, "IsTWidget" )

    if type( isTWidget ) == "function" then
        return isTWidget( widget )
    end

    return false
end



--------------------------------------------------------------------------------
--- Валидирует виджет и бросает ошибку, если это не виджет.
--- @param widget any Проверяемый объект.
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

    -- Требуется, чтобы модификаторы НЕ зажаты
    if requiredKbFlag == KBF_NONE then
        return eventKbFlags == KBF_NONE
    end

    -- Требуется конкретный модификатор Shift/Ctrl/Alt
    return bit.band( eventKbFlags, requiredKbFlag ) ~= 0
end



--------------------------------------------------------------------------------
--- Проверяет и выводит padding в формате { T, R, B, L }.
--- @param padding table|nil Отступы: { T, R, B, L }.
--- @return table
--------------------------------------------------------------------------------
function DnDManager:_NormalizePadding( padding )
    if padding == nil then
        return { 0, 0, 0, 0 }
    end

    for i = 1, 4 do
        assert( type( padding[ i ] ) == "number", "DnDManager: padding[ %d ] must be a number or nil", i )
    end
    
    return padding
end



--------------------------------------------------------------------------------
--- Событие: Отпускание кнопки мыши
--- @param params table Параметры события EVENT_DND_DROP_ATTEMPT.
--------------------------------------------------------------------------------
function DnDManager:_HandleDropAttempt( params )
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
--- Событие: Отмена перетаскивания
--------------------------------------------------------------------------------
function DnDManager:_HandleDragCancelled()
    self:_StopDragging( false )
end



--------------------------------------------------------------------------------
--- Завершение процесса перетаскивания.
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

        if state.info.saveToConfig then
            local plc = state.currentPlacement
            
            self:_SaveConfig( state.info.configName, {
                posX = plc.posX,
                posY = plc.posY,
                highPosX = plc.highPosX,
                highPosY = plc.highPosY,
            } )
        end

        state.info.initialPlacement = table.sclone( state.currentPlacement )
    else
        state.info.wtMovable:SetPlacementPlain( state.resetPlacement )
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
--- Расчёт границ родителя ( limitMin, limitMax ) с учётом alignX / alignY и padding.
--- @param info table Информация о зарегистрированном виджете.
--- @param place table|nil WidgetPlacement. Если nil, берётся текущий placement виджета.
--- @return table limits { min = limitMin, max = limitMax }
--------------------------------------------------------------------------------
function DnDManager:_PrepareLimits( info, place )
    place = place or info.wtMovable:GetPlacementPlain()

    local screen = self._screenParams
    local ParentSize = self:_GetParentRealSize( info.wtMovable )

    local padding = info.padding or { 0, 0, 0, 0 }

    local sizeX = place.sizeX or 0
    local sizeY = place.sizeY or 0

    local limitMin = {}
    local limitMax = {}

    ------------------------------------------------------------------------
    -- X
    ------------------------------------------------------------------------

    if place.alignX == WIDGET_ALIGN_LOW then
        limitMin.posX = padding[4]
        limitMax.posX = ParentSize.sizeX - sizeX - padding[2]

    elseif place.alignX == WIDGET_ALIGN_HIGH then
        limitMin.highPosX = padding[2]
        limitMax.highPosX = ParentSize.sizeX - sizeX - padding[4]

    elseif place.alignX == WIDGET_ALIGN_CENTER then
        limitMin.posX = sizeX / 2 - ParentSize.sizeX / 2 + padding[4]
        limitMax.posX = ParentSize.sizeX / 2 - sizeX / 2 - padding[2]

    elseif place.alignX == WIDGET_ALIGN_BOTH then
        limitMin.posX = padding[4]
        limitMin.highPosX = padding[2]

    elseif place.alignX == WIDGET_ALIGN_LOW_ABS then
        limitMin.posX =
            padding[4]
            * screen.realSizeX
            / screen.fullVirtualSizeX

        limitMax.posX =
            ( ParentSize.sizeX - sizeX - padding[2] )
            * screen.realSizeX
            / screen.fullVirtualSizeX
    end

    ------------------------------------------------------------------------
    -- Y
    ------------------------------------------------------------------------

    if place.alignY == WIDGET_ALIGN_LOW then
        limitMin.posY = padding[1]
        limitMax.posY = ParentSize.sizeY - sizeY - padding[3]

    elseif place.alignY == WIDGET_ALIGN_HIGH then
        limitMin.highPosY = padding[3]
        limitMax.highPosY = ParentSize.sizeY - sizeY - padding[1]

    elseif place.alignY == WIDGET_ALIGN_CENTER then
        limitMin.posY = sizeY / 2 - ParentSize.sizeY / 2 + padding[1]
        limitMax.posY = ParentSize.sizeY / 2 - sizeY / 2 - padding[3]

    elseif place.alignY == WIDGET_ALIGN_BOTH then
        limitMin.posY = padding[1]
        limitMin.highPosY = padding[3]

    elseif place.alignY == WIDGET_ALIGN_LOW_ABS then
        limitMin.posY =
            padding[1]
            * screen.realSizeY
            / screen.fullVirtualSizeY

        limitMax.posY =
            ( ParentSize.sizeY - sizeY - padding[3] )
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
--- Событие: Перемещение курсора во время перетаскивания
--- Документация: EVENT_DND_DRAG_TO может прийти после окончания drag&drop.
--- @param params table
--------------------------------------------------------------------------------
function DnDManager:_HandleDragTo( params )
    if not self:IsDragActive() then
        return
    end

    local state = self._activeDrag

    if params.srcId ~= state.info.dndId then
        return
    end
    
    local dx = params.posX - state.startMousePos.x
    local dy = params.posY - state.startMousePos.y

    local place = state.currentPlacement

    if place.alignX ~= WIDGET_ALIGN_LOW_ABS then
        dx = dx * self._screenParams.fullVirtualSizeX / self._screenParams.realSizeX
    end

    if place.alignY ~= WIDGET_ALIGN_LOW_ABS then
        dy = dy * self._screenParams.fullVirtualSizeY / self._screenParams.realSizeY
    end
    
    -- Вычисляет новые координаты на основе исходных ( resetPlacement )
    place.posX = math.floor( state.resetPlacement.posX + dx )
    place.posY = math.floor( state.resetPlacement.posY + dy )
    place.highPosX = math.floor( state.resetPlacement.highPosX - dx )
    place.highPosY = math.floor( state.resetPlacement.highPosY - dy )
    
    -- Ограничение границами родителя
    if state.info.lockedToParentArea and state.limits then
        place = self:_NormalizePlacement(
            place,
            state.limits.min,
            state.limits.max
        )
    end
    
    -- Применить к виджету
    state.info.wtMovable:SetPlacementPlain( place )
    
    common.SetCursor( state.info.cursor )
end



--------------------------------------------------------------------------------
--- Событие: Изменение разрешения экрана / масштаба
--------------------------------------------------------------------------------
function DnDManager:_HandlePosConverterChanged()
    -- Если прямо сейчас что-то тащится, отменяется, иначе координаты улетят в космос
    if self:IsDragActive() then
        local currentDNDState = self._activeDrag.info.wtReacting:DNDGetState()

        if currentDNDState ~= DND_STATE_NOT_REGISTERED then
            self._activeDrag.info.wtReacting:DNDCancelDrag()
        end
    end
    
    self:_StopDragging( false )

    -- Обновить кэш экрана
    self._screenParams = common.GetPosConverterParams()

    -- Пересчитать границы и запихнуть все виджеты в новые рамки
    for _, info in pairs( self._widgets ) do
        if info.lockedToParentArea and info.initialPlacement then
            -- Актуальный placement виджета.
            local currentPlace = info.wtMovable:GetPlacementPlain()
            
            local limits = self:_PrepareLimits( info, currentPlace )
            
            -- Координаты из сохраненной позиции.
            currentPlace.posX = info.initialPlacement.posX or currentPlace.posX
            currentPlace.posY = info.initialPlacement.posY or currentPlace.posY
            currentPlace.highPosX = info.initialPlacement.highPosX or currentPlace.highPosX
            currentPlace.highPosY = info.initialPlacement.highPosY or currentPlace.highPosY
            
            local correctedPlace = self:_NormalizePlacement(
                currentPlace,
                limits.min,
                limits.max
            )
            
            info.wtMovable:SetPlacementPlain( correctedPlace )
            
            info.initialPlacement = table.sclone( currentPlace )
        end
    end
end



--------------------------------------------------------------------------------
--- Сохранение значения в конфиг.
--- @param name string Имя ключа.
--- @param value any Значение.
--------------------------------------------------------------------------------
function DnDManager:_SaveConfig( name, value )
	local config = self._options.configProvider.get() or {}
    
	config[ name ] = value
    config.DnD_CONFIG_VERSION = self.__CONFIG_VERSION
    
    self._options.configProvider.set( config )
end



--------------------------------------------------------------------------------
--- Загрузка позиции из конфига.
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

    plc.posX = config.posX or plc.posX
    plc.posY = config.posY or plc.posY
    plc.highPosX = config.highPosX or plc.highPosX
    plc.highPosY = config.highPosY or plc.highPosY

    if info.lockedToParentArea then
        local limits = self:_PrepareLimits( info, plc )

        if limits and limits.min and limits.max then
            plc = self:_NormalizePlacement( plc, limits.min, limits.max )
        end
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