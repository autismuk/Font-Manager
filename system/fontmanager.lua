--- ************************************************************************************************************************************************************************
---
---				Name : 		fontmananger.lua
---				Purpose :	Manage and Animate strings of bitmap fonts.
---				Created:	30 April 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

-- Standard OOP (with Constructor parameters added.)
_G.Base =  _G.Base or { new = function(s,...) local o = { } setmetatable(o,s) s.__index = s o:initialise(...) return o end, initialise = function() end }

local FontManager = Base:new() 																-- Fwd reference FontManager - it references and is referenced by the 
																							-- BitmapFont and BitmapString classes.

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
	for spriteID,definition in ipairs(self.rawFontInformation) do 							-- scan the raw data and get what we need.
		if type(definition) == "table" and definition.frame ~= nil then 					-- is it a table with a frame member ?
			options.frames[spriteID] = definition.frame 									-- copy the frame (x,y,w,h) of the sprite into the options structure.
			local charData = { width = definition.width, xOffset = definition.xOffset,		-- create the character data table.
														yOffset = definition.yOffset,spriteID = spriteID }
			self.characterData[definition.code] = charData 									-- and store it in the character data table 
			miny = math.min(miny,definition.yOffset) 										-- work out the uppermost position and the lowermost.
			maxy = math.max(maxy,definition.yOffset + definition.frame.height)
		end
	end
	self.fontHeight = maxy - miny + 1														-- calculate the overall height of the font.
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
end

function BitmapFont:mapCharacterToFont(characterCode)
	if self.characterData[characterCode] == nil then characterCode = '?' end 				-- map unknown chaaracters onto question marks.
	return characterCode
end

function BitmapFont:getCharacterWidth(characterCode,fontSize,xScale) 						-- information functions. These are bounding boxes if you 
	assert(self.characterData[characterCode] ~= nil,"Character unsupported in font")
	return self.characterData[characterCode].width * math.abs(xScale) * fontSize / self.fontHeight 	-- don't use pxScale, pyScale, xAdjust and yAdjust (!)
end

function BitmapFont:getCharacterHeight(characterCode,fontSize,yScale)
	assert(self.characterData[characterCode] ~= nil,"Character unsupported in font")
	return math.abs(yScale) * fontSize
end

function BitmapFont:getAspectRatio()
	return self.aspectRatio
end

--- ************************************************************************************************************************************************************************
--- 												Bitmap String class. It's slightly odd, to put it mildly :) 
---
---	It uses a view group object for basic positioning. Scaling and rotating, it depends. If you create a string, you can scale it and rotate it with transitions, just 
--- as you do with any object.  But if you want a string with animated effects, you cannot use transitions as well. The reason for this is if you 'animate' xScale,yScale
--- with transition.to its scaling effects on the object will be reset by the animation - basically they argue about who does the scaling. The xOffset,yOffset is additional
--- to the actual position, rotation probably won't work either (not sure ?)
--- ************************************************************************************************************************************************************************

local BitmapString = Base:new()

