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
-- Интерфейс
--------------------------------------------------------------------------------
local gui = GUI()
gui:Init(
    common.GetAddonMainForm( "AlchemyV2" ),
    mainForm.wtPanel,
    mainForm.wtPanel.wtTextContainer
)

viewService:Init( common.GetLocalization(), gui )
dndManager:Register( mainForm.wtPanel, { saveToConfig = CONFIG.DND.SAVE } )

--------------------------------------------------------------------------------
-- Логика в событиях
--------------------------------------------------------------------------------
local events = EventHandlers()
events:Init {
    view = viewService,
    search = searchService,
    recipe = recipeService,
}