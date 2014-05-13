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

--//	The fontmananger class controls, animates and updates all the fonts on the screen. It also tracks what fonts are used, and keeps a library of standard
--// 	effects. It is a singleton.

local FontManager = Base:new() 																-- Fwd reference FontManager - it references and is referenced by the 
																							-- BitmapFont and BitmapString classes.

--- ************************************************************************************************************************************************************************
--// 						This class encapsulates a bitmap font, producing characters 'on demand'. (Note, no longer requires a .lua file)
--- ************************************************************************************************************************************************************************

local BitmapFont = Base:new()

BitmapFont.fontDirectory = "fonts" 															-- where fonts are, lua and png.

--//	The Bitmap Font constructor. This reads in the font data 
--//	@fontName [string] name of font (case is sensitive, so I advise use of lower case only)

function BitmapFont:initialise(fontName)
	self.fontName = fontName 																-- save font name.
	self.fontHeight = 0 																	-- actual physical font height, in pixels.
	self.characterData = {} 																-- mapping of character code to character data sizes.
	self:loadFont(fontName)																	-- load the font.
	self:calculateFontHeight() 																-- calculate the font height
end

--//%	Load the font from the .fnt definition - the stub is provided (e.g. 'fred' loads fonts/fred.fnt). Parses the .fnt file to get the character
--//	information, and the image file name.

function BitmapFont:loadFont(fontName)
	local fontFile = BitmapFont.fontDirectory .. "/" .. fontName .. ".fnt" 					-- this is the directory the font is in.
	local source = io.lines(system.pathForFile(fontFile,system.ResourceDirectory)) 			-- read the lines from this file.
	local options = { frames = {} }															-- this is going to be the options read in (see newImageSheet() function)
	local spriteCount = 1 																	-- next available 'frame'
	local imageFile = nil 																	-- this is the sprite image file which will be read in eventually.

	for l in source do 
		local page,fileName = l:match('^%s*page%s*id%s*=%s*(%d+)%s*file%s*=%s*%"(.*)%"$') 	-- is it the page line, which tells us the file name ?
		if page ~= nil then 																-- if so , use it for the file name.
			assert(page == "0","We do not support font files with page > 0. If you have one contact the author")
			imageFile = BitmapFont.fontDirectory .. "/" .. fileName 						-- not currently supporting multi page files, are there any ?
		end
		if l:match("^%s*char%sid") ~= nil then 												-- found a "char id" ? (not chars)
																							-- rip out the x,y,width,height bit that says where the text is.
			local x,y,w,h = l:match("x%s*=%s*(%d+)%s*y%s*=%s*(%d+)%s*width%s*=%s*(%d+)%s*height%s*=%s*(%d+)%s*")
			assert(h ~= nil,"Failure to read line in .fnt file, contact author") 			-- check this parsed out okay.
			local optionsEntry = { x = x*1, y = y*1, width = w*1, height = h*1 } 			-- create a suitable table for use by the imagesheet code.
			options.frames[spriteCount] = optionsEntry 										-- store in the options structure

																							-- now rip out id, xoffset and yoffset
			local charID,xOffset,yOffset,xAdvance = l:match("id%s*=%s*(%d+).*xoffset%s*=%s*([%-%d]+).*yoffset%s*=%s*([%-%d]+).*xadvance%s*=%s*([%-%d]+)")
			assert(xAdvance ~= nil,"Failure to read line in .fnt file, contact author")
			local charInfo = { width = xAdvance*1, xOffset = xOffset*1, yOffset = yOffset*1}-- copy this information into the info structure
			charInfo.spriteID = spriteCount 												-- tell it which sprite this character is
			charInfo.frame = optionsEntry 													-- and store a reference to the sprite rectangle in the image sheet

			assert(self.characterData[charID] == nil,"Duplicate character code, contact author")
			self.characterData[charID*1] = charInfo 										-- store the full font information in the characterData table.
			spriteCount = spriteCount + 1 													-- bump the number of sprites
		end
	end
	assert(imageFile ~= nil,"No image file in fnt file, contact the author")				-- didn't find a 'page' entry i.e. no file name
	self.imageSheet = graphics.newImageSheet(imageFile,options) 							-- load in the image sheet
	assert(self.imageSheet ~= nil,"Image file " .. imageFile .. "failed to load for fnt file ".. fontFile)	
end

--//%	calculates the font height of the loaded bitmap

function BitmapFont:calculateFontHeight()
	local maxy,miny = -999,999 																-- start ranges from top and bottom
	for _,def in pairs(self.characterData) do 												-- work through the font characters
		miny = math.min(miny,def.yOffset) 													-- work out the uppermost position and the lowermost.
		maxy = math.max(maxy,def.yOffset + def.frame.height)
	end
	self.fontHeight = maxy - miny + 1														-- calculate the overall height of the font.
end

--//		Get a display object with the given character in it, centred around the middle - roughly :)
--//		@characterCode [number] 	character code of the character required
--//		@return [displayObject]		a display object representing the character.

function BitmapFont:getCharacter(characterCode) 											
	assert(self.characterData[characterCode] ~= nil,"Character unsupported in font")
	local obj = display.newImage(self.imageSheet,self.characterData[characterCode].spriteID)-- create it.
	obj.anchorX,obj.anchorY = 0.5,0.5 														-- we anchor around the centre of the graphic for rotating and zooming.
	obj.__bmpFontCode = characterCode 														-- move/scale needs the character code.
	return obj
end

