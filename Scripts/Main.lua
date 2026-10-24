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

mainForm.wtPanel.wtDragBottomLeft:Rotate( 4.7124 )
mainForm.wtPanel.wtDragTopRight:Rotate( 1.5708 )
mainForm.wtPanel.wtDragTopLeft:Rotate( 3.1416 )
dndManager:Register( mainForm.wtPanel, { saveToConfig = CONFIG.DND.SAVE },
{
    {
        wtHandle = mainForm.wtPanel.wtDragTopLeft,
        allowX = true,
        allowY = true,
        limitsX = { min = ( CONFIG.GUI.CONTAINER_SIZE_X + CONFIG.GUI.PADDING * 2 ), max = 1000 },
        limitsY = nil,
        callback = { gui, gui.UpdateSizePanel }
    },
    {
        wtHandle = mainForm.wtPanel.wtDragTopCenter,
        allowX = true,
        allowY = true,
        limitsX = { min = ( CONFIG.GUI.CONTAINER_SIZE_X + CONFIG.GUI.PADDING * 2 ), max = 1000 },
        limitsY = nil,
        callback = { gui, gui.UpdateSizePanel }
    },
    {
        wtHandle = mainForm.wtPanel.wtDragTopRight,
        allowX = true,
        allowY = true,
        limitsX = { min = ( CONFIG.GUI.CONTAINER_SIZE_X + CONFIG.GUI.PADDING * 2 ), max = 1000 },
        limitsY = nil,
        callback = { gui, gui.UpdateSizePanel }
    },
    {
        wtHandle = mainForm.wtPanel.wtDragCenterLeft,
        allowX = true,
        allowY = true,
        limitsX = { min = ( CONFIG.GUI.CONTAINER_SIZE_X + CONFIG.GUI.PADDING * 2 ), max = 1000 },
        limitsY = nil,
        callback = { gui, gui.UpdateSizePanel }
    },
    {
        wtHandle = mainForm.wtPanel.wtDragCenterRight,
        allowX = true,
        allowY = true,
        limitsX = { min = ( CONFIG.GUI.CONTAINER_SIZE_X + CONFIG.GUI.PADDING * 2 ), max = 1000 },
        limitsY = nil,
        callback = { gui, gui.UpdateSizePanel }
    },
    {
        wtHandle = mainForm.wtPanel.wtDragBottomLeft,
        allowX = true,
        allowY = true,
        limitsX = { min = ( CONFIG.GUI.CONTAINER_SIZE_X + CONFIG.GUI.PADDING * 2 ), max = 1000 },
        limitsY = nil,
        callback = { gui, gui.UpdateSizePanel }
    },
    {
        wtHandle = mainForm.wtPanel.wtDragBottomCenter,
        allowX = true,
        allowY = true,
        limitsX = { min = ( CONFIG.GUI.CONTAINER_SIZE_X + CONFIG.GUI.PADDING * 2 ), max = 1000 },
        limitsY = nil,
        callback = { gui, gui.UpdateSizePanel }
    },
    {
        wtHandle = mainForm.wtPanel.wtDragBottomRight,
        allowX = true,
        allowY = true,
        limitsX = { min = ( CONFIG.GUI.CONTAINER_SIZE_X + CONFIG.GUI.PADDING * 2 ), max = 1000 },
        limitsY = nil,
        callback = { gui, gui.UpdateSizePanel }
    },
} )

--------------------------------------------------------------------------------
-- Логика в событиях
--------------------------------------------------------------------------------
local events = EventHandlers()
events:Init {
    view = viewService,
    search = searchService,
    recipe = recipeService,
}