local PROTOCOL = "cosmim"

local function loadLib(name)
  local env = _ENV or _G
  if env.package and env.package.path then
    package.path = package.path .. ";" .. shell.dir() .. "/?.lua"
  end
  return require(name)
end

local ui = loadLib("lib.ui")
local api = loadLib("lib.api")
local utils = loadLib("lib.utils")

local function ensureModem()
  local sides = { "top", "bottom", "left", "right", "front", "back" }
  for _, side in ipairs(sides) do
    local ok = pcall(rednet.open, side)
    if ok then return side end
  end
  return nil
end

local function findServer()
  ui.clear()
  local w, h = term.getSize()

  ui.DrawAppInfo("Cosmim v1.0", "v1.0", "Connecting to server...")

  local side = ensureModem()
  if not side then
    ui.CenteredText(math.floor(h / 2) + 5, "No modem found! Attach a modem and restart.", ui.COLORS.error)
    ui.CenteredText(math.floor(h / 2) + 7, "Press any key to exit.", ui.COLORS.textDim)
    os.pullEvent("key")
    return nil
  end

  local attempts = 0
  while attempts < 3 do
    ui.CenteredText(math.floor(h / 2) + 5, "Searching for Cosmim server... (attempt " .. tostring(attempts + 1) .. "/3)", ui.COLORS.textDim)
    local id = api.findServer()
    if id then
      term.setCursorPos(1, math.floor(h / 2) + 7)
      term.setTextColor(colors.green)
      term.setBackgroundColor(colors.black)
      term.write("Connected! Server ID: " .. tostring(id))
      sleep(1)
      return id
    end
    sleep(1)
    attempts = attempts + 1
  end

  ui.CenteredText(math.floor(h / 2) + 7, "Server not found!", ui.COLORS.error)
  ui.CenteredText(math.floor(h / 2) + 9, "Make sure the server computer is on.", ui.COLORS.textDim)
  ui.CenteredText(math.floor(h / 2) + 10, "Press any key to retry or Ctrl+T to quit.", ui.COLORS.textDim)
  os.pullEvent("key")
  return findServer()
end

