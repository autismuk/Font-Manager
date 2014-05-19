--- ************************************************************************************************************************************************************************
---
---				Name : 		fontmananger.lua
---				Purpose :	Manage and Animate strings of bitmap fonts.
---				Created:	30 April 2014 (Reengineered 19th May 2014)
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

-- Standard OOP (with Constructor parameters added.)
_G.Base =  _G.Base or { new = function(s,...) local o = { } setmetatable(o,s) s.__index = s o:initialise(...) return o end, initialise = function() end }


--- ************************************************************************************************************************************************************************
--// 	This class encapsulates a bitmap font, producing characters 'on demand'. Has a factory method for producing character images from that font (using imageSheets)
--//	and sprites. Note that the loadFont() methods and the createImage() methods are closely coupled together if you subclass this for fonts from different 
--//	sources.
--- ************************************************************************************************************************************************************************

local BitmapFont = Base:new()

BitmapFont.fontDirectory = "fonts" 															-- where font files are, fnt and png.

--//	The Bitmap Font constructor. This reads in the font data 
--//	@fontName [string] name of font (case is sensitive, so I advise use of lower case only)

function BitmapFont:initialise(fontName)
	self.fontName = fontName 																-- save font name.
	self.characterData = self:loadFont(fontName)											-- load the font (maps character unicode number to font data)
	self.fontHeight = self:calculateFontHeight() 											-- calculate the font height from the character data.
end

--		Character data structure is as follows.
--			width 					width in pixels of whole character (we do not kern)
--			height 					height in pixels, (excluding yOffset)
--			xOffset 				horizontal offset
--			yOffset 				vertical offset
--			(these not used outside the BitmapFont class even though they may actually be available !)
-- 			spriteID 				internal sprite number (when using display.imageSheet)
--			frame 					{ x,y, width, height } options entry (when using data sheet)

--//%	Load the font from the .fnt definition - the stub is provided (e.g. 'fred' loads fonts/fred.fnt). Parses the .fnt file to get the character
--//	information, and the image file name.
--//	@return [CharacterData] 	Entry for character data.

function BitmapFont:loadFont(fontName)
	local fontFile = BitmapFont.fontDirectory .. "/" .. fontName .. ".fnt" 					-- this is the directory the font is in.
	local source = io.lines(system.pathForFile(fontFile,system.ResourceDirectory)) 			-- read the lines from this file.
	local options = { frames = {} }															-- this is going to be the options read in (see newImageSheet() function)
	local spriteCount = 1 																	-- next available 'frame'
	local imageFile = nil 																	-- this is the sprite image file which will be read in eventually.
	local charData = {} 																	-- character data structure for this font.

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
			charInfo.height = optionsEntry.height 											-- copy the height to the outer structure.
			assert(charData[charID] == nil,"Duplicate character code, contact author")
			charData[charID*1] = charInfo 													-- store the full font information in the characterData table.
			spriteCount = spriteCount + 1 													-- bump the number of sprites
		end
	end
	assert(imageFile ~= nil,"No image file in fnt file, contact the author")				-- didn't find a 'page' entry i.e. no file name
	self.imageSheet = graphics.newImageSheet(imageFile,options) 							-- load in the image sheet
	assert(self.imageSheet ~= nil,"Image file " .. imageFile .. "failed to load for fnt file ".. fontFile)	
	return charData
end

--//%	calculates the font height of the loaded bitmap
--//	@return [number] the actual font height.

function BitmapFont:calculateFontHeight()
	local maxy,miny = -999,999 																-- start ranges from top and bottom
	for _,def in pairs(self.characterData) do 												-- work through the font characters
		miny = math.min(miny,def.yOffset) 													-- work out the uppermost position and the lowermost.
		maxy = math.max(maxy,def.yOffset + def.height)
	end
	return maxy - miny + 1																	-- calculate the overall height of the font.
end

--//%	Create a single individual character for use by other fonts.
--//	@unicodeCharacter [string/number]		Unicode character to create.
--//	@return [table] 						{ image = <display image>, charData = <char data entry>, fontHeight = <actual font height> }

