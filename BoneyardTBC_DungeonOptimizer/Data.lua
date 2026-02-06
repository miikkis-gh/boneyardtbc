BoneyardTBC_DO = {}

BoneyardTBC_DO.FACTIONS = {
    HONOR_HOLD    = { id = 946, name = "Honor Hold",          side = "Alliance" },
    CENARION_EXP  = { id = 942, name = "Cenarion Expedition",  side = "Both" },
    CONSORTIUM    = { id = 933, name = "The Consortium",        side = "Both" },
    KEEPERS_TIME  = { id = 989, name = "Keepers of Time",      side = "Both" },
    LOWER_CITY    = { id = 1011, name = "Lower City",           side = "Both" },
    SHATAR        = { id = 935, name = "The Sha'tar",           side = "Both" },
}

BoneyardTBC_DO.REP_LEVELS = {
    { name = "Neutral",   min = 0,     max = 2999 },
    { name = "Friendly",  min = 3000,  max = 5999 },
    { name = "Honored",   min = 6000,  max = 11999 },
    { name = "Revered",   min = 12000, max = 20999 },
    { name = "Exalted",   min = 21000, max = 42999 },
}

BoneyardTBC_DO.REP_THRESHOLDS = {
    Neutral  = 0,
    Friendly = 3000,
    Honored  = 9000,
    Revered  = 21000,
    Exalted  = 42000,
}

BoneyardTBC_DO.DUNGEONS = {
    BLOOD_FURNACE = {
        name = "The Blood Furnace", faction = "HONOR_HOLD", zone = "Hellfire Peninsula",
        repPerClear = 750, repPerClearHeroic = 1700, minLevel = 58, maxLevel = 63, normalRepCap = "Honored",
    },
    HELLFIRE_RAMPARTS = {
        name = "Hellfire Ramparts", faction = "HONOR_HOLD", zone = "Hellfire Peninsula",
        repPerClear = 600, repPerClearHeroic = 1700, minLevel = 58, maxLevel = 62, normalRepCap = "Honored",
    },
    SHATTERED_HALLS = {
        name = "The Shattered Halls", faction = "HONOR_HOLD", zone = "Hellfire Peninsula",
        repPerClear = 1604, repPerClearHeroic = 2400, minLevel = 67, maxLevel = 70, normalRepCap = nil,
    },
    SLAVE_PENS = {
        name = "The Slave Pens", faction = "CENARION_EXP", zone = "Zangarmarsh",
        repPerClear = 915, repPerClearHeroic = 1700, minLevel = 60, maxLevel = 65, normalRepCap = "Honored",
    },
    UNDERBOG = {
        name = "The Underbog", faction = "CENARION_EXP", zone = "Zangarmarsh",
        repPerClear = 900, repPerClearHeroic = 1700, minLevel = 61, maxLevel = 66, normalRepCap = "Honored",
    },
    STEAMVAULT = {
        name = "The Steamvault", faction = "CENARION_EXP", zone = "Zangarmarsh",
        repPerClear = 1796, repPerClearHeroic = 2400, minLevel = 67, maxLevel = 70, normalRepCap = nil,
    },
    MANA_TOMBS = {
        name = "Mana-Tombs", faction = "CONSORTIUM", zone = "Terokkar Forest",
        repPerClear = 990, repPerClearHeroic = 1700, minLevel = 64, maxLevel = 68, normalRepCap = "Honored",
    },
    AUCHENAI_CRYPTS = {
        name = "Auchenai Crypts", faction = "LOWER_CITY", zone = "Terokkar Forest",
        repPerClear = 1050, repPerClearHeroic = 1700, minLevel = 63, maxLevel = 67, normalRepCap = "Honored",
    },
    SETHEKK_HALLS = {
        name = "Sethekk Halls", faction = "LOWER_CITY", zone = "Terokkar Forest",
        repPerClear = 1139, repPerClearHeroic = 1700, minLevel = 65, maxLevel = 70, normalRepCap = nil,
    },
    SHADOW_LABYRINTH = {
        name = "Shadow Labyrinth", faction = "LOWER_CITY", zone = "Terokkar Forest",
        repPerClear = 2012, repPerClearHeroic = 2400, minLevel = 67, maxLevel = 70, normalRepCap = nil,
    },
    OLD_HILLSBRAD = {
        name = "Old Hillsbrad Foothills", faction = "KEEPERS_TIME", zone = "Caverns of Time",
        repPerClear = 900, repPerClearHeroic = 1700, minLevel = 66, maxLevel = 70, normalRepCap = "Honored",
    },
    BLACK_MORASS = {
        name = "The Black Morass", faction = "KEEPERS_TIME", zone = "Caverns of Time",
        repPerClear = 1110, repPerClearHeroic = 1700, minLevel = 68, maxLevel = 70, normalRepCap = nil,
    },
    BOTANICA = {
        name = "The Botanica", faction = "SHATAR", zone = "Netherstorm",
        repPerClear = 1270, repPerClearHeroic = 1900, minLevel = 68, maxLevel = 70, normalRepCap = nil,
    },
    MECHANAR = {
        name = "The Mechanar", faction = "SHATAR", zone = "Netherstorm",
        repPerClear = 1200, repPerClearHeroic = 1900, minLevel = 67, maxLevel = 70, normalRepCap = nil,
    },
    ARCATRAZ = {
        name = "The Arcatraz", faction = "SHATAR", zone = "Netherstorm",
        repPerClear = 1600, repPerClearHeroic = 2400, minLevel = 68, maxLevel = 70, normalRepCap = nil,
    },
}

