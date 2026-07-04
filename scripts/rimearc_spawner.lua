--[[ =========================================================================
  Rimearc infinite pool spawner  (design: P1 - native infinite bag)

  Injected onto the Arctic Zephyr class ENVELOPE via the CCC perk trick, so
  self = the envelope. It polls (like spawn_deck.lua) until the character
  sheet / standee appears + settles, then builds ONE infinite bag at a world
  offset from it, holding a Rimearc token you can pull infinitely.

  NOTE: the full FHE shadow bundle needs UI the mod injects through its own
  spawn pipeline, which a raw-spawned token never gets -> it crashes. So the
  default token is MINIMAL (image + tags), which works cleanly. Flip
  USE_SHADOW_BUNDLE only if the token is spawned via the mod (not here).
============================================================================ ]]

local CONFIG = {
  TOKEN_NAME  = "Rimearc",
  TOKEN_IMAGE = "https://i.imgur.com/W77V4kK.png",   -- transparent PNG
  TOKEN_TAGS  = { "Has Action", "Has Aid Tokens", "Has Conditions", "Has Health", "Terrain" },

  TOKEN_SCALE          = { 0.6, 1, 0.6 },  -- final PULLED-OUT (map) size; TUNE.
  TOKEN_THICKNESS      = 0.2,
  TOKEN_MERGE_DISTANCE = 15,

  USE_SHADOW_BUNDLE = false,               -- false = minimal token (works); true = attach bundle (crashes when raw-spawned)
  TOKEN_SCRIPT_URL  = "https://raw.githubusercontent.com/kiltev/haven-unscorched/main/scripts/token.lua?v=1",

  ANCHOR_NAME_CONTAINS = "Arctic Zephyr",

  POOL_NAME   = "Rimearc Pool",
  POOL_OFFSET = { 15, 2, 0 },              -- WORLD-space offset from the anchor; tune these 3 numbers.

  POLL_INTERVAL = 0.5,
  MAX_TRIES     = 240,

  ENABLE_DEBUG = true,
}

local tokenScript = nil
local done = false

-- ---- helpers ----------------------------------------------------------

local function dbg(msg)
  if CONFIG.ENABLE_DEBUG then log("[Rimearc] " .. msg) end
end

local function scriptReady()
  return (not CONFIG.USE_SHADOW_BUNDLE) or (tokenScript ~= nil)
end

local function poolExists()
  for _, o in ipairs(getObjects()) do
    if o.getName() == CONFIG.POOL_NAME then return o end
  end
  return nil
end

local function findAnchor()
  for _, tag in ipairs({ "Character Sheet", "Character" }) do
    for _, o in ipairs(getObjectsWithTag(tag)) do
      local n = o.getName() or ""
      if o ~= self
         and n:find(CONFIG.ANCHOR_NAME_CONTAINS, 1, true)
         and not n:find("envelope", 1, true) then
        return o, tag
      end
    end
  end
  return nil
end

local function dressTemplate(o)
  o.setCustomObject({
    image = CONFIG.TOKEN_IMAGE,
    thickness = CONFIG.TOKEN_THICKNESS,
    merge_distance = CONFIG.TOKEN_MERGE_DISTANCE,
    stackable = false,
  })
  o.setName(CONFIG.TOKEN_NAME)
  o.setTags(CONFIG.TOKEN_TAGS)
  o.setScale(CONFIG.TOKEN_SCALE)
  o.UI.setXml("<Panel />")
  if CONFIG.USE_SHADOW_BUNDLE and tokenScript then
    o.setLuaScript(tokenScript)
  end
end