function BitmapFont:createImage(unicodeCharacter)
	if type(unicodeCharacter) == "string" then 												-- if a string provided, convert to a Unicode character.
		unicodeCharacter = unicodeCharacter:byte(1)
	end
	if self.characterData[unicodeCharacter] == nil then unicodeCharacter = 63 end 			-- if we don't know, render it as a question mark.
	assert(self.characterData[unicodeCharacter] ~= nil,"Missing default character in font") -- check the character is actually present.
	local spriteNumber = self.characterData[unicodeCharacter].spriteID 						-- which sprite is it ?
	return {
		image = display.newImage(self.imageSheet,spriteNumber),								-- the display image
		charData = self.characterData[unicodeCharacter], 									-- the information
		fontHeight = self.fontHeight 														-- the main height of the font (for scaling)
	}
end

--- ************************************************************************************************************************************************************************
--//		This singleton class manages an internal list of bitmap fonts, which must implement the BitmapFont method createImage() but otherwise does not care.
--- ************************************************************************************************************************************************************************

local BitmapFontContainer = Base:new()

--//	Initialise the font container

function BitmapFontContainer:initialise()
	self.fontList = {} 																		-- map font name to Bitmap Font Instance.
end

--//	Get an instance of a font creating it if necessary
--//	@fontName [string] 		Font required. This *IS* case dependent because of Corona's casing requirements
--//	@return [BitmapFont]	Instance of bitmap font. Will cause assertion on errors (e.g. font physically not present)

function BitmapFontContainer:getFontInstance(fontName)
	assert(fontName ~= nil,"No font name provided")
	if self.fontList[fontName] == nil then 													-- create it if it doesn't exist already.
		self.fontList[fontName] = BitmapFont:new(fontName)
	end
	return self.fontList[fontName]
end

BitmapFontContainer:initialise() 															-- make it a singleton
BitmapFontContainer.new = nil 																-- very definitely :)


--- ************************************************************************************************************************************************************************
--//	This class represents a single bitmapped character. It can be positioned and have its height and tint set as if it were any other image. However, it can be
--//	post modified, changing the position, scale and rotation of the character (the latter at the individual level). It is not for external use, so it does not use
--//	the normal Corona SDK positioning methods for simplicity.
--- ************************************************************************************************************************************************************************

local BitmapCharacter = Base:new()

BitmapCharacter.isDebug = true 																-- when this is true the objects real rectangle is shown.
BitmapCharacter.instanceCount = 0 															-- tracks number of create/deleted instances of the character

--//%	The font and unicode character are set in the constructor. These are immutable for this object - if you want a different letter/font you need to create a new
--//	instance. We do not initially really care where it is, how big it is, or anything like that. 
--//	@fontName [string] 						name of font
--//	@unicodeCharacter [string/number]		character/character code to use.

function BitmapCharacter:initialise(fontName,unicodeCharacter)
	local info = BitmapFontContainer:getFontInstance(fontName): 							-- access the font instance for this name and create the image.
														createImage(unicodeCharacter)
	BitmapCharacter.instanceCount = BitmapCharacter.instanceCount + 1 						-- bump the instance count.
	self.character = unicodeCharacter 														-- this is the character it is.
	self.image = info.image 																-- save the display object
	self.info = info.charData 																-- save the associated information. Note, we can only use width, height, xOffset, yOffset
	self.basePhysicalHeight = info.fontHeight 												-- save the physical height of the bitmap.
	self.actualHeight = info.fontHeight 													-- initially same size as the physical height.
	self.image.anchorX, self.image.anchorY = 0.5,0.5 										-- anchor at the middle of the display image.
	if self.isDebug then 																	-- if you want it, create the debug rectangle.
		self.debuggingRectangle = display.newRect(0,0,1,1)									-- moving it will update its location correctly.
		self.debuggingRectangle:setStrokeColor(0,0.4,0) 									-- make it green, one width and transparent
		self.debuggingRectangle.strokeWidth = 1
		self.debuggingRectangle:setFillColor( 0,0,0,0 )
		self.debuggingRectangle.anchorX,self.debuggingRectangle.anchorY = 0,0 				-- anchor at top left, position it with the bounding box.
	end
	self.xDefault,self.yDefault = 0,0 														-- the origin position
	self:moveTo(160,240) 																	-- move it somewhere, initially, it will be moved whatever.
end

--//%	Cleans up the current bitmap character, returns everything to nil for gc, frees all images.

