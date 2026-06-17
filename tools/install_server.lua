-- Install Cosmim Server on this computer
-- Run this script to download and set up the Cosmim server
-- Usage: install_server

local PROTOCOL = "cosmim"
local BASE_URL = "https://raw.githubusercontent.com/yourusername/cosmim/main/server/"

local files = {
  "cosmim_server.lua"
}

local function downloadFile(filename)
  local url = BASE_URL .. filename
  write("Downloading " .. filename .. "... ")
  local response = http.get(url)
  if response then
    local content = response.readAll()
    response.close()
    local file = fs.open(filename, "w")
    file.write(content)
    file.close()
    print("OK")
    return true
  else
    print("FAILED")
    return false
  end
end

print("Cosmim Server Installer")
print("=======================")
print()

if not http then
  print("HTTP API not available. Enable it in the CC:Tweaked config.")
  return
end

local ok = true
for _, filename in ipairs(files) do
  if not downloadFile(filename) then
    ok = false
  end
end

print()
if ok then
  print("Installation complete!")
  print("Run 'cosmim_server' to start the server.")
  print()
  print("Make sure a modem is attached before starting.")
else
  print("Some files failed to download.")
  print("Check the URL and try again.")
end