local function buildPool(anchor)
  if poolExists() then printToAll("[Rimearc] pool already exists", "Yellow"); return end
  if not scriptReady() then printToAll("[Rimearc] token script not loaded", "Red"); return end
  if not anchor then printToAll("[Rimearc] no anchor", "Red"); return end

  local p = anchor.getPosition()
  local o = CONFIG.POOL_OFFSET
  local pos = { p.x + o[1], p.y + o[2], p.z + o[3] }
  dbg("building pool at anchor " .. anchor.getName())

  spawnObject({
    type = "Infinite_Bag",
    position = pos,
    sound = false,
    callback_function = function(bag)
      if not bag then printToAll("[Rimearc] bag spawn returned nil", "Red"); return end
      bag.setName(CONFIG.POOL_NAME)

      spawnObject({
        type = "Custom_Token",
        position = { pos[1], pos[2] + 3, pos[3] },
        scale = CONFIG.TOKEN_SCALE,
        sound = false,
        callback_function = function(tok)
          if not tok then printToAll("[Rimearc] token spawn returned nil", "Red"); return end
          local okDress, errDress = pcall(dressTemplate, tok)
          if not okDress then
            printToAll("[Rimearc] dress failed: " .. tostring(errDress), "Red"); return
          end

          Wait.condition(function()
            local ok, err = pcall(function() bag.putObject(tok) end)
            if ok then
              dbg("putObject ok; bag qty=" .. tostring(bag.getQuantity()))
              printToAll("[Rimearc] pool built - pull a Rimearc from it.", "Green")
            else
              printToAll("[Rimearc] putObject failed: " .. tostring(err), "Red")
            end
          end,
          function() return not tok.spawning and not tok.loading_custom end,
          8,
          function() printToAll("[Rimearc] token never finished loading (8s)", "Red") end)
        end,
      })
    end,
  })
end

-- Poll until the anchor exists and holds still, then build once.
local last, stable, tries = nil, 0, 0
local function watch()
  if done then return end
  if poolExists() then dbg("pool already exists - watcher stopping"); done = true; return end
  if not scriptReady() then Wait.time(watch, CONFIG.POLL_INTERVAL); return end

  tries = tries + 1
  local anchor, foundTag = findAnchor()
  if tries % 4 == 1 then
    dbg("watch try " .. tries .. ": anchor=" ..
        (anchor and (anchor.getName() .. " [" .. foundTag .. "]") or "NONE") .. " stable=" .. stable)
  end
  if anchor then
    local ap = anchor.getPosition()
    if last and math.abs(ap.x - last.x) < 0.05 and math.abs(ap.y - last.y) < 0.05
       and math.abs(ap.z - last.z) < 0.05 then
      stable = stable + 1
    else
      stable = 0
    end
    last = { x = ap.x, y = ap.y, z = ap.z }
    if stable >= 3 then
      done = true
      buildPool(anchor)
      return
    end
  end

  if tries < CONFIG.MAX_TRIES then
    Wait.time(watch, CONFIG.POLL_INTERVAL)
  else
    dbg("gave up finding anchor name~'" .. CONFIG.ANCHOR_NAME_CONTAINS .. "'")
  end
end

-- ---- entry ------------------------------------------------------------

function onLoad()
  if CONFIG.ENABLE_DEBUG then
    self.createButton({
      click_function = "onRebuildPool", function_owner = self,
      label = "Rebuild Rimearc Pool", position = { 0, 0.2, 2 },
      width = 1600, height = 400, font_size = 180,
      color = { 0, 0, 0, 0.9 }, font_color = { 1, 1, 1, 1 },
    })
  end

  if CONFIG.USE_SHADOW_BUNDLE then
    WebRequest.get(CONFIG.TOKEN_SCRIPT_URL, function(r)
      if r.is_error or r.response_code ~= 200 or not r.text or r.text == "" then
        printToAll("[Rimearc] token.lua fetch failed (HTTP " .. tostring(r.response_code) .. ")", "Red")
      else
        tokenScript = r.text
        printToAll("[Rimearc] token.lua loaded (" .. #r.text .. " bytes)", "Green")
      end
    end)
  end

  Wait.time(watch, CONFIG.POLL_INTERVAL)
end

function onRebuildPool()
  local existing = poolExists()
  if existing then existing.destruct() end
  done, last, stable, tries = false, nil, 0, 0
  Wait.time(watch, 0.5)
end