BoneyardTBC_DO.DUNGEON_XP = {
    BLOOD_FURNACE    = { base = 45000, levelRange = {58, 63} },
    HELLFIRE_RAMPARTS = { base = 38000, levelRange = {58, 62} },
    SLAVE_PENS       = { base = 52000, levelRange = {60, 65} },
    UNDERBOG         = { base = 52000, levelRange = {61, 66} },
    MANA_TOMBS       = { base = 55000, levelRange = {64, 68} },
    SETHEKK_HALLS    = { base = 58000, levelRange = {65, 70} },
    SHADOW_LABYRINTH = { base = 62000, levelRange = {67, 70} },
    OLD_HILLSBRAD    = { base = 55000, levelRange = {66, 70} },
    BLACK_MORASS     = { base = 52000, levelRange = {68, 70} },
    STEAMVAULT       = { base = 60000, levelRange = {67, 70} },
    SHATTERED_HALLS  = { base = 62000, levelRange = {67, 70} },
    BOTANICA         = { base = 60000, levelRange = {68, 70} },
    MECHANAR         = { base = 55000, levelRange = {67, 70} },
    ARCATRAZ         = { base = 65000, levelRange = {68, 70} },
    AUCHENAI_CRYPTS  = { base = 53000, levelRange = {63, 67} },
}

BoneyardTBC_DO.XP_TO_LEVEL = {
    [58] = 209800,
    [59] = 221200,
    [60] = 290000,
    [61] = 317000,
    [62] = 349000,
    [63] = 386000,
    [64] = 428000,
    [65] = 475000,
    [66] = 527000,
    [67] = 586000,
    [68] = 650000,
    [69] = 720000,
}

BoneyardTBC_DO.ROUTES = {}

