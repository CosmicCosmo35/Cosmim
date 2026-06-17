local ui = require("lib.ui")
local api = require("lib.api")
local utils = require("lib.utils")

local credits = {}

function credits.show(token)
  local w, h = term.getSize()
  local screen = { running = true, result = nil }

  local codeBox
  local redeemBtn
  local historyBtn
  local backBtn

  local function refresh()
    ui.clear()
    ui.drawHeader(1, "COSMICREDIT SHOP", w)
    ui.drawSeparator(3)

    local balanceData = api.getBalance(token)
    local balance = 0
    if balanceData then
      local ok, data = pcall(api.getBalance, token)
      if ok and data then balance = data.credits or 0 end
    end
    ui.writeAt(2, 2, "Balance: " .. tostring(balance) .. " CC", ui.COLORS.gold)

    local y = 5
    ui.writeAt(2, y, "Redeem a Cosmim Card", ui.COLORS.accent); y = y + 2

    local boxW = 40
    local boxX = math.floor((w - boxW) / 2) + 1

    codeBox = ui.TextBox(boxX, y, boxW, "Enter card code (e.g. COSMIM-XXXX-YYYY-ZZZZ)")
    codeBox:draw()
    y = y + 2

    local statusLabel = ui.Label(2, y, "", ui.COLORS.textDim)
    y = y + 3

    local redeeming = false

    redeemBtn = ui.Button("Redeem!", boxX + boxW - 14, y - 2, 14)
    redeemBtn.callback = function()
      if redeeming then return end
      redeeming = true
      local code = codeBox:getValue()
      if #code == 0 then
        statusLabel:setText("Please enter a card code")
        statusLabel.textColor = ui.COLORS.error
        statusLabel:draw()
        redeeming = false
        return
      end
      statusLabel:setText("Redeeming...")
      statusLabel.textColor = ui.COLORS.textDim
      statusLabel:draw()
      local data, err = api.redeemCard(token, code)
      if data then
        statusLabel:setText("Redeemed " .. tostring(data.amount) .. " CC! New balance: " .. tostring(data.credits) .. " CC")
        statusLabel.textColor = ui.COLORS.success
        statusLabel:draw()
        codeBox:setValue("")
        codeBox:draw()
        refresh()
      else
        statusLabel:setText(err or "Invalid card code")
        statusLabel.textColor = ui.COLORS.error
        statusLabel:draw()
      end
      redeeming = false
    end
    redeemBtn:draw()

    backBtn = ui.Button("Back", 2, h - 1, 8)
    backBtn.callback = function()
      screen.result = { action = "back" }
      screen.running = false
    end
    backBtn:draw()

    historyBtn = ui.Button("Transaction History", math.floor(w / 2) - 12, h - 1, 24)
    historyBtn.callback = function()
      local tData, tErr = api.getTransactions(token)
      if not tData then return end
      local tx = tData.transactions or {}
      if #tx == 0 then
        statusLabel:setText("No transactions yet")
        statusLabel.textColor = ui.COLORS.textDim
        statusLabel:draw()
        return
      end
      ui.clear()
      ui.drawHeader(1, "TRANSACTIONS", w)
      local ty = 3
      for i = #tx, math.max(1, #tx - 15), -1 do
        local t = tx[i]
        local sign = (t.amount > 0) and "+" or ""
        local color = (t.amount > 0) and ui.COLORS.success or ui.COLORS.error
        local line = t.type .. ": " .. sign .. tostring(t.amount) .. " CC"
        if t.reference then line = line .. " (" .. tostring(t.reference) .. ")" end
        ui.writeAt(2, ty, line, color)
        ty = ty + 1
      end
      ui.CenteredText(h - 1, "Press any key to go back", ui.COLORS.textDim)
      os.pullEvent("key")
      refresh()
    end
    historyBtn:draw()
  end

  refresh()

  while screen.running do
    local event, p1, p2, p3, p4 = os.pullEvent()

    if event == "mouse_click" then
      local cx, cy = p2, p3
      local handled = false
      if codeBox then
        codeBox.focused = false
        if codeBox:handleClick(cx, cy) then handled = true end
      end
      if not handled then
        if backBtn then backBtn:handleClick(cx, cy) end
        if redeemBtn then redeemBtn:handleClick(cx, cy) end
        if historyBtn then historyBtn:handleClick(cx, cy) end
      end
    elseif event == "mouse_move" then
      local cx, cy = p1, p2
      if backBtn then backBtn:handleHover(cx, cy) end
      if redeemBtn then redeemBtn:handleHover(cx, cy) end
      if historyBtn then historyBtn:handleHover(cx, cy) end
    elseif event == "char" then
      local char = p1
      if codeBox then codeBox:handleChar(char) end
    elseif event == "key" then
      local key = p1
      if codeBox then codeBox:handleKey(key) end
      if key == keys.q or key == keys.escape then
        screen.result = { action = "back" }
        screen.running = false
      end
    elseif event == "terminate" then
      screen.result = { action = "quit" }
      screen.running = false
    end
  end

  return screen.result
end

return credits
