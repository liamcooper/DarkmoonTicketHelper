local ADDON, ns = ...

local function isHuman()
  local _, raceFile = UnitRace("player")
  return raceFile == "Human"
end

function ns.GetRepPerTurnIn()
  local base = ns.REP_PER_TURNIN
  if isHuman() then
    return math.floor(base * 1.1 + 0.5)
  end
  return base
end

--- Returns standingID (4 Neutral / 5 Friendly / …) and value within that standing.
function ns.GetDMFReputation()
  local standingID, valueInStanding, standingName = 4, 0, "Neutral"

  if C_Reputation and C_Reputation.GetFactionDataByID then
    local data = C_Reputation.GetFactionDataByID(ns.FACTION_DMF)
    if data then
      standingID = data.reaction or standingID
      standingName = _G["FACTION_STANDING_LABEL" .. standingID] or standingName
      local cur = data.currentStanding or 0
      local thr = data.currentReactionThreshold or 0
      valueInStanding = math.max(0, cur - thr)
      return standingID, valueInStanding, standingName, data.name
    end
  end

  if GetFactionInfoByID then
    local name, _, standing, barMin, barMax, barValue = GetFactionInfoByID(ns.FACTION_DMF)
    if standing then
      standingID = standing
      standingName = _G["FACTION_STANDING_LABEL" .. standingID] or standingName
      -- Classic-style: barValue is absolute; value in standing is barValue - barMin.
      if barValue and barMin then
        valueInStanding = math.max(0, barValue - barMin)
      elseif barValue then
        valueInStanding = barValue
      end
      return standingID, valueInStanding, standingName, name
    end
  end

  return standingID, valueInStanding, standingName, "Darkmoon Faire"
end

function ns.GetTicketCount()
  if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
    local info = C_CurrencyInfo.GetCurrencyInfo(ns.CURRENCY_TICKET)
    if info and info.quantity then
      return info.quantity
    end
  end
  return 0
end

--- Tier still offerable for this character's level + DMF rep.
function ns.IsTierAvailable(tier, level, standingID, valueInStanding)
  local info = ns.TIERS[tier]
  if not info then
    return false
  end
  if level < info.minLevel then
    return false, "level"
  end
  if standingID > info.cutoffStanding then
    return false, "rep"
  end
  if standingID == info.cutoffStanding and valueInStanding >= info.cutoffValue then
    return false, "rep"
  end
  return true
end

--- Remaining turn-ins before this tier's cutoff, given current rep.
--- Uses floor division; humans hit the wall sooner.
function ns.RemainingTurnInsForTier(tier, standingID, valueInStanding)
  local info = ns.TIERS[tier]
  if not info then
    return 0
  end
  if standingID > info.cutoffStanding then
    return 0
  end
  if standingID < info.cutoffStanding then
    -- Still below the standing that hosts the cutoff (e.g. still Neutral for a Friendly cutoff).
    -- Approximate headroom through the rest of Neutral + into Friendly cutoff.
    if info.cutoffStanding == 5 and standingID == 4 then
      local neutralLeft = math.max(0, 3000 - valueInStanding)
      local friendlyRoom = info.cutoffValue
      local room = neutralLeft + friendlyRoom
      return math.floor(room / ns.GetRepPerTurnIn())
    end
    return math.huge
  end
  local room = math.max(0, info.cutoffValue - valueInStanding)
  return math.floor(room / ns.GetRepPerTurnIn())
end

function ns.BuildRanking()
  ns.EnsureDB()
  local level = UnitLevel("player") or 1
  local standingID, valueInStanding = ns.GetDMFReputation()
  local hideUnavailable = DarkmoonTicketHelperDB.hideUnavailable
  local rows = {}

  for _, turnin in ipairs(ns.TURNINS) do
    local available, reason = ns.IsTierAvailable(turnin.tier, level, standingID, valueInStanding)
    if available or not hideUnavailable then
      local unitPrice, source, buyPrice, craftPrice = ns.GetEffectiveUnitPrice(turnin.itemId)
      local tierInfo = ns.TIERS[turnin.tier]
      local turnInCost = unitPrice and (unitPrice * turnin.qty) or nil
      local costPerTicket = turnInCost and (turnInCost / tierInfo.tickets) or nil
      local bag = 0
      if C_Item and C_Item.GetItemCount then
        bag = C_Item.GetItemCount(turnin.itemId, true, false, true) or 0
      elseif GetItemCount then
        bag = GetItemCount(turnin.itemId, true) or 0
      end
      local remaining = ns.RemainingTurnInsForTier(turnin.tier, standingID, valueInStanding)

      rows[#rows + 1] = {
        turnin = turnin,
        available = available,
        unavailableReason = reason,
        unitPrice = unitPrice,
        source = source,
        buyPrice = buyPrice,
        craftPrice = craftPrice,
        craftable = ns.IsCraftable(turnin.itemId),
        turnInCost = turnInCost,
        costPerTicket = costPerTicket,
        tickets = tierInfo.tickets,
        bag = bag,
        remaining = remaining,
        readyTurnIns = math.floor(bag / turnin.qty),
      }
    end
  end

  table.sort(rows, function(a, b)
    -- Available first, then priced cheapest cost/ticket, then name.
    if a.available ~= b.available then
      return a.available
    end
    local ac, bc = a.costPerTicket, b.costPerTicket
    if ac == nil and bc == nil then
      if a.turnin.tier ~= b.turnin.tier then
        return a.turnin.tier < b.turnin.tier
      end
      return a.turnin.name < b.turnin.name
    end
    if ac == nil then
      return false
    end
    if bc == nil then
      return true
    end
    if ac ~= bc then
      return ac < bc
    end
    return a.turnin.name < b.turnin.name
  end)

  return rows
end

function ns.BestAvailable(rows)
  for _, row in ipairs(rows) do
    if row.available and row.costPerTicket then
      return row
    end
  end
  for _, row in ipairs(rows) do
    if row.available then
      return row
    end
  end
  return nil
end
