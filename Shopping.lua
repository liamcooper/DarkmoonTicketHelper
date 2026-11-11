local ADDON, ns = ...

-- Resolve the plan into purchases, sharing owned reagents and surplus crafts
-- across recipes. Finished turn-in stock was already deducted by the planner.
function ns.BuildShoppingItems(plan)
  local items, vendor, stock = {}, {}, {}
  local function owned(id)
    if stock[id] == nil then
      if C_Item and C_Item.GetItemCount then
        stock[id] = C_Item.GetItemCount(id, true, false, true) or 0
      else
        stock[id] = GetItemCount and GetItemCount(id, true) or 0
      end
    end
    return stock[id]
  end
  local function acquire(id, qty, source, useStock, depth)
    if depth > 10 then error("Recipe nesting is too deep") end
    if useStock then
      local used = math.min(qty, owned(id))
      stock[id] = stock[id] - used
      qty = qty - used
    end
    if qty <= 0 then return end
    local recipe = ns.RECIPES[id]
    if source == "craft" and recipe then
      local crafts = math.ceil(qty / (recipe.yield or 1))
      stock[id] = owned(id) + crafts * (recipe.yield or 1) - qty
      for _, reagent in ipairs(recipe.reagents) do
        local _, reagentSource = ns.GetEffectiveUnitPrice(reagent[1])
        acquire(reagent[1], reagent[2] * crafts, reagentSource, true, depth + 1)
      end
    else
      local list = source == "vendor" and vendor or items
      list[id] = (list[id] or 0) + qty
    end
  end
  for _, step in ipairs(plan.steps) do
    acquire(step.row.turnin.itemId, step.buy, step.row.source, false, 0)
  end
  return items, vendor
end

function ns.CreateAuctionatorList()
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  local function tell(message) print("|cff00ccffDMTH|r " .. message) end
  if not api or not api.CreateShoppingList or not api.ConvertToSearchString then
    tell("This Auctionator version needs the CreateShoppingList and ConvertToSearchString APIs.")
    return
  end
  ns.EnsureDB()
  local need = math.max(0, (DarkmoonTicketHelperDB.target or ns.DEFAULT_TARGET) - ns.GetTicketCount())
  if need == 0 then tell("Target already reached; nothing to buy."); return end
  local plan = ns.BuildExactPlan(ns.BuildRanking(), need)
  if not plan then tell("No exact route with current prices and reputation."); return end
  local ok, err = pcall(function()
    local items, vendor = ns.BuildShoppingItems(plan)
    local terms, ids = {}, {}
    for id in pairs(items) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
      local name = ns.GetItemName(id) or ns.REAGENT_NAMES[id]
      if not name then
        for _, t in ipairs(ns.TURNINS) do if t.itemId == id then name = t.name; break end end
      end
      if not name then error("Item name not loaded for " .. id .. "; try again.") end
      terms[#terms + 1] = api.ConvertToSearchString(ns.CALLER_ID, {
        searchString = name, isExact = true, quantity = items[id],
      })
    end
    if #terms > 0 then
      api.CreateShoppingList(ns.CALLER_ID, ns.CALLER_ID, terms)
      tell('Created Auctionator list "' .. ns.CALLER_ID .. '". Open Shopping and search the list to buy the required quantities.')
    else
      tell("No auction purchases needed; use your owned items and vendor supplies.")
    end
    local supplies = {}
    for id, qty in pairs(vendor) do
      supplies[#supplies + 1] = qty .. " × " .. (ns.GetItemName(id) or ns.REAGENT_NAMES[id] or tostring(id))
    end
    table.sort(supplies)
    if #supplies > 0 then tell("Buy from vendors: " .. table.concat(supplies, ", ")) end
  end)
  if not ok then tell("Could not create shopping list: " .. tostring(err)) end
end
