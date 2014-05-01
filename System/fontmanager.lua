--- ************************************************************************************************************************************************************************
---
---				Name : 		scenemgr.lua
---				Purpose :	Manage Scene transitions and state
---				Created:	30 April 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

-- Standard OOP (with Constructor parameters added.)
_G.Base =  _G.Base or { new = function(s,...) local o = { } setmetatable(o,s) s.__index = s s:initialise(...) return o end, initialise = function() end }


--- ************************************************************************************************************************************************************************
---											Class representing a bit map font, with methods for processing that font
--- ************************************************************************************************************************************************************************

local BitmapFont = Base:new()

BitmapFont.fontDirectory = "fonts" 															-- where fonts are, lua and png.

function BitmapFont:initialise(fontName)
	self.fontName = fontName 																-- save font name.
	self.rawFontInformation = require(BitmapFont.fontDirectory .. "." .. fontName) 			-- load the raw font information
	self.fontHeight = 0 																	-- actual font height, in pixels.
	self.characterData = {} 																-- mapping of character code to character data sizes.
	self.imageSheet = graphics.newImageSheet("fonts/" .. fontName .. ".png", 				-- create an image sheet from analysing the font data.
											 self:_analyseFontData())
end

function BitmapFont:_analyseFontData()
	local options = { frames = {} }															-- this will be the spritesheet 'options' structure.
	local maxy,miny = 0,0
	for spriteID,definition in ipairs(self.rawFontInformation) do 							-- scan the raw data and get what we need.
		if type(definition) == "table" then
			options.frames[spriteID] = definition.frame 									-- copy the frame (x,y,w,h) of the sprite into the options structure.
			local charData = { width = definition.width, xOffset = definition.xOffset,		-- create the character data table.
														yOffset = definition.yOffset,spriteID = spriteID }
			self.characterData[definition.code] = charData 									-- and store it in the character data table 
			miny = math.min(miny,definition.yOffset) 										-- work out the uppermost position and the lowermost.
			maxy = math.max(maxy,definition.yOffset + definition.frame.height)
			assert(definition.yOffset >= 0,"BitmapFont needs changes to handle -ve yoffset")-- needs tweaks if yOffset is < 0, doesn't seem to be.
		end
	end
	self.fontHeight = maxy - miny + 1														-- calculate the overall height of the font.
	return options
end

function BitmapFont:getCharacter(characterCode) 											
	local obj = display.newImage(self.imageSheet,self.characterData[characterCode].spriteID)-- create it.
	obj.anchorX,obj.anchorY = 0,0 															-- we anchor around the top left position.
	obj.__bmpFontCode = characterCode 														-- move/scale needs the character code.
	return obj
end

--
--	This moves the display object to position x,y and positions it correctly allowing for the main scale (xScale,yScale)
--	for actual drawing the scale can be overridden (pxScale,pyScale) but the character will occupy the same space.
-- 	Finally, characters can be set at an offset from the actual position (xAdjust,yAdjust) to allow for wavy font effects and characters to move.
--
function BitmapFont:moveScaleCharacter(displayObject,x,y,xScale,yScale,pxScale,pyScale,xAdjust,yAdjust)
	pxScale = pxScale or xScale pyScale = pyScale or yScale 								-- if no draw scale is used, use the original scale.
	xAdjust = xAdjust or 0 yAdjust = yAdjust or 0 											-- if no adjustment provided, use 0,0
	local cData = self.characterData[displayObject.__bmpFontCode] 							-- get a reference to the character information
	local width = cData.width 																-- character width, scale 1.
	displayObject.xScale,displayObject.yScale = pxScale,pyScale 							-- apply the physical individual scale to the object
	displayObject.x = x + cData.xOffset * xScale - 											-- set position, allowing for offset and scale differences.
									(pxScale-xScale) * (width/2-cData.xOffset/2) + xAdjust * xScale
	displayObject.y = y + cData.yOffset * yScale - 
									(pyScale-yScale) * (self.fontHeight/2-cData.yOffset/2) + yAdjust * yScale
	return width * xScale 																	-- return space used by this character
end

function BitmapFont:getCharacterWidth(characterCode,xScale)
	return self.characterData[characterCode].width * xScale
end

local scale = 1.7
local zscale = 3
local letters = {}
local font = BitmapFont:new("demofont")

display.newCircle(64,320,4)

local text = "Hello, world !"
for i = 1,#text do
	local c = text:sub(i,i):byte(1)
	letters[i] = font:getCharacter(c)
end

function repaint()
	local x = 64
	for i = 1,#text do
		local xs = scale
		if i == 2 then xs = zscale end
		x = x + font:moveScaleCharacter(letters[i],x,320,scale,scale,xs,scale,0,(xs-2)*20)
	end
end

local frame = 0

Runtime:addEventListener( "enterFrame", function(e) 
	frame = frame + 1
	local p = math.floor(frame) % 40
	if p > 20 then p = 40-p end
	zscale = 0.1 + p/5
	repaint()

end)
