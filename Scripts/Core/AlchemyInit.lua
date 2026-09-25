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
-- Cостояние
--------------------------------------------------------------------------------
-- State кэши рецептов и т.д.
local state = AlchemyState { messageType = CONFIG.MESSAGE_GREETINGS }

-- Локализация (rus, eng)
state.localization = common.GetLocalization()

--------------------------------------------------------------------------------
-- Сервисы
--------------------------------------------------------------------------------
local debugService = DebugService()
debugService:Init { GENERAL = CONFIG.DEBUG, REACTION = CONFIG.DEBUG_REACTION }

local recipeService = AlchemyRecipeService()
recipeService:Init( state )

local dndManager = DnDManager()
dndManager:Init { defaultCursor = CONFIG.DND.CURSOR }

--------------------------------------------------------------------------------
-- По алхимке поиск рецептов
--------------------------------------------------------------------------------
-- Маппер сдвигов.
-- Строит карту: "если сдвинуть барабан на N, то выпадет компонент X"
local drumShiftMapper = DrumShiftMapper()
drumShiftMapper:Init( state )

-- Перебирает все возможные комбинации сдвигов барабанов
local searchAlgorithm = BacktrackingSearchAlgorithm()
searchAlgorithm:Init( RecipeEvaluator() )

-- Сервис глубокого поиска
local searchService = AlchemySearchService()
searchService:Init( state, recipeService, drumShiftMapper, searchAlgorithm )

--------------------------------------------------------------------------------
-- Виджеты
--------------------------------------------------------------------------------
local wtPanel = _G.mainForm:GetChildChecked( "Panel" )
local wtOuText = wtPanel:GetChildChecked( "ouText" )

-- Всё что изменяется кастомно внутри окна AlchemyV2
local widgetAlchemyV2 = WidgetAlchemyV2()
widgetAlchemyV2:Init( common.GetAddonMainForm( "AlchemyV2" ) )

--------------------------------------------------------------------------------
-- Всё что связано с текстом (почти)
--------------------------------------------------------------------------------
local widgetTextContainer = WidgetTextContainer { _wtTextContainer = wtOuText }
widgetTextContainer:Init()

local viewService = AlchemyViewService()
viewService:Init {
    alchemy = widgetAlchemyV2,
    textContainer = widgetTextContainer,
    state = state,
}

--------------------------------------------------------------------------------
-- Логика в событиях связано с алхимкой
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

-- Обработчик событий (EVENT_AVATAR_*)
local avatarEvents = AlchemyAvatarEvents { _wtMovable = wtPanel }
avatarEvents:Init( context )

--------------------------------------------------------------------------------
-- Регистрация событий
--------------------------------------------------------------------------------
local events = {
    -- Алхимия
    { -- Окно алхимки открывается. Инициализируется HELLO сообщение и кэш рецептов.
        function() alchemyEvents:OnStarted() end,
        "EVENT_ALCHEMY_STARTED"
    },
    { -- Окно алхимки закрывается / вышли из варки в меню.
        function( params ) alchemyEvents:OnCanceled( params ) end,
        "EVENT_ALCHEMY_CANCELED"
    },
    { -- При каждом изменении слота для компонентов уведомляет, что в такой-то слот был вставлен/вынут компонент.
        function( params ) alchemyEvents:OnItemPlaced( params ) end,
        "EVENT_ALCHEMY_ITEM_PLACED"
    },
    { -- Уведомляет о начале варки зелья. Хоть и название события говорит о другом...
        function() alchemyEvents:OnReactionFinished() end,
        "EVENT_ALCHEMY_REACTION_FINISHED"
    },
    { -- Уведомляет об необходимости обновить список рецептов.
        function() alchemyEvents:OnRecipesChanged() end,
        "EVENT_ALCHEMY_RECIPES_CHANGED"
    },
    
    -- Аватар
    { -- Инициализация логики. Когда игрок уже в игре, только тогда необходимо применинить следующую логику.
        function() avatarEvents:OnAvatarCreated() end,
        "EVENT_AVATAR_CREATED"
    },
    { -- Всё что попало в сумку игрока от крафта алхимки.
        function( params ) avatarEvents:OnItemTaken( params ) end,
        "EVENT_AVATAR_ITEM_TAKEN"
    },
    
    -- Позицирование
    { -- Обновляет размеры Panel при изменении масштаба/размера окна игры.
        function()
            local exactHeight = widgetTextContainer:GetExactTextHeight()
            widgetTextContainer:UpdateSizePanel( exactHeight )
        end,
        "EVENT_POS_CONVERTER_CHANGED"
    },
}

advEvent.RegisterEventHandlers( false, events )

--------------------------------------------------------------------------------

if avatar.IsExist() then
    avatarEvents:OnAvatarCreated()
end
