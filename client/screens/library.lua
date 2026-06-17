local ui = require("lib.ui")
local api = require("lib.api")
local utils = require("lib.utils")

local library = {}

function library.show(token)
  local w, h = term.getSize()
  local screen = { running = true, result = nil }

  local data, err = api.getLibrary(token)
  if not data then
    ui.clear()
    ui.CenteredText(math.floor(h / 2), "Failed to load library: " .. (err or "unknown error"), ui.COLORS.error)
    os.pullEvent("key")
    return { action = "back" }
  end

  local libItems = data.library or {}

  if #libItems == 0 then
    ui.clear()
    ui.drawHeader(1, "YOUR LIBRARY", w)
    ui.CenteredText(math.floor(h / 2), "Your library is empty!", ui.COLORS.textDim)
    ui.CenteredText(math.floor(h / 2) + 1, "Visit the Store to buy games", ui.COLORS.textDim)
    os.pullEvent("key")
    return { action = "back" }
  end

  local listBox = ui.ListBox(2, 4, w - 4, h - 6, libItems)
  listBox.onDoubleClick = function(item)
    screen.result = { action = "play", game = item }
    screen.running = false
  end
  listBox.onSelect = function(item)
    screen.result = { action = "play", game = item }
    screen.running = false
  end

  local function redraw()
    ui.clear()
    ui.drawHeader(1, "YOUR LIBRARY", w)
    ui.writeAt(1, 2, "Select a game to launch (Enter)", ui.COLORS.textDim)
    ui.drawSeparator(3)
    listBox:draw()
    local backBtn = ui.Button("Back", 2, h - 1, 8)
    backBtn.callback = function()
      screen.result = { action = "back" }
      screen.running = false
    end
    backBtn:draw()
  end

  redraw()

  while screen.running do
    local event, p1, p2, p3, p4 = os.pullEvent()

    if event == "mouse_click" then
      local cx, cy = p2, p3
      listBox:handleClick(cx, cy)
    elseif event == "key" then
      local key = p1
      if key == keys.up or key == keys.down then
        listBox:handleKey(key)
      elseif key == keys.enter or key == keys.space then
        local item = listBox:getSelected()
        if item then
          screen.result = { action = "play", game = item }
          screen.running = false
        end
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

return library
