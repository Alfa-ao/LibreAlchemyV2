Global( "EnumTakeItemActionType", EnumFactory:create( {
    LOOT = "ENUM_TakeItemActionType_Loot",                          -- предмет пришёл из лута
    QUEST = "ENUM_TakeItemActionType_Quest",                        -- предмет получен/забран квестом
    QUEST_ABANDON = "ENUM_TakeItemActionType_QuestAbandon",         -- итем забрали по причине отказа от квеста
    SPELL = "ENUM_TakeItemActionType_Spell",                        -- итем появился/исчез по причине каста спела
    VENDOR = "ENUM_TakeItemActionType_Vendor",                      -- итем появился/исчез при разговоре с вендором
    CRAFT = "ENUM_TakeItemActionType_Craft",                        -- при каком-то крафтинге (итем взят из крафт бега)
    MAIL = "ENUM_TakeItemActionType_Mail",                          -- из почты
    DROP = "ENUM_TakeItemActionType_Drop",                          -- игрок выкинул итем
    SELF_ANNIHILATION = "ENUM_TakeItemActionType_SelfAnnihilation", -- итем был уничтожен по времени
    MONEY = "ENUM_TakeItemActionType_Money",                        -- простая операция с деньгами
    BOX = "ENUM_TakeItemActionType_Box",
    RUNE_COMBINE = "ENUM_TakeItemActionType_RuneCombine",
    SKILLED_ITEM_GENERATION = "ENUM_TakeItemActionType_SkilledItemGeneration",
    AUCTION_BET = "ENUM_TakeItemActionType_AuctionBet",             -- игрок делает ставку
    AUCTION_CREATE = "ENUM_TakeItemActionType_AuctionCreate",       -- игрок выставляет предмет на аукцион и с него берут залог
    AUCTION_BUYOUT = "ENUM_TakeItemActionType_AuctionBuyout",       -- игрок выкупает предмет на аукционе
    OTHER = "ENUM_TakeItemActionType_Other",
    CURRENCY_EXCHANGE = "ENUM_TakeItemActionType_CurrencyExchange",
    MENTOR = "ENUM_TakeItemActionType_Mentor",
    ITEM_MALL = "ENUM_TakeItemActionType_ItemMall",
} ) )