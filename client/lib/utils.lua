local utils = {}

function utils.split(str, sep)
  if not str then return {} end
  sep = sep or " "
  local result = {}
  local pattern = ("([^%s]+)"):format(sep)
  for part in str:gmatch(pattern) do
    table.insert(result, part)
  end
  if #result == 0 then
    table.insert(result, str)
  end
  return result
end

function utils.trim(str)
  if not str then return "" end
  return str:match("^%s*(.-)%s*$") or str
end

function utils.wrapText(text, width)
  if not text or text == "" then return {} end
  local lines = {}
  for line in text:gmatch("[^\n]+") do
    while #line > width do
      local space = line:sub(width, width)
      local split = width
      if space ~= " " then
        split = line:match("^.+" .. width .. "()%s") or width
      end
      table.insert(lines, line:sub(1, split - 1))
      line = line:sub(split):match("^%s*(.*)")
    end
    if #line > 0 then
      table.insert(lines, line)
    end
  end
  if #lines == 0 then table.insert(lines, "") end
  return lines
end

function utils.centerText(text, width)
  local padding = math.floor((width - #text) / 2)
  if padding < 0 then padding = 0 end
  return string.rep(" ", padding) .. text
end

function utils.formatNumber(n)
  local s = tostring(n)
  local result = ""
  local count = 0
  for i = #s, 1, -1 do
    count = count + 1
    result = s:sub(i, i) .. result
    if count % 3 == 0 and i > 1 then
      result = "," .. result
    end
  end
  return result
end

function utils.timeAgo(timestamp)
  local now = os.time()
  local diff = now - tonumber(timestamp)
  if diff < 60 then return "just now"
  elseif diff < 3600 then return math.floor(diff / 60) .. "m ago"
  elseif diff < 86400 then return math.floor(diff / 3600) .. "h ago"
  else return math.floor(diff / 86400) .. "d ago"
  end
end

function utils.clamp(val, min, max)
  if val < min then return min end
  if val > max then return max end
  return val
end

function utils.tableContains(t, item)
  for _, v in ipairs(t) do
    if v == item then return true end
  end
  return false
end

function utils.saveToken(token)
  local file = fs.open(".cosmim_token", "w")
  file.write(token)
  file.close()
end

function utils.loadToken()
  if not fs.exists(".cosmim_token") then return nil end
  local file = fs.open(".cosmim_token", "r")
  local token = file.readAll()
  file.close()
  token = utils.trim(token)
  if token == "" then return nil end
  return token
end

function utils.clearToken()
  if fs.exists(".cosmim_token") then
    fs.delete(".cosmim_token")
  end
end

function utils.saveConfig(key, value)
  local path = ".cosmim_config"
  local config = {}
  if fs.exists(path) then
    local file = fs.open(path, "r")
    local ok, data = pcall(textutils.unserialize, file.readAll())
    file.close()
    if ok and type(data) == "table" then config = data end
  end
  config[key] = value
  local file = fs.open(path, "w")
  file.write(textutils.serialize(config))
  file.close()
end

function utils.loadConfig(key)
  local path = ".cosmim_config"
  if not fs.exists(path) then return nil end
  local file = fs.open(path, "r")
  local ok, data = pcall(textutils.unserialize, file.readAll())
  file.close()
  if ok and type(data) == "table" then return data[key] end
  return nil
end

function utils.saveUserData(username)
  utils.saveConfig("last_username", username)
end

function utils.loadLastUsername()
  return utils.loadConfig("last_username")
end

return utils
