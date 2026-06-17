local ui = require("lib.ui")
local api = require("lib.api")
local utils = require("lib.utils")

local profile = {}

function profile.show(token)
  local w, h = term.getSize()
  local screen = { running = true, result = nil }

  local data, err = api.getProfile(token)
  if not data then
    ui.clear()
    ui.CenteredText(math.floor(h / 2), "Failed to load profile: " .. (err or "error"), ui.COLORS.error)
    os.pullEvent("key")
    return { action = "back" }
  end

  local editing = false
  local editNameBox = nil
  local editBioBox = nil

  local function drawProfile()
    ui.clear()
    ui.drawHeader(1, "YOUR PROFILE", w)

    local y = 3
    ui.writeAt(2, y, "Username: " .. tostring(data.username), ui.COLORS.text); y = y + 1
    ui.writeAt(2, y, "Display:  " .. tostring(data.display_name), ui.COLORS.text); y = y + 1
    ui.writeAt(2, y, "Role:     " .. tostring(data.role):upper(), ui.COLORS.accent); y = y + 1
    ui.writeAt(2, y, "Credits:  " .. tostring(data.credits) .. " CC", ui.COLORS.gold); y = y + 2

    ui.writeAt(2, y, "Bio:", ui.COLORS.textDim); y = y + 1
    local bioLines = data.bio and #data.bio > 0 and ui.FormatText(data.bio, w - 4) or { "(no bio)" }
    for _, line in ipairs(bioLines) do
      ui.writeAt(2, y, line, ui.COLORS.text); y = y + 1
    end

    local editBtn = ui.Button("Edit Profile", math.floor(w / 2) - 10, h - 3, 20)
    editBtn.callback = function()
      editing = true
      ui.clear()
      ui.drawHeader(1, "EDIT PROFILE", w)

      editNameBox = ui.TextBox(16, 4, w - 18, "Display Name", data.display_name)
      ui.writeAt(2, 4, "Name:", ui.COLORS.textDim); editNameBox:draw()

      editBioBox = ui.TextBox(16, 6, w - 18, "Bio", data.bio or "")
      ui.writeAt(2, 6, "Bio:", ui.COLORS.textDim); editBioBox:draw()

      local status = ui.Label(2, 8, "", ui.COLORS.textDim)

      local saveBtn = ui.Button("Save", math.floor(w / 2) - 10, 10, 20)
      saveBtn.callback = function()
        local name = editNameBox:getValue()
        local bio = editBioBox:getValue()
        local newData, newErr = api.updateProfile(token, { display_name = name, bio = bio })
        if newData then
          data.display_name = name
          data.bio = bio
          editing = false
          drawProfile()
        else
          status:setText(newErr or "Failed to save")
          status.textColor = ui.COLORS.error; status:draw()
        end
      end

      local cancelBtn = ui.Button("Cancel", 2, h - 1, 10)
      cancelBtn.callback = function()
        editing = false
        drawProfile()
      end

      local textboxes = { editNameBox, editBioBox }
      local buttons = { saveBtn, cancelBtn }
      editNameBox.focused = true
      term.setCursorBlink(true)

      return textboxes, buttons
    end

    local backBtn = ui.Button("Back", 2, h - 1, 8)
    backBtn.callback = function()
      screen.result = { action = "back" }
      screen.running = false
    end

    editBtn:draw()
    backBtn:draw()

    local buttons = { editBtn, backBtn }
    return buttons
  end

  local buttons = drawProfile()

  while screen.running do
    local event, p1, p2, p3, p4 = os.pullEvent()

    if event == "mouse_click" then
      local cx, cy = p2, p3
      if editing then
        if editNameBox then editNameBox.focused = false end
        if editBioBox then editBioBox.focused = false end
        local handled = false
        if editNameBox and editNameBox:handleClick(cx, cy) then handled = true end
        if not handled and editBioBox and editBioBox:handleClick(cx, cy) then handled = true end
        if not handled then
          for _, btn in ipairs(buttons) do btn:handleClick(cx, cy) end
        end
      else
        for _, btn in ipairs(buttons) do btn:handleClick(cx, cy) end
      end
    elseif event == "mouse_move" then
      local cx, cy = p1, p2
      for _, btn in ipairs(buttons) do btn:handleHover(cx, cy) end
    elseif event == "char" then
      if editing then
        if editNameBox then editNameBox:handleChar(p1) end
        if editBioBox then editBioBox:handleChar(p1) end
      end
    elseif event == "key" then
      local key = p1
      if editing then
        if key == keys.tab then
          if editNameBox and editNameBox.focused then
            editNameBox.focused = false; if editBioBox then editBioBox.focused = true; editBioBox:draw() end
          elseif editBioBox and editBioBox.focused then
            editBioBox.focused = false; if editNameBox then editNameBox.focused = true; editNameBox:draw() end
          end
        elseif key == keys.q or key == keys.escape then
          editing = false; drawProfile()
        else
          if editNameBox then editNameBox:handleKey(key) end
          if editBioBox then editBioBox:handleKey(key) end
        end
      else
        if key == keys.q or key == keys.escape then
          screen.result = { action = "back" }
          screen.running = false
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

return profile
