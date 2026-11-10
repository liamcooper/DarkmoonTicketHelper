local ADDON, ns = ...

-- Wowhead Forever guide values (Nov 2026).
-- Rep cutoffs are points *within* the standing (Neutral 0-3000, Friendly 0-6000).
-- Commenters report Tier 1 may cut off a bit early; values stay editable here.

ns.ADDON_NAME = "DarkmoonTicketHelper"
ns.CALLER_ID = "Darkmoon Ticket Helper"

ns.CURRENCY_TICKET = 515
ns.FACTION_DMF = 909

-- standingID: 4 Neutral, 5 Friendly (Classic/Forever faction reaction ids)
ns.TIERS = {
  [1] = { tickets = 1, minLevel = 1,  cutoffStanding = 4, cutoffValue = 500,  label = "Tier 1" },
  [2] = { tickets = 4, minLevel = 10, cutoffStanding = 4, cutoffValue = 1100, label = "Tier 2" },
  [3] = { tickets = 8, minLevel = 20, cutoffStanding = 4, cutoffValue = 1700, label = "Tier 3" },
  [4] = { tickets = 12, minLevel = 30, cutoffStanding = 4, cutoffValue = 2500, label = "Tier 4" },
  [5] = { tickets = 20, minLevel = 40, cutoffStanding = 5, cutoffValue = 5999, label = "Tier 5" },
}

-- Approximate rep per turn-in from the Forever guide. Humans (+10% Diplomacy) get more.
ns.REP_PER_TURNIN = 100

ns.NPCS = {
  animal = { name = "Yebb Neblegear", elwynn = "40.2, 69.5", mulgore = "37.5, 39.6" },
  blacksmithing = { name = "Kerri Hicks", elwynn = "40.5, 69.9", mulgore = "37.8, 38.9" },
  engineering = { name = "Rinling", elwynn = "41.7, 70.7", mulgore = "37.1, 37.2" },
  leatherworking = { name = "Chronos", elwynn = "41.5, 68.9", mulgore = "37.2, 37.7" },
}

-- qty = items per turn-in. itemId = Classic/Forever shared ids for these crafts/drops.
ns.TURNINS = {
  -- Animal parts
  { key = "paw",        tier = 1, category = "animal",         itemId = 5134,  qty = 5,  name = "Small Furry Paw" },
  { key = "pelt",       tier = 2, category = "animal",         itemId = 11407, qty = 5,  name = "Torn Bear Pelt" },
  { key = "tail",       tier = 3, category = "animal",         itemId = 4582,  qty = 5,  name = "Soft Bushy Tail" },
  { key = "plume",      tier = 4, category = "animal",         itemId = 5117,  qty = 5,  name = "Vibrant Plume" },
  { key = "bateye",     tier = 5, category = "animal",         itemId = 11404, qty = 10, name = "Evil Bat Eye" },
  { key = "scorpid",    tier = 5, category = "animal",         itemId = 19933, qty = 10, name = "Glowing Scorpid Blood" },
  -- Blacksmithing
  { key = "weight",     tier = 1, category = "blacksmithing",  itemId = 3240,  qty = 10, name = "Coarse Weightstone" },
  { key = "heavygrind", tier = 2, category = "blacksmithing",  itemId = 3486,  qty = 7,  name = "Heavy Grinding Stone" },
  { key = "bracers",    tier = 3, category = "blacksmithing",  itemId = 3835,  qty = 3,  name = "Green Iron Bracers" },
  { key = "mace",       tier = 4, category = "blacksmithing",  itemId = 7945,  qty = 1,  name = "Big Black Mace" },
  { key = "dense",      tier = 5, category = "blacksmithing",  itemId = 12644, qty = 8,  name = "Dense Grinding Stone" },
  -- Engineering
  { key = "modulator",  tier = 1, category = "engineering",    itemId = 4363,  qty = 5,  name = "Copper Modulator" },
  { key = "gizmo",      tier = 2, category = "engineering",    itemId = 4375,  qty = 7,  name = "Whirring Bronze Gizmo" },
  { key = "firework",   tier = 3, category = "engineering",    itemId = 9313,  qty = 36, name = "Green Firework" },
  { key = "repair",     tier = 4, category = "engineering",    itemId = 11590, qty = 6,  name = "Mechanical Repair Kit" },
  { key = "widget",     tier = 5, category = "engineering",    itemId = 15994, qty = 6,  name = "Thorium Widget" },
  -- Leatherworking
  { key = "boots",      tier = 1, category = "leatherworking", itemId = 2309,  qty = 3,  name = "Embossed Leather Boots" },
  { key = "jerkin",     tier = 2, category = "leatherworking", itemId = 2314,  qty = 3,  name = "Toughened Leather Armor" },
  { key = "harness",    tier = 3, category = "leatherworking", itemId = 5739,  qty = 3,  name = "Barbaric Harness" },
  { key = "turtle",     tier = 4, category = "leatherworking", itemId = 8185,  qty = 1,  name = "Turtle Scale Leggings" },
  { key = "rugged",     tier = 5, category = "leatherworking", itemId = 15564, qty = 8,  name = "Rugged Armor Kit" },
}

ns.CATEGORY_LABEL = {
  animal = "Animal",
  blacksmithing = "Blacksmithing",
  engineering = "Engineering",
  leatherworking = "Leatherworking",
}

-- Gelvas Grimegate ticket redemption. Forever checks tickets + level only — not DMF rep.
ns.REWARD_VENDOR = { name = "Gelvas Grimegate", elwynn = "41.5, 68.9", mulgore = "37.3, 37.7" }

ns.REWARDS = {
  { key = "flower",   itemId = 19295, name = "Darkmoon Flower",              tickets = 5,    minLevel = 6,  repRequired = nil, unique = false, note = "Off-hand fluff" },
  { key = "minor",    itemId = 19298, name = "Minor Darkmoon Prize",         tickets = 5,    minLevel = 15, repRequired = nil, unique = false, note = "Random greens / bags / gems" },
  { key = "mutton1",  itemId = 19292, name = "Last Month's Mutton",          tickets = 10,   minLevel = 25, repRequired = nil, unique = false, note = "One-hand mace" },
  { key = "lesser",   itemId = 19297, name = "Lesser Darkmoon Prize",        tickets = 12,   minLevel = 30, repRequired = nil, unique = false, note = "Random greens / bags / gems" },
  { key = "greater",  itemId = 19296, name = "Greater Darkmoon Prize",       tickets = 40,   minLevel = 45, repRequired = nil, unique = false, note = "Random greens / recipes / gems" },
  { key = "tonk",     itemId = 22729, name = "Schematic: Steam Tonk Controller", tickets = 40, minLevel = 45, repRequired = nil, unique = false, note = "Engineering schematic (if offered)" },
  { key = "box",      itemId = 19291, name = "Darkmoon Storage Box",         tickets = 50,   minLevel = 6,  repRequired = nil, unique = true,  note = "14-slot bag (unique)" },
  { key = "mutton2",  itemId = 19293, name = "Last Year's Mutton",           tickets = 50,   minLevel = 45, repRequired = nil, unique = false, note = "One-hand mace" },
  { key = "amulet",   itemId = 19491, name = "Amulet of the Darkmoon",       tickets = 1200, minLevel = 55, repRequired = nil, unique = false, note = "BiS-style neck (agi/str)" },
  { key = "orb",      itemId = 19426, name = "Orb of the Darkmoon",          tickets = 1200, minLevel = 55, repRequired = nil, unique = false, note = "BiS-style neck (int/spirit)" },
}

ns.DEFAULT_TARGET = 50