--//%	This moves the display object to position x,y and positions it correctly allowing for the main scale (xScale,yScale) and fontSize (height in pixels)
--//	for actual drawing the scale can be adjusted (pxScale,pyScale are multipliers of the scale) but the character will occupy the same space.
--//	Finally, characters can be set at an offset from the actual position (xAdjust,yAdjust) to allow for wavy font effects and characters to move.
--
--//	@displayObject 	[display Object]		Corona SDK Object from the getCharacter() factory
--//	@fontSize 		[number]				Font height in pixels - scales from the bitmap height automatically
--//	@x 				[number]				Horizontal position of charcter centre, with offset adjustment.
--//	@y 				[number]				Vertictal position of charcter centre, with offset adjustment.
--//	@xScale 		[number]				Horizontal main scale
--//	@yScale 		[number]				Vertical main scale
--//	@pxScale 		[number]				Auxiliary Scalar for the horiziontal scale
--//	@pyScale 		[number]				Auxiliary Scalar for the vertical scale
--//	@xOffset 		[number] 				Horizontal Offset from the given position
--//	@yOffset 		[number] 				Vertical Offset from the given position
--//	@rotation 		[number]				Rotation of character around its centre.
	
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

--//	Map any character to a code - currently maps any unsupported character to ? but could be extended to (say) map a-acute and a-grave to a 
--//	in French.
--//	@characterCode [number]		Character code to map
--//	@return [number]			Code of character which does actually exist in the font.

function BitmapFont:mapCharacterToFont(characterCode)
	if self.characterData[characterCode] == nil then characterCode = 63 end 				-- map unknown characters onto question mark (Code 63).
	return characterCode
end

--//	Get the character width, after scaling.
--//	@characterCode [number]		Character code of character to measure
--//	@fontSize 		[number]	Size of the font (horizontal pixels)
--//	@xScale 		[number]	Horizontal Scaling
--//	@return 		[number]	Horizontal width in pixels.

function BitmapFont:getCharacterWidth(characterCode,fontSize,xScale) 						-- information functions. These are bounding boxes if you 
	assert(self.characterData[characterCode] ~= nil,"Character unsupported in font")
	return self.characterData[characterCode].width * math.abs(xScale) * fontSize / self.fontHeight 	-- don't use pxScale, pyScale, xAdjust and yAdjust (!)
end

--//	Get the character height, after scaling.
--//	@characterCode [number]		Character code of character to measure. Not actually needed as all characters are a fixed height
--//	@fontSize 		[number]	Size of the font (horizontal pixels)
--//	@xScale 		[number]	Vertical Scaling
--//	@return 		[number]	Vertical width in pixels.

function BitmapFont:getCharacterHeight(characterCode,fontSize,yScale)
	assert(self.characterData[characterCode] ~= nil,"Character unsupported in font")
	return math.abs(yScale) * fontSize
end

--- ************************************************************************************************************************************************************************
--// 	It uses a view group object for basic positioning. Scaling and rotating, it depends. If you create a string, you can scale it and rotate it with transitions, just 
--// 	as you do with any object.  But if you want a string with animated effects, you cannot use transitions as well. The reason for this is if you 'animate' xScale,yScale
--// 	with transition.to its scaling effects on the object will be reset by the animation - basically they argue about who does the scaling. The xOffset,yOffset is additional
--// 	to the actual position, rotation probably won't work either (not sure ?)
--- ************************************************************************************************************************************************************************

local BitmapString = Base:new()

--//		Constructor. Font can be a reference or a string (in this case the FontManager looks it up), font Size defaults to 32 pixels. Creates an empty
--//		Bitmap String.
--//		@font [String/Reference]	Font to use to create string
--//		@fontSize [number]			Height of font in pixels, default is 32 if ommitted.

function BitmapString:initialise(font,fontSize)
	if type(font) == "string" then 															-- Font can be a bitmap font instance or a name of a font.
		font = FontManager:getFont(font) 													-- if it's a name, fetch it from the font manager.
	end
	self.isValid = false 																	-- needs repainting ?
	self.font = font 																		-- Save reference to a bitmap font.
	self.fontSize = fontSize or 32 															-- Save reference to the font size.
	self.text = "" 																			-- text as string.
	self.lineData = {}																		-- character lines array.
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
	self.eventListeners = {} 																-- map of event listener name -> handler.
	self.verticalSpacing = 1 																-- vertical spacing scalar
	FontManager:addStringReference(self) 													-- tell the font manager about the new string.
end

--//		Remove the current string from the screen and remove the reference from the list.

function BitmapString:remove()
	self:_destroy() 																		-- delete the string, free all resources etc.
	FontManager:removeStringReference(self) 												-- tell FontManager to forget about it.
end


--//%		Destructor, not called by lua, but used by clear screen method - tidies up bitmap font and frees all resources, so ClearScreen can be used
--//		on scene exit event or similar.

function BitmapString:_destroy()
	self:setText("") 																		-- this deletes all the display objects.
	for eventName,handler in pairs(self.eventListeners) do 									-- remove all event listeners that are installed.
		self.viewGroup:removeEventListener(eventName,handler)
	end
	self.viewGroup:removeSelf() 															-- delete the viewgroup
	self.font = nil self.characterCodes = nil self.displayObjects = nil 					-- then nil all the references.
	self.viewGroup = nil 																	-- no reference to view group
	self.modifier = nil 																	-- no reference to a modifier instance if there was one
	self.eventListeners = nil 																-- clear reference to list.
	self.animationSpeedScalar = nil self.fontSize = nil self.spacingAdjust = nil 			-- clear everything else out :)
	self.usageCount = nil self.length = nil self.xScale = nil self.yScale = nil 			-- it is done this way so we can nil out the object to check everything
	self.text = nil self.anchorX = nil self.anchorY = nil  									-- is cleared up - none of these are references.
	self.fontAnimated = nil self.createTime = nil self.isValid = nil self.direction = nil
	self.lineData = nil self.verticalSpacing = nil
