local ui = require("lib.ui")
local api = require("lib.api")
local utils = require("lib.utils")

local store = {}

function store.show(token)
  local w, h = term.getSize()
  local screen = { running = true, result = nil }

  local function drawHeader()
    ui.drawHeader(1, "COSMIM STORE", w)
    ui.writeAt(1, 2, "Browse available games", ui.COLORS.textDim)
    ui.drawSeparator(3)
  end

  local function loadGames()
    local data, err = api.listGames(token)
    if not data then return nil, err end
    return data.games or {}
  end

  local function drawGameList(games, listY, listH, listBox)
    listBox:setItems(games)
    listBox:draw()
  end

  local function showGameDetails(game)
    ui.clear()
    ui.drawHeader(1, tostring(game.name), w)

    local y = 3
    ui.writeAt(2, y, "Developer: " .. tostring(game.developer), ui.COLORS.textDim); y = y + 1
    ui.writeAt(2, y, "Price: " .. tostring(game.price) .. " CC", ui.COLORS.gold); y = y + 1
    ui.writeAt(2, y, "Version: " .. tostring(game.version), ui.COLORS.textDim); y = y + 1
    ui.writeAt(2, y, "Downloads: " .. utils.formatNumber(game.downloads or 0), ui.COLORS.textDim); y = y + 1
    y = y + 1

    ui.writeAt(2, y, "Description:", ui.COLORS.accent); y = y + 1
    local descLines = ui.FormatText(game.description or "No description", w - 4)
    for _, line in ipairs(descLines) do
      ui.writeAt(2, y, line, ui.COLORS.text); y = y + 1
      if y > h - 4 then break end
    end

    y = h - 2
    local backBtn = ui.Button("Back", 2, y, 10)
    backBtn.callback = function()
      screen.result = { action = "back" }
      screen.running = false
    end

    if game.price > 0 then
      local buyBtn = ui.Button("Buy - " .. tostring(game.price) .. " CC", w - 22, y, 20)
      buyBtn.callback = function()
        local data, err = api.purchaseGame(token, game.id)
        if data then
          screen.result = { action = "purchased", data = data }
          screen.running = false
        else
          screen.result = { action = "error", error = err }
          screen.running = false
        end
      end
      buyBtn:draw()
    else
      local freeBtn = ui.Button("Free", w - 14, y, 12)
      freeBtn.callback = function()
        local data, err = api.purchaseGame(token, game.id)
        if not data and err and err ~= "Game is free, no purchase needed" then
          screen.result = { action = "error", error = err }
          screen.running = false
        else
          screen.result = { action = "purchased", data = { message = "Free game added to library!" } }
          screen.running = false
        end
      end
      freeBtn:draw()
    end

    backBtn:draw()
  end

  local games, err = loadGames()
  if not games then
    ui.clear()
    ui.CenteredText(math.floor(h / 2), "Failed to load games: " .. (err or "unknown error"), ui.COLORS.error)
    ui.CenteredText(math.floor(h / 2) + 2, "Press any key to return", ui.COLORS.textDim)
    os.pullEvent("key")
    return { action = "back" }
  end

  local listY = 4
  local listH = h - listY - 2

  if #games == 0 then
    ui.clear()
    ui.drawHeader(1, "COSMIM STORE", w)
    ui.CenteredText(math.floor(h / 2), "No games available yet!", ui.COLORS.textDim)
    ui.CenteredText(math.floor(h / 2) + 2, "Press any key to return", ui.COLORS.textDim)
    os.pullEvent("key")
    return { action = "back" }
  end

  local listBox = ui.ListBox(2, listY, w - 4, listH, games)

  ui.clear()
  drawHeader()
  listBox:draw()

  ui.Button("Back", 2, h - 1, 8).callback = function()
    screen.running = false
    screen.result = { action = "back" }
  end

  local backBtn = ui.Button("Back", 2, h - 1, 8)
  backBtn.callback = function()
    screen.result = { action = "back" }
    screen.running = false
  end

  listBox.onDoubleClick = function(item)
    showGameDetails(item)
  end

  listBox.onSelect = function(item)
    showGameDetails(item)
  end

  local function redraw()
    ui.clear()
    drawHeader()
    listBox:draw()
    backBtn:draw()
  end

  redraw()

  while screen.running do
    local event, p1, p2, p3, p4 = os.pullEvent()

    if event == "mouse_click" then
      local cx, cy = p2, p3
      if not listBox:handleClick(cx, cy) then
        if backBtn:handleClick(cx, cy) then end
      end
    elseif event == "mouse_move" then
      local cx, cy = p2, p3
      backBtn:handleHover(cx, cy)
    elseif event == "key" then
      local key = p1
      if key == keys.up or key == keys.down then
        listBox:handleKey(key)
      elseif key == keys.enter or key == keys.space then
        local item = listBox:getSelected()
        if item then showGameDetails(item) end
      elseif key == keys.q or key == keys.escape then
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

return store
