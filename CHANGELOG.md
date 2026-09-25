# Changelog

Все перечисленные изменения в релизе.



## [v2.4.0](https://github.com/Alfa-ao/LibreAlchemyV2/releases/tag/v2.4.0)

### Added

- `Config.lua`
    - Добавлена глобальная таблица `__CONFIG_VAR_DUMP` для настройки поведения `var_dump`.
    - Добавлена опция `REQUIRED_COMPONENTS_COUNT` (по умолчанию `false`) - строгая проверка совпадения количества заполненных слотов с требуемым количеством компонентов рецепта.
    - Добавлены параметры `GUI.POS_X`, `GUI.SIZE_X`, `GUI.SIZE_Y` для централизованного управления позицией и размерами панели подсказки.
- В `AlchemyState` добавлены поля `localization` (локализация `rus`/`eng`) и `drumSize` (количество аспектов в одном барабане).

### Changed

- DnD `DnDManager`: Менеджер обновлён до версии `v1.2.0`.
- События: переход с `common.RegisterEventHandler` на `advEvent.RegisterEventHandlers`. Формат таблицы событий изменён с `{ [eventName] = handler }` на массив `{ { handler, eventName }, ... }`.
- Локализация: упразднён `AlchemyRelatedTextService`. Получение текстовых ресурсов теперь выполняется напрямую через глобальную функцию `GetAddonText( sysGroup, sysName, optional )`. Локализация сохраняется в `AlchemyState.localization` при инициализации.
- Утилиты: упразднён `MathUtils`. `MathUtils.shallowCopy` заменён на встроенный `table.sclone`. `MathUtils.safeModulo` заменён на стандартный оператор `%` с использованием `drumSize` из состояния.
- Рецепты `AlchemyRecipeService`: удалён кэш строковых имён компонентов `_componentNamesCache`, `GetComponentName`. Рецепты теперь хранят и сравнивают компоненты по `ComponentPropertyId` (userdata) напрямую, без конвертации в строку. Сохранение `drumSize` из `GetAlchemyInfo`. Метод `IsRecipeMatch` учитывает флаг `CONFIG.REQUIRED_COMPONENTS_COUNT`.
- Поиск `DrumShiftMapper`: упрощена инициализация - убрана зависимость от `AlchemyRecipeService`. Карта сдвигов строится по `ComponentPropertyId` напрямую. Используется `state.drumSize` вместо `GetTableSize`.
- Поиск `BacktrackingSearchAlgorithm`: `MathUtils.shallowCopy` заменён на `table.sclone`.
- View `AlchemyViewService`: инициализация принимает `state` вместо отдельных `locale` и `template`. Все вызовы `self._locale:Get()` / `self._template:Get()` заменены на `GetAddonText()`.
- GUI `WidgetTextContainer`: `Init()` больше не принимает параметров - отступ берётся из `CONFIG.GUI.PADDING`. `UpdateCenterPanel()` упрощён: позиция рассчитывается через `CONFIG.GUI.POS_X` и `CONFIG.GUI.SIZE_Y`.
- Debug `DebugService`: улучшена обработка `WString` при отсутствии `var_dump` - используется `userMods.FromWString`. Глобальная функция `log` использует `LogInfo` вместо `common.LogInfo`.
- `Panel.(WidgetPanel).xdb`: выравнивание изменено на `WIDGET_ALIGN_CENTER` по обеим осям, начальные размеры и позиции обнулены (управляются из Lua).
- `ouText.(WidgetTextContainer).xdb`: ширина уменьшена с `570` до `533`.
- `AddonDesc.(UIAddon).xdb`: подключены дополнительные CoreScripts (`AddonBaseUserMods`, `AddonBase`, `WidgetCoreUserMods`, `AdvancedHandlersUserMods`).
- Позицирование: изменена логика позицирования виджета подсказки. Теперь корректно отображается при масштабировании.

### Removed

