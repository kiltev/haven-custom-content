-- Bundled by luabundle {"version":"1.6.0"}
local __bundle_require, __bundle_loaded, __bundle_register, __bundle_modules = (function(superRequire)
	local loadingPlaceholder = {[{}] = true}

	local register
	local modules = {}

	local require
	local loaded = {}

	register = function(name, body)
		if not modules[name] then
			modules[name] = body
		end
	end

	require = function(name)
		local loadedModule = loaded[name]

		if loadedModule then
			if loadedModule == loadingPlaceholder then
				return nil
			end
		else
			if not modules[name] then
				if not superRequire then
					local identifier = type(name) == 'string' and '\"' .. name .. '\"' or tostring(name)
					error('Tried to require ' .. identifier .. ', but no such module has been registered')
				else
					return superRequire(name)
				end
			end

			loaded[name] = loadingPlaceholder
			loadedModule = modules[name](require, loaded, register, modules)
			loaded[name] = loadedModule
		end

		return loadedModule
	end

	return require, loaded, register, modules
end)(require)
__bundle_register("__root", function(require, _LOADED, __bundle_register, __bundle_modules)
-- ACTUAL CODE GOES HERE
require("Overlays.BasicOverlay")
    .withButtonPosition(0.02)
-- ACTUAL CODE GOES HERE
end)
__bundle_register("Overlays.BasicOverlay", function(require, _LOADED, __bundle_register, __bundle_modules)
local ActionElement = require("ActionElement")
local Frame = require("Frames.Frame")
local ScenarioAid = require("Frames.ScenarioAid")

--- The most basic overlay. Only supports adding an action button.
local BasicOverlay = {}

local this = {}

---@type gloom_FigureBar[]
this.bars = { ScenarioAid }

Frame.withOffset(200)

--- Set the y-coordinate where the action button will appear.
function BasicOverlay.withButtonPosition(buttonPosition)
  ActionElement.withButtonPosition(buttonPosition)
  return BasicOverlay
end

function onLoad(savedState)
  if savedState ~= nil and savedState ~= "" then
    local state = JSON.decode(savedState)
    Frame.load(state)
    for _, bar in ipairs(this.bars) do
      bar.load(state)
    end
    ActionElement.load(state.action)
  else
    ActionElement.init()
  end

  local function isLoaded()
    return not self.loading_custom and not self.spawning and self.UI.getXml() ~= "" and not Global.UI.loading
  end

  Wait.condition(function()
    Frame.init()
    this.updateUi()
  end, isLoaded)
end

function this.updateUi()
  for _, bar in ipairs(this.bars) do
    bar.render()
  end
end

function onSave()
  local state = {
    action = ActionElement.save(),
  }
  for _, bar in ipairs(this.bars) do
    bar.save(state)
  end

  return json.serialize(state)
end

function saveNow()
  self.script_state = onSave()
end

return BasicOverlay

end)
__bundle_register("Frames.ScenarioAid", function(require, _LOADED, __bundle_register, __bundle_modules)
local BaseBar = require("Frames.BaseBar")

---@class gloom_ScenarioAidBar : gloom_FigureBar

local ScenarioAid = --[[---@type gloom_ScenarioAidBar]] BaseBar()

---@type (string | integer)[]
local tokens = {}

local maxTokens = 1

function ScenarioAid.load(state)
  tokens = state.tokens or {}
end

function ScenarioAid.save(state)
  state.tokens = tokens
end

function ScenarioAid.parseStats(stats)
end

function ScenarioAid.setStats(stats)
  tokens = stats.tokens or {}
end

function ScenarioAid.render()
  for i, token in ipairs(tokens) do
    local imageName = "aid-token"
    local textSize = 90
    if type(token) == "number" then
      imageName = imageName .. "-number"
      textSize = 70
    end

    self.UI.setAttributes("aid-token-" .. i, { active = true, image = imageName })
    self.UI.setAttributes("aid-token-" .. i .. "-value", { text = token, fontSize = textSize })
  end

  for i = #tokens + 1, maxTokens do
    self.UI.setAttribute("aid-token-" .. i, "active", false)
  end

  self.UI.setAttribute("aid-token-group", "width", #tokens * 200 + (#tokens - 1) * 40)
end

function setScenarioAidTokens(params)
  tokens = params.tokens or {}
  ScenarioAid.render()
end

function ScenarioAid.getTokens()
  return tokens
end

return ScenarioAid

end)
__bundle_register("api.Resource", function(require, _LOADED, __bundle_register, __bundle_modules)
local Resource = {}

---@type seb_Version
Resource.Version = { 1, 3, 11 }

Resource.Remove = "__REMOVE__"
---@type gloom_Spawn_Element
Resource.EmptyElement = { type = 0, name = Resource.Remove }

Resource.LockType = {
    None = 0,
    Hard = 1,
    Soft = 2,
}

Resource.ElementType = {
  Enemy = 0,
  Corridor = 1,
  DifficultTerrain = 2,
  HazardousTerrain = 3,
  Obstacle = 5,
  Trap = 7,
  Treasure = 8,
  Coin = 9,
  Door = 10,
  Start = 11,
  MapTile = 12,
  ScenarioAid = 13,
  ScenarioSection = 14,
  ObjectiveToken = 15,
  Figure = 16,
  Summon = 17,
  Loot = 18,
}

---@param guid GUID
---@return fun(): tts__Object
local function byGuid(guid)
  return function()
    return --[[---@not nil]] getObjectFromGUID(guid)
  end
end

---@param tag string
---@return fun(): tts__Object
local function byTag(tag)
  return function()
    return --[[---@not nil]] getObjectsWithTag(tag)[1]
  end
end

---@param guid GUID
---@param name string
---@return fun(name: string): tts__ObjectState
local function childByName(guid)
  return function(name)
    local parent = --[[---@type tts__Container]] getObjectFromGUID(guid)
    for _, child in ipairs(parent.getData().ContainedObjects) do
      if child.Nickname == name then
        return child
      end
    end
  end
end

---@alias typed<R> fun(): R

Resource.Object = {
  HiddenSection = byGuid("d30150"),
  BlessBag = byGuid("f96829"),
  PlayerCurseBag = byGuid("1802d6"),
  MonsterCurseBag = byGuid("670e89"),
  BattleGoalsBag = byGuid("2d7a80"),
  Backup = childByName("29c2ce"),
  ScenarioBag = --[[---@type typed<tts__Bag>]] byTag("UnlockedScenarios"),
}

Resource.Error = {
  Extension = "__ERROR_IN_EXTENSION__",
}

Resource.Tag = {
  --- Tags for class specific components.
  Class = {
    Envelope = "Class Envelope",
    Sheet = "Character Sheet",
    Figure = "Character",
    Summon = "Summon",
    Ability = "Ability Card",
    HpDial = "HP Dial",
    XpDial = "XP Dial",
  },
  --- Tags for enemy specific components.
  Monster = {
    Envelope = "Enemy Envelope",
    Figure = "Enemy",
    Mat = "MonsterMat",
    StatSheet = "MonsterStatSheet",
    Bag = "MonsterFigureBag",
    Abilities = "Monster Ability Deck",
    Ability = "Monster Ability Card",
  },
  --- Tags for Overlays.
  Overlay = {
    Corridor = "Corridor",
    DifficultTerrain = "Difficult Terrain",
    Door = "Door",
    HazardousTerrain = "Hazardous Terrain",
    Loot = "Loot",
    Map = "Map",
    Obstacle = "Obstacle",
    Trap = "Trap",
    TreasureChest = "Treasure Chest",
    Figure = "Figure",
    Removable = "Removable",
    Token = "Token",
  },
  --- Tags for traits a component can have.
  Trait = {
    --- Supports adding actions.
    HasAction = "Has Action",
    --- Supports adding aid tokens.
    HasAidTokens = "Has Aid Tokens",
    HasAttackEffects = "Has Attack Effects",
    --- Supports adding conditions.
    HasConditions = "Has Conditions",
    --- Supports adding health bar.
    HasHealth = "Has Health",
    --- Supports adding immunities.
    HasImmunities = "Has Immunities",
    HasStats = "Has Stats",
    HasInitiative = "Has Initiative",
    HasTheme = "Has Theme",
    CanReload = "Can Reload",
    CanSpawn = "Can Spawn",
  },
  Scenario = {
    Definition = "Scenario",
    ExtraContent = "Scenario Extra Content",
    Active = "Active Scenario",
  },
  Event = {
    City = "City Event",
    Road = "Road Event",
  },
  Item = {
    Item = "Item",
    Head = "ItemHead",
    Chest = "ItemChest",
    OneHand = "ItemOneHanded",
    TwoHand = "ItemTwoHanded",
    Boots = "ItemBoots",
    Consumable = "ItemConsumable",
    Design = "Item Design",
    Reward = "Item Reward",
    Solo = "Item Solo Reward",
  },
  AMD = {
    RemoveAfterDiscard = "Remove After Discard",
  },
  Card = {
    BattleGoal = "Battle Goal",
  },
  Component = {
    Mock = "GHE API Mock",
    BagOfLockedScenarios = "LockedScenarios",
    BagOfLockedCharacters = "LockedCharacters",
    BagOfMonsters = "MonsterBag",
    BagOfMonsterAbilities = "Bag of Monster Abilities",
    BagOfExtraContent = "Bag of Extra Content",
    BagOfSummons = "Bag of Summons",
    BagOfUnlockedScenarios = "UnlockedScenarios",
    BagOfPersonalQuests = "PersonalQuestBag",
    LockedContent = "Locked Content",
    Treasure = "Treasure",
    ShopItems = "Shop Items",
    RewardItems = "Reward Items",
    ItemDesigns = "Item Designs",
    SoloRewardItems = "Solo Reward Items",
    RoadEvents = "Available Road Events",
    CityEvents = "Available City Events",
    RiftEvents = "Available Rift Events",
    PersonalQuests = "Personal Quests",
    Book = "Book",
  },
  Book = {
    Guide = "Guide Book",
    Scenarios = "Scenario Book",
    Sections = "Section Book",
  },
  Game = {
    Gloomhaven = "Gloomhaven",
    ForgottenCircles = "Forgotten Circles",
  },
  Tool = {
    EnhancementCalculator = "Enhancement Calculator",
  },
  -- TODO better group those below
  Character = "Character",
  Enemy = "Enemy",
  Summon = "Summon",
  Tile = {
    Start = "Tile - Start Area"
  },
  SoftLock = "Soft-Lock",
  EnemyStatSheet = "MonsterStatSheet",
  CustomContent = "Gloomhaven Custom Content",
  PartySheet = "Party Sheet",
  ScenarioLevelChart = "Scenario Level Chart",
  PersonalQuest = "PersonalQuest",
  ConditionStack = "ConditionStack"
}

---@param tag string
---@return boolean
function Resource.hasObject(tag)
  local objects = getObjectsWithTag(tag)
  return objects[1] ~= nil
end

return Resource

end)
__bundle_register("Frames.BaseBar", function(require, _LOADED, __bundle_register, __bundle_modules)
---@class gloom_BaseBar : gloom_FigureBar

---@class gloom_BaseBar_static
---@overload fun(): gloom_BaseBar
local BaseBar = {}

local function new()
  local self = --[[---@type gloom_BaseBar]] {}

  function self.init(params)
  end

  function self.initUi()
  end

  function self.load()
  end
  
  function self.save()
  end

  function self.parseStats()
  end

  function self.setStats()
  end

  function self.render()
  end
  
  return self
end


setmetatable(BaseBar, {
  ---@return gloom_BaseBar
  __call = function(_)
    return new()
  end
})

return BaseBar

end)
__bundle_register("Frames.Frame", function(require, _LOADED, __bundle_register, __bundle_modules)
local Frame = {}

---@type number
local frameOffset = FrameOffset
local adjustment = 0

---@param value integer
local function setHeight(value)
  self.UI.setAttribute("Frame", "position", "0 0 -" .. value + adjustment)
end

--- Calculates the frame offset based on the object's bounding box.
--- Another fifth of the calculated value is added because the Frame panel always has a scale of 0.2.
--- A minimum of 120 is used
local function calculateOffset()
  local size = self.getBounds().size
  local scale = self.getScale()
  local unscaled = size.y * scale.y
  local calculated = (unscaled + unscaled / 5) * 100

  return math.max(calculated, 120)
end

function Frame.withOffset(newFrameOffset)
  frameOffset = newFrameOffset
end

---@param value integer
function Frame.adjust(value)
  if value > 0 then
    adjustment = value
    setHeight(frameOffset)
  end
end

function Frame.init()
  if not frameOffset then
    frameOffset = calculateOffset()
  end
  setHeight(frameOffset)
  Frame.orientFrame()
end

function Frame.save(state)
  if adjustment > 0 then
    state.frameAdjust = adjustment
  end
end

function Frame.load(state)
  if state and state.frameAdjust then
    adjustment = state.frameAdjust
  end
end

function Frame.orientFrame()
  local objRotation = self.getRotation().y
  local newUiRot = -90 + objRotation
  self.UI.setAttribute("Frame", "rotation", tostring(newUiRot) .. " 270 90")
end

function onRotate()
  Wait.time(Frame.orientFrame, 0.5)
end

function onDrop()
  Wait.time(Frame.orientFrame, 0.5)
end

return Frame

end)
__bundle_register("ActionElement", function(require, _LOADED, __bundle_register, __bundle_modules)
local ActionApi = require("api.ActionApi")

--- An element that allows adding an action button.
local ActionElement = {}

--- The attached action
---@type gloom_Action_Definition
local action
local isConfirmed = false
---@type number
local buttonPosition

local function calculateButtonPosition()
  local size = self.getBounds().size
  local scale = self.getScale()
  local unscaled = size.y * scale.y
  local calculated = (unscaled + unscaled / 5)

  return calculated
end

local function createActionButton()
  if not buttonPosition then
    buttonPosition = calculateButtonPosition()
  end

  ActionApi.createActionButton(self, action, buttonPosition, "onPerformActionClicked")
end

local function deleteActionButton()
  self.clearButtons()
end

---@param label string
local function setActionLabel(label)
  if self.getButtons() ~= nil then
    self.editButton({ index = 0, label = label })
  end
end

function ActionElement.withButtonPosition(newButtonPosition)
  buttonPosition = newButtonPosition
end

function ActionElement.init()
  for _, state in ipairs(self.getStates() or {}) do
    if state.lua_script_state ~= nil and state.lua_script_state ~= "" then
      local stateInfo = JSON.decode(--[[---@not nil]] state.lua_script_state)

      if stateInfo.action then
        ActionElement.load(stateInfo.action)
        saveNow()
        break
      end
    end
  end
end

function ActionElement.save()
  return action
end

---@param savedAction nil | gloom_Action_Definition
function ActionElement.load(savedAction)
  if savedAction then
    action = --[[---@not nil]] savedAction

    if not action.state then
      action.state = { done = false, }
    end

    if (--[[---@not nil]] action.state).done then
      ActionApi.performDoneAction(self, action)
    else
      createActionButton()
    end
  end
end

---@param player_color tts__PlayerColor
---@param alt_click boolean
function onPerformActionClicked(_, player_color, alt_click)
  local buttonId = -1
  if alt_click then
    buttonId = -2
  end

  if not action.confirm or isConfirmed then
    local done = ActionApi.performAction(self, action, { player = player_color, button = buttonId })
    if done then
      deleteActionButton()
      action.state.done = true
      saveNow()
      ActionApi.postPerformAction(self, action)
    end
  else
    isConfirmed = true
    setActionLabel(action.name .. "?")
    Wait.time(function()
      setActionLabel(action.name)
      isConfirmed = false
    end, 2)
  end
end

function performActionInstantly()
  if action ~= nil then
    local done = ActionApi.performAction(self, action)
    if done then
      deleteActionButton()
      action.state.done = true
      saveNow()
      ActionApi.postPerformAction(self, action)
    end
  else
    destroyObject(self)
  end
end

--- Sets the action that this element performs, when its button is clicked.
---@param newAction gloom_Action_Definition
function setAction(newAction)
  deleteActionButton()
  ActionElement.load(newAction)
  saveNow()
end

return ActionElement

end)
__bundle_register("api.ActionApi", function(require, _LOADED, __bundle_register, __bundle_modules)
local ApiConsumer = require("api.ApiConsumer")

local ActionApi = --[[---@type ActionApi]] ApiConsumer("action")
  .withApi("createActionButton")
  .withApi("performAction")
  .withApi("performDoneAction")
  .withApi("postPerformAction")

ActionApi.Style = {
  Door = "Door",
  PressurePlate = "PressurePlate",
  Section = "Section",
  Start = "Start",
  Treasure = "Treasure",
}

return ActionApi

end)
__bundle_register("api.ApiConsumer", function(require, _LOADED, __bundle_register, __bundle_modules)
local Api = require("api.ApiUtil").forObject(Global)

---@class ApiConsumer

---@class ApiConsumer_static
---@overload fun(name: string): ApiConsumer
local ApiConsumer = {}

---@param name string
local function new(name)
  local consumer = --[[---@type ApiConsumer]] {}

  ---@param base string
  ---@param name string
  ---@return ApiConsumer
  function consumer.withApi(apiName)
    consumer[apiName] = function(...)
      return Api.call("api_" .. name .. "_" .. apiName, table.pack(...))
    end

    return consumer
  end

  return consumer
end

setmetatable(ApiConsumer, {
  ---@param name string
  __call = function(_, name)
    return new(name)
  end
})

return ApiConsumer

end)
__bundle_register("api.ApiUtil", function(require, _LOADED, __bundle_register, __bundle_modules)
---@class gloom_Api_Util_Static
---@overload fun(object: GUID | tts__Global | tts__Object_Tag, type: gloom_Api_FindType): gloom_Api_Util
local ApiUtil = {}

local R = require("api.Resource")

---@alias gloom_Api_FindType 'object' | 'guid' | 'tag'

local FindType = {
  Object = "object",
  Guid = "guid",
  Tag = "tag",
}

---@class gloom_Api_Util

---@return gloom_Api_Util
local function new(object, findType)
  local this = --[[---@type gloom_Api_Util]] {}

  ---@type tts__Object
  local onObject

  ---@return boolean
  local isInGloomhavenMod = Info.name:find("^Gloomhaven %- TTS Enhanced") ~= nil

  ---@return tts__Object
  function this.getObject()
    if onObject ~= nil then
      return onObject
    end

    if findType == FindType.Object then
      onObject = --[[---@not string]] object
    elseif findType == FindType.Guid then
      onObject = --[[---@not nil]] getObjectFromGUID(--[[---@type GUID]] object)
    elseif findType == FindType.Tag then
      local objects = getObjectsWithTag(--[[---@type tts__Object_Tag]] object)
      if not objects or not objects[1] then
        ApiUtil.error("Not object with tag " .. tostring(object) .. " found!")
      elseif objects[2] then
        ApiUtil.error("Multiple objects with tag " .. tostring(object) .. " found!")
      else
        onObject = objects[1]
      end
    else
      ApiUtil.error("Unknown API type: " .. tostring(findType))
    end

    return onObject
  end

  ---@param functionName string
  ---@param parameters any
  local function callInObject(functionName, parameters)
    parameters = parameters or {}
    if type(parameters) ~= "table" then
      ApiUtil.error("Wrong parameter type given for calling API " .. functionName)
    end
    parameters["__caller"] = self.getGUID()
    parameters["__version"] = R.Version

    return this.getObject().call(functionName, parameters)
  end

  ---@overload fun(functionName: string): any
  ---@param functionName string
  ---@param parameters any
  ---@return any
  function this.call(functionName, parameters)
    if isInGloomhavenMod then
      if this.getObject() == self then
        if _G[functionName] then
          return _G[functionName](parameters)
        end
        error("The function " .. functionName .. " doesn't exist! This will lead to more errors")
        return nil
      else
        return callInObject(functionName, parameters)
      end
    else
      local hasApiMock = getObjectsWithTag(R.Tag.Component.Mock)[1] ~= nil
      if hasApiMock then
        ApiUtil.debug("Calling API mock " .. functionName)
        findType = FindType.Tag
        object = R.Tag.Component.Mock

        local success, value = pcall(function()
          return callInObject(functionName, parameters)
        end)

        if success then
          return value
        else
          ApiUtil.warning("Tried to reach API mock for " .. functionName .. " but it returned error " .. value)
          return nil
        end
      else
        ApiUtil.debug("Would call API " .. functionName)
        return nil
      end
    end
  end

  return this
end

setmetatable(ApiUtil, {
  ---@param object GUID | tts__Global | tts__Object_Tag
    ---@param findType gloom_Api_FindType
  __call = function(_, object, findType)
    return new(object, findType)
  end
})

---@param message string
function ApiUtil.debug(message)
  log(message)
end

---@param message string
function ApiUtil.warning(message)
  printToAll(message, "Yellow")
end

---@param message string
function ApiUtil.error(message)
  printToAll(message, "Red")
end

---@param object GUID | tts__Global
---@return gloom_Api_Util
function ApiUtil.forObject(object)
  if type(object) == "string" then
    return ApiUtil(object, FindType.Guid)
  end
  return ApiUtil(object, FindType.Object)
end

---@param tag tts__Object_Tag
---@return gloom_Api_Util
function ApiUtil.forInstance(tag)
  return ApiUtil(tag, FindType.Tag)
end

return ApiUtil

end)
return __bundle_require("__root")
