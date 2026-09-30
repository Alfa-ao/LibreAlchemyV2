--------------------------------------------------------------------------------
-- Main.lua
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Сервисы
--------------------------------------------------------------------------------
DebugService.Init { General = CONFIG.DEBUG, Reaction = CONFIG.DEBUG_REACTION }

-- Лёгкий подсчёт возможных рецептов
local recipeService = RecipeService()
-- Глубокий поиск
local searchService = SearchService()
-- Управление виджетом подсказки
local viewService = ViewService()

-- Перетаскивание виджета
local dndManager = DnDManager()
dndManager:Init { defaultCursor = CONFIG.DND.CURSOR }

--------------------------------------------------------------------------------
-- По алхимке поиск рецептов
--------------------------------------------------------------------------------
-- Перебор всех возможных комбинаций сдвигов барабанов
local searchAlgorithm = BacktrackingSearchAlgorithm()
searchAlgorithm:Init( RecipeEvaluator() )
searchService:Init( recipeService, DrumShiftMapper(), searchAlgorithm )

--------------------------------------------------------------------------------
-- Виджеты
--------------------------------------------------------------------------------
local wtPanel = _G.mainForm:GetChildChecked( "Panel" )

dndManager:Register( wtPanel, { saveToConfig = CONFIG.DND.SAVE } )

-- Всё что изменяется кастомно внутри окна AlchemyV2
local alchemyV2 = GUIAlchemyV2()
alchemyV2:Init( common.GetAddonMainForm( "AlchemyV2" ) )
alchemyV2:CustomStyle()

--------------------------------------------------------------------------------
-- Всё что связано с текстом (почти)
--------------------------------------------------------------------------------
local textContainer = GUITextContainer()
textContainer:Init( wtPanel, "TextContainer" )
viewService:Init( common.GetLocalization(), alchemyV2, textContainer )
viewService:UpdateCenterPanel()

--------------------------------------------------------------------------------
-- Логика в событиях связаная с алхимкой
--------------------------------------------------------------------------------
-- Обработчик событий (EVENT_ALCHEMY_*)
local alchemyEvents = AlchemyEvents()
alchemyEvents:Init {
    view = viewService,
    search = searchService,
    recipe = recipeService,
}

-- Обработчик событий (EVENT_AVATAR_*)
local avatarEvents = AvatarEvents()
avatarEvents:Init( viewService )
