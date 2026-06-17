local MODEM_SIDE = "top"
local PROTOCOL = "cosmim"
local DATA_DIR = "/cosmim_data"

local function ensureDir(path)
  if not fs.exists(path) then
    fs.makeDir(path)
  end
end

local function readFile(path)
  if not fs.exists(path) then return nil end
  local file = fs.open(path, "r")
  local content = file.readAll()
  file.close()
  return content
end

local function writeFile(path, content)
  ensureDir(fs.getDir(path))
  local file = fs.open(path, "w")
  file.write(content)
  file.close()
end

local function serialize(data)
  return textutils.serialize(data)
end

local function deserialize(str)
  if not str or str == "" then return nil end
  local ok, result = pcall(textutils.unserialize, str)
  if ok then return result end
  return nil
end

local function hashPassword(password)
  return textutils.sha256(password)
end

local function generateToken()
  return textutils.sha256(tostring(os.clock()) .. tostring(math.random()) .. tostring(os.time()))
end

local function generateId()
  local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
  local id = ""
  for i = 1, 8 do
    id = id .. chars:sub(math.random(1, #chars), math.random(1, #chars))
  end
  return id
end

local GAMES_DIR = DATA_DIR .. "/games"
local USERS_DIR = DATA_DIR .. "/users"
local CARDS_FILE = DATA_DIR .. "/credit_cards.txt"
local PURCHASES_FILE = DATA_DIR .. "/purchases.txt"
local TRANSACTIONS_FILE = DATA_DIR .. "/transactions.txt"

local function initStorage()
  ensureDir(DATA_DIR)
  ensureDir(GAMES_DIR)
  ensureDir(USERS_DIR)
  if not fs.exists(CARDS_FILE) then writeFile(CARDS_FILE, serialize({})) end
  if not fs.exists(PURCHASES_FILE) then writeFile(PURCHASES_FILE, serialize({})) end
  if not fs.exists(TRANSACTIONS_FILE) then writeFile(TRANSACTIONS_FILE, serialize({})) end
end

local function getUser(username)
  local path = USERS_DIR .. "/" .. username .. ".txt"
  return deserialize(readFile(path))
end

local function saveUser(user)
  local path = USERS_DIR .. "/" .. user.username .. ".txt"
  writeFile(path, serialize(user))
end

local function getUserByToken(token)
  local list = fs.list(USERS_DIR)
  for _, filename in ipairs(list) do
    local user = deserialize(readFile(USERS_DIR .. "/" .. filename))
    if user and user.token == token then
      return user
    end
  end
  return nil
end

local function getAllGames()
  local games = {}
  if not fs.exists(GAMES_DIR) then return games end
  local list = fs.list(GAMES_DIR)
  for _, dirname in ipairs(list) do
    local metaPath = GAMES_DIR .. "/" .. dirname .. "/metadata.txt"
    local meta = deserialize(readFile(metaPath))
    if meta then
      table.insert(games, meta)
    end
  end
  return games
end

local function getGame(gameId)
  local metaPath = GAMES_DIR .. "/" .. gameId .. "/metadata.txt"
  return deserialize(readFile(metaPath))
end

local function saveGame(gameId, meta)
  local dir = GAMES_DIR .. "/" .. gameId
  ensureDir(dir)
  writeFile(dir .. "/metadata.txt", serialize(meta))
end

local function getAllPurchases()
  return deserialize(readFile(PURCHASES_FILE)) or {}
end

local function saveAllPurchases(purchases)
  writeFile(PURCHASES_FILE, serialize(purchases))
end

local function getAllTransactions()
  return deserialize(readFile(TRANSACTIONS_FILE)) or {}
end

local function saveAllTransactions(transactions)
  writeFile(TRANSACTIONS_FILE, serialize(transactions))
end

local function getAllCards()
  return deserialize(readFile(CARDS_FILE)) or {}
end

local function saveAllCards(cards)
  writeFile(CARDS_FILE, serialize(cards))
end

local function handleRegister(data)
  local username = data.username
  local password = data.password
  local displayName = data.display_name or username

  if not username or not password then
    return { success = false, error = "Username and password required" }
  end

  if username:len() < 3 then
    return { success = false, error = "Username must be at least 3 characters" }
  end

  if getUser(username) then
    return { success = false, error = "Username already taken" }
  end

  local token = generateToken()
  local user = {
    username = username,
    password = hashPassword(password),
    display_name = displayName,
    bio = "",
    role = "user",
    credits = 0,
    token = token
  }
  saveUser(user)

  return {
    success = true,
    data = {
      token = token,
      user = {
        username = user.username,
        display_name = user.display_name,
        role = user.role,
        credits = user.credits,
        bio = user.bio
      }
    }
  }
end

local function handleLogin(data)
  local username = data.username
  local password = data.password

  if not username or not password then
    return { success = false, error = "Username and password required" }
  end

  local user = getUser(username)
  if not user then
    return { success = false, error = "Invalid username or password" }
  end

  if user.password ~= hashPassword(password) then
    return { success = false, error = "Invalid username or password" }
  end

  user.token = generateToken()
  saveUser(user)

  return {
    success = true,
    data = {
      token = user.token,
      user = {
        username = user.username,
        display_name = user.display_name,
        role = user.role,
        credits = user.credits,
        bio = user.bio
      }
    }
  }
end

local function handleGetProfile(data, user)
  return {
    success = true,
    data = {
      username = user.username,
      display_name = user.display_name,
      role = user.role,
      credits = user.credits,
      bio = user.bio
    }
  }
end

local function handleUpdateProfile(data, user)
  if data.display_name then
    if data.display_name:len() < 1 or data.display_name:len() > 32 then
      return { success = false, error = "Display name must be 1-32 characters" }
    end
    user.display_name = data.display_name
  end
  if data.bio then
    user.bio = data.bio
  end
  saveUser(user)
  return { success = true, data = { message = "Profile updated" } }
end

local function handlePublishGame(data, user)
  if user.role ~= "developer" then
    return { success = false, error = "You need a Developer account to publish games" }
  end

  local name = data.name
  local description = data.description or ""
  local price = data.price or 0

  if not name or name:len() < 1 then
    return { success = false, error = "Game name required" }
  end

  if price < 0 then
    return { success = false, error = "Price cannot be negative" }
  end

  local gameId = generateId()
  local meta = {
    id = gameId,
    name = name,
    description = description,
    developer = user.username,
    price = price,
    version = "1.0",
    downloads = 0,
    has_icon = data.has_icon or false,
    has_file = data.has_file or false,
    icon_size = data.icon_size or 0,
    file_size = data.file_size or 0
  }

  local dir = GAMES_DIR .. "/" .. gameId
  ensureDir(dir)
  saveGame(gameId, meta)

  return {
    success = true,
    data = {
      game = meta,
      message = "Game created! You can now upload the icon and game file."
    }
  }
end

local function handleUploadIcon(data, user)
  local gameId = data.game_id
  local meta = getGame(gameId)
  if not meta then return { success = false, error = "Game not found" } end

  if meta.developer ~= user.username then
    return { success = false, error = "Not your game" }
  end

  local dir = GAMES_DIR .. "/" .. gameId
  ensureDir(dir)

  if data.icon_data then
    writeFile(dir .. "/icon", data.icon_data)
    meta.has_icon = true
    meta.icon_size = #data.icon_data
    saveGame(gameId, meta)
  end

  return { success = true, data = { message = "Icon uploaded" } }
end

local function handleUploadGameFile(data, user)
  local gameId = data.game_id
  local meta = getGame(gameId)
  if not meta then return { success = false, error = "Game not found" } end

  if meta.developer ~= user.username then
    return { success = false, error = "Not your game" }
  end

  local dir = GAMES_DIR .. "/" .. gameId
  ensureDir(dir)

  if data.file_data then
    writeFile(dir .. "/game.lua", data.file_data)
    meta.has_file = true
    meta.file_size = #data.file_data
    saveGame(gameId, meta)
  end

  return { success = true, data = { message = "Game uploaded" } }
end

local function handleUploadGameDir(data, user)
  local gameId = data.game_id
  local meta = getGame(gameId)
  if not meta then return { success = false, error = "Game not found" } end

  if meta.developer ~= user.username then
    return { success = false, error = "Not your game" }
  end

  local dir = GAMES_DIR .. "/" .. gameId
  ensureDir(dir)

  if data.files and type(data.files) == "table" then
    local gameDir = dir .. "/game"
    if fs.exists(gameDir) then
      fs.delete(gameDir)
    end
    ensureDir(gameDir)
    for filename, content in pairs(data.files) do
      writeFile(gameDir .. "/" .. filename, content)
    end
    meta.has_file = true
    meta.file_size = #serialize(data.files)
    meta.is_directory = true
    saveGame(gameId, meta)
  end

  return { success = true, data = { message = "Game directory uploaded" } }
end

local function handleListGames(data)
  local games = getAllGames()
  local filter = data.filter or "all"

  local results = {}
  for _, game in ipairs(games) do
    if filter == "all" or filter == game.developer then
      table.insert(results, {
        id = game.id,
        name = game.name,
        description = game.description,
        developer = game.developer,
        price = game.price,
        version = game.version,
        downloads = game.downloads,
        has_icon = game.has_icon,
        has_file = game.has_file
      })
    end
  end

  return { success = true, data = { games = results } }
end

local function handleGetGame(data)
  local gameId = data.game_id
  local meta = getGame(gameId)
  if not meta then return { success = false, error = "Game not found" } end

  return {
    success = true,
    data = {
      id = meta.id,
      name = meta.name,
      description = meta.description,
      developer = meta.developer,
      price = meta.price,
      version = meta.version,
      downloads = meta.downloads,
      has_icon = meta.has_icon,
      has_file = meta.has_file
    }
  }
end

local function handleDownloadIcon(data)
  local gameId = data.game_id
  local meta = getGame(gameId)
  if not meta then return { success = false, error = "Game not found" } end

  local iconPath = GAMES_DIR .. "/" .. gameId .. "/icon"
  local iconData = readFile(iconPath)
  if not iconData then return { success = false, error = "No icon" } end

  return { success = true, data = { icon_data = iconData } }
end

local function handleDownloadGame(data, user)
  local gameId = data.game_id
  local meta = getGame(gameId)
  if not meta then return { success = false, error = "Game not found" } end

  local purchases = getAllPurchases()
  local owned = false
  if user then
    for _, p in ipairs(purchases) do
      if p.user == user.username and p.game_id == gameId then
        owned = true
        break
      end
    end
  end

  if meta.price > 0 and not owned and (not user or user.role ~= "developer") then
    return { success = false, error = "Game not purchased" }
  end

  if user and meta.developer == user.username then
    owned = true
  end

  if meta.price > 0 and not owned then
    return { success = false, error = "Game not purchased" }
  end

  local dir = GAMES_DIR .. "/" .. gameId

  if fs.exists(dir .. "/game") and fs.isDir(dir .. "/game") then
    local files = {}
    local gameFiles = fs.list(dir .. "/game")
    for _, filename in ipairs(gameFiles) do
      local content = readFile(dir .. "/game/" .. filename)
      if content then
        files[filename] = content
      end
    end
    return { success = true, data = { files = files, is_directory = true } }
  end

  local gameData = readFile(dir .. "/game.lua")
  if not gameData then return { success = false, error = "Game file not found" } end

  return { success = true, data = { file_data = gameData, is_directory = false } }
end

local function handleUpdateGame(data, user)
  local gameId = data.game_id
  local meta = getGame(gameId)
  if not meta then return { success = false, error = "Game not found" } end

  if meta.developer ~= user.username then
    return { success = false, error = "Not your game" }
  end

  if data.name then meta.name = data.name end
  if data.description then meta.description = data.description end
  if data.price ~= nil then
    if data.price < 0 then return { success = false, error = "Price cannot be negative" } end
    meta.price = data.price
  end
  if data.version then meta.version = data.version end

  saveGame(gameId, meta)
  return { success = true, data = { message = "Game updated" } }
end

local function handleDeleteGame(data, user)
  local gameId = data.game_id
  local meta = getGame(gameId)
  if not meta then return { success = false, error = "Game not found" } end

  if meta.developer ~= user.username then
    return { success = false, error = "Not your game" }
  end

  fs.delete(GAMES_DIR .. "/" .. gameId)
  return { success = true, data = { message = "Game deleted" } }
end

local function handleGetMyGames(data, user)
  local games = getAllGames()
  local myGames = {}
  for _, game in ipairs(games) do
    if game.developer == user.username then
      table.insert(myGames, game)
    end
  end
  return { success = true, data = { games = myGames } }
end

local function handlePurchaseGame(data, user)
  local gameId = data.game_id
  local meta = getGame(gameId)
  if not meta then return { success = false, error = "Game not found" } end

  if meta.price <= 0 then
    return { success = false, error = "Game is free, no purchase needed" }
  end

  if meta.developer == user.username then
    return { success = false, error = "Cannot purchase your own game" }
  end

  local purchases = getAllPurchases()
  for _, p in ipairs(purchases) do
    if p.user == user.username and p.game_id == gameId then
      return { success = false, error = "Already purchased" }
    end
  end

  if user.credits < meta.price then
    return {
      success = false,
      error = "Insufficient credits. Need " .. tostring(meta.price) .. " CC, have " .. tostring(user.credits) .. " CC"
    }
  end

  user.credits = user.credits - meta.price
  saveUser(user)

  table.insert(purchases, {
    user = user.username,
    game_id = gameId,
    price = meta.price,
    purchased_at = tostring(os.time())
  })
  saveAllPurchases(purchases)

  meta.downloads = (meta.downloads or 0) + 1
  saveGame(gameId, meta)

  local transactions = getAllTransactions()
  table.insert(transactions, {
    user = user.username,
    amount = -meta.price,
    type = "purchase",
    reference = gameId,
    timestamp = tostring(os.time())
  })
  saveAllTransactions(transactions)

  return { success = true, data = { message = "Game purchased!", credits = user.credits } }
end

local function handleGetLibrary(data, user)
  local purchases = getAllPurchases()
  local games = getAllGames()
  local library = {}

  for _, purchase in ipairs(purchases) do
    if purchase.user == user.username then
      for _, game in ipairs(games) do
        if game.id == purchase.game_id then
          table.insert(library, {
            id = game.id,
            name = game.name,
            developer = game.developer,
            price = purchase.price,
            purchased_at = purchase.purchased_at,
            has_icon = game.has_icon
          })
          break
        end
      end
    end
  end

  return { success = true, data = { library = library } }
end

local function handleRedeemCard(data, user)
  local code = data.code
  if not code then return { success = false, error = "Card code required" } end

  local cards = getAllCards()
  for i, card in ipairs(cards) do
    if card.code == code then
      if card.redeemed_by then
        return { success = false, error = "Card already redeemed" }
      end

      card.redeemed_by = user.username
      card.redeemed_at = tostring(os.time())
      saveAllCards(cards)

      user.credits = (user.credits or 0) + card.amount
      saveUser(user)

      local transactions = getAllTransactions()
      table.insert(transactions, {
        user = user.username,
        amount = card.amount,
        type = "redeem",
        reference = code,
        timestamp = tostring(os.time())
      })
      saveAllTransactions(transactions)

      return {
        success = true,
        data = {
          message = "Redeemed " .. tostring(card.amount) .. " CC!",
          amount = card.amount,
          credits = user.credits
        }
      }
    end
  end

  return { success = false, error = "Invalid card code" }
end

local function handleGetBalance(data, user)
  return { success = true, data = { credits = user.credits } }
end

local function handleGetTransactions(data, user)
  local all = getAllTransactions()
  local mine = {}
  for _, t in ipairs(all) do
    if t.user == user.username then
      table.insert(mine, t)
    end
  end
  return { success = true, data = { transactions = mine } }
end

local function handleUpgradeToDeveloper(data, user)
  if user.role == "developer" then
    return { success = false, error = "Already a developer" }
  end
  user.role = "developer"
  saveUser(user)
  return { success = true, data = { message = "Upgraded to Developer!", role = "developer" } }
end

local ROUTES = {
  register = handleRegister,
  login = handleLogin,
  get_profile = handleGetProfile,
  update_profile = handleUpdateProfile,
  publish_game = handlePublishGame,
  upload_icon = handleUploadIcon,
  upload_game_file = handleUploadGameFile,
  upload_game_dir = handleUploadGameDir,
  list_games = handleListGames,
  get_game = handleGetGame,
  download_icon = handleDownloadIcon,
  download_game = handleDownloadGame,
  update_game = handleUpdateGame,
  delete_game = handleDeleteGame,
  get_my_games = handleGetMyGames,
  purchase_game = handlePurchaseGame,
  get_library = handleGetLibrary,
  redeem_card = handleRedeemCard,
  get_balance = handleGetBalance,
  get_transactions = handleGetTransactions,
  upgrade_to_developer = handleUpgradeToDeveloper
}

local function processRequest(senderId, message)
  local ok, req = pcall(textutils.unserialiseJSON, message)
  if not ok or type(req) ~= "table" then
    rednet.send(senderId, textutils.serialiseJSON({ success = false, error = "Invalid request format" }), PROTOCOL)
    return
  end

  local handler = ROUTES[req.type]
  if not handler then
    rednet.send(senderId, textutils.serialiseJSON({ success = false, error = "Unknown request type: " .. tostring(req.type) }), PROTOCOL)
    return
  end

  local user = nil
  if req.auth then
    user = getUserByToken(req.auth)
    if not user then
      rednet.send(senderId, textutils.serialiseJSON({ success = false, error = "Invalid or expired token" }), PROTOCOL)
      return
    end
  end

  if req.type ~= "register" and req.type ~= "login" and not user then
    rednet.send(senderId, textutils.serialiseJSON({ success = false, error = "Authentication required" }), PROTOCOL)
    return
  end

  local ok2, result = pcall(handler, req.data or {}, user)
  if not ok2 then
    print("[ERROR] Handler '" .. tostring(req.type) .. "' crashed: " .. tostring(result))
    rednet.send(senderId, textutils.serialiseJSON({ success = false, error = "Internal server error" }), PROTOCOL)
    return
  end

  local ok3, json = pcall(textutils.serialiseJSON, result)
  if not ok3 then
    print("[ERROR] Failed to serialise response for '" .. tostring(req.type) .. "': " .. tostring(result))
    rednet.send(senderId, textutils.serialiseJSON({ success = false, error = "Internal server error" }), PROTOCOL)
    return
  end

  rednet.send(senderId, json, PROTOCOL)
end

local function main()
  term.clear()
  term.setCursorPos(1, 1)
  print("Cosmim Server v1.0")
  print("Initializing...")
  print()

  if not rednet then
    print("Error: Rednet API not available!")
    print("Make sure this computer has a modem attached.")
    return
  end

  local ok, err = pcall(rednet.open, MODEM_SIDE)
  if not ok then
    print("Error opening modem on " .. MODEM_SIDE .. ":")
    print(tostring(err))
    print("Try changing MODEM_SIDE in the script.")
    return
  end

  math.randomseed(os.time())
  initStorage()

  rednet.host(PROTOCOL, "cosmim_server")
  print("Cosmim Server is running!")
  print("Protocol: " .. PROTOCOL)
  print("Modem: " .. MODEM_SIDE)
  print("Data: " .. DATA_DIR)
  print()
  print("Press any key to shut down.")

  local running = true
  while running do
    local event, p1, p2, p3, p4 = os.pullEvent()
    if event == "rednet_message" then
      local senderId = p1
      local message = p2
      local protocol = p3
      if protocol == PROTOCOL then
        print("[REQ] from " .. tostring(senderId) .. ": " .. (message:sub(1, 80) .. (message:len() > 80 and "..." or "")))
        local ok, err = pcall(processRequest, senderId, message)
        if not ok then
          print("[ERROR] processRequest crashed: " .. tostring(err))
          local ok2, json = pcall(textutils.serialiseJSON, { success = false, error = "Internal server error" })
          if ok2 then
            rednet.send(senderId, json, PROTOCOL)
          end
        end
      end
    elseif event == "key" then
      running = false
    end
  end

  rednet.close(MODEM_SIDE)
  print("Server shut down.")
end

local ok, err = pcall(main)
if not ok then
  print("Fatal error: " .. tostring(err))
  print(debug.traceback())
end
