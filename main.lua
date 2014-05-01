-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------

display.setStatusBar(display.HiddenStatusBar)

fm = require("system.fontmanager")



--[[
local fontList = require("fonts.demofont")
local options = { frames = {} }
local fontFile = nil
local asciiToFrame = {}
for item,cDef in ipairs(fontList) do 
    if type(cDef) == "table" then 
        options.frames[item] = cDef.frame 
        asciiToFrame[cDef.code] = item
    end
    if type(cDef) == "string" then fontFile = cDef end
end


local sheet = graphics.newImageSheet("fonts/"..fontFile,options)

for i = 32,127 do
    if asciiToFrame[i] ~= nil then
        local s = display.newImage(sheet,asciiToFrame[i])    
        p = i - 32
        s.x = p % 8 * 32 + 32
        s.y = math.floor(p / 8) * 32 + 32   
        transition.to(s,{ rotation = 3600, time = 2500 })
    end
end

s = "Hello World"
x = 30

for i = 1,#s do
    local ch = s:sub(i,i):byte(1)
    local f = asciiToFrame[ch]
    local d = display.newImage(sheet,f)
    d.anchorX,d.anchorY = 0,0
    print(fontList[f].xOffset)
    d.x = x+fontList[f].xOffset
    d.y = 420+fontList[f].yOffset
    x = x + fontList[f].width
end

--]]
