local ui = {}

local COLORS = {
  background = colors.black,
  surface = colors.gray,
  primary = colors.blue,
  accent = colors.cyan,
  text = colors.white,
  textDim = colors.lightGray,
  success = colors.green,
  error = colors.red,
  warning = colors.yellow,
  gold = colors.orange,
  headerBg = colors.blue,
  headerText = colors.white,
  border = colors.cyan,
  selected = colors.lightBlue,
  buttonBg = colors.blue,
  buttonText = colors.white,
  buttonHover = colors.lightBlue,
  inputBg = colors.gray,
  inputText = colors.white,
  highlight = colors.magenta
}

ui.COLORS = COLORS

local function setTextColor(color)
  term.setTextColor(color or COLORS.text)
end

local function setBgColor(color)
  term.setBackgroundColor(color or COLORS.background)
end

local function resetColors()
  setTextColor(COLORS.text)
  setBgColor(COLORS.background)
end

function ui.clear()
  setBgColor(COLORS.background)
  term.clear()
  term.setCursorPos(1, 1)
end

function ui.writeAt(x, y, text, textColor, bgColor)
  term.setCursorPos(x, y)
  setTextColor(textColor or COLORS.text)
  setBgColor(bgColor or COLORS.background)
  term.write(text)
  resetColors()
end

function ui.fillRect(x, y, w, h, color)
  setBgColor(color or COLORS.surface)
  for row = y, y + h - 1 do
    term.setCursorPos(x, row)
    term.write(string.rep(" ", w))
  end
  resetColors()
end

function ui.drawBorder(x, y, w, h, color)
  local c = color or COLORS.border
  setTextColor(c)
  setBgColor(COLORS.background)
  term.setCursorPos(x, y)
  term.write("+" .. string.rep("-", w - 2) .. "+")
  for row = y + 1, y + h - 2 do
    term.setCursorPos(x, row)
    term.write("|")
    term.setCursorPos(x + w - 1, row)
    term.write("|")
  end
  term.setCursorPos(x, y + h - 1)
  term.write("+" .. string.rep("-", w - 2) .. "+")
  resetColors()
end

