--[[ =========================================================================
  Rimearc spawner  (design: R1 — custom condition as Quick-Menu trigger)

  Delivery: inject this onto the "Arctyc Zephyr" character object via the CCC
  perk trick (same vector as Dawnbringer/spawn_deck.lua). `self` = that object.

  What it does, on load:
    1. Registers the custom "Rimearc" condition (shows in the Quick Menu).
    2. Fetches the tile's script (the cleaned token.lua) once and caches it.
    3. Polls the class standee's state; on the Rimearc condition appearing
       (absent -> present edge), imperatively spawns the Rimearc tile above
       the standee's head, tagged + scripted + with the FHE overlay UI.

  NOTE ON TRUST: like spawn_deck.lua, this replaces the host object's Lua and
  runs code fetched from a raw URL. Same trust model you already use.
============================================================================ ]]

-- ============================== CONFIG ==================================
local CONFIG = {
  -- Custom condition (Quick Menu icon). Image reused from the token art.
  CONDITION_NAME  = "Rimearc",
  CONDITION_IMAGE = "https://i.imgur.com/W77V4kK.png",
  CONDITION_MAX   = 1,

  -- The spawned tile ("Rimearc").
  TOKEN_NAME      = "Rimearc",
  TOKEN_IMAGE     = "https://i.imgur.com/W77V4kK.png",
  TOKEN_TAGS      = { "Has Action", "Has Aid Tokens", "Has Conditions" },
  TOKEN_XML       = '<Include src="Overlays/Overlay.xml" />', -- mod-global include
  TILE_TYPE       = 2,               -- Custom_Tile: 0 sq, 1 hex, 2 circle, 3 rounded
  TOKEN_SCALE     = { 0.35, 1, 0.35 },-- ~28mm circle. TUNE in-mod to match standee base.
  TOKEN_THICKNESS = 0.1,
  SPAWN_OFFSET    = { 0, 2, 0 },     -- above the standee's head

  -- Raw URL of the cleaned token.lua (the tile's attached script).
  -- >>> set this to wherever you host scripts/token.lua <<<
  TOKEN_SCRIPT_URL = "https://raw.githubusercontent.com/OWNER/REPO/main/scripts/token.lua",

  -- Which figure to watch.
  STANDEE_NAME  = "Arctyc Zephyr",
  STANDEE_TAG   = "Character",
  POLL_INTERVAL = 1,                 -- seconds

  -- Set false once the condition trigger is validated in-mod.
  ENABLE_TEST_BUTTON = true,

  -- Temporary: adds a "Dump Debug" button + per-poll logging to reveal how the
  -- applied condition is stored on the standee. Turn off once detection works.
  ENABLE_DEBUG = true,
}
-- =======================================================================

local tokenScript = nil    -- cached token.lua text
local conditionWasPresent = false

-- ---- helpers ----------------------------------------------------------

local function findStandee()
  for _, o in ipairs(getObjectsWithTag(CONFIG.STANDEE_TAG)) do
    if o.getName() == CONFIG.STANDEE_NAME then return o end
  end
  -- fallback: match by name only
  for _, o in ipairs(getObjects()) do
    if o.getName() == CONFIG.STANDEE_NAME then return o end
  end
  return nil
end

-- Detect the condition by scanning the standee's serialized state.
-- No FHE read-API exists, so this is the pragmatic detector (VALIDATE in-mod:
-- confirm the condition name appears in the figure's script_state).
local function standeeHasCondition(standee)
  local state = standee.script_state
  if not state or state == "" then return false end
  return state:find(CONFIG.CONDITION_NAME, 1, true) ~= nil
end

local function spawnRimearc(standee)
  if not tokenScript then
    printToAll("[Rimearc] tile script not loaded yet - check TOKEN_SCRIPT_URL", "Yellow")
    return
  end
  local p = standee and standee.getPosition() or self.getPosition()
  local pos = { p.x + CONFIG.SPAWN_OFFSET[1], p.y + CONFIG.SPAWN_OFFSET[2], p.z + CONFIG.SPAWN_OFFSET[3] }

  spawnObject({
    type = "Custom_Tile",
    position = pos,
    rotation = { 0, 0, 0 },
    scale = CONFIG.TOKEN_SCALE,
    sound = false,
    callback_function = function(o)
      o.setCustomObject({
        image = CONFIG.TOKEN_IMAGE,
        type = CONFIG.TILE_TYPE,
        thickness = CONFIG.TOKEN_THICKNESS,
        stackable = false,
      })
      o.setName(CONFIG.TOKEN_NAME)
      o.setTags(CONFIG.TOKEN_TAGS)
      o.UI.setXml(CONFIG.TOKEN_XML)
      o.setLuaScript(tokenScript)
      o.reload()
    end,
  })
end

-- ---- FHE api ----------------------------------------------------------

-- FHE api_* functions receive POSITIONAL args, packed via table.pack(...)
-- (see ApiConsumer in token.lua). So registerCondition(name, condition) must
-- arrive as params[1]=name, params[2]=condition. pcall-guarded so a failure
-- can never abort onLoad.
local function registerCondition()
  local ok, err = pcall(function()
    Global.call("api_condition_registerCondition", {
      [1] = CONFIG.CONDITION_NAME,
      [2] = { image = CONFIG.CONDITION_IMAGE, max = CONFIG.CONDITION_MAX },
      n = 2,
    })
  end)
  if not ok then
    printToAll("[Rimearc] registerCondition failed: " .. tostring(err), "Red")
  end
end

-- ---- poll loop --------------------------------------------------------

local function poll()
  local standee = findStandee()
  if standee then
    local present = standeeHasCondition(standee)
    if CONFIG.ENABLE_DEBUG then
      local st = standee.script_state or ""
      log("[Rimearc poll] standee='" .. standee.getName() .. "' state_len=" .. #st ..
          " has('" .. CONFIG.CONDITION_NAME .. "')=" .. tostring(present))
    end
    if present and not conditionWasPresent then
      spawnRimearc(standee)          -- edge trigger: absent -> present
    end
    conditionWasPresent = present
  elseif CONFIG.ENABLE_DEBUG then
    log("[Rimearc poll] standee NOT FOUND (name='" .. CONFIG.STANDEE_NAME ..
        "', tag='" .. CONFIG.STANDEE_TAG .. "')")
  end
  Wait.time(poll, CONFIG.POLL_INTERVAL)
end

-- Prints the standee's full serialized state so we can see how the applied
-- condition is encoded, then write a correct detector.
function onDumpDebug()
  local standee = findStandee()
  if not standee then
    printToAll("[Rimearc] standee '" .. CONFIG.STANDEE_NAME .. "' NOT FOUND", "Red")
    return
  end
  printToAll("[Rimearc] tokenScript loaded=" .. tostring(tokenScript ~= nil), "White")
  printToAll("[Rimearc] standee tags: " .. table.concat(standee.getTags(), ", "), "White")
  local st = standee.script_state or ""
  printToAll("[Rimearc] script_state length=" .. #st, "White")
  log("[Rimearc] FULL script_state of '" .. standee.getName() .. "':")
  log(st)
end

-- ---- entry ------------------------------------------------------------

function onLoad()
  -- Button + fetch + poll FIRST, so a condition-API failure can never abort them.
  if CONFIG.ENABLE_TEST_BUTTON then
    self.createButton({
      click_function = "onTestSpawn", function_owner = self,
      label = "Spawn Rimearc", position = { 0, 0.5, 0 },
      width = 1200, height = 400, font_size = 200,
      color = { 0, 0, 0, 0.9 }, font_color = { 1, 1, 1, 1 },
    })
  end

  if CONFIG.ENABLE_DEBUG then
    self.createButton({
      click_function = "onDumpDebug", function_owner = self,
      label = "Dump Debug", position = { 0, 0.5, 1.2 },
      width = 1000, height = 300, font_size = 160,
      color = { 0.2, 0.2, 0.2, 0.9 }, font_color = { 1, 1, 0, 1 },
    })
  end

  WebRequest.get(CONFIG.TOKEN_SCRIPT_URL, function(r)
    if r.text and not r.is_error then
      tokenScript = r.text
    else
      printToAll("[Rimearc] failed to fetch token.lua: " .. tostring(r.error), "Red")
    end
  end)

  Wait.time(poll, CONFIG.POLL_INTERVAL)

  -- Last + pcall-guarded: worst case the icon is missing, everything else works.
  registerCondition()
end

function onTestSpawn()
  spawnRimearc(findStandee())
end
