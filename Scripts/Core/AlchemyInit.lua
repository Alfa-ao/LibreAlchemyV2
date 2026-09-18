--------------------------------------------------------------------------------
-- Core/AlchemyInit.lua
--------------------------------------------------------------------------------

-- Для логирования
function DebugService:LogGeneral( ... )
    self:Log( "GENERAL", ... )
end

function DebugService:LogReaction( ... )
    self:Log( "REACTION", ... )
end

--------------------------------------------------------------------------------
-- Cостояние.
--------------------------------------------------------------------------------
-- State кэши рецептов и т.д.
local state = AlchemyState { messageType = CONFIG.MESSAGE_GREETINGS }

--------------------------------------------------------------------------------
-- Сервисы.
--------------------------------------------------------------------------------
-- Сервис лога. Включает вывод определенных категорий, чтобы не засорять mods.txt.
local debugService = DebugService()
debugService:Init { GENERAL = CONFIG.DEBUG, REACTION = CONFIG.DEBUG_REACTION }

-- Сервис локализации (rus, eng).
local localeService = AlchemyRelatedTextService()
localeService:Init( common.GetLocalization() )

-- Сервис шаблонов. Забирает XHTML-разметку из отдельной папки template.
local templateService = AlchemyRelatedTextService()
templateService:Init( "template" )

-- Сервис для работы с рецептами. При первом открытии алхимки он запрашивает у игры все (250+) доступных рецептов, сохраняет их в кэш.
local recipeService = AlchemyRecipeService()
recipeService:Init( state )

local dndManager = DnDManager()
dndManager:Init { defaultCursor = CONFIG.DND.CURSOR }

--------------------------------------------------------------------------------
-- По алхимке поиск рецептов.
--------------------------------------------------------------------------------
-- Маппер сдвигов. Когда барабаны прокручиваются, компоненты меняются. 
-- Этот класс строит карту: "если сдвинуть барабан на N, то выпадет компонент X"ю
local drumShiftMapper = DrumShiftMapper()
drumShiftMapper:Init( state )

-- Перебирает все возможные комбинации сдвигов барабанов, чтобы понять, какие рецепты вообще можно сварить.
local searchAlgorithm = BacktrackingSearchAlgorithm()
searchAlgorithm:Init( RecipeEvaluator() )

-- Фасад поиска. Связывает маппер и алгоритм.
local searchService = AlchemySearchService()
searchService:Init( state, recipeService, drumShiftMapper, searchAlgorithm )

--------------------------------------------------------------------------------
-- Виджеты.
--------------------------------------------------------------------------------
local wtPanel = _G.mainForm:GetChildChecked( "Panel" )
local wtOuText = wtPanel:GetChildChecked( "ouText" )

-- Всё что изменяется кастомно внутри окна AlchemyV2
local widgetAlchemyV2 = WidgetAlchemyV2()
widgetAlchemyV2:Init( common.GetAddonMainForm( "AlchemyV2" ) )

--------------------------------------------------------------------------------
-- Всё что связано с текстом, почти.
--------------------------------------------------------------------------------
local widgetTextContainer = WidgetTextContainer { _wtTextContainer = wtOuText }
widgetTextContainer:Init { sizePadding = CONFIG.GUI.PADDING }

local viewService = AlchemyViewService()
viewService:Init {
    alchemy = widgetAlchemyV2,
    textContainer = widgetTextContainer,
    locale = localeService,
    template = templateService,
}

--------------------------------------------------------------------------------
-- Логика в событиях связано с алхимкой.
--------------------------------------------------------------------------------
local context = {
    dnd = dndManager,
    state = state,
    view = viewService,
    debug = debugService,
    search = searchService,
    recipe = recipeService,
    alchemy = widgetAlchemyV2,
}

-- Обработчик событий (EVENT_ALCHEMY_*)
local alchemyEvents = AlchemyEvents()
alchemyEvents:Init( context )

-- Обработчик событий (EVENT_AVATAR_*).
local avatarEvents = AlchemyAvatarEvents { _wtMovable = wtPanel }
avatarEvents:Init( context )

--------------------------------------------------------------------------------
-- Регистрация событий.
--------------------------------------------------------------------------------
local events = {
    -- Алхимия
    EVENT_ALCHEMY_STARTED = function() alchemyEvents:OnStarted() end, -- Окно алхимки открывается. Инициализируется HELLO сообщение и кэш рецептов.
    EVENT_ALCHEMY_CANCELED = function( params ) alchemyEvents:OnCanceled( params ) end, -- Окно алхимки закрывается / вышли из варки в меню.
    EVENT_ALCHEMY_ITEM_PLACED = function( params ) alchemyEvents:OnItemPlaced( params ) end, -- При каждом изменении слота для компонентов уведомляет, что в такой-то слот был вставлен/вынут компонент.
    EVENT_ALCHEMY_REACTION_FINISHED = function() alchemyEvents:OnReactionFinished() end, -- Уведомляет о начале варки зелья. Хоть и название события говорит о другом...
    EVENT_ALCHEMY_RECIPES_CHANGED = function() alchemyEvents:OnRecipesChanged() end, -- Уведомляет об необходимости обновить список рецептов.
    
    -- Аватар
    EVENT_AVATAR_CREATED = function() avatarEvents:OnAvatarCreated() end, -- Инициализация логики. Когда игрок уже в игре, ТОЛЬКО ТОГДА необходимо применинить следующую логику.
    EVENT_AVATAR_ITEM_TAKEN = function( params ) avatarEvents:OnItemTaken( params ) end, -- Всё что попало в сумку игрока от крафта алхимки.

    -- Обновляет размеры Panel при изменении масштаба/размера окна игры.
    -- Причина:
    -- 1) Закомментить этот ивент.
    -- 2) В игре - Меню -> Графика -> выставить Режим: "Оконный"
    -- 3) Изменять размер окна игры.
    -- Результат: Часть текста смещается и скрывается, а padding отступы превращаются невалидными.
    -- DnDManager не знает как работать с текстовым контейнером, если смотреть на опцию padding.
    EVENT_POS_CONVERTER_CHANGED = function()
        local exactHeight = widgetTextContainer:GetExactTextHeight()
        widgetTextContainer:UpdateSizePanel( exactHeight )
    end,
}

for eventName, handler in pairs( events ) do
    common.RegisterEventHandler( handler, eventName )
end

--------------------------------------------------------------------------------
-- Если аддон был перезагружен (reload) в момент, когда аватар уже находится в игре, событие EVENT_AVATAR_CREATED повторно не сработает.
--------------------------------------------------------------------------------
if avatar.IsExist() then
    avatarEvents:OnAvatarCreated()
end
