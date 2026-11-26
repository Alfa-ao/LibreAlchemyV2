DebugService:Init { General = CONFIG.DEBUG, Reaction = CONFIG.DEBUG_REACTION }

local alchemy = Alchemy( mainForm ):Init( common.GetAddonMainForm( CONFIG.SYSTEM_ADDON_NAME ) )

DnDManager:Init()
DnDManager:Register( mainForm.wtTextContainer, { saveToConfig = true }, {
    {
        wtHandle = mainForm.wtTextContainer.wtDragBottomRight,
        allowX = true,
        allowY = true,
        limitsX = { max = 800 },
        callback = { alchemy, alchemy.UpdateSizePanel },
    },
} )

