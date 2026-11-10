local ADDON, ns = ...

-- Classic Era recipes for craftable DMF turn-ins (+ nested components).
-- yield = items produced per craft (Green Firework makes 3).

ns.VENDOR_PRICES = {
  [2320] = 10,    -- Coarse Thread
  [2321] = 100,   -- Fine Thread
  [4291] = 500,   -- Silken Thread
  [8343] = 2000,  -- Heavy Silken Thread
  [2605] = 100,   -- Green Dye
  [4289] = 50,    -- Salt
  [2880] = 100,   -- Weak Flux (not used by current DMF crafts, kept for completeness)
}

-- itemId -> { yield = n, reagents = { { itemId, qty }, ... } }
ns.RECIPES = {
  -- Blacksmithing turn-ins
  [3240]  = { yield = 1, reagents = { { 2836, 1 }, { 2592, 1 } } },             -- Coarse Weightstone
  [3486]  = { yield = 1, reagents = { { 2838, 3 } } },                           -- Heavy Grinding Stone
  [3835]  = { yield = 1, reagents = { { 3575, 6 }, { 2605, 1 } } },              -- Green Iron Bracers
  [7945]  = { yield = 1, reagents = { { 3860, 16 }, { 7971, 1 }, { 1210, 4 }, { 7966, 1 }, { 4304, 2 } } }, -- Big Black Mace
  [12644] = { yield = 1, reagents = { { 12365, 4 } } },                          -- Dense Grinding Stone
  -- Nested BS
  [7966]  = { yield = 1, reagents = { { 7912, 4 } } },                           -- Solid Grinding Stone
  [7071]  = { yield = 1, reagents = { { 3575, 1 } } },                           -- Iron Buckle

  -- Engineering turn-ins
  [4363]  = { yield = 1, reagents = { { 4359, 2 }, { 2840, 1 }, { 2589, 2 } } }, -- Copper Modulator
  [4375]  = { yield = 1, reagents = { { 2841, 2 }, { 2592, 1 } } },              -- Whirring Bronze Gizmo
  [9313]  = { yield = 3, reagents = { { 4377, 1 }, { 4234, 1 } } },              -- Green Firework (×3)
  [11590] = { yield = 1, reagents = { { 3860, 1 }, { 4338, 1 }, { 10505, 1 } } }, -- Mechanical Repair Kit
  [15994] = { yield = 1, reagents = { { 12359, 3 }, { 14047, 1 } } },            -- Thorium Widget
  -- Nested Eng
  [4359]  = { yield = 1, reagents = { { 2840, 1 } } },                           -- Handful of Copper Bolts
  [4377]  = { yield = 1, reagents = { { 2838, 1 } } },                           -- Heavy Blasting Powder
  [10505] = { yield = 1, reagents = { { 7912, 2 } } },                           -- Solid Blasting Powder

  -- Leatherworking turn-ins
  [2309]  = { yield = 1, reagents = { { 2318, 8 }, { 2320, 5 } } },              -- Embossed Leather Boots
  [2314]  = { yield = 1, reagents = { { 2319, 10 }, { 4231, 2 }, { 2321, 2 } } }, -- Toughened Leather Armor
  [5739]  = { yield = 1, reagents = { { 4234, 14 }, { 2321, 2 }, { 7071, 1 } } }, -- Barbaric Harness
  [8185]  = { yield = 1, reagents = { { 4304, 14 }, { 8167, 28 }, { 8343, 1 } } }, -- Turtle Scale Leggings
  [15564] = { yield = 1, reagents = { { 8170, 5 } } },                           -- Rugged Armor Kit
  -- Nested LW
  [4231]  = { yield = 1, reagents = { { 783, 1 }, { 4289, 1 } } },               -- Cured Light Hide
}

