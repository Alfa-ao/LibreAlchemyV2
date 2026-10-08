--------------------------------------------------------------------------------
-- Сервисы / Библиотеки
--------------------------------------------------------------------------------
DebugService.Init { General = CONFIG.DEBUG, Reaction = CONFIG.DEBUG_REACTION }

local recipeService = RecipeService() -- Лёгкий подсчёт возможных рецептов
local searchService = SearchService() -- Глубокий поиск
local viewService = ViewService() -- Управление виджетом подсказки

-- Перетаскивание виджета
local dndManager = DnDManager()
dndManager:Init { defaultCursor = CONFIG.DND.CURSOR }

--------------------------------------------------------------------------------
-- Search
--------------------------------------------------------------------------------
local searchAlgorithm = BacktrackingSearchAlgorithm()
searchAlgorithm:Init( RecipeEvaluator() )
searchService:Init( recipeService, DrumShiftMapper(), searchAlgorithm )

--------------------------------------------------------------------------------
-- Всё что изменяется кастомно внутри окна AlchemyV2
--------------------------------------------------------------------------------
local alchemyV2 = GUIAlchemyV2()
alchemyV2:Init( common.GetAddonMainForm( "AlchemyV2" ) )
alchemyV2:CustomStyle()

--------------------------------------------------------------------------------
-- Всё что связано с текстом (почти)
--------------------------------------------------------------------------------
local textContainer = GUITextContainer()
textContainer:Init( mainForm.wtPanel, "TextContainer" )
viewService:Init( common.GetLocalization(), alchemyV2, textContainer )

viewService:UpdateCenterPanel()
dndManager:Register( mainForm.wtPanel, { saveToConfig = CONFIG.DND.SAVE } )

--------------------------------------------------------------------------------
-- Логика в событиях
--------------------------------------------------------------------------------
-- EVENT_ALCHEMY_*
local alchemyEvents = AlchemyEvents()
alchemyEvents:Init {
    view = viewService,
    search = searchService,
    recipe = recipeService,
}

-- EVENT_AVATAR_*
local avatarEvents = AvatarEvents()
avatarEvents:Init( viewService )