end


--//	Set the text. It uses the current text as a basis for display objects for the font, reusing them when possible, then frees any that are left over
--//	If there isn't a character to reuse, it creates one.
--
--//	@text [string]			text string to set it to.
--//	@return [BitmapString]	allows chaining.

function BitmapString:setText(text) 														-- set the text, adjust display objects to suit, reusing where possible.
	if text == self.text then return self end 												-- if no changes, then return immediately.
	self.text = text 																		-- save the text

	self.oldData = self.lineData 															-- save the old line record.
	self.lineData = { { length = 0, pixelWidth = 0 }} 										-- create a line data record with one empty entry (e.g. the first line)
	local currentLine = 1 																	-- current line being read in.
	local stringPtr = 1 																	-- position in string.
	while stringPtr <= #text do 															-- work through every character.
		local code
		code,stringPtr = self:extractCharacter(text,stringPtr) 								-- get the next character

		-- TODO: Process extended characters.
		if code == 10 or code == 13 then  													-- is it 13 or 10 (\n, \r)
			if self.direction == 0 or self.direction == 180 then 							-- no multilines on vertical characters.
				currentLine = currentLine + 1 												-- next line.
				self.lineData[currentLine] =  { length = 0, pixelWidth = 0 }				-- create a blank next line
			end
		else 																				-- all other characters
			code = self.font:mapCharacterToFont(code) 										-- map to an available font character.
			local charRecord = { code = code }												-- save the character code
			charRecord.displayObject = self:_useOrCreateCharacterObject(code) 				-- create and store display objects
			charRecord.lineNumber = currentLine 											-- save the line number
			local currentRecord = self.lineData[currentLine] 								-- this is the record where it goes.
			currentRecord.length = currentRecord.length + 1 								-- increment the length of the current record
			currentRecord.pixelWidth = currentRecord.pixelWidth + 							-- keep track of the scale neutral pixel width
								self.font:getCharacterWidth(code,self.fontSize,1)
			currentRecord[currentRecord.length] = charRecord 								-- add to the list of characters we have for this line
		end
	end

	for line = 1,#self.oldData do 															-- remove any objects left in the stock.
		for cNum = 1,self.oldData[line].length do 
			local obj = self.oldData[line][cNum]
			if obj.displayObject ~= nil then  												-- if it hasn't been used up.
				obj.displayObject:removeSelf() 												-- remove it from everything.
				self.usageCount = self.usageCount - 1 										-- reduce the count, so it matches the number of live objects
			end
		end
	end
	self.oldData = nil 																		-- clear references to old objects.
	self:reformat() 																		-- reformat the string.
	if self.text == "" then 																-- if clearing, check everything is clear.
		assert(self.usageCount == 0,"usage count wrong, some objects have leaked")
	end
	return self 																			-- permit chaining.
end

--// %	This acquires a display object with the given character. It looks in the 'stock list' - the list of characters used before, if one is 
--//	found it recycles it. Otherwise it creates a new one.
--
--//	@characterCode [number] 	character code to be either recycled from stock, or created.
--//	@return [display Object]	Corona Display Object representing the character.

function BitmapString:_useOrCreateCharacterObject(characterCode)
	for l = 1,#self.oldData do 
		for i = 1,self.oldData[l].length do
			local obj = self.oldData[l][i]
			if obj.code == characterCode then 												-- found a matching one.
				local displayObject = obj.displayObject
		 		obj.code = -1 																-- set the character code to an illegal one, won't match again.
				obj.displayObject = nil 													-- clear the reference to the stock object
	 			return displayObject 														-- return the reused object.
	 		end
	 	end
	end
	self.usageCount = self.usageCount + 1 													-- create a new one, so bump the usage counter we check with.
	local newObject = self.font:getCharacter(characterCode) 								-- we need a new one.
	self.viewGroup:insert(newObject) 														-- put it in the view group
	return newObject
end

--//%	Extract a single unicode character from the string
--//	@string 	[string] 				string to extract character from
--//	@stringPtr 	[number]				position in string
--//	@return 	[number,number]			unicode value of character, position of next character in string

function BitmapString:extractCharacterUnicode(string,stringPtr)
	return string:sub(stringPtr,stringPtr):byte(1),stringPtr+1 								-- get the next character code
end

--//%	Extract a single UTF-8 character from the string
--//	@string 	[string] 				string to extract character from
--//	@stringPtr 	[number]				position in string
--//	@return 	[number,number]			unicode value of character, position of next character in string

function BitmapString:extractCharacterUTF8(string,stringPtr)
	local code = string:sub(stringPtr,stringPtr):byte(1) 									-- get first byte
	if code < 0x80 then return code,stringPtr+1 end 										-- 00-7F return that value
	assert(math.floor(code / 0x20) == 0x06,"UTF-8 more than 2 bytes not supported yet") 	-- only support 0000-07FF at present.
	local code2 = string:sub(stringPtr+1,stringPtr+1):byte(1) 								-- get the second byte.
	assert(math.floor(code2 / 0x40) == 0x02,"Malformed UTF-8 character")					-- has to be 10xx xxxx
	return (code % 0x20) * 0x40 + (code2 % 0x40),stringPtr+2
end

--		BitmapString:extractCharacter is set up to be the same as BitmapString:extractCharacterUnicode
--		which is the default, unicode decoding (as Lua has a standard 8 bit string construct)

BitmapString.extractCharacter = BitmapString.extractCharacterUnicode


