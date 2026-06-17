local ui = require("lib.ui")
local api = require("lib.api")
local utils = require("lib.utils")

local developer = {}

function developer.show(token, user)
  local w, h = term.getSize()
  local screen = { running = true, result = nil }
  local buttons = {}

  local function showDashboard()
    ui.clear()
    ui.drawHeader(1, "DEVELOPER DASHBOARD", w)

    if user.role ~= "developer" then
      ui.CenteredText(math.floor(h / 2) - 2, "You are not a Developer!", ui.COLORS.warning)
      ui.CenteredText(math.floor(h / 2), "Upgrade your account to publish games", ui.COLORS.textDim)

      local upgradeBtn = ui.Button("[1] Upgrade to Developer!", math.floor(w / 2) - 14, math.floor(h / 2) + 2, 28)
      upgradeBtn.callback = function()
        local data, err = api.upgradeToDeveloper(token)
        if data then
          user.role = "developer"
          buttons = showDashboard()
        end
      end

      local backBtn = ui.Button("[Q] Back", 2, h - 1, 10)
      backBtn.callback = function()
        screen.running = false
        screen.result = { action = "back" }
      end

      upgradeBtn:draw()
      backBtn:draw()
      ui.writeAt(2, h - 1, "Press 1 to upgrade or Q to go back", colors.lightGray)

      return { backBtn, upgradeBtn }
    end

    ui.writeAt(2, 3, "Welcome, " .. user.display_name .. "!", ui.COLORS.success)

    local data, err = api.getMyGames(token)
    local myGames = {}
    if data then myGames = data.games or {} end

    ui.writeAt(2, 5, "Your Games (" .. tostring(#myGames) .. ")", ui.COLORS.accent)
    ui.drawSeparator(6, "-", ui.COLORS.textDim)

    local y = 7
    if #myGames > 0 then
      for i, game in ipairs(myGames) do
        local line = tostring(i) .. ". " .. game.name .. " (" .. tostring(game.price) .. " CC) - v" .. game.version
        ui.writeAt(2, y, line, ui.COLORS.text)
        y = y + 1
      end
    else
      ui.writeAt(2, y, "No games published yet", ui.COLORS.textDim)
      y = y + 1
    end

    y = math.max(y, math.floor(h / 2))

    local newBtn = ui.Button("[1] Publish New Game", math.floor(w / 2) - 20, y, 22)
    newBtn.callback = function()
      local result = showPublishForm(token)
      if result == "created" then buttons = showDashboard() end
    end

    local refreshBtn = ui.Button("[2] Refresh", math.floor(w / 2) + 4, y, 14)
    refreshBtn.callback = function()
      buttons = showDashboard()
    end

    local backBtn = ui.Button("[Q] Back", 2, h - 1, 10)
    backBtn.callback = function()
      screen.running = false
      screen.result = { action = "back" }
    end

    newBtn:draw()
    refreshBtn:draw()
    backBtn:draw()
    ui.writeAt(2, h - 1, "1:Publish  2:Refresh  Q:Back", colors.lightGray)

    return { backBtn, newBtn, refreshBtn }
  end

  function showPublishForm(token)
    local formDone = false
    local formResult = nil
    ui.clear()
    ui.drawHeader(1, "PUBLISH NEW GAME", w)

    local y = 4
    ui.writeAt(2, y, "Game Details:", ui.COLORS.accent); y = y + 2

    local nameBox = ui.TextBox(16, y, w - 18, "Game Name")
    ui.writeAt(2, y, "Name:", ui.COLORS.textDim); nameBox:draw(); y = y + 2

    local descBox = ui.TextBox(16, y, w - 18, "Description")
    ui.writeAt(2, y, "Desc:", ui.COLORS.textDim); descBox:draw(); y = y + 2

    local priceBox = ui.TextBox(16, y, 10, "0")
    ui.writeAt(2, y, "Price:", ui.COLORS.textDim); priceBox:draw(); y = y + 2

    local statusLabel = ui.Label(2, y + 2, "", ui.COLORS.textDim)

    local createBtn = ui.Button("Create Game", math.floor(w / 2) - 10, y + 4, 20)
    createBtn.callback = function()
      local name = nameBox:getValue()
      local desc = descBox:getValue()
      local price = tonumber(priceBox:getValue()) or 0
      if #name == 0 then
        statusLabel:setText("Game name required!")
        statusLabel.textColor = ui.COLORS.error; statusLabel:draw()
        return
      end
      statusLabel:setText("Creating game...")
      statusLabel.textColor = ui.COLORS.textDim; statusLabel:draw()
      local data, err = api.publishGame(token, name, desc, price)
      if data then
        statusLabel:setText("Game created! Now upload files.")
        statusLabel.textColor = ui.COLORS.success; statusLabel:draw()
        showUploadForm(token, data.game.id)
        formResult = "created"
        formDone = true
      else
        statusLabel:setText(err or "Failed to create game")
        statusLabel.textColor = ui.COLORS.error; statusLabel:draw()
      end
    end

    local cancelBtn = ui.Button("Cancel", 2, h - 1, 10)
    cancelBtn.callback = function() formDone = true end

    createBtn:draw()
    cancelBtn:draw()
    ui.writeAt(15, h - 1, "Tab:Next  Enter:Create  Esc:Cancel", colors.lightGray)

    local textboxes = { nameBox, descBox, priceBox }
    local btns = { createBtn, cancelBtn }
    nameBox.focused = true
    term.setCursorBlink(true)

    while not formDone do
      local event, p1, p2, p3, p4 = os.pullEvent()
      if event == "mouse_click" then
        local cx, cy = p2, p3
        for _, tb in ipairs(textboxes) do tb.focused = false end
        for _, tb in ipairs(textboxes) do tb:handleClick(cx, cy) end
        for _, btn in ipairs(btns) do btn:handleClick(cx, cy) end
      elseif event == "mouse_move" then
        for _, btn in ipairs(btns) do btn:handleHover(p1, p2) end
      elseif event == "char" then
        for _, tb in ipairs(textboxes) do tb:handleChar(p1) end
      elseif event == "key" then
        local key = p1
        if key == keys.tab then
          for i, tb in ipairs(textboxes) do
            if tb.focused then tb.focused = false; local n = i + 1; if n > #textboxes then n = 1 end; textboxes[n].focused = true; textboxes[n]:draw(); break end
          end
        elseif key == keys.enter then
          createBtn.callback()
        elseif key == keys.escape then
          formDone = true
        else
          for _, tb in ipairs(textboxes) do tb:handleKey(key) end
        end
      elseif event == "terminate" then
        formDone = true; screen.running = false; screen.result = { action = "quit" }
      end
    end
    term.setCursorBlink(false)
    return formResult
  end

  function showUploadForm(token, gameId)
    local subDone = false
    ui.clear()
    ui.drawHeader(1, "UPLOAD GAME FILES", w)

    ui.writeAt(2, 3, "Game ID: " .. gameId, ui.COLORS.textDim)
    ui.writeAt(2, 4, "Select upload method:", ui.COLORS.accent)

    local y = 6
    local statusLabel = ui.Label(2, h - 4, "", ui.COLORS.textDim)

    local singleBtn = ui.Button("[1] Upload Single File", math.floor(w / 2) - 20, y, 24)
    singleBtn.callback = function()
      local sub2Done = false
      ui.clear()
      ui.drawHeader(1, "UPLOAD GAME FILE", w)
      ui.writeAt(2, 3, "Enter the path to your game file:", ui.COLORS.textDim)

      local pathBox = ui.TextBox(2, 5, w - 4, "Path to game.lua")
      pathBox:draw()

      local status = ui.Label(2, 7, "", ui.COLORS.textDim)

      local uploadBtn = ui.Button("Upload", math.floor(w / 2) - 10, 9, 20)
      uploadBtn.callback = function()
        local path = pathBox:getValue()
        if not fs.exists(path) then
          status:setText("File not found!")
          status.textColor = ui.COLORS.error; status:draw()
          return
        end
        if fs.isDir(path) then
          status:setText("Path is a directory, use Upload Folder instead!")
          status.textColor = ui.COLORS.warning; status:draw()
          return
        end
        status:setText("Uploading..."); status.textColor = ui.COLORS.textDim; status:draw()
        local file = fs.open(path, "r")
        local content = file.readAll()
        file.close()
        local data, err = api.uploadGameFile(token, gameId, content)
        if data then
          status:setText("Game uploaded successfully!")
          status.textColor = ui.COLORS.success; status:draw()
          sub2Done = true
          showIconUpload(token, gameId)
        else
          status:setText(err or "Upload failed")
          status.textColor = ui.COLORS.error; status:draw()
        end
      end

      local backBtn = ui.Button("Back", 2, h - 1, 8)
      backBtn.callback = function() sub2Done = true end

      local textboxes = { pathBox }
      local btns = { uploadBtn, backBtn }
      pathBox.focused = true
      term.setCursorBlink(true)

      while not sub2Done do
        local event, p1, p2, p3, p4 = os.pullEvent()
        if event == "mouse_click" then
          for _, tb in ipairs(textboxes) do tb.focused = false end
          for _, tb in ipairs(textboxes) do tb:handleClick(p2, p3) end
          for _, btn in ipairs(btns) do btn:handleClick(p2, p3) end
        elseif event == "mouse_move" then
          for _, btn in ipairs(btns) do btn:handleHover(p1, p2) end
        elseif event == "char" then
          for _, tb in ipairs(textboxes) do tb:handleChar(p1) end
        elseif event == "key" then
          local key = p1
          if key == keys.enter then uploadBtn.callback()
          elseif key == keys.q or key == keys.escape then backBtn.callback()
          else for _, tb in ipairs(textboxes) do tb:handleKey(key) end end
        elseif event == "terminate" then sub2Done = true; screen.running = false; screen.result = { action = "quit" }
        end
      end
      term.setCursorBlink(false)
    end

    local dirBtn = ui.Button("[2] Upload Folder", math.floor(w / 2) + 6, y, 22)
    dirBtn.callback = function()
      local sub2Done = false
      ui.clear()
      ui.drawHeader(1, "UPLOAD GAME FOLDER", w)
      local dir = "/"
      local scroll = 0
      local selectedFile = nil

      local function drawFileList()
        ui.clear()
        ui.drawHeader(1, "SELECT GAME FOLDER: " .. dir, w)
        ui.writeAt(2, 2, "Select a folder and press Enter", ui.COLORS.textDim)
        local items = {}
        if dir ~= "/" then table.insert(items, { label = ".. (Parent)", path = fs.getDir(dir) }) end
        local list = fs.list(dir)
        table.sort(list)
        for _, name in ipairs(list) do
          local fullPath = fs.combine(dir, name)
          if fs.isDir(fullPath) then
            table.insert(items, { label = "[ " .. name .. " ]", path = fullPath, isDir = true })
          end
        end
        for _, name in ipairs(list) do
          local fullPath = fs.combine(dir, name)
          if not fs.isDir(fullPath) then
            table.insert(items, { label = "  " .. name, path = fullPath, isDir = false })
          end
        end
        local listBox = ui.ListBox(2, 4, w - 4, h - 8, items)
        listBox.onDoubleClick = function(item)
          if item.isDir then
            dir = item.path
            drawFileList()
          end
        end
        listBox.onSelect = function(item)
          selectedFile = item
        end
        listBox:draw()

        local selectBtn = ui.Button("Select This Folder", math.floor(w / 2) - 12, h - 2, 24)
        selectBtn.callback = function()
          local status = ui.Label(2, h - 1, "Uploading folder...", ui.COLORS.textDim)
          local files = {}
          local gameList = fs.list(dir)
          for _, name in ipairs(gameList) do
            local fpath = fs.combine(dir, name)
            if not fs.isDir(fpath) then
              local file = fs.open(fpath, "r")
              files[name] = file.readAll()
              file.close()
            end
          end
          local data, err = api.uploadGameDir(token, gameId, files)
          if data then
            status:setText("Folder uploaded! Now upload icon.")
            status.textColor = ui.COLORS.success; status:draw()
            sleep(1)
            sub2Done = true
            showIconUpload(token, gameId)
          else
            status:setText(err or "Upload failed"); status.textColor = ui.COLORS.error; status:draw()
          end
        end
        selectBtn:draw()

        if #items > h - 8 then
          ui.writeAt(w - 1, h - 1, "v", ui.COLORS.textDim)
        end

        return listBox
      end

      local listBox = drawFileList()
      term.setCursorBlink(false)

      while not sub2Done do
        local event, p1, p2, p3, p4 = os.pullEvent()
        if event == "mouse_click" then
          listBox:handleClick(p2, p3)
        elseif event == "key" then
          local key = p1
          if key == keys.up or key == keys.down then listBox:handleKey(key)
          elseif key == keys.enter then
            local item = listBox:getSelected()
            if item and item.isDir then dir = item.path; listBox = drawFileList() end
          elseif key == keys.q or key == keys.escape then sub2Done = true
          end
        elseif event == "terminate" then sub2Done = true; screen.running = false; screen.result = { action = "quit" }
        end
      end
    end

    local backBtn = ui.Button("[Q] Back", 2, h - 1, 10)
    backBtn.callback = function() subDone = true end

    singleBtn:draw()
    dirBtn:draw()
    backBtn:draw()
    ui.writeAt(15, h - 1, "1:File  2:Folder  Q:Back", colors.lightGray)

    local btns = { singleBtn, dirBtn, backBtn }

    while not subDone do
      local event, p1, p2, p3, p4 = os.pullEvent()
      if event == "mouse_click" then
        for _, btn in ipairs(btns) do btn:handleClick(p2, p3) end
      elseif event == "mouse_move" then
        for _, btn in ipairs(btns) do btn:handleHover(p1, p2) end
      elseif event == "key" then
        local key = p1
        if key == keys.one then singleBtn.callback()
        elseif key == keys.two then dirBtn.callback()
        elseif key == keys.q or key == keys.escape then backBtn.callback()
        end
      elseif event == "terminate" then subDone = true; screen.running = false; screen.result = { action = "quit" }
      end
    end
  end

  function showIconUpload(token, gameId)
    local subDone = false
    ui.clear()
    ui.drawHeader(1, "UPLOAD GAME ICON", w)
    ui.writeAt(2, 3, "Optional: upload an icon for your game", ui.COLORS.textDim)
    ui.writeAt(2, 4, "Enter path to a .nfp file or image:", ui.COLORS.textDim)

    local pathBox = ui.TextBox(2, 6, w - 4, "Path to icon file")
    pathBox:draw()

    local status = ui.Label(2, 8, "", ui.COLORS.textDim)

    local uploadBtn = ui.Button("Upload Icon", math.floor(w / 2) - 12, 10, 24)
    uploadBtn.callback = function()
      local path = pathBox:getValue()
      if path and fs.exists(path) and not fs.isDir(path) then
        local file = fs.open(path, "r")
        local content = file.readAll()
        file.close()
        local data, err = api.uploadIcon(token, gameId, content)
        if data then
          status:setText("Icon uploaded!")
          status.textColor = ui.COLORS.success
        else
          status:setText(err or "Upload failed")
          status.textColor = ui.COLORS.error
        end
      else
        status:setText("Skipping icon upload")
        status.textColor = ui.COLORS.textDim
      end
      status:draw()
      sleep(1)
      ui.clear()
      ui.drawHeader(1, "GAME PUBLISHED!", w)
      ui.CenteredText(math.floor(h / 2), "Your game is now on Cosmim!", ui.COLORS.success)
      ui.CenteredText(math.floor(h / 2) + 2, "Press any key", ui.COLORS.textDim)
      os.pullEvent("key")
      subDone = true
      screen.result = { action = "created" }
    end

    local skipBtn = ui.Button("Skip", math.floor(w / 2) + 14, 10, 10)
    skipBtn.callback = function()
      ui.clear()
      ui.drawHeader(1, "GAME PUBLISHED!", w)
      ui.CenteredText(math.floor(h / 2), "Your game is now on Cosmim!", ui.COLORS.success)
      ui.CenteredText(math.floor(h / 2) + 2, "Press any key", ui.COLORS.textDim)
      os.pullEvent("key")
      subDone = true
      screen.result = { action = "created" }
    end

    local backBtn = ui.Button("Back", 2, h - 1, 8)
    backBtn.callback = function() subDone = true end

    uploadBtn:draw()
    skipBtn:draw()
    backBtn:draw()
    ui.writeAt(12, h - 1, "Esc:Back", colors.lightGray)

    local textboxes = { pathBox }
    local btns = { uploadBtn, skipBtn, backBtn }
    pathBox.focused = true
    term.setCursorBlink(true)

    while not subDone do
      local event, p1, p2, p3, p4 = os.pullEvent()
      if event == "mouse_click" then
        for _, tb in ipairs(textboxes) do tb.focused = false end
        for _, tb in ipairs(textboxes) do tb:handleClick(p2, p3) end
        for _, btn in ipairs(btns) do btn:handleClick(p2, p3) end
      elseif event == "mouse_move" then
        for _, btn in ipairs(btns) do btn:handleHover(p1, p2) end
      elseif event == "char" then
        for _, tb in ipairs(textboxes) do tb:handleChar(p1) end
      elseif event == "key" then
        local key = p1
        if key == keys.enter then uploadBtn.callback()
        elseif key == keys.q or key == keys.escape then backBtn.callback()
        else for _, tb in ipairs(textboxes) do tb:handleKey(key) end end
      elseif event == "terminate" then subDone = true; screen.running = false; screen.result = { action = "quit" }
      end
    end
    term.setCursorBlink(false)
  end

  buttons = showDashboard()

  while screen.running do
    local event, p1, p2, p3, p4 = os.pullEvent()
    if event == "mouse_click" then
      for _, btn in ipairs(buttons) do
        if btn.handleClick then btn:handleClick(p2, p3) end
      end
    elseif event == "mouse_move" then
      for _, btn in ipairs(buttons) do
        if btn.handleHover then btn:handleHover(p1, p2) end
      end
    elseif event == "key" then
      local key = p1
      if key == keys.one then
        if user.role == "developer" then
          local result = showPublishForm(token)
          if result == "created" then buttons = showDashboard() end
        else
          local data, err = api.upgradeToDeveloper(token)
          if data then user.role = "developer"; buttons = showDashboard() end
        end
      elseif key == keys.two and user.role == "developer" then
        buttons = showDashboard()
      elseif key == keys.q or key == keys.escape then
        screen.running = false; screen.result = { action = "back" }
      end
    elseif event == "terminate" then
      screen.running = false; screen.result = { action = "quit" }
    end
  end

  return screen.result
end

return developer
