-- Bundled by luabundle {"version":"1.7.0"}
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
require("Overlays.Overlay")
    .withFrameOffset(120)
    .withButtonPosition(0.18)

end)
__bundle_register("Overlays.Overlay", function(require, _LOADED, __bundle_register, __bundle_modules)
local SignalLoading = require("lib.SignalLoading")

local Frame = require("Frames.Frame")
local HealthBar = require("Frames.HealthBar")
local ScenarioAid = require("Frames.ScenarioAid")
local ConditionsBar = require("Frames.ConditionsBar").readOnly()

local ActionElement = require("ActionElement")

local Overlay = {}

local bars = { ConditionsBar }

function Overlay.withFrameOffset(frameOffset)
  Frame.withOffset(frameOffset)
  return Overlay
end

function Overlay.withButtonPosition(buttonPosition)
  ActionElement.withButtonPosition(buttonPosition)
  return Overlay
end

function onLoad(savedState)
  for _, bar in ipairs(bars) do
    bar.init()
  end

  Wait.condition(function()
    Frame.init()

    if savedState ~= nil and savedState ~= "" then
      local save_state = JSON.decode(savedState)
      if save_state.health ~= nil then
        setHp(save_state.health)
      end
      if save_state.tokens ~= nil then
        setScenarioAidTokens({ tokens = save_state.tokens })
      end

      for _, bar in ipairs(bars) do
        bar.load(savedState)
      end

      ActionElement.load(save_state.action)
    else
      ActionElement.init()
    end

    ConditionsBar.createUi()
    SignalLoading.finishOnLoad()
  end, SignalLoading.isLoaded)
end

function onSave()
  local state = {
    health = HealthBar.getHp(),
    tokens = ScenarioAid.getTokens(),
    action = ActionElement.save(),
  }

  for _, bar in ipairs(bars) do
    bar.save(state)
  end

  return json.serialize(state)
end

function toggleEditHealth()
  HealthBar.toggleEditHealth()
end

function saveNow()
  self.script_state = onSave()
end

return Overlay

end)
__bundle_register("ActionElement", function(require, _LOADED, __bundle_register, __bundle_modules)
local ActionApi = require("api.ActionApi")
local R = require("api.Resource")

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

self.addTag(R.Tag.Trait.HasAction)

return ActionElement

end)
__bundle_register("api.Resource", function(require, _LOADED, __bundle_register, __bundle_modules)
local Resource = {}

---@type seb_Version
Resource.Version = { 2, 5, 3 }

function Resource.getVersion()
  return table.concat(Resource.Version, ".")
end

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

---@alias typed<R> fun(): R

--- Possible objects on the table
Resource.Object = {
  LockedClasses = --[[---@type fun(): tts__Bag]] byGuid("class-unlock"),
  HiddenSection = byGuid("d30150"),
  BlessBag = byGuid("am.bless"),
  PlayerCurseBag = byGuid("am.curse.player"),
  MonsterCurseBag = byGuid("am.curse.monster"),
  MinusOneBag = byGuid("am.minusone"),
  BattleGoalsBag = byGuid("scenario.goals"),
  Shop = --[[---@type fun(): tts__Bag]] byGuid("items.unlocked"),
  RandomItems = --[[---@type fun(): tts__Bag]] byGuid("items.random"),
  LockedItems = --[[---@type fun(): tts__Bag]] byGuid("items.locked"),
  QuestDeck = --[[---@type fun(): tts__Bag]] byGuid("decks.quests"),
  CampaignManager = byGuid("campaignmanager"),
  Books = byGuid("books"),
}

---@alias ContainerComponent fun(elementId: string): tts__ContainerState
---@alias ContainerElements fun(elementId: string): tts__ObjectState[]

---@param groupId GUID
---@return tts__ObjectState[]
local function componentGroup(groupId)
  local components = --[[---@type tts__Container]] getObjectFromGUID("components." .. groupId)
  return components.getData().ContainedObjects or {}
end

---@param groupId GUID
---@return fun(elementId: GUID): tts__ObjectState
local function fromComponentGroup(groupId)
  return function(elementId)
    elementId = groupId .. "." .. elementId
    local elements = componentGroup(groupId)
    for _, element in ipairs(elements) do
      if element.GUID == elementId then
        return element
      end
    end
  end
end

---@param deckId GUID
---@param cardName string
---@return tts__ObjectState
local function cardFromDeck(deckId, cardName)
  local deck = fromComponentGroup("decks")(deckId)
  local content = ( --[[---@type tts__ContainerState]] deck).ContainedObjects or {}

  for _, card in ipairs(content) do
    if card.Nickname == cardName then
      return card
    end
  end
end

---@param groupId GUID
---@return fun(elementId: GUID): tts__ObjectState[]
local function elementsFromComponentGroup(groupId)
  return function(elementId)
    local elements = --[[---@type tts__ContainerState]] fromComponentGroup(groupId)(elementId)
    return elements.ContainedObjects or {}
  end
end

---@param groupId GUID
---@return fun(name: string): tts__ObjectState[]
local function namedElements(groupId)
  return function(name)
    local elements = componentGroup(groupId)
    for _, element in ipairs(elements) do
      if element.Nickname == name then
        return ( --[[---@type tts__BagState]] element).ContainedObjects or {}
      end
    end
  end
end

--- Available objects hidden in the components bag
Resource.Component = {
  Group = componentGroup,
  Deck = --[[---@type ContainerComponent]] fromComponentGroup("decks"),
  Card = cardFromDeck,
  MonsterAbilities = namedElements("monster.abilities"),
  Events = --[[---@type ContainerElements]] namedElements("events"),
  Marker = fromComponentGroup("markers"),
  Mat = fromComponentGroup("mats"),
  Overlay = elementsFromComponentGroup("overlays"),
  Tool = fromComponentGroup("tools"),
}

---@param name string
---@return nil | tts__Object
function Resource.Content(name)
  for _, obj in ipairs(getObjectsWithTag(Resource.Tag.ContentBox)) do
    if obj.getName() == name then
      return obj
    end
  end
end

Resource.Error = {
  Extension = "__ERROR_IN_EXTENSION__",
}

Resource.Tag = {
  --- A static, non interactable element that should never be deleted (e.g. the table or the bag containing mod components)
  Static = "Static",
  --- An object that shouldn't be deleted, but otherwise is interactable
  Permanent = "Permanent",
  --- Tags for class specific components.
  Class = {
    Envelope = "Class Envelope",
    Figure = "Character",
    Sheet = "Character Sheet",
    Summon = "Summon",
    Ability = "Ability Card",
    HpDial = "HP Dial",
    XpDial = "XP Dial",
    Tracker = "Class Tracker",
    Inactive = "Inactive Character",
  },
  --- Tags for enemy specific components.
  Monster = {
    Envelope = "Enemy Envelope",
    Figure = "Enemy",
    Mat = "Monster Mat",
    AbilityMat = "Monster Ability Mat",
    Bag = "MonsterFigureBag",
    Abilities = "Monster Ability Deck",
    Ability = "Monster Ability Card",
    AttackModifiers = "Attack Modifier Mat"
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
    Overlay = "Terrain",
    Removable = "Removable",
    Token = "Token",
    Terrain = "Terrain",
    Start = "Start Area",
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
    CanReload = "Can Reload",
    CanSpawn = "Can Spawn",
  },
  Scenario = {
    Definition = "Scenario",
    ExtraContent = "Scenario Extra Content",
    Active = "Active Scenario",
    BattleGoal = "Battle Goal",
    Random = "Random Side Scenario",
    RandomRoom = "Random Dungeon Room",
    RandomMonster = "Random Dungeon Monster",
    -- A part of a scenario
    Piece = "Scenario Piece",
    LootDeck = "Loot Deck",
    LootCard = "Scenario Loot",
  },
  Event = {
    Card = "Event",
    Deck = "Event Deck",
    Mat = "Event Mat",
  },
  Item = {
    Item = "Item",
    Head = "ItemHead",
    Chest = "ItemChest",
    OneHand = "ItemOneHanded",
    TwoHand = "ItemTwoHanded",
    Boots = "ItemBoots",
    Consumable = "ItemConsumable",
    Blueprint = "Item Blueprint",
    Reward = "Item Reward",
    Solo = "Item Solo Reward",
    Random = "Item Random",
  },
  AMD = {
    RemoveAfterDiscard = "Remove After Discard",
  },
  Character = {
    Figure = "Character",
    PersonalQuest = "PersonalQuest",
    Trial = "Trial",
  },
  Component = {
    Base = "Component Base",
    Deck = "Component Deck",
    Mat = "Component Mat",
    DeckBag = "Deck Bag",
    Mock = "GHE API Mock",
    BagOfLockedCharacters = "LockedCharacters",
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
    Sticker = "Sticker",
    Guide = "Guide",
  },
  Book = {
    Puzzle = "Puzzle Book",
    Scenarios = "Scenario Book",
    Sections = "Section Book",
    Rule = "Rule Book",
    Bookmark = "Has Bookmarks"
  },
  Game = {
    Campaign = "Gloomhaven Campaign",
    Gloomhaven = "Gloomhaven",
    ForgottenCircles = "Forgotten Circles",
  },
  Tool = {
    EnhancementCalculator = "Enhancement Calculator",
  },
  Information = {
    Campaign = "Campaign",
    Scenario = "Scenario Information",
  },
  Deck = {
    Infinite = "Infinite",
    Filter = "Filter",
    Split = "Split",
    Unique = "Unique",
  },
  Token = {
    Condition = "Condition"
  },
  -- TODO better group those below
  Enemy = "Enemy",
  Summon = "Summon",
  SoftLock = "Soft-Lock",
  CustomContent = "Gloomhaven Custom Content",
  ContentBox = "Content Box",
  PartySheet = "Party Sheet",
  ScenarioLevelChart = "Scenario Level Chart",
  ConditionStack = "ConditionStack"
}

---@param tag string
---@return boolean
function Resource.hasObject(tag)
  local objects = getObjectsWithTag(tag)
  return objects[1] ~= nil
end

function Resource.invalidateCache()
  cache = {}
end

return Resource

end)
__bundle_register("api.ActionApi", function(require, _LOADED, __bundle_register, __bundle_modules)
local ApiConsumer = require("api.ApiConsumer")

local ActionApi = ApiConsumer("action")
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

---@return gloom_Api_Util
local function new(object, findType)
  ---@class gloom_Api_Util
  local this = {}

  ---@type tts__Object
  local onObject

  ---@return boolean
  local isInGloomhavenMod = Info.name:find("^.*haven Enhanced") ~= nil or
  Info.name:find("^.*haven %- TTS Enhanced") ~= nil

  ---@return tts__Object
  function this.getObject()
    if onObject ~= nil then
      return onObject
    end

    if findType == FindType.Object then
      onObject = object
    elseif findType == FindType.Guid then
      onObject = getObjectFromGUID(object) --[[@as tts__Object]]
    elseif findType == FindType.Tag then
      local objects = getObjectsWithTag(object)
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
__bundle_register("Frames.ConditionsBar", function(require, _LOADED, __bundle_register, __bundle_modules)
local Ui = require("lib.Ui")

local BaseBar = require("Frames.BaseBar")
local ConditionApi = require("api.ConditionApi")
local R = require("api.Resource")

---@class gloom_ConditionsBar : gloom_FigureBar

---@type gloom_ConditionsBar
local ConditionsBar = BaseBar()

local this = {}

local isSummon = false

---@class __condition_data
---@field current integer
---@field max integer

---@type table<string, __condition_data>
local conditions = {}

--- If set conditions can not be removed by clicking and can not be added through coliding condition tokens
local readOnly = false

function ConditionsBar.readOnly()
  readOnly = true
  return ConditionsBar
end

function ConditionsBar.init()
  this.addConditionsFor(ConditionApi.getConditions() or {})
  this.addConditionsFor(ConditionApi.getClassTrackers() or {})
  this.addConditionsFor({ Damage = { max = 20 } })
end

function ConditionsBar.load(state)
  for name, _ in pairs(state.conditions or {}) do
    conditions[name] = state.conditions[name]
  end
  isSummon = state.isSummon
end

function ConditionsBar.save(state)
  state.conditions = conditions
  state.isSummon = isSummon
end

function ConditionsBar.setStats(stats)
  if stats.isSummon ~= nil then
    isSummon = stats.isSummon
  end
end

function ConditionsBar.createUi()
  local xml = self.UI.getXmlTable()
  local conditionsPanel = Ui.findElement(xml, "Conditions")

  if conditionsPanel then
    local buttonAdded = false
    for k, v in pairs(conditions) do
      local isActive = v.current and v.current > 0
      local existingButton = Ui.findElement(conditionsPanel.children, k)
      if not existingButton then
        table.insert(conditionsPanel.children, this.createStatusButton(k, v.current))
        buttonAdded = true
      else
        existingButton.attributes.active = isActive
      end
    end

    if buttonAdded then
      local statePanel = Ui.findElement(xml, "statePanel")
      if statePanel then
        statePanel.attributes.width = this.calculatePanelWidth()
      end
      self.UI.setXmlTable(xml)
    else
      this.updatePanelWidth()
    end
  end
  this.setSummonIcon()
end

function ConditionsBar.render()
  this.setSummonIcon()
end

---@param values table<string, gloom_Condition>
function this.addConditionsFor(values)
  for key, condition in pairs(values) do
    local existing = conditions[key]
    if not existing then
      conditions[key] = {
        current = 0,
        max = condition.max,
      }
    elseif existing == true then
      conditions[key] = {
        current = 1,
        max = condition.max,
      }
    elseif existing ~= nil then
      existing.max = condition.max
    end
  end
end

function this.createStatusButton(name, initVal)
  local displayNumber = ""
  local isActive = initVal and initVal > 0
  if initVal and initVal > 1 then
    displayNumber = tostring(initVal)
  end

  local element = {
    tag = "Button",
    attributes = {
      id = name,
      active = isActive,
    },
    children = {
      {
        tag = "Image",
        attributes = {
          image = name,
          preserveAspect = true
        },
      },
      {
        tag = "Text",
        attributes = {
          id = name .. "Count",
          color = "White",
          offsetXY = "100 -100",
          text = displayNumber
        }
      }
    }
  }
  if readOnly then
    element.tag = "Panel"
  else
    element.attributes.onClick = "statusClick"
  end

  return element
end

function this.calculatePanelWidth()
  return 260 + (this.getStatsCount() - 1) * 280
end

function this.getStatsCount()
  local count = 0
  for _, condition in pairs(conditions) do
    if condition.current > 0 then
      count = count + 1
    end
  end
  return count
end

---@param name string
function this.removeCondition(name)
  local condition = conditions[name]
  if condition ~= nil then
    if condition.current > 0 then
      condition.current = condition.current - 1
      this.updateCondition(name, condition)
    end
  end
end

function this.updateCondition(name, status)
  if status.current > 0 then
    Ui.setActive(name, true)
    if status.current > 1 then
      Ui.setText(name .. "Count", tostring(status.current))
    else
      Ui.setText(name .. "Count", "")
    end
  else
    Ui.setActive(name, false)
    Ui.setText(name .. "Count", "")
  end

  this.updatePanelWidth()
end

function this.updatePanelWidth()
  Wait.time(function()
    self.UI.setAttribute("statePanel", "width", this.calculatePanelWidth())
  end, 0.1)
end

---@param condition string
---@return boolean
function this.isImmuneTo(condition)
  if self.hasTag(R.Tag.Trait.HasImmunities) then
    return _G.isImmuneTo(condition)
  end
  return false
end

function this.setSummonIcon()
  self.UI.setAttribute("summonIcon", "active", isSummon)
end

---@param conditionName string
function addCondition(conditionName)
  local status = conditions[conditionName]
  if status ~= nil and not this.isImmuneTo(conditionName) then
    if status.current ~= status.max then
      status.current = status.current + 1
      this.updateCondition(conditionName, status)
    end
  end
end

function clearConditions()
  for name, condition in pairs(conditions) do
    condition.current = 0
    this.updateCondition(name, condition)
  end
end

function statusClick(player, value, id)
  if not readOnly then
    this.removeCondition(id)
  end
end

local collided = {}

function onCollisionEnter(info)
  if info.collision_object.getQuantity() ~= -1 or readOnly then
    return
  end

  if not info.collision_object.hasTag(R.Tag.Token.Condition) then
    return
  end

  Wait.condition(
    function()
      --found = do nothing
    end,
    function() return collided[info.collision_object.guid] == true end,
    0.1,
    function()
      local conditionName = info.collision_object.getName()
      if conditionName == "Summon Marker" and canBeASummon then
        isSummon = true
        info.collision_object.destruct()
        this.setSummonIcon()
      else
        local condition = conditions[conditionName]
        if condition ~= nil and not this.isImmuneTo(conditionName) then
          if condition.current ~= condition.max then
            condition.current = condition.current + 1
            collided[info.collision_object.guid] = true
            Wait.time(function() collided[info.collision_object.guid] = nil end, 1)
            info.collision_object.destruct()
            this.updateCondition(conditionName, condition)
          end
        end
      end
    end
  )
end

self.addTag(R.Tag.Trait.HasConditions)

return ConditionsBar

end)
__bundle_register("api.ConditionApi", function(require, _LOADED, __bundle_register, __bundle_modules)
local ApiConsumer = require("api.ApiConsumer")

local ConditionApi = --[[---@type ConditionApi]] ApiConsumer("condition")
  .withApi("registerCondition")
  .withApi("registerTracker")
  .withApi("registerEffect")
  .withApi("getConditions")
  .withApi("getCondition")
  .withApi("getClassTrackers")
  .withApi("getClassTracker")
  .withApi("getEffects")
  .withApi("getEffect")
  .withApi("getImmunities")

return ConditionApi

end)
__bundle_register("Frames.BaseBar", function(require, _LOADED, __bundle_register, __bundle_modules)
---@class gloom_BaseBar : gloom_FigureBar

---@class gloom_BaseBar_static
---@overload fun(): gloom_BaseBar
local BaseBar = {}

local function new()
  local self = --[[---@type gloom_BaseBar]] {}

  ---@param params? any
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
__bundle_register("lib.Ui", function(require, _LOADED, __bundle_register, __bundle_modules)
local Math = require("lib.Math")

---@class Lib_UI
local Ui = {}

Ui.MouseEvent = {
  LeftClick = "-1",
  RightClick = "-2",
  MiddleClick = "-3",
  SingleTouch = "1",
  DoubleTouch = "2",
  TripleTouch = "3",
}

---@param id tts__UIElement_Id
---@param player tts__Player
function Ui.showForPlayer(id, player)
  showForPlayer({ panel = id, color = player.color })
end

function Ui.setAttribute(id, attribute, value)
  self.UI.setAttribute(id, attribute, value)
end

---@param active boolean
function Ui.setActive(id, active)
  Ui.setAttribute(id, "active", active)
end

---@param text string | number
function Ui.setText(id, text)
  Ui.setAttribute(id, "text", text)
end

---@param image string
function Ui.setImage(id, image)
  Ui.setAttribute(id, "image", image)
end

---@param xml tts__UIElement[]
---@param id string
function Ui.findElement(xml, id)
  for _, element in ipairs(xml) do
    if element.attributes.id == id then
      return element
    end
  end

  for _, element in ipairs(xml) do
    if element.children then
      local found = Ui.findElement(element.children, id)
      if found then
        return found
      end
    end
  end
end

function Ui.isLoaded()
  return self.UI.getXml() ~= ""
end

---@param id string
---@param pattern string
---@return string
function Ui.getPart(id, pattern)
  local part = id:match(pattern)
  return part
end

---@param id string
---@param pattern string
---@return integer
function Ui.getIndex(id, pattern)
  return Ui.getIndexes(id, pattern)
end

---@param id string
---@param pattern string
---@return integer, integer...
function Ui.getIndexes(id, pattern)
  local parts = table.pack(id:match(pattern))

  for i, part in ipairs(parts) do
    parts[i] = tonumber(part)
  end

  return table.unpack(parts)
end

---@param size number
---@return integer
function Ui.fontSize(size)
  return Math.round(size * 0.7)
end

---@param colorHex string
---@param adjustment? integer
function Ui.adjustColor(colorHex, adjustment)
  local color = Color.fromHex(colorHex)
  adjustment = adjustment or 1

  color.r = (color.r + adjustment) / 2
  color.g = (color.g + adjustment) / 2
  color.b = (color.b + adjustment) / 2

  local asHex = color:toHex(true)
  return "#" .. asHex
end


return Ui

end)
__bundle_register("lib.Math", function(require, _LOADED, __bundle_register, __bundle_modules)
local Math = {}

--- Same as Math.roundUp()
---@param value number
---@param decimalPlaces? number @Defaults to 0.
---@return number
function Math.round(value, decimalPlaces)
  return Math.roundUp(value, decimalPlaces)
end

---@param value number
---@param decimalPlaces? number @Defaults to 0.
---@return number
function Math.roundUp(value, decimalPlaces)
  if decimalPlaces and decimalPlaces > 0 then
    local multiple = 10 ^ decimalPlaces
    return math.floor(value * multiple + 0.5) / multiple
  end

  return math.floor(value + 0.5)
end

---@param value number
---@param decimalPlaces? number @Defaults to 0.
---@return number
function Math.roundDown(value, decimalPlaces)
  if decimalPlaces and decimalPlaces > 0 then
    local multiple = 10 ^ decimalPlaces
    return math.ceil(value * multiple + 0.5) / multiple
  end

  return math.ceil(value - 0.5)
end

---@param value number
---@param min number
---@param max number
function Math.clamp(value, min, max)
  if value < min then
    return min
  end

  if value > max then
    return max
  end

  return value
end

---@param tab number[]
---@return number
function Math.sum(tab)
  local total = 0
  for _, v in ipairs(tab) do
    total = total + v
  end

  return total
end

---@param tab number[]
---@return number
function Math.average(tab)
  local total = Math.sum(tab)
  return total / #tab
end

return Math

end)
__bundle_register("Frames.ScenarioAid", function(require, _LOADED, __bundle_register, __bundle_modules)
local BaseBar = require("Frames.BaseBar")
local R = require("api.Resource")

---@class gloom_ScenarioAidBar : gloom_FigureBar

---@type gloom_ScenarioAidBar
local ScenarioAid = BaseBar()

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

self.addTag(R.Tag.Trait.HasAidTokens)

return ScenarioAid

end)
__bundle_register("Frames.HealthBar", function(require, _LOADED, __bundle_register, __bundle_modules)
local BaseBar = require("Frames.BaseBar")

local ComponentApi = require("api.ComponentApi")
local R = require("api.Resource")
local ScenarioApi = require("api.ScenarioApi")

---@class gloom_HealthBar : gloom_FigureBar

local HealthBar = BaseBar()

local health = {
  ---@type nil | integer
  value = nil,
  ---@type nil | integer
  max = nil
}

local colors = {}

function HealthBar.init(params)
  colors.background = params.hpColour or params.backgroundColor or "#710000"
  colors.text = params.hpTextColour or params.textColor or "#FFFFFF"
  health.value = params.startingHealth
  health.max = params.startingHealth
end

function HealthBar.load(state)
  if state.health then
    health = state.health
  end
end

function HealthBar.save(state)
  state.health = health
end

function HealthBar.setStats(stats)
  local calculated = ScenarioApi.calculateFormula(stats.health)
  health = { value = calculated, max = calculated }
end

function HealthBar.render()
  setHp(health)
end

function updateColors()
  self.UI.setAttribute("progressBar", "fillImageColor", colors.background)
  self.UI.setAttribute("healthText", "color", colors.text)
  self.UI.setAttribute("addHP", "textColor", colors.text)
  self.UI.setAttribute("subHP", "textColor", colors.text)
  self.UI.setAttribute("addMax", "textColor", colors.text)
  self.UI.setAttribute("subMax", "textColor", colors.text)
end

function setHpMax()
  if health.value == health.max then
    broadcastToAll(self.getName() .. " HP is full.")
  else
    broadcastToAll(self.getName() .. " HP set from " .. health.value .. "HP to " .. health.max .. "HP.")
    setHp({ value = health.max })
  end
end

function setHp(params)
  updateColors()
  if params.value ~= nil then
    toggleUIActivity("HealthBar", "true")
    health = params
    if health.max == nil or health.max < health.value then
      health.max = health.value
    end
    updateHealthUI()
  else
    toggleUIActivity("HealthBar", "false")
  end
end

function HealthBar.getHp()
  return health
end

function getHp()
  return health
end

-- Destroy an enemy and make a coin if appropriate
function defeatClick(player, value, id)
  ComponentApi.destroyObject(self, player)
end

function add() hits(nil, "add") end

function sub() hits(nil, "sub") end

local hpMessage = {
  --- HP value at the beginning
  ---@type nil | integer
  startHp = nil,
  --- ID of the wait timer currently running if any
  ---@type nil | integer
  timer = nil,
  --- The delay to wait between clicks
  delay = 0.5,
}

local function messageHpChanges()
  local diff = --[[---@not nil]] health.value - hpMessage.startHp
  if diff == 0 then
    return
  end

  local diffName = " gained "
  if diff < 0 then
    diffName = " lost "
    diff = math.abs(diff)
  end

  broadcastToAll(
    self.getName() .. diffName .. diff .. " HP. From " .. hpMessage.startHp .. " HP to " .. health.value .. " HP.",
    "Orange")
  hpMessage.timer = nil
end


-- Do the appropriate healing / damaging
function hits(player, change)
  local oldHP = health.value

  if change == "add" then
    health.value = health.value + 1
  elseif change == "addMax" then
    health.value = health.value + 1
    health.max = health.max + 1
  elseif change == "sub" then
    health.value = health.value - 1
  elseif change == "subMax" then
    health.value = health.value - 1
    if health.max > 0 then health.max = health.max - 1 end
  end

  -- Boundary-check health values
  if health.value > health.max then health.value = health.max end
  if health.value < 0 then health.value = 0 end
  updateHealthUI()

  if oldHP ~= health.value then
    if hpMessage.timer then
      Wait.stop( --[[---@not nil]] hpMessage.timer)
      hpMessage.timer = Wait.time(messageHpChanges, hpMessage.delay)
    else
      hpMessage.startHp = oldHP
      hpMessage.timer = Wait.time(messageHpChanges, hpMessage.delay)
    end
  else
    if change == "add" then
      broadcastToAll(self.getName() .. " is already at max HP.", "Orange")
    elseif change == "sub" then
      broadcastToAll(self.getName() .. " is already at 0 HP.", "Orange")
    end
  end
end

-- Sets health in the UI
function updateHealthUI()
  -- Activate defeat interface
  if health.value and health.value < 1 and self.hasTag("Character") == false then
    self.UI.setAttribute("defeatPanel", "active", true)
    self.UI.setAttribute("healthText", "active", false)
    self.UI.setAttribute("editButton", "active", false)
  else
    self.UI.setAttribute("defeatPanel", "active", false)
    self.UI.setAttribute("healthText", "active", true)
    self.UI.setAttribute("editButton", "active", true)
  end

  self.UI.setAttribute("progressBar", "percentage", health.value / health.max * 100)
  self.UI.setAttribute("healthText", "text", health.value .. "/" .. health.max)
  if not self.hasTag(R.Tag.Trait.HasInitiative) then
    self.setDescription(health.value .. "/" .. health.max)
  end

  Global.call("changeHP", { self.getName(), health.value })
end

-- Toggle the customize monster interface (elite, max health, number)
function HealthBar.toggleEditHealth()
  -- Toggle max health modifier panel
  toggleUIActivity("healthAddPanel")
  toggleUIActivity("healthSubPanel")

  -- Toggle current HP buttons
  toggleUIActivity("healthAddMaxPanel")
  toggleUIActivity("healthSubMaxPanel")
end

---@param elementID string
---@return boolean True if element attribute "active" matches "True" or "true", False for all other circumstances
function isUIElementActive(elementID)
  local attributeValue = self.UI.getAttribute(elementID, "active")
  return (attributeValue == "True") or (attributeValue == "true")
end

--- Set "active" attribute of UI element to given boolean value
---@param elementID string
---@param state? boolean
function toggleUIActivity(elementID, state)
  if (nil == state) then state = (true ~= isUIElementActive(elementID)) end
  self.UI.setAttribute(elementID, "active", state)
end

self.addTag(R.Tag.Trait.HasHealth)

return HealthBar

end)
__bundle_register("api.ScenarioApi", function(require, _LOADED, __bundle_register, __bundle_modules)
local ApiConsumer = require("api.ApiConsumer")

---@type ScenarioApi
local ScenarioApi = ApiConsumer("scenario")
    .withApi("registerScenario")
    .withApi("registerRandomPool")
    .withApi("getCampaigns")
    .withApi("unlockScenario")
    .withApi("lockScenario")
    .withApi("revealScenario")
    .withApi("calculateFormula")
    .withApi("getScenarioLevel")
    .withApi("getScenarioLevelSettings")
    .withApi("getScenario")
    .withApi("getActiveScenario")
    .withApi("getCharacterCount")
    .withApi("getRandomPool")
    .withApi("getRandomPools")
    .withApi("revealRooms")
    .withApi("revealTreasure")
    .withApi("getElements")
    .withApi("changeElement")
    .withApi("setElement")
    .withApi("getCurrentRound")
    .withApi("changeCurrentRound")
    .withApi("startScenario")

ScenarioApi.GridType = {
  Horizontal = 1,
  Vertical = 2,
}

ScenarioApi.MonsterLevel = {
  Normal = 1,
  Elite = 2,
}

ScenarioApi.OverlayType = {
  Corridor = 1,
  DifficultTerrain = 2,
  HazardousTerrain = 3,
  Obstacle = 5,
  Trap = 7,
  Treasure = 8,
  Door = 10,
}

ScenarioApi.RandomType = {
  Tokens = 1,
  Objects = 2,
  Card = 3,
}

ScenarioApi.Element = { "Fire", "Ice", "Air", "Earth", "Light", "Dark" }

return ScenarioApi

end)
__bundle_register("api.ComponentApi", function(require, _LOADED, __bundle_register, __bundle_modules)
local ApiConsumer = require("api.ApiConsumer")

---@type ComponentApi
local ComponentApi = ApiConsumer("component")
    .withApi("spawnElement")
    .withApi("hasElement")
    .withApi("registerOverlay")
    .withApi("getOverlays")
    .withApi("registerSummon")
    .withApi("getSummons")
    .withApi("getAssetsForElementType")
    .withApi("getAssetsForObjectType")
    .withApi("requestAssetUpdate")
    .withApi("placeGameComponent")
    .withApi("placeDeck")
    .withApi("setupDeck")
    .withApi("addToDeck")
    .withApi("removeFromDeck")
    .withApi("removeDeck")
    .withApi("getDecks")
    .withApi("getDeck")
    .withApi("cleanScenarioArea")
    .withApi("cleanMonsterArea")
    .withApi("getOwner")
    .withApi("setOwner")
    .withApi("destroyObject")

ComponentApi.GameComponent = {
  EnhancementCalculator = "enhancementCalculator",
  EnhancementGuide = "enhancementGuide",
}

ComponentApi.DeckType = {
  AttackModifier = "attack-modifiers",
  Deck = "deck",
  EventDeck = "event-deck",
}

ComponentApi.DeckContainer = {
  Default = "default",
  Deck = "deck",
}

ComponentApi.Order = {
  LIFO = 0,
  FIFO = 1,
  Random = 2,
}

return ComponentApi

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
__bundle_register("lib.SignalLoading", function(require, _LOADED, __bundle_register, __bundle_modules)
local SignalLoading = {}

local TAG = "Signal Loading"
local finishedOnLoad = false

local this = {}

---@param withUi? boolean
---@return boolean
function SignalLoading.isLoaded(withUi)
  if not this.isObjectLoaded(self) then
    return false
  end

  if withUi == nil or withUi == true then
    return SignalLoading.isObjectUiLoaded(self)
  end

  return true
end

function SignalLoading.isObjectUiLoaded(obj)
  return obj.UI.getXml() ~= "" and not Global.UI.loading
end

---@param obj? tts__Object
---@return boolean
function SignalLoading.isObjectLoaded(obj)
  if not obj then
    obj = self
  end
  if obj == Global then
    return true
  end

  if obj.hasTag(TAG) then
    return --[[---@type boolean]] obj.call("isOnLoadFinished")
  end

  return this.isObjectLoaded(obj)
end

function SignalLoading.finishOnLoad()
  Wait.frames(function()
    finishedOnLoad = true
  end)
end

---@param obj tts__Object
function this.isObjectLoaded(obj)
  return not obj.spawning and not obj.loading_custom
end

function isOnLoadFinished()
  return finishedOnLoad
end

if self ~= Global then
  self.addTag(TAG)
end

return SignalLoading

end)
return __bundle_require("__root")
