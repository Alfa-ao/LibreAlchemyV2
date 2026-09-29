Class( "WidgetCoreExtends" )

-- GetChildByPath( "MainFrame.Alchemy.Game.View.Rolls" )
function WidgetCoreExtends:GetChildByPath( path )
    ---BEGIN_DEBUG---
    assert( type( path ) == "string" and path ~= "", "widgetcore::GetChildByPath Error: path must be a non-empty string" )
    ---END_DEBUG---
    
    local currentWidget = self
    
    for part in string.gmatch( path, "[^%.]+" ) do
        currentWidget = currentWidget:GetChildChecked( part )
    end

    return currentWidget
end

RegisterWidgetcoreExternalLib( WidgetCoreExtends )