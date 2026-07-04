--[[ =========================================================================
  Rimearc infinite pool spawner  (design: P1 - native infinite bag)

  Injected onto the Arctic Zephyr class ENVELOPE via the CCC perk trick, so
  self = the envelope. We must NOT build at envelope-draw time; instead we
  poll (like spawn_deck.lua) until the character SHEET appears and holds a
  stable position - i.e. the tuckbox has been unpacked - then build ONE
  infinite bag ~15 units to the sheet's right, holding a fully-configured
  Rimearc token. Pull one out and it spawns with the shadow overlay behavior.
============================================================================ ]]

local CONFIG = {
  TOKEN_NAME  = "Rimearc",
  TOKEN_IMAGE = "https://i.imgur.com/W77V4kK.png",   -- transparent PNG
  TOKEN_TAGS  = { "Has Action", "Has Aid Tokens", "Has Conditions", "Has Health", "Terrain" },
  TOKEN_XML   = '<Include src="Overlays/Overlay.xml" />',

  -- Custom_Token traces the image alpha -> clean shape, no whitespace.
  TOKEN_SCALE          = { 0.6, 1, 0.6 },  -- final PULLED-OUT (map) size; TUNE to a shadow.
  TOKEN_THICKNESS      = 0.2,
  TOKEN_MERGE_DISTANCE = 15,

  TOKEN_SCRIPT_URL = "https://raw.githubusercontent.com/kiltev/haven-unscorched/main/scripts/token.lua?v=1",

  -- The pool is anchored to (and appears when) THIS object exists + settles.
  ANCHOR_TAG           = "Character Sheet",
  ANCHOR_NAME_CONTAINS = "Arctic Zephyr",

  POOL_NAME         = "Rimearc Pool",
  POOL_RIGHT_OFFSET = 15,   -- units to the anchor's right (flip sign if it lands left)
  POOL_UP_OFFSET    = 2,

  POLL_INTERVAL = 0.5,
  MAX_TRIES     = 240,      -- ~2 min of polling before giving up

  ENABLE_DEBUG = true,      -- "Rebuild Pool" button + logging
}

local tokenScript = nil
local done = false

-- ---- helpers ----------------------------------------------------------

local function poolExists()
  for _, o in ipairs(getObjects()) do
    if o.getName() == CONFIG.POOL_NAME then return o end
  end
  return nil
end

local function findAnchor()
  for _, o in ipairs(getObjectsWithTag(CONFIG.ANCHOR_TAG)) do
    local n = o.getName()
    if n and n:find(CONFIG.ANCHOR_NAME_CONTAINS, 1, true) then return o end
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
  o.UI.setXml(CONFIG.TOKEN_XML)
  o.setLuaScript(tokenScript)
  -- NB: do NOT reload() here - reload invalidates the handle and putObject
  -- would then receive a dead reference. putObject captures the data as set.
end

local function buildPool(anchor)
  if poolExists() then printToAll("[Rimearc] pool already exists", "Yellow"); return end
  if not tokenScript then printToAll("[Rimearc] token script not loaded", "Red"); return end
  if not anchor then printToAll("[Rimearc] no anchor", "Red"); return end

  local p = anchor.getPosition()
  local r = anchor.getTransformRight()
  local pos = {
    p.x + r.x * CONFIG.POOL_RIGHT_OFFSET,
    p.y + CONFIG.POOL_UP_OFFSET,
    p.z + r.z * CONFIG.POOL_RIGHT_OFFSET,
  }

  local ok, err = pcall(function()
    spawnObject({
      type = "Infinite_Bag",
      position = pos,
      sound = false,
      callback_function = function(bag)
        bag.setName(CONFIG.POOL_NAME)

        spawnObject({
          type = "Custom_Token",
          position = { pos[1], pos[2] + 3, pos[3] },
          scale = CONFIG.TOKEN_SCALE,
          sound = false,
          callback_function = function(tok)
            dressTemplate(tok)
            -- wait for the custom image to finish loading, then store the
            -- (still-valid) token as the bag's template.
            Wait.condition(function()
              if CONFIG.ENABLE_DEBUG then
                local s = tok.getScale()
                log(string.format("[Rimearc] template scale = %.3f, %.3f, %.3f", s.x, s.y, s.z))
              end
              bag.putObject(tok)
              printToAll("[Rimearc] pool built - pull a Rimearc from it.", "Green")
            end, function()
              return not tok.spawning and not tok.loading_custom
            end)
          end,
        })
      end,
    })
  end)
  if not ok then printToAll("[Rimearc] build failed: " .. tostring(err), "Red") end
end

-- Poll until the character sheet exists and holds still, then build once.
local last, stable, tries = nil, 0, 0
local function watch()
  if done or poolExists() then done = true; return end
  if not tokenScript then Wait.time(watch, CONFIG.POLL_INTERVAL); return end

  tries = tries + 1
  local anchor = findAnchor()
  if anchor then
    local p = anchor.getPosition()
    if last and math.abs(p.x - last.x) < 0.05 and math.abs(p.y - last.y) < 0.05
       and math.abs(p.z - last.z) < 0.05 then
      stable = stable + 1
    else
      stable = 0
    end
    last = { x = p.x, y = p.y, z = p.z }
    if stable >= 3 then
      done = true
      buildPool(anchor)
      return
    end
  end

  if tries < CONFIG.MAX_TRIES then
    Wait.time(watch, CONFIG.POLL_INTERVAL)
  elseif CONFIG.ENABLE_DEBUG then
    log("[Rimearc] gave up finding anchor tag='" .. CONFIG.ANCHOR_TAG ..
        "' name~'" .. CONFIG.ANCHOR_NAME_CONTAINS .. "'")
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

  WebRequest.get(CONFIG.TOKEN_SCRIPT_URL, function(r)
    if r.is_error then
      printToAll("[Rimearc] token.lua fetch error: " .. tostring(r.error), "Red")
    elseif r.response_code ~= 200 then
      printToAll("[Rimearc] token.lua HTTP " .. tostring(r.response_code) ..
                 " - check TOKEN_SCRIPT_URL", "Red")
    elseif not r.text or r.text == "" then
      printToAll("[Rimearc] token.lua returned empty body", "Red")
    else
      tokenScript = r.text
      printToAll("[Rimearc] token.lua loaded (" .. #r.text .. " bytes)", "Green")
    end
  end)

  Wait.time(watch, CONFIG.POLL_INTERVAL)
end

function onRebuildPool()
  local existing = poolExists()
  if existing then existing.destruct() end
  done, last, stable, tries = false, nil, 0, 0
  Wait.time(watch, 0.5)
end