- Удалён файл `Libs/Utils/MathUtils.lua`.
- Удалён файл `Scripts/Services/AlchemyRelatedTextService.lua`.
- Удалена зависимость от `/Mods/SampleCommon/SampleAddonBase.lua` `GetTableSize`.
- Удалены параметры `GUI.PANEL_HALF_WIDTH` и `GUI.PANEL_OFFSET_X` из `Config.lua`.
- Удалён кэш имён компонентов (`_componentNamesCache`, `GetComponentName`) из `AlchemyRecipeService`.



## [v2.3.0](https://github.com/Alfa-ao/LibreAlchemyV2/releases/tag/v2.3.0)

### Added

- Добавлен виджет-обертка `Scripts/GUI/WidgetTextContainer.lua`, содержащую логику работы с нативным текстовым контейнером и его родителем.

### Changed

- `AlchemyTextContainerService` упразднен, его роль выполняет `WidgetTextContainer`, работающий напрямую с нативными виджетами (`wtOuText` и его родитель).
- `AlchemyTextFormatter` упразднен, логика форматирования перенесена в `AlchemyViewService`.
- Строка `AVATAR_ITEM_TAKEN` переведена на формат `ValuedText`/XHTML с использованием тега `<alchemy>` и CSS-класса.
- Сервис отладки перенесен из `Scripts/Services/AlchemyDebugService.lua` в `Libs/DebugService.lua`.



## [v2.3.0-beta.1](https://github.com/Alfa-ao/LibreAlchemyV2/releases/tag/v2.3.0-beta.1)

> [!CAUTION]
> **Глобальный рефакторинг архитектуры**
>
> В этой версии проведён глубокий анализ и пересмотр архитектурных решений, принятых на alpha‑стадии.
>
> Основные изменения:
> - отказ от излишней абстракции (over‑engineering).
> - упрощение за счёт удаления паттернов контекста и менеджеров.
> - переход к прямому, прозрачному коду.
>
> Внутренняя версия аддона в `AddonDesc` обновлена до `2.3.0`.


### Added
- Добавлен сервис `AlchemyViewService` в `Scripts/Services/AlchemyViewService.lua` для централизованного управления отображением GUI и форматированием сообщений.
- Добавлен файл стилей `Widgets/Styles.(WidgetCss).xdb` с именем `alchemy-yellow-text` и настройками тега `<alchemy>`.
- Добавлен метод `AlchemyState:InvalidateReaction()` для корректного сброса флага успешной реакции и результатов поиска.
- В глобальную таблицу `CONFIG` добавлены секции:
  - `GUI` (параметры отступов, размеров элементов и позиционирования).
  - `DND` (параметры `SAVE` и `CURSOR`).
  - Константа `DELAY_MS_UPDATE` для отложенных вызовов.

### Changed
- Глобальный рефакторинг архитектуры: отказ от паттернов `Context`, `Manager` и `Bootstrap` в пользу прямой инициализации зависимостей в `AlchemyInit.lua`.
- `AlchemyConfig` переименован в `CONFIG` и переведен из `Class` в `Global` таблицу.
- `MathUtils` перемещен из `Scripts/Utils` в `Libs/Utils` и изменен с `Class` на `Global` таблицу.
- Структура событий упрощена: удалены `AlchemyEventManager` и `EventClassInterface`, события регистрируются напрямую через локальную таблицу хендлеров в `AlchemyInit.lua`.
- `AlchemyTextContainerService` теперь работает напрямую с нативными виджетами (`wtOuText` и его родитель), методы `UpdateSizePanel` и `GetExactTextHeight` перенесены в этот сервис.
- `AlchemyTextFormatter` и `WidgetAlchemyV2` перемещены из `Scripts/UI` в `Scripts/GUI` и упрощены: убраны зависимости от менеджеров виджетов, инициализация происходит через прямую передачу нативных виджетов и сервисов.
- Логика подсветки текущего рецепта в `AlchemyTextFormatter` переведена с шаблона `COLOR_YELLOW_TEXT` на использование CSS-виджета `alchemy-yellow-text` через параметр `class1`.
- В шаблонах `RECIPE_LINE.txt` и `ContainerFormat.txt`, а также в `COUNT_RECIPES.txt` тег `<log fontsize="15">` заменен на кастомный тег `<alchemy>`. В `RECIPE_LINE.txt` добавлена поддержка CSS-виджета через `<rs class="class1">`.
- Обработчик `EVENT_POS_CONVERTER_CHANGED` теперь явно обновляет размеры панели через `textContainerService`, что предотвращает смещение текста при изменении масштаба интерфейса игры.
- `BacktrackingSearchAlgorithm` и `DrumShiftMapper` больше не принимают `mathUtils` через конструктор, а используют глобальный `MathUtils`.
- `AlchemyRecipeService` теперь сохраняет имя рецепта как `WString` (ранее конвертировалось в строку).
- Обновлены строки локализации: добавлен префикс `LibreAlchemyV2: ` в `AVATAR_ITEM_TAKEN`.

