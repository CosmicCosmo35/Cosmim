local utils = require("lib.utils")

local api = {}

local PROTOCOL = "cosmim"
local TIMEOUT = 5
local serverId = nil

function api.findServer()
  local results = rednet.lookup(PROTOCOL, "cosmim_server")
  if results then
    if type(results) == "table" then
      serverId = results[1]
    else
      serverId = results
    end
    return serverId
  end
  return nil
end

function api.getServerId()
  return serverId
end

function api.setServerId(id)
  serverId = id
end

function api.send(type, data, auth)
  if not serverId then
    return nil, "Not connected to server"
  end

  local msg = {
    type = type,
    data = data or {}
  }
  if auth then
    msg.auth = auth
  end

  local json = textutils.serialiseJSON(msg)
  rednet.send(serverId, json, PROTOCOL)

  local id, message = rednet.receive(PROTOCOL, TIMEOUT)
  if not id then
    return nil, "Server response timeout"
  end

  local ok, result = pcall(textutils.unserialiseJSON, message)
  if not ok then
    return nil, "Invalid server response"
  end

  if not result.success then
    return nil, result.error or "Request failed"
  end

  return result.data, nil
end

function api.register(username, password, displayName)
  return api.send("register", {
    username = username,
    password = password,
    display_name = displayName
  })
end

function api.login(username, password)
  return api.send("login", {
    username = username,
    password = password
  })
end

function api.getProfile(token)
  return api.send("get_profile", {}, token)
end

function api.updateProfile(token, data)
  return api.send("update_profile", data, token)
end

function api.listGames(token, filter)
  return api.send("list_games", { filter = filter or "all" }, token)
end

function api.getGame(token, gameId)
  return api.send("get_game", { game_id = gameId }, token)
end

function api.downloadGame(token, gameId)
  return api.send("download_game", { game_id = gameId }, token)
end

function api.downloadIcon(token, gameId)
  return api.send("download_icon", { game_id = gameId }, token)
end

function api.publishGame(token, name, description, price)
  return api.send("publish_game", {
    name = name,
    description = description or "",
    price = price or 0
  }, token)
end

function api.uploadIcon(token, gameId, iconData)
  return api.send("upload_icon", {
    game_id = gameId,
    icon_data = iconData
  }, token)
end

function api.uploadGameFile(token, gameId, fileData)
  return api.send("upload_game_file", {
    game_id = gameId,
    file_data = fileData
  }, token)
end

function api.uploadGameDir(token, gameId, files)
  return api.send("upload_game_dir", {
    game_id = gameId,
    files = files
  }, token)
end

function api.updateGame(token, gameId, data)
  data.game_id = gameId
  return api.send("update_game", data, token)
end

function api.deleteGame(token, gameId)
  return api.send("delete_game", { game_id = gameId }, token)
end

function api.getMyGames(token)
  return api.send("get_my_games", {}, token)
end

function api.purchaseGame(token, gameId)
  return api.send("purchase_game", { game_id = gameId }, token)
end

function api.getLibrary(token)
  return api.send("get_library", {}, token)
end

function api.redeemCard(token, code)
  return api.send("redeem_card", { code = code }, token)
end

function api.getBalance(token)
  return api.send("get_balance", {}, token)
end

function api.getTransactions(token)
  return api.send("get_transactions", {}, token)
end

function api.upgradeToDeveloper(token)
  return api.send("upgrade_to_developer", {}, token)
end

return api
