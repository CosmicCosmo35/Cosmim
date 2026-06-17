-- Cosmim Card Generator
-- Run this on the server computer to generate Cosmim Card codes
-- Usage: generate_card <amount> [count]
-- Example: generate_card 50 5  (generates 5 cards worth 50 CC each)

local DATA_DIR = "/cosmim_data"
local CARDS_FILE = DATA_DIR .. "/credit_cards.txt"

local function ensureDir(path)
  if not fs.exists(path) then fs.makeDir(path) end
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

local function generateCode()
  local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  local segments = {}
  for s = 1, 4 do
    local seg = ""
    for i = 1, 4 do
      seg = seg .. chars:sub(math.random(1, #chars), math.random(1, #chars))
    end
    table.insert(segments, seg)
  end
  return "COSMIM-" .. table.concat(segments, "-")
end

local args = { ... }
if #args < 1 then
  print("Usage: generate_card <amount> [count]")
  print("Example: generate_card 50 5")
  return
end

local amount = tonumber(args[1])
local count = tonumber(args[2]) or 1

if not amount or amount < 1 then
  print("Invalid amount. Must be a positive number.")
  return
end

if count < 1 then count = 1 end

local cards = {}
local existingCards = deserialize(readFile(CARDS_FILE)) or {}
if type(existingCards) == "table" then
  for _, c in ipairs(existingCards) do
    table.insert(cards, c)
  end
end

print("Generating " .. tostring(count) .. " Cosmim Card(s)...")
print()

local generated = {}
for i = 1, count do
  local code = generateCode()
  local card = {
    code = code,
    amount = amount,
    redeemed_by = nil,
    redeemed_at = nil,
    created_at = tostring(os.time())
  }
  table.insert(cards, card)
  table.insert(generated, code)
  print("  " .. tostring(i) .. ". " .. code .. " - " .. tostring(amount) .. " CC")
end

writeFile(CARDS_FILE, serialize(cards))
print()
print("Saved " .. tostring(count) .. " card(s) to " .. CARDS_FILE)
print()
print("Share these codes with players!")
print("They can redeem them in the CosmiCredit Shop.")