local function mainMenu(token, user)
  local w, h = term.getSize()
  local menu = { running = true, result = nil }

  local function drawMenu()
    ui.clear()

    -- Header bar
    ui.fillRect(1, 1, w, 1, colors.blue)
    local headerText = " ◆ Cosmim v1.0 "
    ui.writeAt(2, 1, headerText, colors.white, colors.blue)
    local nameText = " " .. (user.display_name or user.username) .. " "
    ui.writeAt(w - #nameText - 1, 1, nameText, colors.white, colors.blue)
    ui.drawSeparator(2, "─", colors.cyan)

    -- Menu panel
    local panelW = 34
    local panelH = 10
    local panelX = math.floor((w - panelW) / 2) + 1
    local panelY = 4

    ui.DrawPanel(panelX, panelY, panelW, panelH, " MAIN MENU ", colors.cyan, colors.cyan)

    local items = {
      { text = "Store",              key = keys.one,   action = "store",     color = colors.blue },
      { text = "Library",            key = keys.two,   action = "library",   color = colors.green },
      { text = "CosmiCredit Shop",   key = keys.three, action = "credits",   color = colors.orange },
      { text = "Developer Dashboard", key = keys.four,  action = "developer", color = colors.purple },
      { text = "Profile",            key = keys.five,  action = "profile",   color = colors.cyan },
    }

    local buttons = {}
    local startY = panelY + 2
    local startX = panelX + 4

    for i, item in ipairs(items) do
      local label = "[" .. i .. "]  " .. item.text
      local btn = ui.Button(label, startX, startY + i - 1, panelW - 8)
      btn.color = item.color
      btn.hoverColor = colors.lightGray
      btn.textColor = colors.white
      btn.callback = function()
        menu.result = { action = item.action }
        menu.running = false
      end
      table.insert(buttons, btn)
      btn:draw()
    end

    -- Credentials bar
    ui.drawSeparator(h - 3, "─", colors.textDim)
    local balData, _ = api.getBalance(token)
    local balText = " ◆ " .. tostring(balData and balData.credits or "?") .. " CC"
    ui.writeAt(3, h - 2, balText, colors.orange)

    local roleColors = { user = colors.lightGray, developer = colors.orange, admin = colors.red }
    local roleColor = roleColors[user.role] or colors.lightGray
    local roleText = "Role: " .. (user.role or "user")
    ui.writeAt(w - #roleText - 3, h - 2, roleText, roleColor)

    -- Bottom bar: quit + hints
    local quitBtn = ui.Button("[Q] Quit", 3, h - 1, 12)
    quitBtn.color = colors.gray
    quitBtn.callback = function()
      menu.result = { action = "quit" }
      menu.running = false
    end
    table.insert(buttons, quitBtn)
    quitBtn:draw()

    local hint = "Keys 1-5 or click to select"
    ui.writeAt(w - #hint - 3, h - 1, hint, colors.lightGray, colors.black)

    return buttons
  end

  ui.clear()
  local buttons = drawMenu()

  while menu.running do
    local event, p1, p2, p3, p4 = os.pullEvent()

    if event == "mouse_click" then
      local cx, cy = p2, p3
      for _, btn in ipairs(buttons) do
        if btn:handleClick(cx, cy) then break end
      end
    elseif event == "mouse_move" then
      local cx, cy = p1, p2
      for _, btn in ipairs(buttons) do
        btn:handleHover(cx, cy)
      end
    elseif event == "key" then
      local key = p1
      if key == keys.one then menu.result = { action = "store" }; menu.running = false
      elseif key == keys.two then menu.result = { action = "library" }; menu.running = false
      elseif key == keys.three then menu.result = { action = "credits" }; menu.running = false
      elseif key == keys.four then menu.result = { action = "developer" }; menu.running = false
      elseif key == keys.five then menu.result = { action = "profile" }; menu.running = false
      elseif key == keys.q or key == keys.escape then
        menu.result = { action = "quit" }
        menu.running = false
      end
    elseif event == "terminate" then
      menu.result = { action = "quit" }
      menu.running = false
    end
  end

  return menu.result
end

local function handlePlayGame(token, game)
  ui.clear()
  local w, h = term.getSize()
  ui.drawHeader(1, "LAUNCHING: " .. tostring(game.name), w)
  ui.writeAt(2, 3, "Downloading game...", ui.COLORS.textDim)

  local data, err = api.downloadGame(token, game.id)
  if not data then
    ui.writeAt(2, 4, "Download failed: " .. (err or "unknown error"), ui.COLORS.error)
    ui.CenteredText(h - 1, "Press any key", ui.COLORS.textDim)
    os.pullEvent("key")
    return
  end

  local gameDir = "/cosmim_games/" .. game.id
  if fs.exists(gameDir) then
    fs.delete(gameDir)
  end
  fs.makeDir(gameDir)

  if data.is_directory then
    for filename, content in pairs(data.files or {}) do
      local f = fs.open(fs.combine(gameDir, filename), "w")
      f.write(content)
      f.close()
    end
    local mainFile = gameDir .. "/" .. "startup.lua"
    if not fs.exists(mainFile) then
      local list = fs.list(gameDir)
      if #list > 0 then
        mainFile = fs.combine(gameDir, list[1])
      end
    end
    ui.clear()
    ui.drawHeader(1, "RUNNING: " .. tostring(game.name), w)
    ui.writeAt(2, 3, "Launching from: " .. mainFile, ui.COLORS.textDim)
    sleep(1)
    shell.run(mainFile)
  else
    local gamePath = gameDir .. "/game.lua"
    local f = fs.open(gamePath, "w")
    f.write(data.file_data)
    f.close()
    ui.clear()
    ui.drawHeader(1, "RUNNING: " .. tostring(game.name), w)
    ui.writeAt(2, 3, "Launching...", ui.COLORS.textDim)
    sleep(1)
    shell.run(gamePath)
  end
end

local function main()
  local w, h = term.getSize()

  ui.clear()
  ui.DrawAppInfo("Cosmim v1.0", "v1.0", "Welcome to Cosmim!")

  if not rednet then
    term.setCursorPos(1, math.floor(h / 2) + 5)
    print("Error: Rednet API not available!")
    print("Make sure this computer has a modem attached.")
    return
  end

  local serverId = findServer()
  if not serverId then return end

  local token = utils.loadToken()
  local user = nil

  if token then
    local data, err = api.getProfile(token)
    if data then
      user = data
    else
      token = nil
      utils.clearToken()
    end
  end

  if not token then
    local loginScreen = require("screens/login")
    local result = loginScreen.show()
    if not result or result.action == "quit" then return end
    if result.data then
      token = result.data.token
      user = result.data.user
    end
  end

  if not token or not user then return end

  while true do
    local result = mainMenu(token, user)
    if not result or result.action == "quit" then
      break
    elseif result.action == "store" then
      local storeScreen = require("screens/store")
      local res = storeScreen.show(token)
      if res and res.action == "purchased" then
        if res.data and res.data.message then
          ui.clear()
          ui.DrawAppInfo("Cosmim v1.0", "v1.0", res.data.message)
          sleep(1.5)
        end
      elseif res and res.action == "play" then
        handlePlayGame(token, res.game)
      end
    elseif result.action == "library" then
      local libScreen = require("screens/library")
      local res = libScreen.show(token)
      if res and res.action == "play" then
        handlePlayGame(token, res.game)
      end
    elseif result.action == "credits" then
      local creditsScreen = require("screens/credits")
      creditsScreen.show(token)
    elseif result.action == "developer" then
      local devScreen = require("screens/developer")
      devScreen.show(token, user)
    elseif result.action == "profile" then
      local profileScreen = require("screens/profile")
      profileScreen.show(token)
    end
  end

  ui.clear()
  ui.CenteredText(math.floor(h / 2), "Thanks for using Cosmim!", ui.COLORS.textDim)
  ui.CenteredText(math.floor(h / 2) + 1, "See you later!", ui.COLORS.textDim)
  sleep(1)
  ui.clear()
end

local ok, err = pcall(main)
if not ok then
  term.clear()
  term.setCursorPos(1, 1)
  print("Cosmim crashed:")
  print(tostring(err))
  if debug and debug.traceback then
    print(debug.traceback())
  end
end