function BitmapCharacter:destroy() 
	if self.image ~= nil then 
		self.image:removeSelf() self.image = nil self.info = nil self.boundingBox = nil 	-- clean up by hand, to make sure :)
		self.xDefault = nil self.yDefault = nil self.actualHeight = nil self.basePhysicalHeight = nil
		self.character = nil
		if self.debuggingRectangle ~= nil then  											-- remove debugging rectangle if exists.
			self.debuggingRectangle:removeSelf()
			self.debuggingRectangle = nil
		end
	end
	BitmapCharacter.instanceCount = BitmapCharacter.instanceCount - 1 						-- decrement the instance count.
	for k,v in pairs(self) do print("(BitmapCharacter)",k,v) end
end


--//%	Move the bitmap character's location, update the bounding rectangle. The coordinates are the top left, even though the actual anchor position
--//	used is not.
--//	@x 		[number]		x coordinate (optional)
--//	@y 		[number]		y coordinate (optional)
--//	@newHeight [number]		New font height (optional)

function BitmapCharacter:moveTo(x,y,newHeight)
	x = x or self.xDefault y = y or self.yDefault											-- handle default positions.
	self.xDefault,self.yDefault = x,y 														-- update the internal stored positions for defaults.
	newHeight = newHeight or self.actualHeight 												-- the height you want it to be.
	self.actualHeight = newHeight  															-- update that.
	local scale = newHeight / self.basePhysicalHeight 										-- the new scale required.
	self.image.xScale,self.image.yScale = scale,scale 										-- scale the characters up.
	local width = self.info.width * scale 													-- how wide the characters box is.
	y = y + self.info.yOffset/2 * self.actualHeight / self.basePhysicalHeight * scale		-- adjust half the y offset (from the middle) and adjust for the font size.
	x = x + width / 2 y = y + newHeight / 2	
	self.image.x,self.image.y = x,y  														-- physically move the image.
	self.boundingBox = { x1 = self.xDefault, x2 = self.xDefault + width, y1 = self.yDefault, y2 = self.yDefault + newHeight }
	self.boundingBox.width = self.boundingBox.x2 - self.boundingBox.x1 						-- it is done this way so they cannot get out of sync 
	self.boundingBox.height = self.boundingBox.y2 - self.boundingBox.y1
	if self.isDebug then 																	-- move the debugging box, if provided.
		local b = self.boundingBox
		self.debuggingRectangle.x,self.debuggingRectangle.y = b.x1,b.y1
		self.debuggingRectangle.width,self.debuggingRectangle.height = b.width,b.height
	end
end

--//%	Set the tint of the bitmap character, no parameter clears it.
--//	@tint [table] 		tint with red,green,blue components.

function BitmapCharacter:setTint(tint)
	if tint == nil then 
		self.image:setFillColor( 1,1,1 )
	else
		self.image:setFillColor( tint.red,tint.green,tint.blue )
	end
end

--- ************************************************************************************************************************************************************************
--//	This is a collection of Bitmap Characters that may be available for re-use, when changing the text on a Bitmap String. For some reason I called it a Bucket class
--- ************************************************************************************************************************************************************************

local BitmapCharacterBucket = Base:new() 

--//%	Create a bucket using the bitmap table. Once this has been copied, the original references should be released.
--//	@bitmapCharacterTable 	[table]			table of bitmap characters