--//	Add an event listener to the view. This is removed automatically on clear.
--//	@eventName 	[string]	name of event e.g. tap, touch
--//	@handler 	[table]		event listener

function BitmapString:addEventListener(eventName,handler)
	assert(self.eventListeners[eventName] == nil,"Object has two "..eventName.." handlers attached.")
	self.eventListeners[eventName] = handler 												-- save the listener
	self.viewGroup:addEventListener(eventName,handler)										-- add the listener to the object
end

--//	Remove an event listener.
--//	@eventName 	[string] 	name of event e.g. tap

function BitmapString:removeEventListener(eventName)
	assert(self.eventListeners[eventName] ~= nil,"Listener not added for "..eventName)		-- check it was added.
	self.viewGroup:removeEventListener(eventName,self.eventListeners[eventName])			-- remove the listener
	self.eventListeners[eventName] = nil 													-- null it out in the table
end

--//%	Marks the string as invalid and in need of repainting.
--//	Many functions call this if they change something that means the string needs repainting or rescaling.

function BitmapString:reformat() 															-- reposition the string on the screen.
	self.isValid = false
end

--//%	Reposition and Scale the whole string dependent on the settings - called when text is changed, scale changed etc. However, it is not called
--//	directly ; those changes mark the string display as invalid and they are checked by the font manager - that way we don't repaint with every
--//	change. It starts by putting it at 0,0 but then moves it to fit the anchor and position settings.
--//	We cannot use the ViewGroups version because the effects - scaling and so on - would move it about. The view group positioning is based
--// 	on unmodified characters - otherwise anchoring would not work.

function BitmapString:repositionAndScale()
	self.isValid = true 																	-- it will be valid at this point.
	self.minx,self.miny,self.maxx,self.maxy = 0,0,0,0 										-- initialise the tracked drawing rectangle
	local fullWidth = 0 																	-- get the longest horizontal width
	for i = 1,#self.lineData do 
		fullWidth = math.max(fullWidth,self.lineData[i].pixelWidth * self.xScale)
	end
	for i = 1,#self.lineData do  															-- work through each line
		local centre = (fullWidth - self.lineData[i].pixelWidth*self.xScale)/2 				-- how much to centre it
		if self.direction == 180 then centre = -centre end 									-- handle centreing when rendering text backwards
		self:paintandFormatLine(self.lineData[i], 											-- character data
								centre, 													-- centre it by allowing space.
								(i - 1) * self.verticalSpacing * 							-- vertical positioning
											self.font:getCharacterHeight(32,self.fontSize,self.yScale),
								self.spacing,
								fullWidth)
	end
	self:postProcessAnchorFix()																-- adjust positioning for given anchor.
end

--//	Paint and format the given line.
--//	@lineData	[table]			table consisting of array of { code, displayObject } with a length property
--//	@nextX 		[number]		where we start drawing from x
--//	@nextY 		[number]		where we start drawing from y
--//	@spacing 	[number]		extra spacing to format the text correctly.
--//	@fullWidth 	[number]		full pixel width of string box

function BitmapString:paintandFormatLine(lineData,nextX,nextY,spacing,fullWidth)
	if lineData.length == 0 then return end 												-- if length is zero, we don't have to do anything.
	spacing = spacing or 0 																	-- spacing is zero if not provided
	local height = self.font:getCharacterHeight(32,self.fontSize,self.yScale) 				-- all characters are the same height, or in the same box.
	local elapsed = system.getTimer() - self.createTime 									-- elapsed time since creation.

	for i = 1,lineData.length do 																
		local width = self.font:getCharacterWidth(lineData[i].code,							-- calculate the width of the character.
																self.fontSize,self.xScale)
		if i == 1 then 																		-- initialise bounding box to first char first time.
			self.maxx = math.max(self.maxx,nextX+width)
			self.maxy = math.max(self.maxy,nextY+height)
		end 				

		local modifier = { xScale = 1, yScale = 1, xOffset = 0, yOffset = 0, rotation = 0 }	-- default modifier

		if self.modifier ~= nil then 														-- modifier provided
			local cPos = (nextX + width / 2 - fullWidth) / fullWidth * 100 					-- position across string box, percent (0 to 100)

			if self.fontAnimated then 														-- if animated then advance that position by time.
				cPos = math.round(cPos + elapsed / 100 * self.animationSpeedScalar) % 100 
			end

			local infoTable = { elapsed = elapsed, index = i, length = lineData.length } 	-- construct current information table

			if type(self.modifier) == "table" then 											-- if it is a table, e.g. a class, call its modify method
				self.modifier:modify(modifier,cPos,infoTable)
			else 																			-- otherwise, call it as a function.
				self.modifier(modifier,cPos,infoTable)
			end
			if math.abs(modifier.xScale) < 0.001 then modifier.xScale = 0.001 end 			-- very low value scaling does not work, zero causes an error
			if math.abs(modifier.yScale) < 0.001 then modifier.yScale = 0.001 end
		end

		self.font:moveScaleCharacter(lineData[i].displayObject, 							-- call moveScaleCharacter with modifier.
												 self.fontSize,
												 nextX,
												 nextY,
									 			 self.xScale,self.yScale,
									 			 modifier.xScale,modifier.yScale,
									 			 modifier.xOffset,modifier.yOffset,
									 			 modifier.rotation)
		if self.direction == 0 then 														-- advance to next position using character width, updating the bounding box
			nextX = nextX + width + (self.spacingAdjust+spacing) * math.abs(self.xScale) 			
			self.maxx = math.max(self.maxx,nextX)
		elseif self.direction == 180 then  													-- when going left, we need the width of the *next* character.
			if i < lineData.length then
				local pWidth = self.font:getCharacterWidth(lineData[i+1].code,self.fontSize,self.xScale)
				nextX = nextX - pWidth - (self.spacingAdjust+spacing) * math.abs(self.xScale) 	
				self.minx = math.min(self.minx,nextX)
			end
		elseif self.direction == 270 then  													-- up and down tend to be highly spaced, because the kerning stuff is not
			nextY = nextY + height + self.spacingAdjust * math.abs(self.xScale) 			-- designed for this. You can fix it with setSpacing()
			self.maxy = math.max(self.maxy,nextY)
		else
			self.miny = math.min(self.miny,nextY)
			nextY = nextY - height - self.spacingAdjust * math.abs(self.xScale) 			

		end
	end