### Removed
- Удалены файлы и классы, связанные с устаревшей архитектурой:
    - `Scripts/Facade.lua`
    - `Scripts/Core/AlchemyContext.lua`
    - `Scripts/Core/AlchemyBootstrap.lua`
    - `Scripts/Handler/AlchemyEventManager.lua`
    - `Scripts/Handler/EventClassInterface.lua`
    - `Scripts/Handler/Events/AlchemyDNDEvents.lua`
    - `Scripts/Handler/Events/AlchemyPosEvents.lua`
    - `Scripts/Handler/Events/AlchemySystemEvents.lua`
    - `Scripts/UI/AlchemyWidgetManager.lua`
    - `Scripts/UI/WidgetClassInterface.lua`
    - `Scripts/UI/Widgets/WidgetPanel.lua`
    - `Scripts/UI/Widgets/WidgetOuText.lua`
- Удален шаблон `Locales/template/COLOR_YELLOW_TEXT.txt` (функциональность заменена на CSS-Виджет).
- Удалены отладочные файлы локализации:
    - `Locales/lang/eng/DEBUG_COUNT_COMPONENTS.txt`
    - `Locales/lang/eng/DEBUG_COUNT_RECIPES.txt`
    - `Locales/lang/eng/DEBUG_INSERT_BAR.txt`
    - `Locales/lang/eng/DEBUG_ITERATION_COMPONENTS.txt`
    - `Locales/lang/eng/DEBUG_REMOVED_BAR.txt`
    - `Locales/lang/rus/DEBUG_COUNT_COMPONENTS.txt`
    - `Locales/lang/rus/DEBUG_COUNT_RECIPES.txt`
    - `Locales/lang/rus/DEBUG_INSERT_BAR.txt`
    - `Locales/lang/rus/DEBUG_ITERATION_COMPONENTS.txt`
    - `Locales/lang/rus/DEBUG_REMOVED_BAR.txt`
- Удалена зависимость от `mathUtils` в `AlchemySearchService`, `BacktrackingSearchAlgorithm` и `DrumShiftMapper`.
- Удалена константа `MESSAGE_WARNING` из конфигурации.



## [v2.2.0-alpha.4](https://github.com/Alfa-ao/LibreAlchemyV2/releases/tag/v2.2.0-alpha.4)

### Added
- Добавлена библиотека `Libs/DND/src/DnDManager.lua` - ООП-менеджер Drag & Drop.
- Добавлен класс `AlchemyContext` в `Scripts/Core/AlchemyContext.lua` - единый контекст зависимостей:
  - `AlchemyState`.
  - `AlchemyConfig`.
  - `AlchemyWidgetManager`.
  - `AlchemyTextFormatter`.
  - сервисы.
- Добавлено использование `AlchemyRelatedTextService` для работы с группой шаблонов `template` (инициализация с параметром `"template"`).
- Добавлены новые обработчики событий:
  - `AlchemyDNDEvents` в `Scripts/Handler/Events/AlchemyDNDEvents.lua` для обработки событий `EVENT_DND_*`.
  - `AlchemyPosEvents` в `Scripts/Handler/Events/AlchemyPosEvents.lua` для обработки события `EVENT_POS_CONVERTER_CHANGED`.
- Добавлена отдельная группа локализации `template`:
  - `Locales/template/Locale.(UIRelatedTexts).xdb`.
  - `Locales/template/RECIPE_LINE.txt`.
  - `Locales/template/COLOR_YELLOW_TEXT.txt`.