function BitmapCharacterBucket:initialise(bitmapCharacterTable)
	self.collection = {}
	for _,chars in pairs(bitmapCharacterTable) do 											-- go through all the bitmaps in the table
		self.collection[#self.collection+1] = chars.bitmapChar 								-- copy their references into the collection
	end
end

--//%	Get an instance of a unicode character from the bucket, and remove it from the bucket.
--//	@unicodeCharacter [number] 				character code wanted from the bucket.
--//	@return 		  [BitmapCharacter]		useable bitmap character from bucket or nil if not found.

function BitmapCharacterBucket:getInstance(unicodeCharacter)
	for index,bucketItem in pairs(self.collection) do 										-- work through the bucket
		if bucketItem.character == unicodeCharacter then  									-- found a match ?
			local instance = bucketItem 													-- save the instance.
			self.collection[index] = nil 													-- remove it from the list
			return instance 																-- return the instance
		end
	end
	return nil  																			-- not found.
end

--//%	Empty the bucket and remove all the bitmap character objects

function BitmapCharacterBucket:destroy() 		
	for _,bucketItem in pairs(self.collection) do 											-- work through them all
		bucketItem:destroy() 																-- remove them all
	end
	self.collection = nil 																	-- remove references and the collection table.
end

--- ************************************************************************************************************************************************************************
--														This extracts characters, one at a time, from a string
--- ************************************************************************************************************************************************************************

local CharacterSource = Base:new()

--//%	Initialise a character source
--//	@str 	[string] 				string to use.

function CharacterSource:initialise(str)
	self.source = str 																		-- save the source.
	self.index = 1 																			-- next character from here.
end

--//% 	Get the next character from the source
--//	@return 	[number] 			unicode of character, returns 13 for both CR and LF, nil if there is nothing left.

function CharacterSource:get() 																
	local unicode = self:getRaw() 															-- get the Unicode character, unprocessed.
	if unicode == 10 then unicode = 13 end 													-- convert return to newline so 0x0D and 0x0A are synonymous.
	return unicode 
end

function CharacterSource:isMore() 
	return self.index <= #self.source
end

--//% 	Allows us to read a single character, if available. Can be overridden for UTF-8 support.
--//	@return 	[number]			unicode of next character or nil.

function CharacterSource:getRaw()
	if not self:isMore() then return nil end 												-- nothing left.
	local unicode = self.source:sub(self.index,self.index):byte(1) 							-- get character, make into a number
	self.index = self.index + 1 															-- advance to next.
	return unicode 
end 

--- ************************************************************************************************************************************************************************
--		Bitmap String class.
--
--- ************************************************************************************************************************************************************************

local BitmapString = Base:new() 															-- exists purely for the documentation.

BitmapString.isDebug = true 																-- provides visual debug support for the string.

--//% We have a replacement constructor, which decorates a Corona Group with the BitmapString's methods.

function BitmapString:new(...)
	local newObject = display.newGroup() 													-- create new group
	for name,object in pairs(BitmapString) do  												-- go through bitmap string looking for methods etc.
		if type(object) == "function" and name ~= "new" then 								-- if it's a function, other than new.
			newObject[name] = object  														-- decorate the new Object
		end
	end
	newObject:initialise(...) 																-- now call the constructor.
	return newObject
end

function BitmapString:initialise(fontName,fontSize) 
	self.fontName = fontName self.fontSize = fontSize or 64 								-- save the font name and the font size.
	assert(self.fontName ~= nil,"No default font name for Bitmap String")					-- check a font was provided.
	self.characterList = {} 																-- list of characters.
	self.text = "" 																			-- text string is currently empty
	self.isHorizontal = true																-- is horizontal text.
	self.justification = "C"																-- and multi-line is centred.
	self.verticalSpacingScalar = 1 															-- vertical spacing scalar
	self.horizontalSpacingPixels = 0 														-- horizontal gap extra.
	if BitmapString.isDebug then 
		self.debuggingRectangle = display.newRect(0,0,1,1)									-- moving it will update its location correctly.
		self.debuggingRectangle:setStrokeColor(0.4,0.4,0) 									-- make it green, one width and transparent
		self.debuggingRectangle.strokeWidth = 1
		self.debuggingRectangle:setFillColor( 0,0,0,0 )
		self.debuggingRectangle.anchorX,self.debuggingRectangle.anchorY = 0,0 				-- anchor at top left, position it with the bounding box.
		self:insert(self.debuggingRectangle)
	end
end 

--//	Destructor.

function BitmapString:destroy()
	self:setText("") 																		-- removes the bitmaps and tidies up.
	if BitmapString.isDebug then self.debuggingRectangle:removeSelf() end 					-- remove the debugging rectangle if it is in use.
	assert(self.numChildren == 0,"View group not cleaned up correctly")
	self.boundingBox = nil self.justification = nil self.characterList = nil 				-- clean up
	self.debuggingRectangle = nil self.text = nil self.fontName = nil
	self.lineCount = nil self.wordCount = nil self.fontSize = nil self.isHorizontal = nil
	self.lineLength = nil self.horizontalSpacingPixels = nil self.verticalSpacingScalar = nil
	for k,v in pairs(self) do if type(v) ~= "function" then print("(BitmapCharacter)",k,v) end end
end


--//	Set the text of the string to the new text. If it changes, it recreates the entire string,using the previous text items where possible.
--//	lines, words, characters are counted, then it is formatted around (0,0) and multi line text is justified.
--//	@newText [string]		Replacement text
--//	@return  [BitmapString]	Chain

function BitmapString:setText(newText)
	if newText == self.text then return self end 											-- if unchanged, do absolutely nothing.
	local bucket = BitmapCharacterBucket:new(self.characterList) 							-- create a bucket out of the old character list.
	self.characterList = {} 																-- clear the character list.
	self.text = newText 																	-- update the text saved.
	local source = CharacterSource:new(newText) 											-- create a character source for it.
	local xCharacter = 1 local yCharacter = 1 												-- these are the indexes of the character.
	self.wordCount = 1 																		-- number of words
	self.lineCount = 1 																		-- number of lines.
	local wordNumber = 0 																	-- current word number
	local inWord = false 																	-- word tracking state.

	while source:isMore() do 																-- is there more to get ?
		local unicode = source:get() 														-- yes, get the next character.
		if not self.isHorizontal and unicode == 13 then unicode = 32 end 					-- if vertical, then use space rather than CR.

		local isWord = unicode > 32 														-- check for word split, e.g. not space.
		if isWord ~= inWord then 															-- moved in or out of word
			inWord = isWord 																-- update state
			if inWord then wordNumber = wordNumber + 1 end 									-- moved into word, bump the word number
		end

		if unicode ~= 13 then 	
			local newRect = { charNumber = xCharacter, lineNumber = yCharacter }			-- start with the character number.
			newRect.wordNumber = wordNumber 												-- save the word number
			newRect.bitmapChar = bucket:getInstance(unicode) 								-- is there one in the bucket we can use.
			if newRect.bitmapChar == nil then 												-- no so create a new one
				newRect.bitmapChar = BitmapCharacter:new(self.fontName,unicode) 			-- of the correct font and character.
				self:insert(newRect.bitmapChar.image) 										-- insert the bitmap image into the view group.
				if BitmapCharacter.isDebug then 											-- if debugging the bitmap character
					self:insert(newRect.bitmapChar.debuggingRectangle) 						-- insert that as well.
				end
			end
			if self.isHorizontal then 														-- Horizontal or vertical text
				xCharacter = xCharacter + 1 												-- one character to the left
			else 
				yCharacter = yCharacter + 1 												-- one character down.
			end
			self.characterList[#self.characterList+1] = newRect 							-- store it in the character lists
			self.lineCount = math.max(self.lineCount,yCharacter) 							-- update number of lines.
		else 	
			xCharacter = 1 																	-- carriage return.
			yCharacter = yCharacter + 1
		end
	end

	for i = 1,#self.characterList do 														-- tell everyone the word count and line count
		self.characterList[i].wordCount = wordCount
		self.characterList[i].lineCount = lineCount 
	end
	bucket:destroy() 																		-- empty what is left in the bucket
	self:reformatText() 																	-- reformat the text left justified and recalculate the bounding box.
	return self
end

--//%	Reformat and rejustify the text, calculate the non-modified bounding box.

function BitmapString:reformatText() 
	self.boundingBox = { x1 = 0,x2 = 0,y1 = 0, y2 = 0 }										-- initial bounding box.
	self.lineLength = {} 																	-- line lengths table.
	for line = 1,self.lineCount do  														-- format each line in turn
		self.lineLength[line] = self:reformatLine(line,0) 									-- reformat each line, and get its length
	end
	self.boundingBox.width = self.boundingBox.x2 - self.boundingBox.x1 						-- set width and height.
	self.boundingBox.height = self.boundingBox.y2 - self.boundingBox.y1
	if BitmapString.isDebug then 															-- if debugging, update the debugging rectangle.
		local r = self.debuggingRectangle
		r.x,r.y = self.boundingBox.x1,self.boundingBox.y1
		r.width,r.height = self.boundingBox.width,self.boundingBox.height
		r:toFront()
	end
	if self.justification ~= "L" then 														-- if not left justified
		self:justifyText(self.justification == "R")											-- right or centre justify it
	end
end

--//%	Justify the text 
--//%	@isRightJustify [boolean]	true if to be right justified rather than centred (default if not called is left)

function BitmapString:justifyText(isRightJustify)
	for line = 1,self.lineCount do  														-- work through each line
		local offset = (self.boundingBox.width-self.lineLength[line]) 						-- calculate the difference between this line and the longest one.
		if not isRightJustify then offset = offset / 2 end 									-- if centre, halve it.
		self:reformatLine(line,offset) 														-- and reformat it.
	end
end

--//%	Reformat a single line, update the bounding box, return the right most display pixel used
--// 	@lineNumber	[number]	line to reformat
--// 	@xPos 		[number] 	indent from left to reformat with
--//	@return 	[number]	rightmost pixel used.

function BitmapString:reformatLine(lineNumber,xPos)
	local index = 1 																		-- index in character list.
	while index <= #self.characterList do 													-- work through all the characters.
		local charItem = self.characterList[index] 											-- short cut to the item
		if charItem.lineNumber == lineNumber then 											-- is it in the line we are rendering.
			charItem.bitmapChar:moveTo(xPos,												-- move and size correctly.
										(lineNumber - 1) * self.fontSize * self.verticalSpacingScalar,self.fontSize) 
			xPos = charItem.bitmapChar.boundingBox.x2 										-- get the next position to the right.
			self.boundingBox.x2 = math.max(self.boundingBox.x2,xPos) 						-- update the bounding box.
			self.boundingBox.y2 = math.max(self.boundingBox.y2,charItem.bitmapChar.boundingBox.y2)
			xPos = xPos + self.horizontalSpacingPixels 										-- spacing goes after bounding box.
		end
		index = index + 1 																	-- go to next entry
	end
	return xPos
end

--//	Return the view group if you want to animate it using transition.to. The object now is the view group
--//	but this is left in for consistency
--//	@return [self]

function BitmapString:getView() return self end 								


--//	Turns animation on, with an optional speed scalar. This causes the 'cPos' in modifiers to change with time
--//	allowing the various animation effects
--//	@speedScalar [number]	Speed Scalar, defaults to 1. 3 is three times as fast.
--//	@return [BitmapString]	allows chaining.

function BitmapString:animate(speedScalar)
	-- TODO
	return self
end

--//	Move the view group - i.e. the font
--//	@x 		[number]		Horizontal position
--//	@y 		[number]		Vertictal position
--//	@return [BitmapString]	allows chaining.

function BitmapString:moveTo(x,y)
	self.x,self.y = x,y
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
	self.fontName = font or self.fontName													-- update font and font size
	self.fontSize = fontSize or self.fontSize
	self:setText(originalText) 																-- and put the text back.
	return self
end

--//	Set the anchor position - same as Corona except it is done with a method not by assigning member variables.
--//	@anchorX 	[number]			X anchor position 0->1
--//	@anchorY 	[number]			Y anchor position 0->1
--//	@return [BitmapString]	allows chaining.

function BitmapString:setAnchor(anchorX,anchorY)
	-- TODO
	return self
end

--//	Set the direction - we only support 4 main compass points, and the font is always upright. 
--//	@direction [number] string direction (degrees) 0 (default), 90
--//	@return [BitmapString]	allows chaining.

function BitmapString:setDirection(direction)
	assert(direction == 0 or direction == 90,"Direction not supported")						-- now we only support, at present 0 and 90
	self.isHorizontal = (direction == 0) 													-- set the horizontal flag
	self:setFont() 																			-- recreate the font to update the alignment.
	return self
end

--//	Allows you to adjust the spacing between letters.
--//	@spacing [number]	Pixels to insert between letters (or remove, can be negative) 
--//	@return [BitmapString]	allows chaining.

function BitmapString:setSpacing(spacing)
	self.horizontalSpacingPixels = spacing or 0 											-- update the distance
	self:reformatText() 																	-- reformat the text
	return self
end

--//	Allows you to adjust the spacing between letters vertically
--//	@spacing [number]	Pixels to insert between letters (or remove, can be negative)
--//	@return [BitmapString]	allows chaining.

function BitmapString:setVerticalSpacing(spacing)
	self.verticalSpacingScalar = spacing or 1 												-- update the spacing
	self:reformatText() 																	-- reformat the text
	return self
end

--//	Set the Font Size
--//	@size [number]	new font size (vertical pixel height), default is no change
--//	@return [BitmapString]	allows chaining.

function BitmapString:setFontSize(size)
	return self:setFont(self.fontName,size) 												-- recreate with a different font size.
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

--//	Apply an overall tint to the string. This can be overridden or modified using the tint table of the modifier
--//	which itself has three fields - red, green and blue
--//	@r 	[number] 		Red component 0-1
--//	@g 	[number] 		Green component 0-1
--//	@b 	[number] 		Blue component 0-1
--//	@return [BitmapString] self
function BitmapString:setTintColor(r,g,b)
	self.tinting = { red = r or 1 , green = g or 1, blue = b or 1 }
	return self
end

return { BitmapString = BitmapString }

-- setModifier / re-render
-- animation code.
-- auto remove?

-- UTF-8 implementation
-- setting text justification, use constants.
-- anchors, positioning, text setting via members.
-- tinting - overall, coded, modifiers.