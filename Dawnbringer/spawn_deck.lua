local TARGET_GUID = "dawnbringer-sheet"
local DECK = "Dawnbringer Master Deck"
local OFFSET = {-1.5, 1.2, 10.5}        
local FACE = "https://github.com/kiltev/haven-custom-content/blob/main/Dawnbringer/items-front.png?raw=true&v=6"
local BACK = "https://github.com/kiltev/haven-custom-content/blob/main/Dawnbringer/items-back.png?raw=true&v=1"

local S = [==[
function onLoad()
 self.createButton({click_function="triggerSplit",function_owner=self,label="Open Pack",position={0,.5,0},width=1400,height=400,font_size=220,color={0,0,0,.9},font_color={1,1,1,1}})
end
function triggerSplit()
 self.clearButtons()
 local cards = self.spread(1)
 local sizes, p, stepX, stepZ = {4,3,3,2,2,3,4,1,2}, self.getPosition(), 2.5, 3.5
 Wait.frames(function()
  local k, g = 1, 9
  for i, n in ipairs(sizes) do
   local row, col = math.floor((i-1)/5), (i-1)%5
   local pos = {p.x + col*stepX, p.y + 1, p.z - row*stepZ}
   local name = "Dawnbringer Group "..g
   g = g - 1
   for c=1, n do
    if cards[k] then
     cards[k].setName(name)
     cards[k].setPositionSmooth({pos[1], pos[2] + c*.05, pos[3]}, false, false)
    end
    k = k + 1
   end
  end
 end, 2)
end]==]

local function exists()
    for _, o in ipairs(getObjects()) do
        if o.getName and o.getName() == DECK then return true end
    end
    return false
end

local function spawnNear(o)
    if exists() then return end
    local p = o.getPosition()
    spawnObject({
        type = "DeckCustom",
        position = {p.x + OFFSET[1], p.y + OFFSET[2], p.z + OFFSET[3]},
        rotation = {0, 180, 0},
        scale = {.73, 1, .73},
        sound = false,
        callback_function = function(deckObj)
            deckObj.setCustomObject({face = FACE, back = BACK, width = 3, height = 8, number = 24, back_is_hidden = true, unique_back = true})
            deckObj.setName(DECK)
            deckObj.setLuaScript(S)
            deckObj.reload()
        end
    })
end

local last, stable, tries, done = nil, 0, 0, false

Wait.time(function()
    if done or exists() then return end
    tries = tries + 1

    local sheet = getObjectFromGUID(TARGET_GUID)
    if sheet then
        local p = sheet.getPosition()
        if last and math.abs(p.x-last.x) < 0.05 and math.abs(p.y-last.y) < 0.05 and math.abs(p.z-last.z) < 0.05 then
            stable = stable + 1
        else
            stable = 0
        end
        last = {x=p.x, y=p.y, z=p.z}

        if stable >= 3 then
            done = true
            spawnNear(sheet)
            return
        end
    end

    if tries >= 60 then
        done = true
        spawnNear(getObjectFromGUID(TARGET_GUID) or self)
    end
end, 0.5, 60)