- Добавлен шаблон `COLOR_YELLOW_TEXT` для выделения текста жёлтым цветом через `ValuedText`.
- Добавлено логирование событий `EVENT_DND_PICK_ATTEMPT`, `EVENT_DND_DRAG_TO`, `EVENT_DND_DROP_ATTEMPT`, `EVENT_DND_DRAG_CANCELLED` и `EVENT_POS_CONVERTER_CHANGED`.
- В `AlchemyInit` добавлено создание и инициализация сервиса `DnDManager` с параметрами:
  - `autoRegisterEvents = false`.
  - `defaultCursor = "drag"`.
- `AlchemyEventManager` теперь принимает список обработчиков и `AlchemyContext`, а также самостоятельно вызывает инициализацию обработчиков через `handler:Init(context)`.

### Changed
- Drag & Drop полностью переведён с библиотеки `LibDnD.lua` на сервис `DnDManager.lua`.
- Регистрация Drag & Drop для панели подсказок перенесена из `WidgetDnD` напрямую в `AlchemyAvatarEvents:OnAvatarCreated()` через `services.dnd:Register(...)`.
- Системное имя виджета Drag & Drop изменено с `"Drag&Drop"` на `"dnd"`.
- Структура проекта изменена:
  - `Scripts/Events` переименован в `Scripts/Handler`.
  - все скрипты событий `*Events.lua` перемещены в `Scripts/Handler/Events`.
  - `AlchemyEventManager.lua` перемещён в `Scripts/Handler/AlchemyEventManager.lua`.
  - `EventClassInterface.lua` перемещён в `Scripts/Handler/EventClassInterface.lua`.
  - `WidgetClassInterface.lua` перемещён из `Scripts/UI/Widgets/WidgetClassInterface.lua` в `Scripts/UI/WidgetClassInterface.lua`.
- Локализация языков `rus` и `eng` перемещена:
  - из `Locales/rus` в `Locales/lang/rus`.
  - из `Locales/eng` в `Locales/lang/eng`.
- Шаблон `RECIPE_LINE` вынесен из языковой локализации `rus`/`eng` в отдельную группу `Locales/template`.
- Формат `COUNT_RECIPES` изменён с обычного текста и `string.format` на шаблон `ValuedText`/HTML:
  - теперь используется тег `<r name="count"/>`.
  - сообщение формируется через `common.CreateValuedText`.
- `AlchemyTextFormatter` переведён на использование `AlchemyContext`.
- `AlchemyTextFormatter` теперь использует сервис шаблонов (`services.template`) для получения:
  - `RECIPE_LINE`.
  - `COLOR_YELLOW_TEXT`.
- Логика подсветки текущего рецепта переведена на шаблон `COLOR_YELLOW_TEXT` вместо хардкода HTML-строки.
- `WidgetAlchemyV2:GetCurrentRecipeName()` теперь возвращает `WString`, а не строку.
- Сравнение имени текущего рецепта в `AlchemyTextFormatter` теперь работает с `WString`-значениями.
- `AlchemyWidgetManager` теперь принимает список виджетов и `AlchemyContext`:
  - старый вариант инициализации через варарг заменён на передачу контекста.
  - виджеты инициализируются через `widget:Init(context)`.
- Методы `Init` в виджетах `WidgetPanel`, `WidgetOuText` и `WidgetAlchemyV2` теперь принимают `context` вместо `widgetManager`.
- `EventClassInterface` изменён:
  - добавлен контракт `Init(context)`.
  - удалены поля `_state` и `_config` из базового интерфейса.
- Обработчики событий переведены на получение зависимостей через `AlchemyContext`:
  - `AlchemyEvents`.
  - `AlchemyAvatarEvents`.
  - `AlchemyDNDEvents`.
  - `AlchemyPosEvents`.
- `AlchemyAvatarEvents` больше не вызывает `services.locale:Init()` в `EVENT_AVATAR_CREATED`. Инициализация локали теперь выполняется централизованно в `AlchemyInit`.
- `AlchemyEvents` - исправлена проблема с зависшим поздравлением при изменении списка доступных зельев.
- `AlchemyTextContainerService:SetLines()` больше не автоматически преобразует `string` в `WString`:
  - использование `userMods.ToWString` для этого сценария помечено как deprecated.