end

--//	Fix up the positioning to allow for the drawing rectangle (pre-modifier) and the anchors.

function BitmapString:postProcessAnchorFix()
	local xOffset = -self.minx-(self.maxx-self.minx) * self.anchorX 						-- we want it to be centred around the anchor point, we cannot use anchorChildren
	local yOffset = -self.miny-(self.maxy-self.miny) * self.anchorY 						-- because of the animated modifications, so we calculate it

	for l = 1,#self.lineData do
		for i = 1,self.lineData[l].length do 												-- and move the objects appropriately.
			local obj = self.lineData[l][i].displayObject
			obj.x = obj.x + xOffset
			obj.y = obj.y + yOffset
		end
	end
end

--//	Return the view group if you want to animate it using transition.to
--//	@return [display Group]	the strings display group

function BitmapString:getView() return self.viewGroup end 								

--//	Check to see if the string is animated or not. (e.g. has animate() been called)
--//	@return [boolean] true if string is animated

function BitmapString:isAnimated() return self.fontAnimated end

--//%	Check to see if the string is 'invalid' e.g. its current position does not reflect what it should look like
--//	text changed, position changed, scaled etc.
--//	@return [boolean] true if string needs reorganising

function BitmapString:isInvalid() return not self.isValid end

--//	Turns animation on, with an optional speed scalar. This causes the 'cPos' in modifiers to change with time
--//	allowing the various animation effects
--//	@speedScalar [number]	Speed Scalar, defaults to 1. 3 is three times as fast.
--//	@return [BitmapString]	allows chaining.

function BitmapString:animate(speedScalar)
	self.fontAnimated = true 	 															-- enable animation
	self.animationSpeedScalar = speedScalar or 1 											-- set speed scalar
	return self
end

--//	Move the view group - i.e. the font
--//	@x 		[number]		Horizontal position
--//	@y 		[number]		Vertictal position
--//	@return [BitmapString]	allows chaining.

function BitmapString:moveTo(x,y)
	self.viewGroup.x,self.viewGroup.y = x,y 
	return self
end

--//	Change the font used, optionally change its size (there is another helper to just change the size). This involves freeing and reallocating
--//	the whole font objects - if you just want to change the base size, use that helper.
--//	@font [String/Reference]	Font to use to create string
--//	@fontSize [number]			Height of font in pixels, default is current size if ommitted.
--//	@return [BitmapString]	allows chaining.

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

--//	Set the anchor position - same as Corona except it is done with a method not by assigning member variables.
--//	@anchorX 	[number]			X anchor position 0->1
--//	@anchorY 	[number]			Y anchor position 0->1
--//	@return [BitmapString]	allows chaining.

function BitmapString:setAnchor(anchorX,anchorY)
	self.anchorX,self.anchorY = anchorX,anchorY
	self:reformat()
	return self
end

--//	Set the overall scale of the font (e.g. pre-modifier)
--//	@xScale 	[number]			Horizontal scaling of string
--//	@yScale 	[number]			Vertical scaling of string
--//	@return [BitmapString]	allows chaining.

function BitmapString:setScale(xScale,yScale)
	assert(xScale ~= 0 and yScale ~= 0,"Scales cannot be zero")
	self.xScale,self.yScale = xScale or 1,yScale or 1
	self:reformat()
	return self
end

--//	Set the direction - we only support 4 main compass points, and the font is always upright. 
--//	@direction [number] string direction (degrees) 0 (default), 90, 180 or 360.
--//	@return [BitmapString]	allows chaining.

function BitmapString:setDirection(direction)
	self.direction = ((direction or 0)+3600) % 360 											-- force into sensible range
	assert(self.direction/90 == math.floor(self.direction/90),"Only right angle directions allowed")
	self:reformat()
	return self
end

--//	Allows you to adjust the spacing between letters.
--//	@spacing [number]	Pixels to insert between letters (or remove, can be negative) - scaled by x Scaling.
--//	@return [BitmapString]	allows chaining.

function BitmapString:setSpacing(spacing)
	self.spacingAdjust = spacing or 0
	self:reformat()
	return self
end

--//	Allows you to adjust the spacing between letters vertically
--//	@spacing [number]	Pixels to insert between letters (or remove, can be negative) - scaled by y Scaling.
--//	@return [BitmapString]	allows chaining.

function BitmapString:setVerticalSpacing(spacing)
	self.verticalSpacing = spacing or 1
	self:reformat()
	return self
end

--//	Set the Font Size
--//	@size [number]	new font size (vertical pixel height), default is no change
--//	@return [BitmapString]	allows chaining.

function BitmapString:setFontSize(size)
	self.fontSize = size or self.fontSize
	self:reformat()
	return self
end

--//	Set the modifier (class, function or string) which shapes and optionally animates the string. For examples, see the main.lua file
--//	and the sample modifiers.
--//	@funcOrTable [String/Class/Function] a function, class or string defining how you want the bitmap font to be modified.
--//	@return [BitmapString]	allows chaining.

