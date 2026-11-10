local ns = {}
assert(loadfile('Data.lua'))('test', ns)
assert(loadfile('Prices.lua'))('test', ns)
assert(loadfile('Recipes.lua'))('test', ns)
assert(loadfile('Shopping.lua'))('test', ns)
local bags = {[2838] = 4}
C_Item = {GetItemCount = function(id) return bags[id] or 0 end}
local function step(id, qty, source)
  return {row = {turnin = {itemId = id}, source = source}, buy = qty}
end
local items, vendor = ns.BuildShoppingItems({steps = {step(3486, 3, 'craft'), step(5117, 5, 'buy')}})
assert(items[2838] == 5 and items[5117] == 5)
-- Shared owned stock is deducted once across different recipes.
ns.RECIPES[1] = {reagents = {{2838, 3}}, yield = 1}
ns.RECIPES[2] = {reagents = {{2838, 3}}, yield = 1}
items = ns.BuildShoppingItems({steps = {step(1, 1, 'craft'), step(2, 1, 'craft')}})
assert(items[2838] == 2)
-- Yield rounding and vendor supplies.
items, vendor = ns.BuildShoppingItems({steps = {step(9313, 4, 'craft'), step(2309, 1, 'craft')}})
assert(items[4377] == 2 and items[4234] == 2 and vendor[2320] == 5)
ns.GetTicketCount = function() return 0 end
ns.BuildRanking = function() return {} end
ns.BuildExactPlan = function() return {steps = {step(5117, 5, 'buy')}} end
ns.GetItemName = function(id) return id == 5117 and 'Vibrant Plume' end
local calls = 0
Auctionator = {API = {v1 = {
  ConvertToSearchString = function(caller, term)
    assert(caller == ns.CALLER_ID and term.isExact and term.quantity == 5 and term.searchString == 'Vibrant Plume')
    return 'quantity-search'
  end,
  CreateShoppingList = function(caller, name, terms)
    assert(caller == ns.CALLER_ID and name == ns.CALLER_ID and #terms == 1 and terms[1] == 'quantity-search')
    calls = calls + 1
  end,
}}}
ns.CreateAuctionatorList()
assert(calls == 1)
print('Shopping list inventory, recipes, quantities and API contract tests passed')
