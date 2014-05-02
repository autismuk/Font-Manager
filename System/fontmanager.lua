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
	self.rawFontInformation = require(BitmapFont.fontDirectory .. "." .. fontName) 			-- load the raw font information as a lua file.
	self.fontHeight = 0 																	-- actual physical font height, in pixels.
	self.characterData = {} 																-- mapping of character code to character data sizes.
	self.imageSheet = graphics.newImageSheet("fonts/" .. fontName .. ".png", 				-- create an image sheet from analysing the font data.
											 self:_analyseFontData())
end

function BitmapFont:_analyseFontData()														-- generate SpriteSheet structure and calculate font actual height.
	local options = { frames = {} }															-- this will be the spritesheet 'options' structure.
	local maxy,miny = 0,0
	local widthTotal = 0 																	-- total number of widths (for calculating aspect ratio)
	local widthCount = 0
	for spriteID,definition in ipairs(self.rawFontInformation) do 							-- scan the raw data and get what we need.
		if type(definition) == "table" and definition.frame ~= nil then 					-- is it a table with a frame member ?
			options.frames[spriteID] = definition.frame 									-- copy the frame (x,y,w,h) of the sprite into the options structure.
			local charData = { width = definition.width, xOffset = definition.xOffset,		-- create the character data table.
														yOffset = definition.yOffset,spriteID = spriteID }
			self.characterData[definition.code] = charData 									-- and store it in the character data table 
			miny = math.min(miny,definition.yOffset) 										-- work out the uppermost position and the lowermost.
			maxy = math.max(maxy,definition.yOffset + definition.frame.height)
			assert(definition.yOffset >= 0,"BitmapFont needs changes to handle -ve yoffset")-- needs tweaks if yOffset is < 0, doesn't seem to be.
			widthTotal = widthTotal + definition.width 										-- add width to width total
			widthCount = widthCount + 1 													-- bump width count.
		end
	end
	self.fontHeight = maxy - miny + 1														-- calculate the overall height of the font.
	self.aspectRatio = (widthTotal/widthCount)/self.fontHeight 								-- calculate the aspect ratio, on average.
	return options
end

function BitmapFont:getCharacter(characterCode) 											
	assert(self.characterData[characterCode] ~= nil,"Character unsupported in font")
	local obj = display.newImage(self.imageSheet,self.characterData[characterCode].spriteID)-- create it.
	obj.anchorX,obj.anchorY = 0.5,0.5 														-- we anchor around the centre of the graphic for rotating and zooming.
	obj.__bmpFontCode = characterCode 														-- move/scale needs the character code.
	return obj
end

--
--	This moves the display object to position x,y and positions it correctly allowing for the main scale (xScale,yScale) and fontSize (height in pixels)
--	for actual drawing the scale can be adjusted (pxScale,pyScale are multipliers of the scale) but the character will occupy the same space.
-- 	Finally, characters can be set at an offset from the actual position (xAdjust,yAdjust) to allow for wavy font effects and characters to move.
--
function BitmapFont:moveScaleCharacter(displayObject,fontSize,x,y,xScale,yScale,pxScale,pyScale,xOffset,yOffset,rotation)
	local scalar = fontSize / self.fontHeight 												-- how much to scale the font by to make it the required size.
	xScale = xScale * scalar yScale = yScale * scalar 										-- make scales scale to actual size.
	local axScale = math.abs(xScale) 														-- precalculate absolute value of scales, differentiating flipping
	local ayScale = math.abs(yScale) 														-- and scaling.
	pxScale = (pxScale or 1) * xScale  														-- work out final scale
	pyScale = (pyScale or 1) * yScale 
	xOffset = xOffset or 0 yOffset = yOffset or 0 											-- if no offsets provided, use 0,0
	local cData = self.characterData[displayObject.__bmpFontCode] 							-- get a reference to the character information
	local width = cData.width 																-- character width, scale 1.
	displayObject.xScale,displayObject.yScale = pxScale,pyScale 							-- apply the physical individual scale to the object
	displayObject.rotation = rotation or 0 													-- internal rotation
	displayObject.x = x + cData.xOffset * axScale + displayObject.width / 2 * axScale + xOffset * xScale
	displayObject.y = y + cData.yOffset * ayScale + displayObject.height / 2 * ayScale + yOffset * yScale
	return displayObject.x,displayObject.y
end

function BitmapFont:mapCharacterToFont(characterCode)
	if self.characterData[characterCode] == nil then characterCode = '?' end 				-- map unknown chaaracters onto question marks.
	return characterCode
end

function BitmapFont:getCharacterWidth(characterCode,fontSize,xScale) 						-- information functions. These are bounding boxes if you 
	assert(self.characterData[characterCode] ~= nil,"Character unsupported in font")
	return self.characterData[characterCode].width * xScale * fontSize / self.fontHeight 	-- don't use pxScale, pyScale, xAdjust and yAdjust (!)
end

function BitmapFont:getCharacterHeight(characterCode,fontSize,yScale)
	assert(self.characterData[characterCode] ~= nil,"Character unsupported in font")
	return yScale * fontSize
end

function BitmapFont:getAspectRatio()
	return self.aspectRatio
end

--- ************************************************************************************************************************************************************************
--- ************************************************************************************************************************************************************************

local BitmapString = Base:new()