function BitmapString:setModifier(funcOrTable)
	if type(funcOrTable) == "string" then 													-- get it from the directory if is a string
		funcOrTable = FontManager:getModifier(funcOrTable)
	end
	self.modifier = funcOrTable
	self:reformat()
	return self
end

--- ************************************************************************************************************************************************************************
-- 									this is the actual implementation of the FontManager which is forward referenced.
--- ************************************************************************************************************************************************************************

--//	Constructor - note this is the prototype and the instance.

function FontManager:initialise()
	self.fontList = {} 																		-- maps font name (l/c) to bitmap object
	self.currentStrings = {} 																-- list of current strings (contains reference as key)
	self.eventListenerAttached = false 														-- enter Frame is not attached.
	self.animationsPerSecond = 15 															-- animation rate hertz
	self.nextAnimation = 0 																	-- time of next animation
	self.modifierDirectory = {} 															-- no known modifiers
end

--//	Set the string encoding used to convert strings to bitmap sequences
--//	@enc [string] 		encoding, either (currently) unicode (default), utf8 or utf-8
--//	@return [FontManager] chaining

function FontManager:setEncoding(enc)
	enc = (enc or "unicode"):lower()
	if enc == "unicode" then
		BitmapString.extractCharacter = BitmapString.extractCharacterUnicode
	elseif enc == "utf8" or enc == "utf-8" then 
		BitmapString.extractCharacter = BitmapString.extractCharacterUTF8
	else
		error("Unknown font encoding " .. enc)
	end
	return self
end

print(FontManager.setEncoding)

--//	Erase all text - clear screen effectively. All new text strings are registered with the font mananger.

function FontManager:clearText()
	for string,_ in pairs(self.currentStrings) do 											-- destroy all current strings.
		string:_destroy()
	end 
	self.currentStrings = {} 																-- clear the current strings list
	FontManager:_stopEnterFrame() 															-- turn the animation off.
end

--//	Set the animation rate - how many updates are a done a second. If this is > fps it will be fps.
--//	@frequency [number]		updates per second of the animation rate, defaults to 15 updates per second.

function FontManager:setAnimationRate(frequency) 											-- method to set the animations frequency.
	self.animationsPerSecond = frequency or 15
end


--//	Get font by name, creating it if required.
--//	@fontName [string]		Name of font to acquire
--//	@return [BitmapFont]	Font from cache,or loaded

function FontManager:getFont(fontName) 														-- load a new font.
	local keyName = fontName:lower() 														-- key used is lower case.
	if self.fontList[keyName] == nil then 													-- font not known ?
		self.fontList[keyName] = BitmapFont:new(fontName) 									-- instantiate one, using the uncapitalised name
	end
	return self.fontList[keyName] 															-- return a font instance.
end

--//%	Add a string (part of BitmapString constructor) so the FontManager knows about the bitmap strings - then it can update and animate them.
--//	@bitmapString [BitmapString]	Newly created bitmap string object which the manager kneeds to know about

function FontManager:addStringReference(bitmapString)
	assert(self.currentStrings[bitmapString] == nil,"String reference duplicate ?")
	self.currentStrings[bitmapString] = bitmapString 										-- remember the string we are adding.
	self:_startEnterFrame() 																-- we now need the enter frame tick.
end

--//%	Remove a string from that known from the list maintained by the font mananger.
--//	@bitmapString [BitmapString]	Newly created bitmap string object which the manager kneeds to know about

function FontManager:removeStringReference(bitmapString)
	assert(self.currentStrings[bitmapString] ~= nil,"String reference missing ???")
	self.currentStrings[bitmapString] = nil 												-- blank the reference.
end

--//%	Turn on the eventframe event.

function FontManager:_startEnterFrame() 													-- turn animation on.
	if not self.eventListenerAttached then
		Runtime:addEventListener( "enterFrame", self )
		self.eventListenerAttached = true
	end
end

--//%	Turn off the event frame event

function FontManager:_stopEnterFrame() 														-- turn animation off
	if self.eventListenerAttached then
		Runtime:removeEventListener("enterFrame",self)
		self.eventListenerAttached = false
	end
end

--//%	Handle the enter frame event. Repaints if either (i) it is invalid or (ii) it is animated.
--//	@e [Event Object]	Event data from Corona SDK

function FontManager:enterFrame(e)
	local currentTime = system.getTimer() 													-- elapsed time in milliseconds
	if currentTime > self.nextAnimation then 												-- time to animate - we animated at a fixed rate, irrespective of fps.
		self.nextAnimation = currentTime + 1000 / self.animationsPerSecond 					-- very approximate, not too worried about errors.
		for string,_ in pairs(self.currentStrings) do 										-- iterate through current strings.
			if string:isAnimated() or string:isInvalid() then 								-- if the string is animated or invalid, then reformat it.
				string:repositionAndScale() 												-- changes will pick up in the Modifier class/function.
			end
		end
	end
end

--//	Helper function which calculates curves according to the definition - basically can take a segment of a trigonometrical curve and apply it to 
--//	whatever you want, it can be repeated over a range, so you could say apply the sin curve from 0-180 5 times and get 5 'humps'
--
--//	@curveDefinition 	[Modifier Descriptor]	Table containing startAngle,endAngle,curveCount,formula
--//	@position 			[number]				Position in curve 0 to 100
--//	@return 			[number]				Value of curve (normally between 0 and 1)

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
	else error("Unknown formula "..formula) 												-- add extra formulae here
	end
	return result 																			-- this will be 0-1 (usually)
end

