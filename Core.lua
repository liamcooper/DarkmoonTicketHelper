local ADDON, ns = ...

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
eventFrame:RegisterEvent("UPDATE_FACTION")
eventFrame:RegisterEvent("BAG_UPDATE")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    ns.EnsureDB()
    if ns.HasAuctionator() and Auctionator.API.v1.RegisterForDBUpdate then
      pcall(Auctionator.API.v1.RegisterForDBUpdate, ns.CALLER_ID, function()
        if ns.frame and ns.frame:IsShown() then
          ns.RefreshUI()
        end
      end)
    end
  elseif event == "PLAYER_LOGIN" then
    print("|cff00ccffDarkmoon Ticket Helper|r loaded. Type |cffffff00/dmth|r for cheapest ticket turn-ins.")
  elseif ns.frame and ns.frame:IsShown() then
    if event == "CURRENCY_DISPLAY_UPDATE" and arg1 and arg1 ~= ns.CURRENCY_TICKET then
      return
    end
    ns.RefreshUI()
  end
end)

SLASH_DMTH1 = "/dmth"
SLASH_DMTH2 = "/dmftickets"
SLASH_DMTH3 = "/darkmoontickets"
SlashCmdList.DMTH = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "prices" then
    ns.CreateUI()
    ns.ShowPriceEditor()
  elseif msg == "refresh" then
    if ns.frame then
      ns.RefreshUI()
    end
  elseif msg:match("^target") then
    local n = tonumber(msg:match("target%s+(%d+)"))
    if n then
      ns.EnsureDB()
      DarkmoonTicketHelperDB.target = n
      print("|cff00ccffDMTH|r target set to " .. n)
      if ns.frame and ns.frame:IsShown() then
        ns.RefreshUI()
      end
    else
      print("|cff00ccffDMTH|r usage: /dmth target 50")
    end
  else
    ns.ToggleUI()
  end
end