function BitmapString:initialise(font,fontSize)
	if type(font) == "string" then 															-- Font can be a bitmap font instance or a name of a font.
		font = FontManager:getFont(font) 													-- if it's a name, fetch it from the font manager.
	end
	self.isValid = false 																	-- needs repainting ?
	self.font = font 																		-- Save reference to a bitmap font.
	self.fontSize = fontSize or 32 															-- Save reference to the font size.
	self.text = "" 																			-- text as string.
	self.length = 0 																		-- number of characters.
	self.characterCodes = {} 																-- Character codes of string, fed through mapper.
	self.displayObjects = {} 																-- Corresponding display objects
	self.direction = 0 																		-- text direction, in degrees (right angles only)
	self.xScale, self.yScale = 1,1 															-- text standard scale.
	self.spacingAdjust = 0 																	-- spacing adjustment.
	self.usageCount = 0 																	-- usage count (tracks # of create/deleted objects)
	self.anchorX,self.anchorY = 0.5,0.5 													-- anchor position.
	self.viewGroup = display.newGroup() 													-- this is the group the objects are put in.
	self.createTime = system.getTimer() 													-- remember bitmap creation time.
	self.modifier = nil 																	-- modifier function or instance.
	self.fontAnimated = false 																-- not an animated bitmap
	self.animationSpeedScalar = 1 															-- animation speed adjustment.
	FontManager:addStringReference(self) 													-- tell the font manager about the new string.
end

function BitmapString:destroy()
	self:setText("") 																		-- this deletes all the display objects.
	self.viewGroup:removeSelf() 															-- delete the viewgroup
	self.font = nil self.characterCodes = nil self.displayObjects = nil 					-- then nil all the references.
	self.viewGroup = nil 																	-- no reference to view group
	self.modifier = nil 																	-- no reference to a modifier instance if there was one
end

function BitmapString:setText(text) 														-- set the text, adjust display objects to suit, reusing where possible.
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
		self.displayObjects[i] = self:_useOrCreateCharacterObject(code) 					-- create and store display objects
	end
	self.length = #text 																	-- store the length of the string.
	for _,obj in pairs(self.stockObjects) do 												-- remove any objects left in the stock.
		if obj ~= nil then 
			obj:removeSelf() 																-- remove it from everything.
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
function BitmapString:_useOrCreateCharacterObject(characterCode)
	for i = 1,#self.stockList do 															-- check through the stock list.
		if self.stockList[i] == characterCode then 											-- found a matching one.
			local obj = self.stockObjects[i] 												-- keep a reference to the stock object
			self.stockList[i] = -1 															-- set the character code to an illegal one, won't match again.
			self.stockObjects[i] = nil 														-- clear the reference to the stock object
			return obj 																		-- return the reused object.
		end
	end
	self.usageCount = self.usageCount + 1 													-- create a new one, so bump the usage counter we check with.
	local newObject = self.font:getCharacter(characterCode) 								-- we need a new one.
	self.viewGroup:insert(newObject) 														-- put it in the view group
	return newObject
end

--
--	Marks the string as invalid and in need of repainting.
--

function BitmapString:reformat() 															-- reposition the string on the screen.
	self.isValid = false
end


function BitmapString:repositionAndScale()
	self.isValid = true 																	-- it will be valid at this point.
	if self.length == 0 then return end 													-- if length is zero, we don't have to do anything.
	local nextX,nextY = 0,0		 															-- where the next character goes.
	local height = self.font:getCharacterHeight(32,self.fontSize,self.yScale) 				-- all characters are the same height, or in the same box.
	local maxx,maxy,minx,miny 																-- bounding box of the unmodified character.
	local elapsed = system.getTimer() - self.createTime 									-- elapsed time since creation.
	local minScale = 0.6

	for i = 1,self.length do 																
		local width = self.font:getCharacterWidth(self.characterCodes[i],					-- calculate the width of the character.
																self.fontSize,self.xScale)

		if i == 1 then minx,miny,maxx,maxy = 0,0,width,height end 							-- initialise bounding box to first char first time.

		local modifier = { xScale = 1, yScale = 1, xOffset = 0, yOffset = 0, rotation = 0 }	-- default modifier

		if self.modifier ~= nil then 														-- modifier provided
			local cPos = math.round(100 * (i - 1) / (self.length - 1)) 						-- position in string 0->100
			if self.fontAnimated then 														-- if animated then advance that position by time.
				cPos = math.round(cPos + elapsed / 100 * self.animationSpeedScalar) % 100 
			end
			if type(self.modifier) == "table" then 											-- if it is a table, e.g. a class, call its modify method
				self.modifier:modify(modifier,cPos,elapsed,i,self.length)
			else 																			-- otherwise, call it as a function.
				self.modifier(modifier,cPos,elapsed,i,self.length)
			end
			if math.abs(modifier.xScale) < 0.001 then modifier.xScale = 0.001 end 			-- very low value scaling does not work, zero causes an error
			if math.abs(modifier.yScale) < 0.001 then modifier.yScale = 0.001 end
		end

		self.font:moveScaleCharacter(self.displayObjects[i], 								-- call moveScaleCharacter with modifier.
												 self.fontSize,
												 nextX,
												 nextY,
									 			 self.xScale,self.yScale,
									 			 modifier.xScale,modifier.yScale,
									 			 modifier.xOffset,modifier.yOffset,
									 			 modifier.rotation)

		if self.direction == 0 then 														-- advance to next position using character width, updating the bounding box
			nextX = nextX + width + self.spacingAdjust * math.abs(self.xScale) 			
			maxx = nextX
		elseif self.direction == 180 then  													-- when going left, we need the width of the *next* character.
			if i < self.length then
				local pWidth = self.font:getCharacterWidth(self.characterCodes[i+1],self.fontSize,self.xScale)
				nextX = nextX - pWidth - self.spacingAdjust * math.abs(self.xScale) 	
				minx = nextX
			end
		elseif self.direction == 270 then  													-- up and down tend to be highly spaced, because the kerning stuff is not
			nextY = nextY + height + self.spacingAdjust * math.abs(self.xScale) 			-- designed for this. You can fix it with setSpacing()
			maxy = nextY
		else
			miny = nextY
			nextY = nextY - height - self.spacingAdjust * math.abs(self.xScale) 			

		end
	end

	local xOffset = -minx-(maxx-minx) * self.anchorX 										-- we want it to be centred around the anchor point, we cannot use anchorChildren
	local yOffset = -miny-(maxy-miny) * self.anchorY 										-- because of the animated modifications, so we calculate it

	for i = 1,self.length do 																-- and move the objects appropriately.
		self.displayObjects[i].x = self.displayObjects[i].x + xOffset
		self.displayObjects[i].y = self.displayObjects[i].y + yOffset
	end
end

function BitmapString:getView() return self.viewGroup end 									-- a stack of helpers
function BitmapString:isAnimated() return self.fontAnimated end
function BitmapString:isInvalid() return not self.isValid end

function BitmapString:animate(speedScalar)
	self.fontAnimated = true 	 															-- enable animation
	self.animationSpeedScalar = speedScalar or 1 											-- set speed scalar
	return self
end

function BitmapString:moveTo(x,y)
	self.viewGroup.x,self.viewGroup.y = x,y 
	return self
end

function BitmapString:setFont(font,fontSize)
	local originalText = self.text 															-- preserve the original text
	self:setText("") 																		-- set the text to empty, which clears up the displayObjects etc.
	if type(font) == "string" then 															-- if it's a name, get the font from the font manager.
		font = FontManager:getFont(font)
	end
	self.font = font 																		-- update font and font size
	self.fontSize = fontSize or self.fontSize
	self:setText(originalText) 																-- and put the text back.
	return self
end

function BitmapString:setAnchor(anchorX,anchorY)
	self.anchorX,self.anchorY = anchorX,anchorY
	self:reformat()
	return self
end

function BitmapString:setScale(xScale,yScale)
	assert(xScale ~= 0 and yScale ~= 0,"Scales cannot be zero")
	self.xScale,self.yScale = xScale or 1,yScale or 1
	self:reformat()
	return self
end

function BitmapString:setDirection(direction)
	self.direction = ((direction or 0)+3600) % 360
	assert(self.direction/90 == math.floor(self.direction/90),"Only right angle directions allowed")
	self:reformat()
	return self
end

function BitmapString:setSpacing(spacing)
	self.spacingAdjust = spacing or 0
	self:reformat()
	return self
end

function BitmapString:setFontSize(size)
	self.fontSize = size
	self:reformat()
	return self
end

function BitmapString:setModifier(funcOrTable)
	if type(funcOrTable) == "string" then 													-- get it from the directory if is a string
		funcOrTable = FontManager:getModifier(funcOrTable)
	end
	self.modifier = funcOrTable
	self:reformat()
	return self
end

--- ************************************************************************************************************************************************************************
---																	Font Manager Class
--- ************************************************************************************************************************************************************************

function FontManager:initialise()
	self.fontList = {} 																		-- maps font name (l/c) to bitmap object
	self.currentStrings = {} 																-- list of current strings.
	self.eventListenerAttached = false 														-- enter Frame is not attached.
	self.animationsPerSecond = 15 															-- animation rate hertz
	self.nextAnimation = 0 																	-- time of next animation
	self.modifierDirectory = {} 															-- no known modifiers
end

function FontManager:clearText()
	for _,string in ipairs(self.currentStrings) do 											-- destroy all current strings.
		string:destroy()
	end 
	self.currentStrings = {} 																-- clear the current strings list
	FontManager:_stopEnterFrame() 															-- turn the animation off.
end

function FontManager:setAnimationRate(frequency) 											-- method to set the animations frequency.
	self.animationsPerSecond = frequency
end

function FontManager:getFont(fontName) 														-- load a new font.
	local keyName = fontName:lower() 														-- key used is lower case.
	if self.fontList[keyName] == nil then 													-- font not known ?
		self.fontList[keyName] = BitmapFont:new(fontName) 									-- instantiate one, using the uncapitalised name
	end
	return self.fontList[keyName] 															-- return a font instance.
end

function FontManager:addStringReference(bitmapString)
	self.currentStrings[#self.currentStrings+1] = bitmapString 								-- remember the string we are adding.
	self:_startEnterFrame() 																-- we now need the enter frame tick.
end

function FontManager:_startEnterFrame() 													-- turn animation on.
	if not self.eventListenerAttached then
		Runtime:addEventListener( "enterFrame", self )
		self.eventListenerAttached = true
	end
end

function FontManager:_stopEnterFrame() 														-- turn animation off
	if self.eventListenerAttached then
		Runtime:removeEventListener("enterFrame",self)
		self.eventListenerAttached = false
	end
end

function FontManager:enterFrame(e)
	local currentTime = system.getTimer() 													-- elapsed time in milliseconds
	if currentTime > self.nextAnimation then 												-- time to animate - we animated at a fixed rate, irrespective of fps.
		self.nextAnimation = currentTime + 1000 / self.animationsPerSecond 					-- very approximate, not too worried about errors.
		for _,string in ipairs(self.currentStrings) do 										-- iterate through current strings.
			if string:isAnimated() or string:isInvalid() then 								-- if the string is animated or invalid, then reformat it.
				string:repositionAndScale() 												-- changes will pick up in the Modifier class/function.
			end
		end
	end
end

function FontManager:curve(curveDefinition,position)
	curveDefinition.startAngle = curveDefinition.startAngle or 0 							-- where in the curve the font is, so by default it is 0-90
	curveDefinition.endAngle = curveDefinition.endAngle or 180
	curveDefinition.curveCount = curveDefinition.curveCount or 1 							-- number of iterations of that curve over the whole range.
	curveDefinition.formula = curveDefinition.formula or "sin" 								-- use sin by default.
	position = (math.round(position) * curveDefinition.curveCount) % 100 					-- allow for the repetition of curves.
	local angle = curveDefinition.startAngle + 												-- work out how far through the angle it is.
								(curveDefinition.endAngle - curveDefinition.startAngle) * position / 100
	angle = math.rad(angle) 																-- convert to radians
	local formula = curveDefinition.formula:lower() 										-- get formula in lower case.
	local result
	if formula == "sin" 	then result = math.sin(angle) 									-- calculate the result
	elseif formula == "cos"	then result = math.cos(angle)
	elseif formula == "tan" then result = math.tan(angle)
	else error("Unknown formula "..formula)
	end
	return result
end

function FontManager:registerModifier(name,instance)
	name = name : lower()
	assert(self.modifierDirectory[name] == nil,"Duplicate modifier")
	self.modifierDirectory[name] = instance
end

function FontManager:getModifier(name)
	name = name:lower()
	assert(self.modifierDirectory[name] ~= nil,"Unknown modifier "..name)
	return self.modifierDirectory[name]
end

FontManager:initialise() 																	-- initialise the font manager so it's a standalone object
FontManager.new = function() error("FontManager is a singleton instance") end 				-- and clear the new method so you can't instantitate a copy.

--- ************************************************************************************************************************************************************************
---																				Some Modifier Classes
--- ************************************************************************************************************************************************************************

local Modifier = Base:new() 																-- establish a base class. Probably isn't necessary :)

local WobbleModifier = Modifier:new()					 									-- Wobble Modifier makes it,err.... wobble ?

function WobbleModifier:initialise(violence) self.violence = violence or 1 end 

function WobbleModifier:modify(modifier,cPos,elapsed,index,length)
	modifier.xOffset = math.random(-self.violence,self.violence)
	modifier.yOffset = math.random(-self.violence,self.violence)
	modifier.xScale = math.random(-self.violence,self.violence) / 10 + 1
	modifier.yScale = math.random(-self.violence,self.violence) / 10 + 1
	modifier.rotation = math.random(-self.violence,self.violence) * 5
end

local SimpleCurveModifier = Modifier:new()													-- curvepos curves the text positionally vertically

function SimpleCurveModifier:initialise(start,enda,scale,count)
	self.curveDesc = { startAngle = start or 0, endAngle = enda or 180, curveCount = count or 1 }
	self.scale = scale or 1
end

function SimpleCurveModifier:modify(modifier,cPos,elapsed,index,length)
	modifier.yOffset = FontManager:curve(self.curveDesc,cPos) * 50 * self.scale
end

local SimpleCurveScaleModifier = SimpleCurveModifier:new()						 			-- curvepos scales the text vertically rather than the position.

function SimpleCurveScaleModifier:modify(modifier,cPos,elapsed,index,length)
	modifier.yScale = FontManager:curve(self.curveDesc,cPos)*self.scale+1
end

local JaggedModifier = Modifier:new()														-- jagged alternates left and right rotation.

function JaggedModifier:modify(modifier,cPos,elapsed,index,length)
	modifier.rotation = ((index % 2 * 2) - 1) * 15
end

local ZoomOutModifier = Modifier:new() 														-- Zoom out from nothing to standard
																							-- this scales letters back spaced - if you want a classic zoom
function ZoomOutModifier:initialise(zoomTime)												-- use transition.to to scale it :)
	self.zoomTime = zoomTime or 3000 				
end

function ZoomOutModifier:modify(modifier,cPos,elapsed,index,length)
	local scale = math.min(1,elapsed / self.zoomTime)
	modifier.xScale,modifier.yScale = scale,scale
end

local ZoomInModifier = ZoomOutModifier:new() 												-- Zoom in, as zoom out but the other way round

function ZoomInModifier:modify(modifier,cPos,elapsed,index,length)
	local scale = math.min(1,elapsed / self.zoomTime)
	modifier.xScale,modifier.yScale = 1-scale,1-scale
end

FontManager:registerModifier("wobble",WobbleModifier:new())									-- tell the system about them.
FontManager:registerModifier("curve",SimpleCurveModifier:new())
FontManager:registerModifier("scale",SimpleCurveScaleModifier:new())
FontManager:registerModifier("jagged",JaggedModifier:new())
FontManager:registerModifier("zoomout",ZoomOutModifier:new())
FontManager:registerModifier("zoomin",ZoomInModifier:new())

local Modifiers = { WobbleModifier = WobbleModifier,										-- create table so we can provide the Modifiers.
					SimpleCurveModifier = SimpleCurveModifier,
					SimpleCurveScaleModifier = SimpleCurveScaleModifier,
					JaggedModifier = JaggedModifier,
					ZoomOutModifier = ZoomOutModifier,
					ZoomInModifier = ZoomInModifier }

return { BitmapString = BitmapString, FontManager = FontManager, Modifiers = Modifiers }

-- Write some demos.
-- Read FNT files directly ?