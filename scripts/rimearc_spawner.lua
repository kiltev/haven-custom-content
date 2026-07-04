--[[ =========================================================================
  Rimearc infinite pool spawner  (design: P1 - native infinite bag)

  Inject onto the "Arctic Zephyr" character sheet via the CCC perk trick.
  self = that sheet. On load it builds ONE infinite bag ~15 units to the
  sheet's right, holding a fully-configured Rimearc token. Pull one out and
  a Rimearc spawns with the shadow overlay behavior (conditions/aid/health/
  action) - exactly like the Deathwalker shadow pool.

  The condition/poll trigger is retired; this replaces it.
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

  -- Raw URL of the tile script (the shadow Overlays.Overlay bundle).
  -- Host that bundle as token.lua; keep ?v= and bump it on every change.
  TOKEN_SCRIPT_URL = "https://raw.githubusercontent.com/kiltev/haven-unscorched/main/scripts/token.lua?v=1",

  POOL_NAME         = "Rimearc Pool",
  POOL_RIGHT_OFFSET = 15,   -- units to the sheet's right
  POOL_UP_OFFSET    = 2,

  ENABLE_DEBUG = true,      -- adds a "Rebuild Pool" button + scale logging
}

local tokenScript = nil

-- ---- helpers ----------------------------------------------------------

local function poolExists()
  for _, o in ipairs(getObjects()) do
    if o.getName() == CONFIG.POOL_NAME then return o end
  end
  return nil
end

local function poolPosition()
  local p = self.getPosition()
  local r = self.getTransformRight()   -- sheet's right, unit vector
  return {
    p.x + r.x * CONFIG.POOL_RIGHT_OFFSET,
    p.y + CONFIG.POOL_UP_OFFSET,
    p.z + r.z * CONFIG.POOL_RIGHT_OFFSET,
  }
end

-- Configure a freshly spawned token as a Rimearc.
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
  o.reload()
end

local function buildPool()
  if poolExists() then
    printToAll("[Rimearc] pool already exists", "Yellow"); return
  end
  if not tokenScript then
    printToAll("[Rimearc] token script not loaded - check TOKEN_SCRIPT_URL", "Red"); return
  end

  local pos = poolPosition()

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
          -- wait until the custom image + script are applied, then store it
          -- as the bag's template (putObject captures the object's data).
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
end

local function rebuildPool()
  local existing = poolExists()
  if existing then existing.destruct() end
  Wait.time(buildPool, 0.5)
end

-- ---- entry ------------------------------------------------------------

function onLoad()
  if CONFIG.ENABLE_DEBUG then
    self.createButton({
      click_function = "onRebuildPool", function_owner = self,
      label = "Rebuild Rimearc Pool", position = { 0, 0.5, 0 },
      width = 1600, height = 400, font_size = 180,
      color = { 0, 0, 0, 0.9 }, font_color = { 1, 1, 1, 1 },
    })
  end

  WebRequest.get(CONFIG.TOKEN_SCRIPT_URL, function(r)
    if r.is_error then
      printToAll("[Rimearc] token.lua fetch error: " .. tostring(r.error), "Red")
    elseif r.response_code ~= 200 then
      printToAll("[Rimearc] token.lua HTTP " .. tostring(r.response_code) ..
                 " - check TOKEN_SCRIPT_URL (still 'OWNER/REPO'?)", "Red")
    elseif not r.text or r.text == "" then
      printToAll("[Rimearc] token.lua returned empty body", "Red")
    else
      tokenScript = r.text
      printToAll("[Rimearc] token.lua loaded (" .. #r.text .. " bytes)", "Green")
      if not poolExists() then buildPool() end
    end
  end)
end

function onRebuildPool()
  rebuildPool()
end
