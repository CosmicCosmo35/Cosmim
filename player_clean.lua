local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")
if not speaker then
    print("Error: No speaker peripheral found!")
    return
end
local CHUNK_SIZE = 4 * 1024
local W, H = term.getSize()
local COL = {
    bg        = colours.black,
    header_bg = colours.blue,
    header_fg = colours.white,
    dir_fg    = colours.yellow,
    file_fg   = colours.white,
    sel_bg    = colours.blue,
    sel_fg    = colours.white,
    status_bg = colours.grey,
    status_fg = colours.white,
    playing   = colours.lime,
    error_fg  = colours.red,
}
local cwd        = "/"
local entries    = {}
local selected   = 1
local scroll     = 0
local status     = "Select a .dfpwm file and press Enter to play"
local nowPlaying = nil
local stopFlag   = false
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function listDir(path)
    local list = {}
    for _, name in ipairs(fs.list(path)) do
        local full = fs.combine(path, name)
        table.insert(list, { name = name, isDir = fs.isDir(full) })
    end
    table.sort(list, function(a, b)
        if a.isDir ~= b.isDir then return a.isDir end
        return a.name:lower() < b.name:lower()
    end)
    return list
end
local function navigate(path)
    cwd      = path
    entries  = listDir(path)
    selected = 1
    scroll   = 0
end
local HEADER_H = 2
local STATUS_H = 2
local LIST_H   = H - HEADER_H - STATUS_H
local function drawHeader()
    term.setCursorPos(1, 1)
    term.setBackgroundColour(COL.header_bg)
    term.setTextColour(COL.header_fg)
    term.clearLine()
    local title = " \xbb DFPWM Player"
    term.write(title)
    term.setCursorPos(1, 2)
    term.clearLine()
    local pathLine = " " .. cwd
    if #pathLine > W then pathLine = pathLine:sub(#pathLine - W + 2) end
    term.write(pathLine)
end
local function drawList()
    if selected - 1 < scroll then scroll = selected - 1 end
    if selected - 1 >= scroll + LIST_H then scroll = selected - LIST_H end
    scroll = clamp(scroll, 0, math.max(0, #entries - LIST_H))
    for row = 1, LIST_H do
        local y    = HEADER_H + row
        local idx  = scroll + row
        local item = entries[idx]
        term.setCursorPos(1, y)
        if idx == selected and item then
            term.setBackgroundColour(COL.sel_bg)
            term.setTextColour(COL.sel_fg)
        else
            term.setBackgroundColour(COL.bg)
            term.setTextColour(item and (item.isDir and COL.dir_fg or COL.file_fg) or COL.bg)
        end
        term.clearLine()
        if item then
            local icon   = item.isDir and "\x10 " or "  "
            local suffix = item.isDir and "/" or ""
            local label  = icon .. item.name .. suffix
            if #label > W - 1 then label = label:sub(1, W - 4) .. "..." end
            term.write(" " .. label)
        end
    end
end
local function drawStatus()
    local y1 = H - 1
    local y2 = H
    term.setCursorPos(1, y1)
    term.setBackgroundColour(COL.status_bg)
    term.setTextColour(COL.playing)
    term.clearLine()
    if nowPlaying then
        local np = " \x10 " .. nowPlaying
        if #np > W then np = np:sub(1, W - 3) .. "..." end
        term.write(np)
    else
        term.setTextColour(COL.status_fg)
        term.write(" No file playing")
    end
    term.setCursorPos(1, y2)
    term.setBackgroundColour(COL.status_bg)
    term.setTextColour(COL.status_fg)
    term.clearLine()
    local hint = " Enter:Open  Bksp:Up  S:Stop  Q:Quit"
    term.write(hint)
end
local function redraw()
    term.setBackgroundColour(COL.bg)
    term.clear()
    drawHeader()
    drawList()
    drawStatus()
    term.setCursorPos(1, H)
end
local function playFile(path)
    stopFlag   = false
    nowPlaying = fs.getName(path)
    redraw()
    local decoder = dfpwm.make_decoder()
    local f, err  = fs.open(path, "rb")
    if not f then
        nowPlaying = nil
        status     = "Error: " .. (err or "cannot open file")
        redraw()
        return
    end
    while not stopFlag do
        local chunk = f.read(CHUNK_SIZE)
        if not chunk then break end
        local buffer = decoder(chunk)
        while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end
        os.pullEvent("speaker_audio_empty")
    end
    f.close()
    nowPlaying = nil
    redraw()
end
navigate("/")
redraw()
while true do
    local e, key = os.pullEvent("key")
    if key == keys.q then
        stopFlag = true
        break
    elseif key == keys.s then
        stopFlag = true
        nowPlaying = nil
        redraw()
    elseif key == keys.up then
        selected = clamp(selected - 1, 1, #entries)
        redraw()
    elseif key == keys.down then
        selected = clamp(selected + 1, 1, #entries)
        redraw()
    elseif key == keys.enter then
        local item = entries[selected]
        if item then
            local full = fs.combine(cwd, item.name)
            if item.isDir then
                navigate(full)
                redraw()
            else
                if item.name:lower():match("%.dfpwm$") then
                    playFile(full)
                else
                    status = "Not a .dfpwm file"
                    redraw()
                end
            end
        end
    elseif key == keys.backspace then
        local parent = fs.getDir(cwd)
        if parent ~= cwd then
            navigate(parent)
            redraw()
        end
    end
end
term.setBackgroundColour(colours.black)
term.setTextColour(colours.white)
term.clear()
term.setCursorPos(1, 1)
print("Bye!")