--//%	Register one of the standard modifiers
--//	@name [string]			Name of modifier (case irrelevant)
--//	@instance [Modifier]	Modifier instance

function FontManager:registerModifier(name,instance)
	name = name : lower()
	assert(self.modifierDirectory[name] == nil,"Duplicate modifier")
	self.modifierDirectory[name] = instance
end

--//	Access one of the standard modifiers
--//	@name [string] 			Name of modifier you want to access
--//	@return [Modifier]		Modifier that does what you want.

function FontManager:getModifier(name)
	name = name:lower() 																	-- case doesn't matter.
	assert(self.modifierDirectory[name] ~= nil,"Unknown modifier "..name)
	return self.modifierDirectory[name]			
end

FontManager:initialise() 																	-- initialise the font manager so it's a standalone object
FontManager.new = function() error("FontManager is a singleton instance") end 				-- and clear the new method so you can't instantitate a copy.

--- ************************************************************************************************************************************************************************
--
--//		Modifiers can be functions, classes or text references to system modifiers. The modifier takes five parameters <br><ul>
--//
--//			<li>modifier 		structure to modify - has xOffset, yOffset, xScale, yScale and rotation members (0,0,1,1,0) which it can
--// 								tweak. Called for each character of the string. You can see all of them in Wobble, or just rotation in Jagged.</li>
--//			<li>cPos 			the character position, from 0-100 - how far along the string this is. This does not correlate to string character
--// 								position, as this is changed to animate the display. </li>
--// 			<li>info 			table containing information for the modifier : elapsed - elapsed time in ms, index, position in this line, length
--//								length of this line.</li></ul>
--
--- ************************************************************************************************************************************************************************

local Modifier = Base:new() 																-- establish a base class. Probably isn't necessary :)

--//	Class which wobbles the characters randomly

local WobbleModifier = Modifier:new()					 									-- Wobble Modifier makes it,err.... wobble ?

--//	Constructor, sets the violence of the wobble.
--//	@violence [number]	degree of wobbliness, defaults to 1.

function WobbleModifier:initialise(violence) self.violence = violence or 1 end 

--// %	Make the font wobble by changing values just a little bit
--//	@modifier [Modifier Table]	Structure to modify to change effects
--//	@cPos [number]  Position in effect
--//	@info [table] Information about the character/string/line

function WobbleModifier:modify(modifier,cPos,info)
	modifier.xOffset = math.random(-self.violence,self.violence) 							-- adjust all these values by the random level of 'violence'
	modifier.yOffset = math.random(-self.violence,self.violence)
	modifier.xScale = math.random(-self.violence,self.violence) / 10 + 1
	modifier.yScale = math.random(-self.violence,self.violence) / 10 + 1
	modifier.rotation = math.random(-self.violence,self.violence) * 5
end

--//	Modifier which changes the vertical position on a curve

local SimpleCurveModifier = Modifier:new()													-- curvepos curves the text positionally vertically

--// 	Initialise the curve modifier
--//	@start [number] 	start angle of cuve
--//	@enda [number]		end angle of curve
--//	@scale [number]     degree to which it affects the bitmapstring
--//	@count [number]		number of segments to map onto the text

function SimpleCurveModifier:initialise(start,enda,scale,count)
	self.curveDesc = { startAngle = start or 0, endAngle = enda or 180, 					-- by default, sine curve from 0 - 180 degrees replicated once.
															curveCount = count or 1 }
	self.scale = scale or 1
end

--// %	Make the modifications needed to change the vertical position
--//	@modifier [Modifier Table]	Structure to modify to change effects
--//	@cPos [number]  Position in effect
--//	@info [table] Information about the character/string/line

function SimpleCurveModifier:modify(modifier,cPos,info)
	modifier.yOffset = FontManager:curve(self.curveDesc,cPos) * 50 * self.scale 			
end

--//	Extend simple Curve scale Modifier so it is inverted.

local SimpleInverseCurveModifier = SimpleCurveModifier:new()

--// %	Make the modifications needed to change the vertical position
--//	@modifier [Modifier Table]	Structure to modify to change effects
--//	@cPos [number]  Position in effect
--//	@info [table] Information about the character/string/line

function SimpleInverseCurveModifier:modify(modifier,cPos,info)
	modifier.yOffset = - FontManager:curve(self.curveDesc,cPos) * 50 * self.scale 			
end

--//	Modifier which changes the vertical scale on a curve

local SimpleCurveScaleModifier = SimpleCurveModifier:new()						 			-- curvepos scales the text vertically rather than the position.

--// %	Make the modifications needed to change the vertical scale
--//	@modifier [Modifier Table]	Structure to modify to change effects
--//	@cPos [number]  Position in effect
--//	@info [table] Information about the character/string/line

function SimpleCurveScaleModifier:modify(modifier,cPos,info)
	modifier.yScale = FontManager:curve(self.curveDesc,cPos)*self.scale+1 					-- so we just override the bit that applies it.
end

--//	Scale but shaped the other way.

local SimpleInverseCurveScaleModifier = SimpleCurveScaleModifier:new()

--// %	Make the modifications needed to change the vertical scale
--//	@modifier [Modifier Table]	Structure to modify to change effects
--//	@cPos [number]  Position in effect
--//	@info [table] Information about the character/string/line

function SimpleInverseCurveScaleModifier:modify(modifier,cPos,info)
	modifier.yScale = 1 - FontManager:curve(self.curveDesc,cPos)*self.scale*2/3				-- so we just override the bit that applies it.
end

--// 	Modifier which turns alternate characters 15 degrees in different directions

local JaggedModifier = Modifier:new()														-- jagged alternates left and right rotation.