ns.REAGENT_NAMES = {
  [2836] = "Coarse Stone",
  [2592] = "Wool Cloth",
  [2838] = "Heavy Stone",
  [3575] = "Iron Bar",
  [2605] = "Green Dye",
  [3860] = "Mithril Bar",
  [7971] = "Black Pearl",
  [1210] = "Shadowgem",
  [7966] = "Solid Grinding Stone",
  [4304] = "Thick Leather",
  [7912] = "Solid Stone",
  [12365] = "Dense Stone",
  [4359] = "Handful of Copper Bolts",
  [2840] = "Copper Bar",
  [2589] = "Linen Cloth",
  [2841] = "Bronze Bar",
  [4377] = "Heavy Blasting Powder",
  [4234] = "Heavy Leather",
  [4338] = "Mageweave Cloth",
  [10505] = "Solid Blasting Powder",
  [12359] = "Thorium Bar",
  [14047] = "Runecloth",
  [2318] = "Light Leather",
  [2320] = "Coarse Thread",
  [2319] = "Medium Leather",
  [4231] = "Cured Light Hide",
  [2321] = "Fine Thread",
  [783] = "Light Hide",
  [4289] = "Salt",
  [7071] = "Iron Buckle",
  [8167] = "Turtle Scale",
  [8343] = "Heavy Silken Thread",
  [8170] = "Rugged Leather",
}

function ns.IsCraftable(itemId)
  return ns.RECIPES[itemId] ~= nil
end

--- Market/override/vendor only (no crafting recursion).
function ns.GetBuyUnitPrice(itemId)
  local price, source = ns.GetUnitPrice(itemId)
  if price then
    return price, source
  end
  local vendor = ns.VENDOR_PRICES[itemId]
  if vendor then
    return vendor, "vendor"
  end
  return nil, "none"
end

local function craftCostFor(itemId, depth, stack)
  local recipe = ns.RECIPES[itemId]
  if not recipe then
    return nil, nil
  end
  depth = depth or 0
  if depth > 6 then
    return nil, nil
  end
  stack = stack or {}
  if stack[itemId] then
    return nil, nil
  end
  stack[itemId] = true

  local total = 0
  local missing = false
  for _, reagent in ipairs(recipe.reagents) do
    local rid, qty = reagent[1], reagent[2]
    local unit = select(1, ns.GetEffectiveUnitPrice(rid, depth + 1, stack))
    if not unit then
      missing = true
      break
    end
    total = total + unit * qty
  end

  stack[itemId] = nil
  if missing then
    return nil, nil
  end
  local yield = recipe.yield or 1
  return total / yield, "craft"
end

--- Cheapest of buy vs craft (craft recurses into mats).
--- @return number|nil price, string source, number|nil buyPrice, number|nil craftPrice
function ns.GetEffectiveUnitPrice(itemId, depth, stack)
  local buyPrice, buySource = ns.GetBuyUnitPrice(itemId)
  local craftPrice = select(1, craftCostFor(itemId, depth, stack))

  if buyPrice and craftPrice then
    if craftPrice < buyPrice then
      return craftPrice, "craft", buyPrice, craftPrice
    end
    return buyPrice, buySource == "override" and "override" or "buy", buyPrice, craftPrice
  end
  if craftPrice then
    return craftPrice, "craft", buyPrice, craftPrice
  end
  if buyPrice then
    local label = buySource
    if buySource == "auctionator" then
      label = "buy"
    end
    return buyPrice, label, buyPrice, craftPrice
  end
  return nil, "none", nil, nil
end

--- Flat list of reagent item ids used by DMF crafts (for the price editor).
function ns.CollectReagentItemIds()
  local seen, list = {}, {}
  local function add(id)
    if not seen[id] then
      seen[id] = true
      list[#list + 1] = id
    end
  end
  for itemId, recipe in pairs(ns.RECIPES) do
    add(itemId)
    for _, reagent in ipairs(recipe.reagents) do
      add(reagent[1])
    end
  end
  table.sort(list)
  return list
end
