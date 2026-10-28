--------------------------------------------------------------------------------
-- Сервисы / Библиотеки
--------------------------------------------------------------------------------
DebugService:Init { General = CONFIG.DEBUG, Reaction = CONFIG.DEBUG_REACTION }

local viewService = ViewService() -- Управление виджетом подсказки
local recipeService = RecipeService() -- подсчёт возможных рецептов
local searchService = SearchService() -- поиск и сопоставление карты
searchService:Init( recipeService )

-- Перетаскивание виджета
DnDManager:Init { defaultCursor = CONFIG.DND.CURSOR }

--------------------------------------------------------------------------------
-- Интерфейс
--------------------------------------------------------------------------------
local gui = GUI()
gui:Init(
    common.GetAddonMainForm( "AlchemyV2" ),
    mainForm.wtPanel,
    mainForm.wtPanel.wtPadding.wtTextContainer
)

viewService:Init( common.GetLocalization(), gui )

DnDManager:Register( mainForm.wtPanel, { saveToConfig = CONFIG.DND.SAVE },
{
    {
        wtHandle = mainForm.wtPanel.wtDragBottomRight,
        allowX = true,
        allowY = true,
        limitsX = { max = 800 },
        callback = { gui, gui.UpdateSizePanel }
    }
} )

--------------------------------------------------------------------------------
-- Логика в событиях
--------------------------------------------------------------------------------
EventHandlers:Init {
    view = viewService,
    search = searchService,
    recipe = recipeService,
}