function BitmapString:initialise(font,fontSize)
	-- TODO: Look up string in Font Manager Singleton.
	self.font = font 																		-- Save reference to a bitmap font.
	self.fontSize = fontSize 																-- Save reference to the font size.
	self.text = "" 																			-- text as string.
	self.length = 0 																		-- number of characters.
	self.characterCodes = {} 																-- Character codes of string, fed through mapper.
	self.displayObjects = {} 																-- Corresponding display objects
	self.direction = 0 																		-- text direction, in degrees.
	self.xScale, self.yScale = 1,1 															-- text standard scale.
	self.spacingAdjust = 0 																	-- spacing adjustment.
	self.usageCount = 0 																	-- usage count (tracks # of create/deleted objects)
	self.anchorX,self.anchorY = 0,0 														-- anchor position.
end

function BitmapString:destroy()
	self:setText("") 																		-- this deletes all the display objects.
	self.font = nil self.characterCodes = nil self.displayObjects = nil 					-- then nil all the references.
end

function BitmapString:setText(text) 														-- set the text
	if text == self.text then return self end 												-- if no changes, then return immediately.
	self.text = text 																		-- save the text
	self.stockList = self.characterCodes 													-- put all the current objects where we can reuse them if we can.
	self.stockObjects = self.displayObjects
	self.characterCodes = {} 																-- and blank the current list. 
	self.displayObjects = {}
	for i = 1,#text do 																		-- work through every character.
		local code = text:sub(i,i):byte(1)													-- convert to ascii code
		code = self.font:mapCharacterToFont(code) 											-- map to an available font character.
		self.characterCodes[i] = code 														-- save the code.
		self.displayObjects[i] = self:useOrCreateCharacterObject(code) 						-- create and store display objects
	end
	self.length = #text 																	-- store the length of the string.
	for _,obj in ipairs(self.stockObjects) do 												-- remove any objects left in the stock.
		if obj ~= nil then 
			display.remove(obj) 
			self.usageCount = self.usageCount - 1 											-- reduce the count, so it matches the number of live objects
		end
	end
	self.stockList = nil  																	-- erase the outstanding stock list.
	self.stockObjects = nil 																-- so there are no outstanding references.
	assert(self.usageCount == self.length,"Bitmap Object leak")
	self:reformat() 																		-- reformat the string.
	return self 																			-- permit chaining.
end

--
-- 	This acquires a display object with the given character. It looks in the 'stock list' - the list of characters used before, if one is 
-- 	found it recycles it. Otherwise it creates a new one.
--
function BitmapString:useOrCreateCharacterObject(characterCode)
	for i = 1,#self.stockList do 															-- check through the stock list.
		if self.stockList[i] == characterCode then 											-- found a matching one.
			local obj = self.stockObjects[i] 												-- keep a reference to the stock object
			self.stockList[i] = -1 															-- set the character code to an illegal one, won't match again.
			self.stockObjects[i] = nil 														-- clear the reference to the stock object
			return obj 																		-- return the reused object.
		end
	end
	self.usageCount = self.usageCount + 1 													-- create a new one, so bump the usage counter we check with.
	return self.font:getCharacter(characterCode) 											-- we need a new one.
end

--
--	This repositions everything after any change that effects the display.
--

function BitmapString:reformat() 															-- reposition the string on the screen.
	if self.length == 0 then return end 													-- if length is zero, we don't have to do anything.

	local nextX,nextY = 0,0 															-- where the next character goes.
	local charXPositions = {} 																-- X Positions of character (needed for directional drawing)
	local charXWidth = {} 																	-- The character widths

	for i = 1,self.length do 																
		local charWidth = self.font:getCharacterWidth(self.characterCodes[i],				-- calculate the width of the character.
																self.fontSize,self.xScale)
		local xctr,yctr 																	-- centre point of unmodified characters.
		xctr,yctr = self.font:moveScaleCharacter(self.displayObjects[i],
												 self.fontSize,
												 nextX,
												 nextY,
									 			 self.xScale,self.yScale) --TO DO Put post position modifications in

		charXPositions[i] = xctr 															-- save the X position for rotation, if we are rotating.
		charXWidth[i] = charWidth 															-- save the character widths.
		nextX = nextX + charWidth + self.spacingAdjust * self.xScale 						-- move to next position.
	end

	if self.length > 1 and self.direction % 360 ~= 0 then 									-- if two things to display, and not left -> right then
		local radians = math.rad(self.direction) 											-- get direction in radians
		for i = 2,self.length do 															-- now reposition all the other characters.
			local prop = (charXPositions[i] - charXPositions[1]) 				 			-- this is how far the distance is.
			self.displayObjects[i].x = self.displayObjects[1].x + prop * math.cos(radians) 	-- adjust all the positions using the cos and sine of the angle
			self.displayObjects[i].y = self.displayObjects[i].y - prop * math.sin(radians)  -- x is offset from object 1, y from the current position.
		end
	end

	local maxx,maxy,minx,miny = -999,-999,999,999 											-- work out the bounding box for the whole thing, so we can 
	for i = 1,self.length do 																-- work out where to move it to, finally.
		minx = math.min(minx,self.displayObjects[i].x-charXWidth[i]/2)
		miny = math.min(minx,self.displayObjects[i].y-self.fontSize*math.abs(self.yScale/2))
		maxx = math.max(maxx,self.displayObjects[i].x+charXWidth[i]/2)
		maxy = math.max(maxy,self.displayObjects[i].y+self.fontSize*math.abs(self.yScale/2))
	end

	print(minx,miny,maxx,maxy)
end

local font = BitmapFont:new("demofont")
local str = BitmapString:new(font,32)
str.x = 160
str.y = 240
str.xScale, str.yScale = 2,2
str.direction = -2
str:setText("Test string")
display.newLine(0,240,320,240)
display.newLine(160,0,160,480)
return { BitmapFont = BitmapFont }