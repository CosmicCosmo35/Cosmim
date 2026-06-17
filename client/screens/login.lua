local ui = require("lib.ui")
local api = require("lib.api")
local utils = require("lib.utils")

local login = {}

function login.show()
  local w, h = term.getSize()
  local screen = { running = true, result = nil }

  local buttons = {}
  local textboxes = {}

  local function clearScreen()
    ui.clear()
  end

  local function drawLogo()
    local logoColors = { colors.orange, colors.yellow, colors.cyan, colors.lightBlue, colors.blue, colors.lightBlue, colors.cyan, colors.yellow, colors.orange }
    local logo = {
      "  ___  ___  ___  __  __  ___  _  _  ",
      " / __]/ __]/ __/|  \\/  |/ __]| || | ",
      "|  _// /  | |   | \\/  | |  | | || | ",
      "| / \\\\ \\_ | |__ | |\\/| | |__| \\_/\\_/ ",
      "|_|\\_\\\\___| \\___||_|  |_|\\___|\\_\\_\\_/ "
    }
    for i, line in ipairs(logo) do
      local x = math.floor((w - #line) / 2) + 1
      term.setTextColor(logoColors[i])
      term.setBackgroundColor(colors.black)
      term.setCursorPos(x, i)
      term.write(line)
    end
    term.setTextColor(colors.white)
  end

  local function showForm(mode)
    clearScreen()
    drawLogo()
    textboxes = {}
    buttons = {}

    local boxW = 30
    local boxX = math.floor((w - boxW) / 2)

    local title = (mode == "login") and "LOGIN" or "REGISTER"
    local titleX = math.floor((w - #title) / 2) + 1
    term.setTextColor(ui.COLORS.text)
    term.setBackgroundColor(colors.black)
    term.setCursorPos(titleX, 7)
    term.write(title)
    ui.drawSeparator(8, "-", ui.COLORS.textDim)

    local unameBox = ui.TextBox(boxX + 10, 9, boxW - 10, "Username")
    local passBox = ui.TextBox(boxX + 10, 10, boxW - 10, "Password")
    local displayBox = nil

    ui.writeAt(boxX, 9, "Username:", ui.COLORS.textDim)
    ui.writeAt(boxX, 10, "Password:", ui.COLORS.textDim)

    local statusLabel = ui.Label(boxX, 14, "", ui.COLORS.textDim)

    if mode == "register" then
      displayBox = ui.TextBox(boxX + 10, 11, boxW - 10, "Display Name")
      ui.writeAt(boxX, 11, "Display:", ui.COLORS.textDim)
    end

    local actionY = 15
    local actionLabel = (mode == "login") and "Login" or "Register"
    local actionBtn = ui.Button(actionLabel, math.floor(w / 2) - 12, actionY, 24, nil)
    function actionBtn.callback()
      local uname = unameBox:getValue()
      local pass = passBox:getValue()
      if #uname < 3 then
        statusLabel:setText("Username must be at least 3 chars")
        statusLabel.textColor = ui.COLORS.error
        statusLabel:draw()
        return
      end
      if #pass < 3 then
        statusLabel:setText("Password must be at least 3 chars")
        statusLabel.textColor = ui.COLORS.error
        statusLabel:draw()
        return
      end
      statusLabel:setText("Contacting server...")
      statusLabel.textColor = ui.COLORS.textDim
      statusLabel:draw()
      local data, err
      if mode == "login" then
        data, err = api.login(uname, pass)
      else
        local display = uname
        if displayBox then
          display = displayBox:getValue()
          if display == "" then display = uname end
        end
        data, err = api.register(uname, pass, display)
      end
      if data then
        utils.saveToken(data.token)
        utils.saveUserData(data.user.username)
        screen.result = { action = "logged_in", data = data }
        screen.running = false
      else
        statusLabel:setText(err or "Unknown error")
        statusLabel.textColor = ui.COLORS.error
        statusLabel:draw()
      end
    end
    table.insert(buttons, actionBtn)

    local switchLabel = (mode == "login") and "Create Account" or "Back to Login"
    local switchBtn = ui.Button(switchLabel, math.floor(w / 2) - 10, 17, 20)
    function switchBtn.callback()
      showForm(mode == "login" and "register" or "login")
    end
    table.insert(buttons, switchBtn)

    local connectBtn = ui.Button("Reconnect", 2, h - 1, 12)
    function connectBtn.callback()
      statusLabel:setText("Searching for server...")
      statusLabel.textColor = ui.COLORS.textDim
      statusLabel:draw()
      if api.findServer() then
        statusLabel:setText("Connected!")
        statusLabel.textColor = ui.COLORS.success
      else
        statusLabel:setText("Server not found on Rednet")
        statusLabel.textColor = ui.COLORS.error
      end
      statusLabel:draw()
    end
    table.insert(buttons, connectBtn)

    table.insert(textboxes, unameBox)
    table.insert(textboxes, passBox)
    if displayBox then table.insert(textboxes, displayBox) end
    unameBox.focused = true

    for _, btn in ipairs(buttons) do btn:draw() end
    for _, tb in ipairs(textboxes) do tb:draw() end
    term.setCursorBlink(true)
  end

  showForm("login")

  while screen.running do
    local event, p1, p2, p3, p4 = os.pullEvent()

    if event == "mouse_click" then
      local cx, cy = p2, p3
      local handled = false
      for _, tb in ipairs(textboxes) do
        tb.focused = false
      end
      for _, tb in ipairs(textboxes) do
        if tb:handleClick(cx, cy) then handled = true; break end
      end
      if not handled then
        for _, btn in ipairs(buttons) do
          if btn:handleClick(cx, cy) then break end
        end
      end
    elseif event == "mouse_move" then
      local cx, cy = p1, p2
      for _, btn in ipairs(buttons) do
        btn:handleHover(cx, cy)
      end
    elseif event == "char" then
      local char = p1
      for _, tb in ipairs(textboxes) do
        if tb:handleChar(char) then break end
      end
    elseif event == "key" then
      local key = p1
      if key == keys.enter then
        if #buttons > 0 and buttons[1].callback then
          buttons[1].callback()
        end
      elseif key == keys.tab then
        local focused = nil
        for i, tb in ipairs(textboxes) do
          if tb.focused then focused = i; tb.focused = false; break end
        end
        if focused then
          local next = focused + 1
          if next > #textboxes then next = 1 end
          textboxes[next].focused = true
          textboxes[next]:draw()
        end
      elseif key == keys.escape then
        screen.running = false
        screen.result = { action = "quit" }
      else
        for _, tb in ipairs(textboxes) do
          if tb:handleKey(key) then break end
        end
      end
    elseif event == "terminate" then
      screen.running = false
      screen.result = { action = "quit" }
    end
  end

  term.setCursorBlink(false)
  return screen.result
end

return login
