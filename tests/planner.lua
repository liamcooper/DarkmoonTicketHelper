local ns = {}
assert(loadfile('Data.lua'))('test', ns)
UnitRace = function() return 'Human', 'Human' end
assert(loadfile('Rank.lua'))('test', ns)
local function row(key, tier, tickets, qty, price, bag, remaining)
  return { turnin = { key = key, tier = tier, qty = qty }, tickets = tickets,
    unitPrice = price, bag = bag or 0, remaining = remaining or 80,
    readyTurnIns = math.floor((bag or 0) / qty), available = true }
end
local rows = {row('a', 1, 1, 5, 10), row('b', 2, 4, 5, 10), row('c', 4, 12, 1, 1)}
local plan = assert(ns.BuildExactPlan(rows, 50))
assert(plan.tickets == 50 and plan.cost == 104 and plan.byKey.c.count == 4)
assert(not ns.BuildExactPlan({rows[3]}, 50))
assert(ns.BuildExactPlan(rows, 0).cost == 0)
-- Partial stacks reduce only the missing items; owned unpriced stock is usable.
plan = assert(ns.BuildExactPlan({row('a', 1, 1, 5, 10, 7)}, 2))
assert(plan.cost == 30 and plan.steps[1].buy == 3)
assert(ns.BuildExactPlan({row('a', 1, 1, 5, nil, 10)}, 2).cost == 0)
assert(not ns.BuildExactPlan({row('a', 1, 1, 5, nil, 9)}, 2))
-- Shared reputation: individually affordable rows cannot each use full headroom.
assert(not ns.BuildExactPlan({row('a', 1, 1, 1, 1, 0, 1), row('b', 1, 1, 1, 1, 0, 1)}, 2))
assert(not ns.BuildExactPlan({row('a', 1, 1, 1, 1, 0, 1), row('b', 2, 4, 1, 1, 0, 1)}, 5))
assert(ns.BuildExactPlan({row('a', 1, 1, 1, 1, 0, 1), row('b', 2, 4, 1, 1, 0, 2)}, 5))
assert(ns.RemainingTurnInsForTier(1, 4, 499) == 1)
assert(ns.RemainingTurnInsForTier(1, 4, 500) == 0)
-- Compare the planner against exhaustive choices on small varied inventories.
math.randomseed(42)
for trial = 1, 200 do
  local sample = {}
  for i = 1, 3 do sample[i] = row(tostring(i), i, i == 1 and 1 or i * 2, 3, math.random(0, 12), math.random(0, 8), i + 2) end
  local need = math.random(1, 30)
  local cheapest
  for a = 0, 3 do for b = 0, 4 - a do for c = 0, 5 - a - b do
    if a + b * 4 + c * 6 == need then
      local cost = 0
      for i, n in ipairs({a, b, c}) do cost = cost + math.max(0, n * 3 - sample[i].bag) * sample[i].unitPrice end
      if not cheapest or cost < cheapest then cheapest = cost end
    end
  end end end
  local result = ns.BuildExactPlan(sample, need)
  assert((result and result.cost) == cheapest, 'exhaustive comparison failed')
end
print('Planner regression tests and 200 exhaustive comparisons passed')

C_CurrencyInfo = { GetCurrencyInfo = function() return { quantity = 0 } end }
GetItemCount = function(id) assert(id == 19182); return 13 end
assert(ns.GetTicketCount() == 13)
C_CurrencyInfo.GetCurrencyInfo = function() return { quantity = 21 } end
assert(ns.GetTicketCount() == 21)