function ui.drawHeader(y, text, w)
  local wGet, hGet = term.getSize()
  local width = w or wGet
  setBgColor(COLORS.headerBg)
  setTextColor(COLORS.headerText)
  term.setCursorPos(1, y)
  term.write(string.rep(" ", width))
  term.setCursorPos(math.floor((width - #text) / 2) + 1, y)
  term.write(text)
  resetColors()
end

function ui.drawSeparator(y, char, color)
  local w, h = term.getSize()
  char = char or "="
  setTextColor(color or COLORS.textDim)
  setBgColor(COLORS.background)
  term.setCursorPos(1, y)
  term.write(string.rep(char, w))
  resetColors()
end

function ui.Button(text, x, y, w, callback)
  local width = w or #text + 4
  local isHovered = false
  local parent = { text = text, x = x, y = y, w = width, callback = callback, visible = true }

  function parent.draw()
    if not parent.visible then return end
    local bg = isHovered and COLORS.buttonHover or COLORS.buttonBg
    local label = " " .. parent.text .. " "
    local padding = math.max(0, parent.w - #label - 2)
    local leftPad = math.floor(padding / 2)
    local rightPad = padding - leftPad
    setBgColor(bg)
    setTextColor(COLORS.buttonText)
    term.setCursorPos(parent.x, parent.y)
    term.write(" " .. string.rep(" ", leftPad) .. label .. string.rep(" ", rightPad) .. " ")
    resetColors()
  end

  function parent.handleClick(_, cx, cy)
    if not parent.visible or type(cx) ~= "number" or type(cy) ~= "number" then return false end
    if cy == parent.y and cx >= parent.x and cx < parent.x + parent.w then
      if parent.callback then
        parent.callback()
      end
      return true
    end
    return false
  end

  function parent.handleHover(_, cx, cy)
    if not parent.visible or type(cx) ~= "number" or type(cy) ~= "number" then return end
    local was = isHovered
    isHovered = (cy == parent.y and cx >= parent.x and cx < parent.x + parent.w)
    if was ~= isHovered then
      parent.draw()
    end
  end

  return parent
end

function ui.TextBox(x, y, w, placeholder, initialText)
  local obj = {
    x = x, y = y, w = w,
    text = initialText or "",
    placeholder = placeholder or "",
    focused = false,
    visible = true,
    cursorPos = 1,
    onChange = nil
  }

  function obj.draw()
    if not obj.visible then return end
    local bg = obj.focused and colors.gray or colors.black
    setBgColor(bg)
    setTextColor(COLORS.inputText)

    local display = obj.text
    if #display > obj.w then
      display = display:sub(#display - obj.w + 1)
    end

    local padding = obj.w - #display
    if padding < 0 then padding = 0 end

    term.setCursorPos(obj.x, obj.y)
    term.write(display .. string.rep(" ", padding))
    resetColors()

    if obj.focused then
      local cx = obj.x + math.min(#display, obj.w)
      term.setCursorPos(cx, obj.y)
      term.setCursorBlink(true)
    end
  end

  function obj.handleClick(_, cx, cy)
    if not obj.visible or type(cx) ~= "number" or type(cy) ~= "number" then return false end
    if cy == obj.y and cx >= obj.x and cx < obj.x + obj.w then
      obj.focused = true
      obj.draw()
      return true
    end
    return false
  end

  function obj.handleChar(_, char)
    if not obj.focused then return false end
    obj.text = obj.text:sub(1, obj.cursorPos - 1) .. char .. obj.text:sub(obj.cursorPos)
    obj.cursorPos = obj.cursorPos + 1
    if obj.onChange then obj.onChange(obj.text) end
    obj.draw()
    return true
  end

  function obj.handleKey(_, key)
    if not obj.focused then return false end
    if key == keys.backspace then
      if obj.cursorPos > 1 then
        obj.text = obj.text:sub(1, obj.cursorPos - 2) .. obj.text:sub(obj.cursorPos)
        obj.cursorPos = obj.cursorPos - 1
        if obj.onChange then obj.onChange(obj.text) end
      end
    elseif key == keys.left then
      if obj.cursorPos > 1 then obj.cursorPos = obj.cursorPos - 1 end
    elseif key == keys.right then
      if obj.cursorPos <= #obj.text then obj.cursorPos = obj.cursorPos + 1 end
    elseif key == keys.home then
      obj.cursorPos = 1
    elseif key == keys["end"] then
      obj.cursorPos = #obj.text + 1
    elseif key == keys.delete then
      if obj.cursorPos <= #obj.text then
        obj.text = obj.text:sub(1, obj.cursorPos - 1) .. obj.text:sub(obj.cursorPos + 1)
        if obj.onChange then obj.onChange(obj.text) end
      end
    elseif key == keys.enter or key == keys.tab then
      obj.focused = false
      if obj.onChange then obj.onChange(obj.text) end
    end
    obj.draw()
    return true
  end

  function obj.setValue(_, val)
    obj.text = val or ""
    obj.cursorPos = #obj.text + 1
  end

  function obj.getValue()
    return obj.text
  end

  return obj
end

function ui.ListBox(x, y, w, h, items)
  local obj = {
    x = x, y = y, w = w, h = h,
    items = items or {},
    selected = 1,
    scrollOffset = 0,
    visible = true,
    onSelect = nil,
    onDoubleClick = nil
  }

  function obj.draw()
    if not obj.visible then return end
    ui.fillRect(obj.x, obj.y, obj.w, obj.h, colors.black)
    local visibleCount = obj.h
    if obj.scrollOffset > #obj.items - visibleCount then
      obj.scrollOffset = math.max(0, #obj.items - visibleCount)
    end
    for i = 1, visibleCount do
      local idx = obj.scrollOffset + i
      if idx > #obj.items then break end
      local item = obj.items[idx]
      local label = tostring(item.label or item)
      if #label > obj.w then
        label = label:sub(1, obj.w)
      end
      local bg = (idx == obj.selected) and COLORS.selected or colors.black
      local tc = (idx == obj.selected) and colors.white or COLORS.text
      local prefix = (idx == obj.selected) and "> " or "  "
      label = prefix .. label
      if #label > obj.w then label = label:sub(1, obj.w) end
      ui.writeAt(obj.x, obj.y + i - 1, label, tc, bg)
    end
  end

  function obj.setItems(_, newItems)
    obj.items = newItems or {}
    if obj.selected > #obj.items then obj.selected = #obj.items end
    if obj.selected < 1 and #obj.items > 0 then obj.selected = 1 end
    obj.draw()
  end

  function obj.handleClick(_, cx, cy)
    if not obj.visible or type(cx) ~= "number" or type(cy) ~= "number" then return false end
    if cx >= obj.x and cx < obj.x + obj.w and cy >= obj.y and cy < obj.y + obj.h then
      local idx = obj.scrollOffset + (cy - obj.y + 1)
      if idx >= 1 and idx <= #obj.items then
        obj.selected = idx
        obj.draw()
        if obj.onSelect then obj.onSelect(obj.items[idx], idx) end
      end
      return true
    end
    return false
  end

  function obj.handleKey(_, key)
    if not obj.visible then return false end
    if key == keys.up then
      if obj.selected > 1 then
        obj.selected = obj.selected - 1
        if obj.selected <= obj.scrollOffset then
          obj.scrollOffset = math.max(0, obj.scrollOffset - 1)
        end
        obj.draw()
        if obj.onSelect then obj.onSelect(obj.items[obj.selected], obj.selected) end
      end
      return true
    elseif key == keys.down then
      if obj.selected < #obj.items then
        obj.selected = obj.selected + 1
        if obj.selected > obj.scrollOffset + obj.h - 1 then
          obj.scrollOffset = math.min(#obj.items - obj.h, obj.scrollOffset + 1)
        end
        obj.draw()
        if obj.onSelect then obj.onSelect(obj.items[obj.selected], obj.selected) end
      end
      return true
    end
    return false
  end

  function obj.getSelected()
    if #obj.items == 0 then return nil end
    return obj.items[obj.selected]
  end

  return obj
end

function ui.Label(x, y, text, textColor, bgColor)
  local obj = { x = x, y = y, text = text, textColor = textColor or COLORS.text, bgColor = bgColor or COLORS.background, visible = true }

  function obj.draw()
    if not obj.visible then return end
    ui.writeAt(obj.x, obj.y, obj.text, obj.textColor, obj.bgColor)
  end

  function obj.setText(_, newText)
    obj.text = newText
    obj.draw()
  end

  return obj
end

function ui.ScrollBar(x, y, h, totalItems, visibleItems, scrollOffset)
  local obj = {
    x = x, y = y, h = h, totalItems = totalItems,
    visibleItems = visibleItems, scrollOffset = scrollOffset
  }

  function obj.draw()
    if obj.totalItems <= obj.visibleItems then
      ui.writeAt(obj.x, obj.y, string.rep(" ", obj.h), COLORS.textDim, colors.black)
      return
    end
    local barHeight = math.max(1, math.floor(obj.h * obj.visibleItems / obj.totalItems))
    local maxOffset = obj.totalItems - obj.visibleItems
    local barPos = math.floor((obj.scrollOffset / maxOffset) * (obj.h - barHeight)) + 1
    for i = 1, obj.h do
      if i >= barPos and i < barPos + barHeight then
        ui.writeAt(obj.x, obj.y + i - 1, " ", colors.white, colors.white)
      else
        ui.writeAt(obj.x, obj.y + i - 1, " ", COLORS.textDim, colors.black)
      end
    end
  end

  return obj
end

function ui.FormatText(text, width)
  local lines = {}
  for line in text:gmatch("[^\n]+") do
    while #line > width do
      local split = line:match("^.+" .. width .. "()%s") or width
      table.insert(lines, line:sub(1, split - 1))
      line = line:sub(split):match("^%s*(.*)")
    end
    if #line > 0 then
      table.insert(lines, line)
    end
  end
  if #lines == 0 then lines = { "" } end
  return lines
end

function ui.CenteredText(y, text, textColor, bgColor)
  local w, h = term.getSize()
  local x = math.floor((w - #text) / 2) + 1
  if x < 1 then x = 1 end
  ui.writeAt(x, y, text, textColor or COLORS.text, bgColor or COLORS.background)
  return x
end

function ui.DrawAppInfo(appName, version, tagline)
  local w, h = term.getSize()
  ui.clear()
  local logoColors = {
    colors.orange, colors.yellow, colors.cyan,
    colors.lightBlue, colors.blue, colors.lightBlue,
    colors.cyan, colors.yellow, colors.orange
  }
  local logo = "  ___  ___  ___  __  __  ___  _  _  "
  local logo2 = " / __]/ __]/ __/|  \\/  |/ __]| || | "
  local logo3 = "|  _// /  | |   | \\/  | |  | | || | "
  local logo4 = "| / \\\\ \\_ | |__ | |\\/| | |__| \\_/\\_/ "
  local logo5 = "|_|\\_\\\\___| \\___||_|  |_|\\___|\\_\\_\\_/ "
  local logos = { logo, logo2, logo3, logo4, logo5 }
  local startY = math.floor(h / 2) - 5
  if startY < 1 then startY = 1 end
  for i, line in ipairs(logos) do
    local x = math.floor((w - #line) / 2) + 1
    if x < 1 then x = 1 end
    setTextColor(logoColors[i] or colors.white)
    setBgColor(COLORS.background)
    term.setCursorPos(x, startY + i - 1)
    term.write(line)
  end
  if tagline then
    local ty = startY + #logos + 1
    local tx = math.floor((w - #tagline) / 2) + 1
    if tx < 1 then tx = 1 end
    setTextColor(COLORS.textDim)
    setBgColor(COLORS.background)
    term.setCursorPos(tx, ty)
    term.write(tagline)
  end
  resetColors()
end

return ui
