-- Install Cosmim Client on this computer
-- Run this script to download and set up Cosmim
-- Usage: install_client

local BASE_URL = "https://raw.githubusercontent.com/yourusername/cosmim/main/client/"

local files = {
  "cosmim.lua",
  "lib/utils.lua",
  "lib/ui.lua",
  "lib/api.lua",
  "screens/login.lua",
  "screens/store.lua",
  "screens/library.lua",
  "screens/credits.lua",
  "screens/developer.lua",
  "screens/profile.lua"
}

local function ensureDir(path)
  if not fs.exists(path) then
    fs.makeDir(path)
  end
end

local function downloadFile(filename)
  local url = BASE_URL .. filename
  write("Downloading " .. filename .. "... ")
  local response = http.get(url)
  if response then
    local content = response.readAll()
    response.close()

    local dir = fs.getDir(filename)
    if dir and dir ~= "" then
      ensureDir(dir)
    end

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

print("Cosmim Client Installer")
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
  print("Run 'cosmim' to start Cosmim!")
  print()
  print("Before running, make sure:")
  print("  - Your computer has a modem attached")
  print("  - The Cosmim server is running nearby")
  print("  - Rednet can reach the server (wired/wireless)")
else
  print("Some files failed to download.")
  print("Check the URL and try again.")
end
