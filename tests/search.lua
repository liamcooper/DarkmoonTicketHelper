local ns = {}
assert(loadfile('Data.lua'))('test', ns)
assert(loadfile('Recipes.lua'))('test', ns)
assert(loadfile('Prices.lua'))('test', ns)

local printed = {}
print = function(msg) printed[#printed + 1] = msg end

-- Link construction without GetItemInfo.
assert(ns.GetItemLink(5117, 'Vibrant Plume'):find('%[Vibrant Plume%]'))

-- Auctionator AH closed: MultiSearchExact fails → printable item link fallback.
Auctionator = {API = {v1 = {
  MultiSearchExact = function() error('Auction house is not open') end,
}}}
HandleModifiedItemClick = function() return false end
ChatEdit_InsertLink = function() return false end
printed = {}
ns.SearchAuctionHouse(5117)
assert(#printed == 1 and printed[1]:find('Vibrant Plume') and printed[1]:find('Hitem:5117'))

-- Auctionator AH open: search succeeds and no link spam.
local searched = false
Auctionator.API.v1.MultiSearchExact = function() searched = true end
printed = {}
ns.SearchAuctionHouse(5117)
assert(searched and #printed == 0)

-- No Auctionator: prefer HandleModifiedItemClick.
Auctionator = nil
local handled = false
HandleModifiedItemClick = function(link)
  assert(link:find('Hitem:5117'))
  handled = true
  return true
end
printed = {}
ns.SearchAuctionHouse(5117)
assert(handled and #printed == 0)

print = function(msg) io.write(msg, '\n') end
print('SearchAuctionHouse AH-closed link fallback tests passed')