BoneyardTBC_DO.ROUTES.ALLIANCE_BALANCED = {
    -- PHASE 1: Blood Furnace (lvl 60-61)
    { type = "travel",  step = 1,  text = "Enter Dark Portal, set Hearth to Honor Hold", zone = "Hellfire Peninsula" },
    { type = "dungeon", step = 2,  dungeon = "BLOOD_FURNACE", runs = 12, repGoal = "Honored",
      faction = "HONOR_HOLD", note = "750 rep/clear, 12 runs to Honored" },

    -- PHASE 2: Slave Pens (lvl 61-65)
    { type = "travel",  step = 3,  text = "Run to Zangarmarsh, grab flight path", zone = "Zangarmarsh" },
    { type = "travel",  step = 4,  text = "Run to Shattrath City, set Hearth", zone = "Shattrath City", note = "Only trainers in Outland" },
    { type = "quest",   step = 5,  action = "Accept",  quest = "A'dal",                      npc = "Haggard War Veteran", zone = "Shattrath City" },
    { type = "quest",   step = 6,  action = "Turn In", quest = "A'dal",                      npc = "A'dal" },
    { type = "quest",   step = 7,  action = "Accept",  quest = "City of Light",              npc = "Khadgar" },
    { type = "quest",   step = 8,  action = "Turn In", quest = "City of Light",              npc = "Khadgar" },
    { type = "quest",   step = 9,  action = "Accept",  quest = "Allegiance to the Aldor",    npc = "Khadgar", note = "Choose Aldor OR Scryers" },
    { type = "quest",   step = 10, action = "Turn In", quest = "Allegiance to the Aldor/Scryers", npc = "Khadgar" },
    { type = "travel",  step = 11, text = "Fly to Telredor (Zangarmarsh)", zone = "Zangarmarsh" },
    { type = "dungeon", step = 12, dungeon = "SLAVE_PENS", runs = -1, repGoal = "Honored",
      faction = "CENARION_EXP", levelGoal = 65, note = "915 rep/clear, stay until level 65" },

    -- PHASE 3: Mana-Tombs (lvl 65-66)
    { type = "travel",  step = 13, text = "Hearth to Shattrath", zone = "Shattrath City" },
    { type = "travel",  step = 14, text = "Run to Allerian Stronghold, grab flight path", zone = "Terokkar Forest" },
    { type = "dungeon", step = 15, dungeon = "MANA_TOMBS", runs = -1, repGoal = "Honored",
      faction = "CONSORTIUM", levelGoal = 66, note = "990 rep/clear, stay until level 66" },

    -- PHASE 4: Sethekk Halls (lvl 66-68)
    { type = "dungeon", step = 16, dungeon = "SETHEKK_HALLS", runs = 8, repGoal = "Honored",
      faction = "LOWER_CITY", note = "1139 rep/clear, 8 runs to Honored" },
    { type = "quest",   step = 17, action = "Collect", quest = "Shadow Labyrinth Key",
      note = "Loot from chest behind last boss of Sethekk Halls" },

    -- PHASE 5: Karazhan Attunement Start (lvl 68)
    { type = "travel",  step = 18, text = "Portal to Stormwind City", zone = "Stormwind City" },
    { type = "travel",  step = 19, text = "Fly to Darkshire", zone = "Duskwood" },
    { type = "travel",  step = 20, text = "Run to Karazhan", zone = "Deadwind Pass" },
    { type = "quest",   step = 21, action = "Accept",   quest = "Arcane Disturbances",       npc = "Archmage Alturus", zone = "Deadwind Pass" },
    { type = "quest",   step = 22, action = "Accept",   quest = "Restless Activity",         npc = "Archmage Alturus" },
    { type = "quest",   step = 23, action = "Complete", quest = "Arcane Disturbances" },
    { type = "quest",   step = 24, action = "Complete", quest = "Restless Activity" },
    { type = "quest",   step = 25, action = "Turn In",  quest = "Arcane Disturbances",       npc = "Archmage Alturus" },
    { type = "quest",   step = 26, action = "Turn In",  quest = "Restless Activity",         npc = "Archmage Alturus" },
    { type = "quest",   step = 27, action = "Accept",   quest = "Contact from Dalaran",      npc = "Archmage Alturus" },
    { type = "travel",  step = 28, text = "Fly to Southshore", zone = "Hillsbrad Foothills" },
    { type = "quest",   step = 29, action = "Turn In",  quest = "Contact from Dalaran",      npc = "Archmage Cedric", zone = "Alterac Mountains" },
    { type = "quest",   step = 30, action = "Accept",   quest = "Khadgar",                   npc = "Archmage Cedric" },
    { type = "travel",  step = 31, text = "Hearth to Shattrath", zone = "Shattrath City" },
    { type = "quest",   step = 32, action = "Turn In",  quest = "Khadgar",                   npc = "Khadgar", zone = "Shattrath City" },
    { type = "quest",   step = 33, action = "Accept",   quest = "Entry Into Karazhan",       npc = "Khadgar" },
    { type = "travel",  step = 34, text = "Portal to Theramore, fly to Gadgetzan", zone = "Tanaris" },
    { type = "travel",  step = 35, text = "Run to Caverns of Time", zone = "Caverns of Time" },

    -- PHASE 6: Caverns of Time dungeons (lvl 68-69)
    { type = "quest",   step = 36, action = "Accept",   quest = "The Caverns of Time",       npc = "Andormu", zone = "Tanaris" },
    { type = "quest",   step = 37, action = "Complete", quest = "The Caverns of Time" },
    { type = "quest",   step = 38, action = "Turn In",  quest = "The Caverns of Time",       npc = "Andormu" },
    { type = "quest",   step = 39, action = "Accept",   quest = "Old Hillsbrad",             npc = "Andormu" },
    { type = "dungeon", step = 40, dungeon = "OLD_HILLSBRAD", runs = 1,
      faction = "KEEPERS_TIME", note = "1 clear, complete quests inside" },
    { type = "quest",   step = 41, action = "Accept",   quest = "Taretha's Diversion",       npc = "Erozion" },
    { type = "quest",   step = 42, action = "Complete", quest = "Taretha's Diversion" },
    { type = "quest",   step = 43, action = "Turn In",  quest = "Taretha's Diversion",       npc = "Thrall" },
    { type = "quest",   step = 44, action = "Accept",   quest = "Escape from Durnholde",     npc = "Thrall" },
    { type = "quest",   step = 45, action = "Complete", quest = "Escape from Durnholde" },
    { type = "quest",   step = 46, action = "Turn In",  quest = "Escape from Durnholde",     npc = "Erozion" },
    { type = "quest",   step = 47, action = "Accept",   quest = "Return to Andormu",         npc = "Erozion" },
    { type = "quest",   step = 48, action = "Turn In",  quest = "Return to Andormu",         npc = "Andormu" },
    { type = "quest",   step = 49, action = "Accept",   quest = "The Black Morass",          npc = "Andormu" },
    { type = "dungeon", step = 50, dungeon = "BLACK_MORASS", runs = 7, repGoal = "Revered",
      faction = "KEEPERS_TIME", note = "1110 rep/clear, 6-7 runs to Revered" },
    { type = "quest",   step = 51, action = "Complete", quest = "The Black Morass" },
    { type = "quest",   step = 52, action = "Accept",   quest = "The Opening of the Dark Portal", npc = "Sa'at" },
    { type = "quest",   step = 53, action = "Complete", quest = "The Opening of the Dark Portal" },
    { type = "quest",   step = 54, action = "Turn In",  quest = "The Opening of the Dark Portal", npc = "Sa'at" },
    { type = "quest",   step = 55, action = "Accept",   quest = "Hero of the Brood",         npc = "Sa'at" },
    { type = "quest",   step = 56, action = "Turn In",  quest = "Hero of the Brood",         npc = "Andormu" },

    -- PHASE 7: Shadow Labyrinth (lvl 69)
    { type = "travel",  step = 57, text = "Hearth to Shattrath, fly to Allerian Stronghold", zone = "Terokkar Forest" },
    { type = "dungeon", step = 58, dungeon = "SHADOW_LABYRINTH", runs = 6, repGoal = "Revered",
      faction = "LOWER_CITY", note = "2012 rep/clear, 6 runs to Revered" },

    -- PHASE 8: Steamvault + Kara attunement cont. (lvl 69-70)
    { type = "travel",  step = 59, text = "Hearth to Shattrath", zone = "Shattrath City" },
    { type = "quest",   step = 60, action = "Turn In",  quest = "Entry Into Karazhan",       npc = "Khadgar" },
    { type = "quest",   step = 61, action = "Accept",   quest = "The Second and Third Fragments", npc = "Khadgar" },
    { type = "travel",  step = 62, text = "Fly to Telredor (Zangarmarsh)", zone = "Zangarmarsh" },
    { type = "dungeon", step = 63, dungeon = "STEAMVAULT", runs = 7, repGoal = "Revered",
      faction = "CENARION_EXP", note = "1796 rep/clear, 7 runs to Revered" },

    -- PHASE 9: Shattered Halls Key + Dungeon
    { type = "travel",  step = 64, text = "Run to the Black Temple (Shadowmoon Valley)", zone = "Shadowmoon Valley" },
    { type = "quest",   step = 65, action = "Kill",     quest = "Kill Smith Gorlunk for quest item", zone = "Shadowmoon Valley" },
    { type = "quest",   step = 66, action = "Accept",   quest = "Entry Into the Citadel" },
    { type = "travel",  step = 67, text = "Fly to Honor Hold", zone = "Hellfire Peninsula" },
    { type = "quest",   step = 68, action = "Turn In",  quest = "Entry Into the Citadel",    npc = "Force Commander Danath Trollbane" },
    { type = "quest",   step = 69, action = "Accept",   quest = "Grand Master Dumphry",      npc = "Force Commander Danath Trollbane" },
    { type = "quest",   step = 70, action = "Turn In",  quest = "Grand Master Dumphry",      npc = "Dumphry" },
    { type = "quest",   step = 71, action = "Accept",   quest = "Dumphry's Request",         npc = "Dumphry" },
    { type = "quest",   step = 72, action = "Turn In",  quest = "Dumphry's Request",         npc = "Dumphry" },
    { type = "quest",   step = 73, action = "Accept",   quest = "Hotter than Hell",          npc = "Dumphry" },
    { type = "quest",   step = 74, action = "Complete", quest = "Hotter than Hell" },
    { type = "quest",   step = 75, action = "Turn In",  quest = "Hotter than Hell",          npc = "Dumphry" },
    { type = "dungeon", step = 76, dungeon = "SHATTERED_HALLS", runs = 8, repGoal = "Revered",
      faction = "HONOR_HOLD", note = "1604 rep/clear, run until Revered" },

    { type = "checkpoint", step = 77, text = "Level 70, 4/5 Heroic Keys, 2/3 Kara Fragments" },

    -- PHASE 10: Flying + Arcatraz Key Chain
    { type = "travel",  step = 78, text = "Fly to Wildhammer Stronghold, buy flying training", zone = "Shadowmoon Valley" },
    { type = "travel",  step = 79, text = "Fly to Area 52 (Netherstorm)", zone = "Netherstorm" },
    { type = "quest",   step = 80, action = "Accept",   quest = "Assisting the Consortium",       npc = "Anchorite Karja", zone = "Netherstorm" },
    { type = "quest",   step = 81, action = "Turn In",  quest = "Assisting the Consortium",       npc = "Nether-Stalker Khay'ji" },
    { type = "quest",   step = 82, action = "Accept",   quest = "Consortium Crystal Collection",  npc = "Nether-Stalker Khay'ji" },
    { type = "quest",   step = 83, action = "Complete", quest = "Consortium Crystal Collection",  note = "Kill named boss at Arklon Ruins" },
    { type = "quest",   step = 84, action = "Turn In",  quest = "Consortium Crystal Collection",  npc = "Nether-Stalker Khay'ji" },
    { type = "quest",   step = 85, action = "Accept",   quest = "A Heap of Ethereals",            npc = "Nether-Stalker Khay'ji" },
    { type = "quest",   step = 86, action = "Complete", quest = "A Heap of Ethereals" },
    { type = "quest",   step = 87, action = "Turn In",  quest = "A Heap of Ethereals",            npc = "Nether-Stalker Khay'ji" },
    { type = "quest",   step = 88, action = "Accept",   quest = "Warp-Rider Nesaad",              npc = "Nether-Stalker Khay'ji" },
    { type = "quest",   step = 89, action = "Complete", quest = "Warp-Rider Nesaad" },
    { type = "quest",   step = 90, action = "Turn In",  quest = "Warp-Rider Nesaad",              npc = "Nether-Stalker Khay'ji" },
    { type = "quest",   step = 91, action = "Accept",   quest = "Request for Assistance",         npc = "Nether-Stalker Khay'ji" },
    { type = "quest",   step = 92, action = "Turn In",  quest = "Request for Assistance",         npc = "Gahruj", zone = "Eco-Dome Midrealm" },
    { type = "quest",   step = 93, action = "Accept",   quest = "Rightful Repossession",          npc = "Gahruj" },
    { type = "quest",   step = 94, action = "Complete", quest = "Rightful Repossession",          note = "Boxes at Manaforge Duro" },
    { type = "quest",   step = 95, action = "Turn In",  quest = "Rightful Repossession",          npc = "Gahruj" },
    { type = "quest",   step = 96, action = "Accept",   quest = "An Audience with the Prince",    npc = "Gahruj" },
    { type = "quest",   step = 97, action = "Turn In",  quest = "An Audience with the Prince",    npc = "Image of Nexus-Prince Haramad" },
    { type = "quest",   step = 98, action = "Accept",   quest = "Triangulation Point One" },
    { type = "quest",   step = 99, action = "Complete", quest = "Triangulation Point One",        note = "NE of Manaforge Ultris" },
    { type = "quest",   step = 100, action = "Turn In", quest = "Triangulation Point One",        npc = "Dealer Hazzin" },
    { type = "quest",   step = 101, action = "Accept",  quest = "Triangulation Point Two" },
    { type = "quest",   step = 102, action = "Complete",quest = "Triangulation Point Two",        note = "Near Manaforge Ara" },
    { type = "quest",   step = 103, action = "Turn In", quest = "Triangulation Point Two",        npc = "Wind Trader Tuluman" },
    { type = "quest",   step = 104, action = "Accept",  quest = "Full Triangle" },
    { type = "quest",   step = 105, action = "Complete",quest = "Full Triangle",                  note = "Kill named boss, loot crystal" },
    { type = "quest",   step = 106, action = "Turn In", quest = "Full Triangle",                  npc = "Image of Nexus-Prince Haramad" },
    { type = "quest",   step = 107, action = "Accept",  quest = "Special Delivery to Shattrath City" },
    { type = "travel",  step = 108, text = "Hearth to Shattrath", zone = "Shattrath City" },
    { type = "quest",   step = 109, action = "Turn In", quest = "Special Delivery to Shattrath City", npc = "A'dal" },
    { type = "quest",   step = 110, action = "Accept",  quest = "How to Break into Arcatraz",     npc = "A'dal" },
    { type = "travel",  step = 111, text = "Fly to Area 52", zone = "Netherstorm" },
    { type = "dungeon", step = 112, dungeon = "BOTANICA", runs = 1, note = "1 clear for attunement" },
    { type = "dungeon", step = 113, dungeon = "MECHANAR", runs = 1, note = "1 clear for attunement" },
    { type = "travel",  step = 114, text = "Hearth to Shattrath", zone = "Shattrath City" },
    { type = "quest",   step = 115, action = "Turn In", quest = "How to Break into Arcatraz",     npc = "A'dal" },
    { type = "travel",  step = 116, text = "Fly to Area 52", zone = "Netherstorm" },
    { type = "dungeon", step = 117, dungeon = "ARCATRAZ", runs = 1,
      note = "1 clear for Kara key fragment (don't need to finish)" },

    -- PHASE 11: Finish Karazhan Attunement
    { type = "travel",  step = 118, text = "Hearth to Shattrath", zone = "Shattrath City" },
    { type = "quest",   step = 119, action = "Turn In", quest = "The Second and Third Fragments", npc = "Khadgar" },
    { type = "quest",   step = 120, action = "Accept",  quest = "The Master's Touch",             npc = "Khadgar" },
    { type = "travel",  step = 121, text = "Portal to Theramore, fly to Gadgetzan, run to Caverns of Time", zone = "Caverns of Time" },
    { type = "dungeon", step = 122, dungeon = "BLACK_MORASS", runs = 1, note = "1 clear for Master's Touch" },
    { type = "quest",   step = 123, action = "Complete",quest = "The Master's Touch",             npc = "Medivh" },
    { type = "quest",   step = 124, action = "Turn In", quest = "The Master's Touch",             npc = "Medivh" },
    { type = "quest",   step = 125, action = "Accept",  quest = "Return to Khadgar",              npc = "Medivh" },
    { type = "travel",  step = 126, text = "Hearth to Shattrath", zone = "Shattrath City" },
    { type = "quest",   step = 127, action = "Turn In", quest = "Return to Khadgar",              npc = "Khadgar" },
    { type = "quest",   step = 128, action = "Accept",  quest = "The Violet Eye",                 npc = "Khadgar" },
    { type = "travel",  step = 129, text = "Portal to Stormwind, fly to Darkshire, run to Karazhan", zone = "Deadwind Pass" },
    { type = "quest",   step = 130, action = "Turn In", quest = "The Violet Eye",                 npc = "Archmage Alturus" },

    { type = "checkpoint", step = 131, text = "Level 70, 12/15 Heroics, Flying, Karazhan Attuned!" },

    -- BONUS
    { type = "dungeon", step = 132, dungeon = "BOTANICA", runs = -1, repGoal = "Revered",
      faction = "SHATAR", note = "Farm Botanica until Revered with Sha'tar (bonus)" },
}