- `AlchemyConfig` изменён с `Class` на `Global` (теперь это глобальная таблица конфигурации).
- `AlchemyRelatedTextService` (бывший `AlchemyLocaleService`) теперь принимает параметр `sysGroup` в `Init`, что позволило использовать его и для `locale`, и для `template`.
- Обновлены текстовые строки локализации:
  - `GREETINGS`: `LibreAlchemy` заменён на `LibreAlchemyV2`.
  - `WELCOME_BACK`: `LibreAlchemy` заменён на `LibreAlchemyV2`.
  - `CONGRATULATION`: `LibreAlchemy` заменён на `LibreAlchemyV2`.
- Обновлён `AddonDesc.(UIAddon).xdb`:
  - версия обновлена до `2.2.0`.
  - изменены пути подключения скриптов.
  - изменены пути локализации.
  - добавлена группа локализации `template`.
  - подключение Drag & Drop теперь указывает на `Libs/DND/src/DnDManager.lua`.
- Инициализация кэша имён компонентов в `AlchemyRecipeService` перенесена в метод `Init`.

### Removed
- Удалена библиотека `Libs/LibDnD.lua`.
- Удален вызов `dndWidgetWrapper:InitDragAndDrop()` и связанные с ним проверки из `AlchemyAvatarEvents`.
- Удален класс `WidgetDnD`.
- Удалён файл `Scripts/Services/AlchemyLocaleService.lua` (заменён универсальным `AlchemyRelatedTextService.lua`).
- Удалён файл `Scripts/Services/Search/SearchAlgorithmClassInterface.lua` (алгоритм поиска больше не использует этот интерфейс).
- Удалены локализационные шаблоны `INSTALL_LIB_DND`:
  - `Locales/eng/INSTALL_LIB_DND.txt`.
  - `Locales/rus/INSTALL_LIB_DND.txt`.
- Удалены записи `INSTALL_LIB_DND` из языковых файлов локализации `Locale.(UIRelatedTexts).xdb`.
- Удалён `RECIPE_LINE` из языковых групп `eng` и `rus`.
- Удалены старые пути:
  - `Scripts/Events/*`.
  - `Scripts/UI/Widgets/WidgetClassInterface.lua`.
  - `Locales/rus/*`.
  - `Locales/eng/*`.
- Удалено неиспользуемое поле `_mathUtils` из `AlchemySearchService`.
- Удалено неиспользуемое локальное объявление `local userMods = Facade.AO.userMods` из `Scripts/Facade.lua`.



## [v2.1.2-alpha.3](https://github.com/Alfa-ao/LibreAlchemyV2/releases/tag/v2.1.2-alpha.3)

### Added
- Добавлены запланированные задачи `common.DelayedCall`.
- Добавлена библиотека `EnumFactory`.
- В `AlchemyState` добавлена полная очистка запланированных вызовов.

### Changed
- Логическая ответственность `AlchemySystemEvents` перенесена и упрощена в `AlchemyEvents`.

### Removed
- Полностью удалён `AlchemySystemEvents`.

## [v2.1.2-alpha.2](https://github.com/Alfa-ao/LibreAlchemyV2/releases/tag/v2.1.2-alpha.2)

### Added
- Счётчик слотов события `EVENT_ALCHEMY_ITEM_PLACED` дополнен логированием.

### Changed
- Изменён `Debug`: глобальная функция `log` в `Facade.lua` теперь корректно работает без `/Mods/Facade`.
- Фасад-методы вынесены из класса в `AlchemyInit`.

### Fixed
- Исправлена опечатка в имени локализации `NOT_FOUND_RECIPLES` на `NOT_FOUND_RECIPES`.
- Исправлена логика счётчиков заполненных слотов в обработчике события `EVENT_ALCHEMY_ITEM_PLACED`.

## [v2.1.2-alpha](https://github.com/Alfa-ao/LibreAlchemyV2/releases/tag/v2.1.2-alpha)

> Промежуточный alpha-релиз

## [v2.1.0](https://github.com/Alfa-ao/LibreAlchemyV2/releases/tag/v2.1.0)

