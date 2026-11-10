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
    if info and info.quantity and info.quantity > 0 then
      return info.quantity
    end
  end
  -- Classic stores Prize Tickets as items rather than currency.
  if C_Item and C_Item.GetItemCount then
    return C_Item.GetItemCount(19182, false) or 0
  elseif GetItemCount then
    return GetItemCount(19182, false) or 0
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
--- A turn-in is allowed while below the cutoff, even if its rep crosses it.
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
      return math.ceil(room / ns.GetRepPerTurnIn())
    end
    return math.huge
  end
  local room = math.max(0, info.cutoffValue - valueInStanding)
  return math.ceil(room / ns.GetRepPerTurnIn())
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


-- Process tiers in ascending order so low-rep quests are completed first.
-- State includes total turn-ins because all tiers share reputation headroom.
-- Each item is processed once: its owned stock is deducted once, including
-- partial stacks. Unknown prices allow only fully owned turn-ins.
function ns.BuildExactPlan(rows, need)
  need = math.max(0, math.floor(need))
  local candidates, capacity = {}, 0
  for _, row in ipairs(rows) do
    if row.available then
      candidates[#candidates + 1] = row
      capacity = math.max(capacity, row.remaining * row.tickets)
    end
  end
  if need > capacity then return nil end
  table.sort(candidates, function(a, b)
    if a.turnin.tier ~= b.turnin.tier then return a.turnin.tier < b.turnin.tier end
    return a.turnin.key < b.turnin.key
  end)
  local states = { [0] = { [0] = { cost = 0 } } }
  for _, row in ipairs(candidates) do
    local nextStates = {}
    for tickets, counts in pairs(states) do
      nextStates[tickets] = {}
      for count, state in pairs(counts) do nextStates[tickets][count] = state end
    end
    for tickets, counts in pairs(states) do
      for count, state in pairs(counts) do
        local limit = math.min(math.floor((need - tickets) / row.tickets), row.remaining - count)
        if not row.unitPrice then limit = math.min(limit, row.readyTurnIns) end
        for n = 1, limit do
          local buy = math.max(0, n * row.turnin.qty - row.bag)
          local cost = state.cost + buy * (row.unitPrice or 0)
          local total, turns = tickets + n * row.tickets, count + n
          nextStates[total] = nextStates[total] or {}
          local old = nextStates[total][turns]
          if not old or cost < old.cost then
            nextStates[total][turns] = { cost = cost, previous = state, row = row, count = n, buy = buy }
          end
        end
      end
    end
    states = nextStates
  end
  local best, bestCount
  for count, state in pairs(states[need] or {}) do
    if not best or state.cost < best.cost or (state.cost == best.cost and count < bestCount) then
      best, bestCount = state, count
    end
  end
  if not best then return nil end
  local plan = { cost = best.cost, tickets = need, turnIns = bestCount, steps = {}, byKey = {} }
  while best.row do
    local step = { row = best.row, count = best.count, buy = best.buy }
    table.insert(plan.steps, 1, step)
    plan.byKey[best.row.turnin.key] = step
    best = best.previous
  end
  return plan
end
