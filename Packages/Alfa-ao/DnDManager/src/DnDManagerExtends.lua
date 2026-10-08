Class( "DnDManagerExtends", DnDManager() )

--------------------------------------------------------------------------------
--- @param params table|nil
--------------------------------------------------------------------------------
function DnDManagerExtends:Init( params )
    error( "Overrides DnDManager:Init to provide custom logic." ) -- Переопределение метода для кастомной логики.
    
    -- Вызов родительского Init
    -- DnDManager.Init( self, params )
end