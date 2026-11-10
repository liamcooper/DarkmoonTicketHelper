local ADDON, ns = ...

local function ensureDB()
  if type(DarkmoonTicketHelperDB) ~= "table" then
    DarkmoonTicketHelperDB = {}
  end
  local db = DarkmoonTicketHelperDB
  db.overrides = db.overrides or {} -- [itemId] = copper
  db.target = db.target or ns.DEFAULT_TARGET
  db.hideUnavailable = db.hideUnavailable ~= false
  db.minimiseUnpriced = db.minimiseUnpriced ~= false
  db.tab = db.tab or "turnins"
  return db
end

ns.EnsureDB = ensureDB

function ns.HasAuctionator()
  return Auctionator
    and Auctionator.API
    and Auctionator.API.v1
    and Auctionator.API.v1.GetAuctionPriceByItemID
end

--- @return number|nil price in copper
--- @return string source "override"|"auctionator"|"none"
function ns.GetUnitPrice(itemId)
  ensureDB()
  local override = DarkmoonTicketHelperDB.overrides[itemId]
  if type(override) == "number" and override >= 0 then
    return override, "override"
  end
  if ns.HasAuctionator() then
    local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, ns.CALLER_ID, itemId)
    if ok and type(price) == "number" and price > 0 then
      return price, "auctionator"
    end
  end
  return nil, "none"
end

function ns.SetOverride(itemId, copper)
  ensureDB()
  if copper == nil then
    DarkmoonTicketHelperDB.overrides[itemId] = nil
  else
    DarkmoonTicketHelperDB.overrides[itemId] = math.max(0, math.floor(copper + 0.5))
  end
end

function ns.ClearOverrides()
  ensureDB()
  wipe(DarkmoonTicketHelperDB.overrides)
end

--- Parse "1g 23s 4c", "1.23", "1g23s", "123s", or copper integer string.
function ns.ParseMoney(text)
  if text == nil then
    return nil
  end
  text = tostring(text):gsub(",", ""):match("^%s*(.-)%s*$") or ""
  if text == "" then
    return nil
  end

  local g = tonumber(text:match("(%d+)%s*[gG]")) or 0
  local s = tonumber(text:match("(%d+)%s*[sS]")) or 0
  local c = tonumber(text:match("(%d+)%s*[cC]")) or 0
  if text:find("[gGsScC]") then
    return g * 10000 + s * 100 + c
  end

  local decimal = tonumber(text)
  if decimal then
    -- Treat plain numbers as gold (including fractional gold).
    return math.floor(decimal * 10000 + 0.5)
  end
  return nil
end

function ns.FormatMoney(copper)
  if copper == nil then
    return "—"
  end
  copper = math.floor(copper + 0.5)
  if GetMoneyString then
    return GetMoneyString(copper, true)
  end
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  if g > 0 then
    return string.format("%dg %ds %dc", g, s, c)
  elseif s > 0 then
    return string.format("%ds %dc", s, c)
  end
  return string.format("%dc", c)
end

function ns.FormatMoneyEdit(copper)
  if copper == nil then
    return ""
  end
  local g = copper / 10000
  if copper % 100 == 0 and copper % 10000 == 0 then
    return tostring(math.floor(g))
  end
  -- Keep two decimals of gold for easy typing.
  return string.format("%.2f", g)
end

function ns.GetItemName(itemId)
  if C_Item and C_Item.GetItemNameByID then
    local name = C_Item.GetItemNameByID(itemId)
    if name then
      return name
    end
  end
  local name = GetItemInfo and GetItemInfo(itemId)
  return name
end

--- Shift-click helper: exact Auctionator search (AH must be open), else insert item link.
function ns.SearchAuctionHouse(itemId)
  if not itemId then
    return
  end
  if C_Item and C_Item.RequestLoadItemDataByID then
    C_Item.RequestLoadItemDataByID(itemId)
  end

  local name = ns.GetItemName(itemId) or ns.REAGENT_NAMES[itemId]
  if not name then
    for _, turnin in ipairs(ns.TURNINS) do
      if turnin.itemId == itemId then
        name = turnin.name
        break
      end
    end
  end
  if not name and ns.REWARDS then
    for _, reward in ipairs(ns.REWARDS) do
      if reward.itemId == itemId then
        name = reward.name
        break
      end
    end
  end
  if not name then
    print("|cff00ccffDMTH|r Item name not loaded yet — try shift-click again.")
    return
  end

  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if api then
    local terms = { name }
    if api.MultiSearchExact then
      local ok, err = pcall(api.MultiSearchExact, ns.CALLER_ID, terms)
      if ok then
        return
      end
      print("|cff00ccffDMTH|r Auctionator search failed — is the AH open? (" .. tostring(err) .. ")")
      return
    end
    if api.MultiSearch then
      local ok, err = pcall(api.MultiSearch, ns.CALLER_ID, terms)
      if ok then
        return
      end
      print("|cff00ccffDMTH|r Auctionator search failed — is the AH open? (" .. tostring(err) .. ")")
      return
    end
  end

  local link
  if GetItemInfo then
    link = select(2, GetItemInfo(itemId))
  end
  if link and ChatEdit_InsertLink and ChatEdit_InsertLink(link) then
    return
  end
  print("|cff00ccffDMTH|r Open the Auction House (Auctionator) to search for: " .. name)
end
