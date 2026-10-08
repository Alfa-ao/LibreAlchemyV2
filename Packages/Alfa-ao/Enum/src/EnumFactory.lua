--------------------------------------------------------------------------------
-- Enum/src/EnumFactory.lua
--------------------------------------------------------------------------------

--- Фабрика для создания перечислений (Enum).
--- @class EnumFactory
Global( "EnumFactory", {} )

--------------------------------------------------------------------------------
--- Создает перечисление на основе таблицы определений.
--- Формирует объекты элементов перечисления, содержащие исходное значение и ключ.
--- Добавляет метод сравнения :Equals() и метаметоды для неявного приведения к строке (__tostring), числу (__tonumber) и сравнения (__eq).
--- Обеспечивает обратный поиск по значению или первому элементу таблицы.
--- Блокирует изменение и добавление новых ключей в возвращаемую таблицу.
--- @param def table Определения (ключ -> значение или таблица значений).
--- @return table
--- @usage
--- -- Создание стандартного перечисления
--- EnumTakeItemActionType = EnumFactory:create({
---     CRAFT = "ENUM_TakeItemActionType_Craft",
---     LOOT  = "ENUM_TakeItemActionType_Loot",
--- })
---
--- -- Создание гибридного перечисления из несколько допустимых значений
--- EnumStatus = EnumFactory:create {
---     ACTIVE = { "STATUS_ACTIVE", 1 },
--- }
---
--- -- Прямой и обратный доступ к элементам
--- local craftObj = EnumTakeItemActionType.CRAFT
--- local sameObj  = EnumTakeItemActionType[ "ENUM_TakeItemActionType_Craft" ]
---
--- -- Сравнение с внешними значениями через метод :Equals()
--- if EnumTakeItemActionType.CRAFT:Equals( "ENUM_TakeItemActionType_Craft" ) then
---     -- Обработка действия
--- end
--- if EnumStatus.ACTIVE:Equals( 1 ) then
---     -- Обработка статуса
--- end
---
--- -- Неявное приведение типов при конкатенации и арифметике
--- local logMsg = "Current action: " .. EnumTakeItemActionType.CRAFT
---
--- -- Сравнение двух объектов перечисления через оператор ==
--- if EnumTakeItemActionType.CRAFT == EnumTakeItemActionType.CRAFT then
---     -- Объекты идентичны
--- end
--------------------------------------------------------------------------------
function EnumFactory:create( def )
    local enum = {}
    
    for k, v in pairs( def ) do
        local enumValue = {
            _raw = v, -- Сейв оригинала значения
            _key = k,
        }
        
        function enumValue:Equals( target )
            local raw = self._raw
            -- Таблица "гибридный enum"
            if type( raw ) == "table" then
                for _, val in ipairs( raw ) do
                    if val == target then 
                        return true 
                    end
                end
                return false
            end
            -- Примитив
            return raw == target
        end
        
        -- Чтобы объект можно было легко приводить к строке/числу
        setmetatable( enumValue, {
            __tostring = function() return tostring( enumValue._raw ) end,
            __tonumber = function() return tonumber( enumValue._raw ) end,
            -- Чтобы можно было сравнивать через ==
            __eq = function( a, b ) 
                return a._raw == (type(b) == "table" and b._raw or b) 
            end
        } )

        -- Объект по ключу
        enum[ k ] = enumValue
        
        -- Если v - таблица, юзаем первый элемент как ключ
        local lookupKey = ( type( v ) == "table" ) and v[1] or v
        enum[ lookupKey ] = enumValue
    end
    
    return setmetatable( enum, {
        __newindex = function() error( "Enum is read-only" ) end,
        __index = function( _, k ) error( "Invalid enum key: " .. tostring( k ) ) end,
    } )
end