### Added
- Добавлены контракты:
  - `EventClassInterface.lua`
  - `SearchAlgorithmClassInterface.lua`
  - `WidgetClassInterface.lua`
- Добавлены компоненты поиска:
  - `BacktrackingSearchAlgorithm` - алгоритм перебора сдвигов каждого барабана на основе сопоставления аспектов компонента с требуемыми компонентами.
  - `DrumShiftMapper` - создаёт карту всевозможных сдвигов для каждого барабана.
  - `RecipeEvaluator` - отсекает худшие рецепты.
- Добавлен `AlchemyWidgetManager`:
  - регистрирует виджеты с элементами управления.
  - Также проверяет, что переданный объект реализует интерфейс `WidgetClassInterface` через `InstanceOf`.
- Добавлены виджетные компоненты:
  - `WidgetRollsBar`.
  - `WidgetOuText`.
  - `WidgetDnD`.

### Changed
- Изменён интерфейс и расположение кнопок.
- Для возврата стандартного расположения кнопок необходимо установить `ENABLE_CUSTOM_LAYOUT = false` в скрипте `LibreAlchemyV2\Scripts\Core\AlchemyConfig.lua` и перезагрузить игру.
- Скриптовая часть полностью переписана с нуля.
- Использовано объектно-ориентированное программирование и принципы SOLID, где это было возможно.
- `AlchemySearchService` разделён на логические составляющие с отдельными зонами ответственности.

### Fixed
- Исправлены недочёты виджетов, issue #1.

> [!WARNING]
> Известные ошибки:
> 
> При изменении масштаба интерфейса игры с минимального на стандартный после перезагрузки игры текст подсказки может исчезать.  
> Причина: координаты подсказки становятся отрицательными, и при следующем входе в игру текст прячется за экраном.  
> Временно лечится удалением `Configs\LibreAlchemyV2\user.cfg`.  
> Ответственность за это несёт библиотека `LibDnD.lua`: она должна обнулять или корректировать координаты.

## [v1.2.1](https://github.com/Alfa-ao/LibreAlchemyV2/releases/tag/v1.2.1)

### Added
- Добавлена локализация:
  - `ENG`
  - `RUS`

### Changed
- Все текстовые сообщения из Lua перенесены в локализацию.
- Скриптовая часть переведена в кодировку `UTF-8 no BOM`.

## [v1.2.0](https://github.com/Alfa-ao/LibreAlchemyV2/releases/tag/v1.2.0)

### Added
- Добавлена библиотека Drag&Drop `LibDnD.lua`.
- Текст с подсказкой теперь можно перемещать по всей области экрана `MainForm`.
- Добавлен `Debug` событий.
- Добавлены состояния сообщений:
  - приветствие при первом открытии окна алхимии.
  - сообщение при повторном открытии окна алхимии.
  - сообщение о возможных рецептах при полном заполнении требуемых слотов.
  - сообщение о неготовых компонентах при недостаточном заполнении слотов.
  - сообщение об отсутствии рецептов при пустых слотах.
  - поздравление при получении предмета из результата алхимических реакций.

### Changed
- Проведена чистка неиспользуемых участков кода и функций.
- `SetBackgroundColor`, `SetPriority`, частично метод `OnSize` и связанные атрибуты перенесены в ответственные виджеты.
- Переписана точка инициализации аддона.
- Переделана логика сообщений: текст теперь отрабатывает один раз вместо наложения друг на друга.
- В `MainForm` увеличен приоритет позиционирования родителя для текста подсказки на `10000`.
- В `BackBlack` используется цвет `0xe61a1a0d` вместо `SetBackgroundColor`.

### Fixed
- Исправлен `Placement` окна `MainForm` на `WIDGET_ALIGN_BOTH`.
- Исправлен `Placement` и размер `ouText`: размер теперь определяется на основании содержимого текста.
- Множество логических исправлений.

### Removed
- Удалена старая функция `Init`.

## [v1.1.4](https://github.com/Alfa-ao/LibreAlchemyV2/releases/tag/v1.1.4)

### Changed
- Опубликован бэкап старой версии.