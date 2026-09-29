--------------------------------------------------------------------------------
-- Core/AlchemyInit.lua
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Cостояние
--------------------------------------------------------------------------------
-- Начальное сообщение.
AlchemyState.messageType = CONFIG.MESSAGE_GREETINGS
-- Локализация (rus, eng)
AlchemyState.localization = common.GetLocalization()

--------------------------------------------------------------------------------
-- Сервисы
--------------------------------------------------------------------------------
DebugService.Init { General = CONFIG.DEBUG, Reaction = CONFIG.DEBUG_REACTION }

local recipeService = AlchemyRecipeService()

local dndManager = DnDManager()
dndManager:Init { defaultCursor = CONFIG.DND.CURSOR }

--------------------------------------------------------------------------------
-- По алхимке поиск рецептов
--------------------------------------------------------------------------------
-- Перебирает все возможные комбинации сдвигов барабанов
local searchAlgorithm = BacktrackingSearchAlgorithm()
searchAlgorithm:Init( RecipeEvaluator() )

-- Сервис глубокого поиска
local searchService = AlchemySearchService()
searchService:Init( recipeService, DrumShiftMapper(), searchAlgorithm )

--------------------------------------------------------------------------------
-- Виджеты
--------------------------------------------------------------------------------
local wtPanel = _G.mainForm:GetChildChecked( "Panel" )
local wtouText = wtPanel:GetChildChecked( "ouText" )

-- Всё что изменяется кастомно внутри окна AlchemyV2
local widgetAlchemyV2 = WidgetAlchemyV2()
widgetAlchemyV2:Init( common.GetAddonMainForm( "AlchemyV2" ) )

--------------------------------------------------------------------------------
-- Всё что связано с текстом (почти)
--------------------------------------------------------------------------------
local widgetTextContainer = WidgetTextContainer { _wtTextContainer = wtouText }
widgetTextContainer:Init()

local viewService = AlchemyViewService()
viewService:Init {
    alchemy = widgetAlchemyV2,
    textContainer = widgetTextContainer,
}

--------------------------------------------------------------------------------
-- Логика в событиях связаная с алхимкой
--------------------------------------------------------------------------------
local context = {
    dnd = dndManager,
    view = viewService,
    search = searchService,
    recipe = recipeService,
    alchemy = widgetAlchemyV2,
}

-- Обработчик событий (EVENT_ALCHEMY_*)
local alchemyEvents = AlchemyEvents()
alchemyEvents:Init( context )

-- Обработчик событий (EVENT_AVATAR_*)
local avatarEvents = AvatarEvents { _wtMovable = wtPanel }
avatarEvents:Init( context )
