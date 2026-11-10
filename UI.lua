local ADDON, ns = ...

local ROW_HEIGHT = 22

local function textureForItem(itemId)
  local tex = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemId)
  if not tex and GetItemIcon then
    tex = GetItemIcon(itemId)
  end
  return tex or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function sourceLabel(source)
  if source == "override" then
    return "manual"
  elseif source == "auctionator" then
    return "AH"
  end
  return "no price"
end

local function makeTabButton(parent, label, x)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetSize(100, 22)
  btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -32)
  btn:SetText(label)
  return btn
end

local function setTabActive(f, tab)
  ns.EnsureDB()
  DarkmoonTicketHelperDB.tab = tab
  f.activeTab = tab
  if tab == "rewards" then
    f.turninPanel:Hide()
    f.rewardPanel:Show()
    f.tabTurnins:Enable()
    f.tabRewards:Disable()
  else
    f.rewardPanel:Hide()
    f.turninPanel:Show()
    f.tabRewards:Enable()
    f.tabTurnins:Disable()
  end
end

function ns.CreateUI()
  if ns.frame then
    return ns.frame
  end

  local f = CreateFrame("Frame", "DarkmoonTicketHelperFrame", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(680, 500)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    ns.EnsureDB()
    local point, _, relativePoint, x, y = self:GetPoint(1)
    DarkmoonTicketHelperDB.point = { point, relativePoint, x, y }
  end)
  f:Hide()
  tinsert(UISpecialFrames, f:GetName())
  f.TitleText:SetText("Darkmoon Ticket Helper")

  f.tabTurnins = makeTabButton(f, "Turn-ins", 14)
  f.tabRewards = makeTabButton(f, "Rewards", 120)
  f.tabTurnins:SetScript("OnClick", function()
    setTabActive(f, "turnins")
    ns.RefreshUI()
  end)
  f.tabRewards:SetScript("OnClick", function()
    setTabActive(f, "rewards")
    ns.RefreshUI()
  end)

  local summary = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  summary:SetPoint("TOPLEFT", 14, -58)
  summary:SetPoint("TOPRIGHT", -14, -58)
  summary:SetJustifyH("LEFT")
  f.summary = summary

  local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  hint:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -4)
  hint:SetPoint("TOPRIGHT", summary, "BOTTOMRIGHT", 0, -4)
  hint:SetJustifyH("LEFT")
  hint:SetTextColor(0.75, 0.75, 0.75)
  f.hint = hint

  -- Shared panels under the summary
  local turninPanel = CreateFrame("Frame", nil, f)
  turninPanel:SetPoint("TOPLEFT", 8, -95)
  turninPanel:SetPoint("BOTTOMRIGHT", -8, 8)
  f.turninPanel = turninPanel

  local rewardPanel = CreateFrame("Frame", nil, f)
  rewardPanel:SetPoint("TOPLEFT", 8, -95)
  rewardPanel:SetPoint("BOTTOMRIGHT", -8, 8)
  rewardPanel:Hide()
  f.rewardPanel = rewardPanel

  -- ===== Turn-ins panel =====
  local targetLabel = turninPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  targetLabel:SetPoint("TOPLEFT", 6, -2)
  targetLabel:SetText("Target tickets")

  local targetBox = CreateFrame("EditBox", nil, turninPanel, "InputBoxTemplate")
  targetBox:SetSize(70, 20)
  targetBox:SetPoint("LEFT", targetLabel, "RIGHT", 8, 0)
  targetBox:SetAutoFocus(false)
  targetBox:SetNumeric(true)
  targetBox:SetMaxLetters(5)
  targetBox:SetScript("OnEnterPressed", function(self)
    ns.EnsureDB()
    local v = tonumber(self:GetText()) or ns.DEFAULT_TARGET
    DarkmoonTicketHelperDB.target = math.max(0, math.floor(v))
    self:ClearFocus()
    ns.RefreshUI()
  end)
  targetBox:SetScript("OnEditFocusLost", function(self)
    ns.EnsureDB()
    local v = tonumber(self:GetText()) or DarkmoonTicketHelperDB.target
    DarkmoonTicketHelperDB.target = math.max(0, math.floor(v or ns.DEFAULT_TARGET))
    ns.RefreshUI()
  end)
  f.targetBox = targetBox

  local refreshBtn = CreateFrame("Button", nil, turninPanel, "UIPanelButtonTemplate")
  refreshBtn:SetSize(80, 22)
  refreshBtn:SetPoint("LEFT", targetBox, "RIGHT", 10, 0)
  refreshBtn:SetText("Refresh")
  refreshBtn:SetScript("OnClick", function()
    ns.RefreshUI()
  end)

  local pricesBtn = CreateFrame("Button", nil, turninPanel, "UIPanelButtonTemplate")
  pricesBtn:SetSize(100, 22)
  pricesBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 6, 0)
  pricesBtn:SetText("Edit prices")
  pricesBtn:SetScript("OnClick", function()
    if ns.priceFrame and ns.priceFrame:IsShown() then
      ns.priceFrame:Hide()
    else
      ns.ShowPriceEditor()
    end
  end)

  local hideCheck = CreateFrame("CheckButton", nil, turninPanel, "UICheckButtonTemplate")
  hideCheck:SetPoint("LEFT", pricesBtn, "RIGHT", 8, 0)
  hideCheck:SetSize(24, 24)
  local hideLabel = hideCheck.Text or hideCheck.text
  if hideLabel then
    hideLabel:SetText("Hide unavailable")
  else
    local fs = hideCheck:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fs:SetPoint("LEFT", hideCheck, "RIGHT", 2, 0)
    fs:SetText("Hide unavailable")
  end
  hideCheck:SetScript("OnClick", function(self)
    ns.EnsureDB()
    DarkmoonTicketHelperDB.hideUnavailable = self:GetChecked()
    ns.RefreshUI()
  end)
  f.hideCheck = hideCheck

  local turninHeaders = {
    { text = "Turn-in", x = 34, w = 200 },
    { text = "Tier", x = 244, w = 40 },
    { text = "Tickets", x = 289, w = 50 },
    { text = "Cost / ticket", x = 349, w = 100 },
    { text = "Bags", x = 459, w = 50 },
    { text = "Source", x = 514, w = 70 },
  }
  for _, h in ipairs(turninHeaders) do
    local fs = turninPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", h.x, -28)
    fs:SetWidth(h.w)
    fs:SetJustifyH("LEFT")
    fs:SetText(h.text)
  end

  local scroll = CreateFrame("ScrollFrame", "DarkmoonTicketHelperScroll", turninPanel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 4, -46)
  scroll:SetPoint("BOTTOMRIGHT", -26, 4)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(620, ROW_HEIGHT * #ns.TURNINS)
  scroll:SetScrollChild(content)
  f.scroll = scroll
  f.content = content
  f.rows = {}

  for i = 1, #ns.TURNINS do
    local row = CreateFrame("Button", nil, content)
    row:SetSize(620, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 4, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetWidth(200)
    row.name:SetJustifyH("LEFT")

    row.tier = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.tier:SetPoint("LEFT", 232, 0)
    row.tier:SetWidth(40)

    row.tickets = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.tickets:SetPoint("LEFT", 277, 0)
    row.tickets:SetWidth(50)

    row.cost = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.cost:SetPoint("LEFT", 337, 0)
    row.cost:SetWidth(110)

    row.bags = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.bags:SetPoint("LEFT", 447, 0)
    row.bags:SetWidth(50)

    row.src = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.src:SetPoint("LEFT", 502, 0)
    row.src:SetWidth(70)

    row:SetScript("OnEnter", function(self)
      if not self.itemId then
        return
      end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetItemByID(self.itemId)
      local t = self.turnin
      if t then
        local npc = ns.NPCS[t.category]
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(ns.CATEGORY_LABEL[t.category] .. " → " .. (npc and npc.name or "?"), 0.4, 0.8, 1)
        GameTooltip:AddLine(string.format("Turn in %dx for %d tickets", t.qty, ns.TIERS[t.tier].tickets), 1, 1, 1)
        local tier = ns.TIERS[t.tier]
        GameTooltip:AddLine(string.format(
          "Available until %s %d (min level %d)",
          tier.cutoffStanding == 4 and "Neutral" or "Friendly",
          tier.cutoffValue,
          tier.minLevel
        ), 1, 0.82, 0)
        if self.remaining and self.remaining ~= math.huge then
          GameTooltip:AddLine(string.format("≈ %d turn-ins left before this tier cuts off", self.remaining), 1, 0.82, 0)
        end
        GameTooltip:AddLine("Right-click to edit unit price", 0.6, 0.6, 0.6)
      end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(self, button)
      if button == "RightButton" and self.itemId then
        ns.PromptPrice(self.itemId, self.turnin and self.turnin.name)
      end
    end)

    f.rows[i] = row
  end

  -- ===== Rewards panel =====
  local rewardNote = rewardPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  rewardNote:SetPoint("TOPLEFT", 6, -2)
  rewardNote:SetPoint("TOPRIGHT", -6, -2)
  rewardNote:SetJustifyH("LEFT")
  rewardNote:SetTextColor(0.75, 0.75, 0.75)
  rewardNote:SetText("Gelvas Grimegate — prizes need tickets + level only. DMF reputation is not required.")
  f.rewardNote = rewardNote

  local rewardHeaders = {
    { text = "Reward", x = 34, w = 210 },
    { text = "Tickets", x = 250, w = 55 },
    { text = "Level", x = 310, w = 45 },
    { text = "Rep req", x = 360, w = 70 },
    { text = "Have / need", x = 440, w = 90 },
    { text = "Status", x = 540, w = 110 },
  }
  for _, h in ipairs(rewardHeaders) do
    local fs = rewardPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", h.x, -22)
    fs:SetWidth(h.w)
    fs:SetJustifyH("LEFT")
    fs:SetText(h.text)
  end

  local rscroll = CreateFrame("ScrollFrame", "DarkmoonTicketHelperRewardScroll", rewardPanel, "UIPanelScrollFrameTemplate")
  rscroll:SetPoint("TOPLEFT", 4, -40)
  rscroll:SetPoint("BOTTOMRIGHT", -26, 4)

  local rcontent = CreateFrame("Frame", nil, rscroll)
  rcontent:SetSize(620, ROW_HEIGHT * #ns.REWARDS)
  rscroll:SetScrollChild(rcontent)
  f.rewardScroll = rscroll
  f.rewardContent = rcontent
  f.rewardRows = {}

  for i = 1, #ns.REWARDS do
    local row = CreateFrame("Button", nil, rcontent)
    row:SetSize(620, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 4, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetWidth(210)
    row.name:SetJustifyH("LEFT")

    row.tickets = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.tickets:SetPoint("LEFT", 238, 0)
    row.tickets:SetWidth(55)

    row.level = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.level:SetPoint("LEFT", 298, 0)
    row.level:SetWidth(45)

    row.rep = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.rep:SetPoint("LEFT", 348, 0)
    row.rep:SetWidth(70)

    row.progress = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.progress:SetPoint("LEFT", 428, 0)
    row.progress:SetWidth(90)

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("LEFT", 528, 0)
    row.status:SetWidth(110)

    row:SetScript("OnEnter", function(self)
      if not self.reward then
        return
      end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if self.reward.itemId then
        GameTooltip:SetItemByID(self.reward.itemId)
      else
        GameTooltip:SetText(self.reward.name)
      end
      GameTooltip:AddLine(" ")
      local v = ns.REWARD_VENDOR
      GameTooltip:AddLine("Vendor: " .. v.name, 0.4, 0.8, 1)
      GameTooltip:AddLine(string.format("Elwynn %s  ·  Mulgore %s", v.elwynn, v.mulgore), 0.7, 0.7, 0.7)
      GameTooltip:AddLine(string.format("Cost: %d Darkmoon Prize Tickets", self.reward.tickets), 1, 1, 1)
      GameTooltip:AddLine(string.format("Requires level %d", self.reward.minLevel), 1, 1, 1)
      GameTooltip:AddLine("Darkmoon Faire reputation: none", 0.2, 1, 0.2)
      if self.reward.unique then
        GameTooltip:AddLine("Unique — one per character", 1, 0.82, 0)
      end
      if self.reward.note then
        GameTooltip:AddLine(self.reward.note, 0.8, 0.8, 0.8, true)
      end
      if self.shortfall and self.shortfall > 0 then
        GameTooltip:AddLine(string.format("Need %d more tickets", self.shortfall), 1, 0.4, 0.4)
      end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(self)
      if self.reward then
        ns.EnsureDB()
        DarkmoonTicketHelperDB.target = self.reward.tickets
        setTabActive(f, "turnins")
        ns.RefreshUI()
      end
    end)

    f.rewardRows[i] = row
  end

  ns.frame = f
  ns.EnsureDB()
  if DarkmoonTicketHelperDB.point then
    local p = DarkmoonTicketHelperDB.point
    f:ClearAllPoints()
    f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  end
  setTabActive(f, DarkmoonTicketHelperDB.tab or "turnins")
  return f
end

function ns.PromptPrice(itemId, name)
  StaticPopupDialogs["DMTH_SET_PRICE"] = {
    text = "Unit price for %s\n(gold, e.g. 1.25 or 1g 25s)\nLeave blank to clear override.",
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnShow = function(dialog)
      local box = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
      local price = select(1, ns.GetUnitPrice(itemId))
      if box then
        box:SetText(ns.FormatMoneyEdit(price))
        box:HighlightText()
      end
    end,
    OnAccept = function(dialog)
      local box = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
      local text = box and box:GetText() or ""
      text = text:match("^%s*(.-)%s*$") or ""
      if text == "" then
        ns.SetOverride(itemId, nil)
      else
        local copper = ns.ParseMoney(text)
        if copper then
          ns.SetOverride(itemId, copper)
        end
      end
      ns.RefreshUI()
      if ns.priceFrame and ns.priceFrame:IsShown() then
        ns.ShowPriceEditor()
      end
    end,
  }
  StaticPopup_Show("DMTH_SET_PRICE", name or ("item " .. itemId))
end

function ns.ShowPriceEditor()
  if not ns.priceFrame then
    local pf = CreateFrame("Frame", "DarkmoonTicketHelperPrices", UIParent, "BasicFrameTemplateWithInset")
    pf:SetSize(420, 520)
    pf:SetPoint("LEFT", ns.frame or UIParent, "RIGHT", 10, 0)
    pf:SetMovable(true)
    pf:EnableMouse(true)
    pf:RegisterForDrag("LeftButton")
    pf:SetScript("OnDragStart", pf.StartMoving)
    pf:SetScript("OnDragStop", pf.StopMovingOrSizing)
    pf.TitleText:SetText("Manual price overrides")
    tinsert(UISpecialFrames, pf:GetName())

    local clear = CreateFrame("Button", nil, pf, "UIPanelButtonTemplate")
    clear:SetSize(120, 22)
    clear:SetPoint("TOPLEFT", 14, -32)
    clear:SetText("Clear overrides")
    clear:SetScript("OnClick", function()
      ns.ClearOverrides()
      ns.ShowPriceEditor()
      ns.RefreshUI()
    end)

    local note = pf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    note:SetPoint("LEFT", clear, "RIGHT", 10, 0)
    note:SetText("Blank = use Auctionator / none")

    local scroll = CreateFrame("ScrollFrame", nil, pf, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -60)
    scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(360, 28 * #ns.TURNINS)
    scroll:SetScrollChild(content)
    pf.content = content
    pf.editors = {}

    for i, turnin in ipairs(ns.TURNINS) do
      local row = CreateFrame("Frame", nil, content)
      row:SetSize(360, 26)
      row:SetPoint("TOPLEFT", 0, -(i - 1) * 28)

      local icon = row:CreateTexture(nil, "ARTWORK")
      icon:SetSize(18, 18)
      icon:SetPoint("LEFT", 2, 0)
      icon:SetTexture(textureForItem(turnin.itemId))

      local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
      label:SetWidth(200)
      label:SetJustifyH("LEFT")
      label:SetText(turnin.name)

      local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
      box:SetSize(90, 20)
      box:SetPoint("RIGHT", -4, 0)
      box:SetAutoFocus(false)
      box.itemId = turnin.itemId
      box:SetScript("OnEnterPressed", function(self)
        local text = self:GetText():match("^%s*(.-)%s*$") or ""
        if text == "" then
          ns.SetOverride(self.itemId, nil)
        else
          local copper = ns.ParseMoney(text)
          if copper then
            ns.SetOverride(self.itemId, copper)
          end
        end
        self:ClearFocus()
        ns.RefreshUI()
      end)
      pf.editors[i] = box
    end

    ns.priceFrame = pf
  end

  ns.EnsureDB()
  for i, turnin in ipairs(ns.TURNINS) do
    local box = ns.priceFrame.editors[i]
    local override = DarkmoonTicketHelperDB.overrides[turnin.itemId]
    if override then
      box:SetText(ns.FormatMoneyEdit(override))
    else
      local ah = nil
      if ns.HasAuctionator() then
        local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, ns.CALLER_ID, turnin.itemId)
        if ok then
          ah = price
        end
      end
      box:SetText(ah and ns.FormatMoneyEdit(ah) or "")
    end
  end
  ns.priceFrame:Show()
  ns.priceFrame:Raise()
end

local function refreshTurnins(f, tickets, target, need, standingName, valueInStanding, factionName, level, ah)
  f.targetBox:SetText(tostring(target))
  f.hideCheck:SetChecked(DarkmoonTicketHelperDB.hideUnavailable ~= false)

  f.summary:SetText(string.format(
    "%s  |  Tickets %d → target %d (need %d)  |  Level %d  |  %s %d  |  %s",
    factionName or "Darkmoon Faire",
    tickets,
    target,
    need,
    level,
    standingName,
    valueInStanding,
    ah
  ))

  local rows = ns.BuildRanking()
  local best = ns.BestAvailable(rows)
  if best and best.costPerTicket and need > 0 then
    local turnIns = math.ceil(need / best.tickets)
    local totalCost = best.turnInCost * turnIns
    local itemsNeeded = best.turnin.qty * turnIns
    f.hint:SetText(string.format(
      "Cheapest now: %s — %s / ticket. ≈ %d turn-ins (%d× %s) ≈ %s",
      best.turnin.name,
      ns.FormatMoney(best.costPerTicket),
      turnIns,
      itemsNeeded,
      best.turnin.name,
      ns.FormatMoney(totalCost)
    ))
  elseif best and not best.costPerTicket then
    f.hint:SetText("Cheapest available turn-in has no price yet — scan AH or right-click a row to set one.")
  elseif need <= 0 then
    f.hint:SetText("Target reached. Turn-ins still ranked below if you want more tickets.")
  else
    f.hint:SetText("No turn-ins available at this level / reputation. Lower tiers vanish as DMF rep rises — finish them first.")
  end

  for i, rowFrame in ipairs(f.rows) do
    local data = rows[i]
    if data then
      local t = data.turnin
      rowFrame:Show()
      rowFrame.itemId = t.itemId
      rowFrame.turnin = t
      rowFrame.remaining = data.remaining
      rowFrame.icon:SetTexture(textureForItem(t.itemId))
      rowFrame.name:SetText(string.format("%s ×%d", t.name, t.qty))
      rowFrame.tier:SetText("T" .. t.tier)
      rowFrame.tickets:SetText(tostring(data.tickets))
      rowFrame.cost:SetText(data.costPerTicket and ns.FormatMoney(data.costPerTicket) or "—")
      rowFrame.bags:SetText(string.format("%d (%d)", data.bag, data.readyTurnIns))
      rowFrame.src:SetText(sourceLabel(data.source))

      if not data.available then
        rowFrame.name:SetTextColor(0.5, 0.5, 0.5)
        rowFrame.cost:SetTextColor(0.5, 0.5, 0.5)
      elseif data.source == "none" then
        rowFrame.name:SetTextColor(1, 0.82, 0)
        rowFrame.cost:SetTextColor(1, 0.82, 0)
      elseif best and data.turnin.key == best.turnin.key then
        rowFrame.name:SetTextColor(0.2, 1, 0.2)
        rowFrame.cost:SetTextColor(0.2, 1, 0.2)
      else
        rowFrame.name:SetTextColor(1, 1, 1)
        rowFrame.cost:SetTextColor(1, 1, 1)
      end
    else
      rowFrame:Hide()
      rowFrame.itemId = nil
    end
  end

  f.content:SetHeight(math.max(ROW_HEIGHT, ROW_HEIGHT * #rows))
end

local function refreshRewards(f, tickets, level, standingName, valueInStanding, factionName)
  f.summary:SetText(string.format(
    "%s  |  Tickets %d  |  Level %d  |  %s %d  |  Vendor: %s",
    factionName or "Darkmoon Faire",
    tickets,
    level,
    standingName,
    valueInStanding,
    ns.REWARD_VENDOR.name
  ))
  f.hint:SetText("Click a reward to set it as your turn-in ticket target. Hover for vendor coords and details.")

  for i, row in ipairs(f.rewardRows) do
    local reward = ns.REWARDS[i]
    row:Show()
    row.reward = reward
    row.icon:SetTexture(textureForItem(reward.itemId))
    row.name:SetText(reward.unique and (reward.name .. " (unique)") or reward.name)
    row.tickets:SetText(tostring(reward.tickets))
    row.level:SetText(tostring(reward.minLevel))
    row.rep:SetText(reward.repRequired or "None")

    local shortfall = math.max(0, reward.tickets - tickets)
    row.shortfall = shortfall
    row.progress:SetText(string.format("%d / %d", tickets, reward.tickets))

    local levelOk = level >= reward.minLevel
    local ticketsOk = tickets >= reward.tickets
    local status, r, g, b
    if ticketsOk and levelOk then
      status, r, g, b = "Ready to buy", 0.2, 1, 0.2
    elseif not levelOk and not ticketsOk then
      status, r, g, b = string.format("Lvl %d + %d tix", reward.minLevel, shortfall), 1, 0.4, 0.4
    elseif not levelOk then
      status, r, g, b = "Need level " .. reward.minLevel, 1, 0.82, 0
    else
      status, r, g, b = "Need " .. shortfall .. " tickets", 1, 0.55, 0.2
    end
    row.status:SetText(status)
    row.name:SetTextColor(r, g, b)
    row.status:SetTextColor(r, g, b)
    row.rep:SetTextColor(0.2, 1, 0.2)
  end

  f.rewardContent:SetHeight(math.max(ROW_HEIGHT, ROW_HEIGHT * #ns.REWARDS))
end

function ns.RefreshUI()
  local f = ns.CreateUI()
  ns.EnsureDB()

  local tickets = ns.GetTicketCount()
  local target = DarkmoonTicketHelperDB.target or ns.DEFAULT_TARGET
  local need = math.max(0, target - tickets)
  local _, valueInStanding, standingName, factionName = ns.GetDMFReputation()
  local level = UnitLevel("player") or 1
  local ah = ns.HasAuctionator() and "Auctionator on" or "Auctionator off"
  local tab = DarkmoonTicketHelperDB.tab or "turnins"
  setTabActive(f, tab)

  if tab == "rewards" then
    refreshRewards(f, tickets, level, standingName, valueInStanding, factionName)
  else
    refreshTurnins(f, tickets, target, need, standingName, valueInStanding, factionName, level, ah)
  end
end

function ns.ToggleUI()
  local f = ns.CreateUI()
  if f:IsShown() then
    f:Hide()
  else
    ns.RefreshUI()
    f:Show()
    f:Raise()
  end
end