--// %	Make the modifications needed to look jagged
--//	@modifier [Modifier Table]	Structure to modify to change effects
--//	@cPos [number]  Position in effect
--//	@info [table] Information about the character/string/line

function JaggedModifier:modify(modifier,cPos,info)
	modifier.rotation = ((info.index % 2 * 2) - 1) * 15 									-- generates -15 and +15 rotation alternately on index.
end

--//	Modifier which zooms characters from 0->1 but the base positions don't change.

local ZoomOutModifier = Modifier:new() 														-- Zoom out from nothing to standard

--//	Initialise the zoom
--//	@zoomTime [number] how long the zoom takes, defaults to three seconds.
																							-- this scales letters back spaced - if you want a classic zoom
function ZoomOutModifier:initialise(zoomTime)												-- use transition.to to scale it :)
	self.zoomTime = zoomTime or 3000 				
end

--// %	Make the modifications to cause the zoom
--//	@modifier [Modifier Table]	Structure to modify to change effects
--//	@cPos [number]  Position in effect
--//	@info [table] Information about the character/string/line

function ZoomOutModifier:modify(modifier,cPos,info)
	local scale = math.min(1,info.elapsed / self.zoomTime)
	modifier.xScale,modifier.yScale = scale,scale
end

--//	Modifier which zooms characters from 1->0 but the base positions don't change.

local ZoomInModifier = ZoomOutModifier:new() 												-- Zoom in, as zoom out but the other way round

--// %	Make the modifications to cause the zoom.
--//	@modifier [Modifier Table]	Structure to modify to change effects
--//	@cPos [number]  Position in effect
--//	@info [table] Information about the character/string/line

function ZoomInModifier:modify(modifier,cPos,info)
	local scale = math.min(1,info.elapsed / self.zoomTime)
	modifier.xScale,modifier.yScale = 1-scale,1-scale
end

FontManager:registerModifier("wobble",WobbleModifier:new())									-- tell the system about them.
FontManager:registerModifier("curve",SimpleCurveModifier:new())
FontManager:registerModifier("icurve",SimpleInverseCurveModifier:new())
FontManager:registerModifier("scale",SimpleCurveScaleModifier:new())
FontManager:registerModifier("iscale",SimpleInverseCurveScaleModifier:new())
FontManager:registerModifier("jagged",JaggedModifier:new())
FontManager:registerModifier("zoomout",ZoomOutModifier:new())
FontManager:registerModifier("zoomin",ZoomInModifier:new())

local Modifiers = { WobbleModifier = WobbleModifier,										-- create table so we can provide the Modifiers.
					SimpleCurveModifier = SimpleCurveModifier,
					SimpleInverseCurveModifier = SimpleCurveModifier,
					SimpleCurveScaleModifier = SimpleCurveScaleModifier,
					SimpleInverseCurveScaleModifier = SimpleInverseCurveScaleModifier,
					JaggedModifier = JaggedModifier,
					ZoomOutModifier = ZoomOutModifier,
					ZoomInModifier = ZoomInModifier }

--- ************************************************************************************************************************************************************************
--
--		This adds a display.newBitmapText method which is fairly close to that provided by Corona for newText, as close as I can get. It is not multi-line so it does
--		not support width and height. Parent view may not be a great idea because of the animation of the font manager, but might work. 
--		
--		However this still uses BitmapString methods, so you cannot assign to x,y,anchorX,anchorY,xScale,yScale etc. At present anyway.
--
--- ************************************************************************************************************************************************************************

function display.newBitmapText(...)
	local options = arg 																		-- equivalent to 'options' in documentation
	if #arg > 1 then 																			-- legacy syntax [parentgroup],text,x,y,font,fontSize if more than one argument
		local paramOffset = 1 																	-- where to start getting parameters from
		options = {} 																			-- create an equivalent 'options'
		if type(arg[1]) == "table" then 														-- argument 1 is table, this must be a parentGroup
			options.parent = arg[1] 															-- insert it as parent option.
			paramOffset = 2 																	-- and start from argument 2.
		end
		assert(#arg == paramOffset+4,															-- check parameter count is correct
						"Parameters to display.newBitmapText([parentGroup,],text,x,y,font,fontsize)")
		options.text = arg[paramOffset] 														-- copy parameters into table.
		options.x = arg[paramOffset+1]
		options.y = arg[paramOffset+2]
		options.font = arg[paramOffset+3]
		options.fontSize = arg[paramOffset+4]
	end
	assert(options.text ~= nil,"newBitmapText:bad 'text' parameter")							-- some simple validation.
	assert(options.font ~= nil and type(options.font) == "string","newBitmapText:bad 'font' parameter")
	assert(options.fontSize ~= nil and type(options.fontSize) == "number","newBitmapText:bad 'fontSize' parameter")
	if options.width ~= nil or options.height ~= nil then print("newBitmapText does not support multiline text") end

	local bitmapString = display.hiddenBitmapStringPrototype:new(options.font,options.fontSize)	-- create a bitmap string object
	bitmapString:setText(options.text) 															-- set the text
	if options.x ~= nil then bitmapString:moveTo(options.x,options.y or 0) end 					-- if a position is provided, move it there.
	if options.parent ~= nil then options.parent:insert(bitmapString:getView()) end 			-- insert into parent, probably not a great idea :)
	return bitmapString
end

display.hiddenBitmapStringPrototype = BitmapString 												-- we make sure the display knows about the class it needs

return { BitmapString = BitmapString, FontManager = FontManager, Modifiers = Modifiers } 		-- hand it back to the caller so it can use it.

-- printing font backwards bug
-- word tracking (adapt pulse)
-- line tracking (adapt pulse)
-- tinting (?)
