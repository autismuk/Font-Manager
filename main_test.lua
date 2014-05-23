--- ************************************************************************************************************************************************************************
---
---				Name : 		main_test.lua
---				Purpose :	Bullying test of BitmapString class
---				Created:	23 May 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

display.setStatusBar(display.HiddenStatusBar)
fm = require("system.fontmanager")

local marker = display.newBitmapText("Test",160,240,"retrofont",40)
local stringList = {}
local count = 10000
local maxStrings = 500

local fontList = { "retrofont","demofont","font2","testfont"}

local function tidyUp()
	for _,bms in pairs(stringList) do bms:remove() end
	marker:remove(true)
	print("Ok completed.")
end

local function sillyModifier(modifier,cPos,info) 
	modifier.xOffset = math.random(-10,10)
	modifier.yOffset = math.random(-10,10)
	modifier.xScale = math.random(-10,10)/5 + 1
	modifier.yScale = math.random(-10,10)/5 + 1
	modifier.alpha  = math.random(0,10)/20+0.5
	modifier.rotation = math.random(0,360)
end 

local function getX() return math.random(0,320) end 
local function getY() return math.random(0,480) end 
local function getFont() return fontList[math.random(1,#fontList)] end 
local function getFontSize() return math.random(1,200) end 

local function getText() 
	local str = ""
	local size = math.random(1,32) 
	for i = 1,size do str = str .. string.char(math.random(32,96)) end 
	return str 
end 

Runtime:addEventListener("enterFrame",function(e)
	count = count - 1
	if count == 0 then tidyUp() end
	if count > 0 then 
		if count % 100 == 0 then print(count) end
		local index = math.random(1,maxStrings)
		if stringList[index] == nil then 
			stringList[index] = display.newBitmapText(getText(),getX(),getY(),getFont(),getFontSize())
			stringList[index]:setModifier(sillyModifier):animate()
			stringList[index]:setAnchor(math.random(0,2)/2,math.random(0,2)/2)
		end 
		if math.random(1,3) == 1 then 
			local s = stringList[index]
			s:setText(getText()):moveTo(getX(),getY()):setFont(getFont(),getFontSize()):setDirection(math.random(0,3)*90)
		end
		if math.random(1,5) == 1 then 
			stringList[index]:removeSelf() 
			stringList[index] = nil
		end 
	end
end)
