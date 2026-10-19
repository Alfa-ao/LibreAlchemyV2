--------------------------------------------------------------------------------
-- Сервисы / Библиотеки
--------------------------------------------------------------------------------
DebugService.Init { General = CONFIG.DEBUG, Reaction = CONFIG.DEBUG_REACTION }

local viewService = ViewService() -- Управление виджетом подсказки
local recipeService = RecipeService() -- подсчёт возможных рецептов
local searchService = SearchService() -- поиск и сопоставление карты
searchService:Init( recipeService )

-- Перетаскивание виджета
local dndManager = DnDManager()
dndManager:Init { defaultCursor = CONFIG.DND.CURSOR }

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

textContainer:PosCenterPanel()
--dndManager:Register( mainForm.wtPanel, { saveToConfig = CONFIG.DND.SAVE } )

--------------------------------------------------------------------------------
-- Логика в событиях
--------------------------------------------------------------------------------
local events = EventHandlers()
events:Init {
    view = viewService,
    search = searchService,
    recipe = recipeService,
}