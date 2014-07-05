--- ************************************************************************************************************************************************************************
---
---				Name : 		fontmanager.lua
---				Purpose :	Manage and Animate strings of bitmap fonts.
---				Created:	30 April 2014 (Reengineered 19th May 2014)
---				Authors:	Paul Robson (paul@robsons.org.uk)
---							Ingemar Bergmark.
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

-- Standard OOP (with Constructor parameters added.)
_G.Base =  _G.Base or { new = function(s,...) local o = { } setmetatable(o,s) s.__index = s o:initialise(...) return o end, initialise = function() end }

require("config")

--- ************************************************************************************************************************************************************************
--// 	This class encapsulates a bitmap font, producing characters 'on demand'. Has a factory method for producing character images from that font (using imageSheets)
--//	and sprites. Note that the loadFont() methods and the createImage() methods are closely coupled together if you subclass this for fonts from different 
--//	sources.
--- ************************************************************************************************************************************************************************

local BitmapFont = Base:new()

BitmapFont.fontDirectory = "fonts" 															-- where font files are, fnt and png.

--//	The Bitmap Font constructor. This reads in the font data from the .FNT file and calculates the font height.
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
	local options = { frames = {} }															-- this is going to be the options read in (see newImageSheet() function)
	local spriteCount = 1 																	-- next available 'frame'
	local imageFile = nil 																	-- this is the sprite image file which will be read in eventually.
	local charData = {} 																	-- character data structure for this font.
	local source = io.lines(self:getFontFile(fontName)) 									-- read the lines from this file.
	self.padding = { 0,0,0,0 } 																-- clear padding.

	for l in source do 
		local page = l:match('^%s*page%s*id%s*=%s*(%d+)%s*file%s*=%s*%"(.*)%"$') 		    -- get the page line
		local fileName = fontName .. ".png" 												-- no need to add suffix as Corona will figure it out

		if page ~= nil then 																-- check page.
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
		if l:match("padding") ~= nil then 
			self.padding[1],self.padding[2],self.padding[3],self.padding[4] = 				-- parse out padding information
				l:match("padding%s*%=%s*([%d+])%s*%,%s*([%d+])%s*%,%s*([%d+])%s*%,%s*([%d+])")
			assert(self.padding[4] ~= nil,"Bad padding parameter format") 					-- check the padding scanned okay.
			for i = 1,4 do self.padding[i] = self.padding[i] * 1 end 						-- convert to numbers
		end
	end

	assert(imageFile ~= nil,"No image file in fnt file, contact the author")				-- didn't find a 'page' entry i.e. no file name
	self.imageSheet = graphics.newImageSheet(imageFile,options) 							-- load in the image sheet
	assert(self.imageSheet ~= nil,"Image file " .. imageFile .. "failed to load for fnt file ".. fontName)	
	return charData
end

--//%	Get font file name, scaling for display size and checking for @nx files.
--//	@fontFile 	[string] 		Base name of font file. May use @4x tags to force high res font
--//	@return 	[string]		Path of font file.

function BitmapFont:getFontFile(fontFile)
	--// TODO: Explain in docs what it actually does.
	self.fontScalar = 1 / display.contentScaleX  											-- save the scale factor
	return self:getFileNameScalar(fontFile)													-- return the file.
end 

--//	Changes the directory where bitmap fonts are found.
--//	@newDir [string] name of font directory

function BitmapFont:setFontDirectory(newDir)
	BitmapFont.fontDirectory = newDir
end

--//%	Create a full file name for a font scaled by a particular amount (so 2 => @2x etc.)
--//	@fontFile 	[string] 		Base name of font file
--//	@return 	[string]		Path of font file.

function BitmapFont:getFileNameScalar(fontFile)
	local selectedSuffix = ""																-- default suffix
	local selectedScale = -1 																-- selected scale from config.lua (no guarantee that the
																							-- order in the table is ascending)
	
	for configSuffix, configScale in pairs(application.content.imageSuffix or {}) do 		-- traverse through config.lua's imageSuffix table	
		if (self.fontScalar >= configScale) and (configScale > selectedScale) then 			-- to get file suffix to use
			selectedScale = configScale
			selectedSuffix = configSuffix
		end
	end

	fontFile = fontFile .. selectedSuffix
	self.suffix = selectedSuffix 															-- save the selected suffix

	return system.pathForFile(BitmapFont.fontDirectory .. "/" .. 							-- create full file path
												fontFile .. ".fnt", system.ResourceDirectory)
end 

--//%	Calculates the font height of the loaded bitmap, which defines the base height of the font. This is used when scaling the bitmaps
--//	to specific font sizes.
--//	@return [number] the actual font height.

function BitmapFont:calculateFontHeight()
	local maxy,miny = -999,999 																-- start ranges from top and bottom
	for _,def in pairs(self.characterData) do 												-- work through the font characters
		miny = math.min(miny,def.yOffset) 													-- work out the uppermost position and the lowermost.
		maxy = math.max(maxy,def.yOffset + def.height)
	end
	self.minimumYOffset = miny 																-- save minimum y Offset.
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
		fontHeight = self.fontHeight, 														-- the main height of the font (for scaling)
		yOffsetMin = self.minimumYOffset, 													-- the smallest value of yOffset
		padding = self.padding																-- padding up/right/down/left
	}
end

--//%	Return the size of the scaled fault. So for normal this would be the font size, @2x would be half the font size, @4x a quarter of
--//	the font size and so on. This allows DEFAULT_SIZE to be consistent irrespective of which scale is being used.
--//	@return [number]	Size of font in 1x.

function BitmapFont:getScaledDefaultSize() 
	return self.fontHeight / self.fontScalar 
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

BitmapCharacter.isDebug = false 															-- when this is true the objects real rectangle is shown.
BitmapCharacter.instanceCount = 0 															-- tracks number of create/deleted instances of the character

--//%	The font and unicode character are set in the constructor. These are immutable for this object - if you want a different letter/font you need to create a new
--//	instance. We do not initially really care where it is, how big it is, or anything like that. 
--//	@fontName [string] 						name of font
--//	@character [string/number]				character/character code to use.

function BitmapCharacter:initialise(fontName,character)

	local info
	if (character.." "):match("^%$%w") == nil then 											-- if it is not a $<image> ?
		info = BitmapFontContainer:getFontInstance(fontName): 								-- access the font instance for this name and create the image.
														createImage(character)
	else  																					-- for a $image, create an info structure that has the same
		info = { charData = {} }  															-- data that a font character would have.	
		info.image = display.newImage(character:sub(2)) 									-- if this fails, Corona will print a message.
		if info.image == nil then  															-- failed, put a circle there so it's obvious.
			info.image = display.newCircle(0,0,10,10)
		end
		info.charData.width = info.image.width 
		info.charData.height = info.image.height 
		info.charData.xOffset,info.charData.yOffset = 0,0
		info.fontHeight = info.image.height
	end
	BitmapCharacter.instanceCount = BitmapCharacter.instanceCount + 1 						-- bump the instance count.
	self.character = character 																-- this is the character it is.
	self.image = info.image 																-- save the display object
	self.info = info.charData 																-- save the associated information. Note, we can only use width, height, xOffset, yOffset
	self.basePhysicalHeight = info.fontHeight 												-- save the physical height of the bitmap.
	self.actualHeight = info.fontHeight 													-- initially same size as the physical height.
	self.padding = info.padding or { 0,0,0,0 }												-- save padding
	self.image.anchorX, self.image.anchorY = 0.5,0.5 										-- anchor at the middle of the display image.
	self.tinting = nil 																		-- current default tinting.
	if self.isDebug then 																	-- if you want it, create the debug rectangle.
		self.debuggingRectangle = display.newRect(0,0,1,1)									-- moving it will update its location correctly.
		self.debuggingRectangle:setStrokeColor(1,0,0) 									    -- make it red, one width 
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
		self.character = nil self.tinting = nil self.padding = nil
		if self.debuggingRectangle ~= nil then  											-- remove debugging rectangle if exists.
			self.debuggingRectangle:removeSelf()
			self.debuggingRectangle = nil
		end
	end
	BitmapCharacter.instanceCount = BitmapCharacter.instanceCount - 1 						-- decrement the instance count.
	--for k,v in pairs(self) do print("(BitmapCh)",k,v) end 									-- check for leftovers.
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
	x = x + self.info.xOffset * scale /2
	y = y + self.info.yOffset * scale 														-- adjust half the y offset (from the middle) and adjust for the font size.
	x = x + width / 2 y = y + self.image.height / 2	* scale
	x = x + self.padding[4] * scale y = y + self.padding[1] * scale  						-- adjust for padding left and up

	self.image.x,self.image.y = x,y  														-- physically move the image.

	self.boundingBox = { x1 = self.xDefault,  												-- calculate bounding box, add padding space.
						 x2 = self.xDefault + width + (self.padding[2]+self.padding[4]) * scale,
						 y1 = self.yDefault, 
						 y2 = self.yDefault + newHeight + (self.padding[1]+self.padding[3]) * scale
	}
	self.boundingBox.width = self.boundingBox.x2 - self.boundingBox.x1 						-- it is done this way so they cannot get out of sync 
	self.boundingBox.height = self.boundingBox.y2 - self.boundingBox.y1
	if self.isDebug then 																	-- move the debugging box, if provided.
		local b = self.boundingBox
		self.debuggingRectangle.x,self.debuggingRectangle.y = b.x1,b.y1
		self.debuggingRectangle.width,self.debuggingRectangle.height = b.width,b.height
	end
end

--//%	Move the bitmap font by an offset
--//	@x  	[number]	x offset
--//	@y  	[number]	y offset

function BitmapCharacter:moveBy(x,y) 
	self:moveTo(self.xDefault + x,self.yDefault + y)
end

--//% 	Apply a modifier. This does not affect the bounding box, merely the visual appearance, and the target area for tap/touch events.
--//	@modifier [table] 		Modifier containing xScale, yScale, xOffset, yOffset,rotation,alpha options.

function BitmapCharacter:modify(modifier)
	self:moveTo(self.xDefault,self.yDefault) 												-- move to current position which is correct
	self.image.x = self.image.x + (modifier.xOffset or 0) * self.image.xScale				-- movement offset
	self.image.y = self.image.y + (modifier.yOffset or 0) * self.image.yScale 
	self.image.xScale = self.image.xScale * (modifier.xScale or 1) 							-- scale scalar
	self.image.yScale = self.image.yScale * (modifier.yScale or 1)
	self.image.rotation = modifier.rotation or 0 											-- set rotation.
	self.image.alpha = modifier.alpha or 1 													-- set alpha
end


--//%	Set the tint of the bitmap character, no parameter clears it.
--//	@tint [table] 		tint with red,green,blue components, nil clears the tint

function BitmapCharacter:setTintColor(tint)
	if tint == nil then  																	-- if nil, then reset it
		self.image:setFillColor( 1,1,1 )
	else 																					-- otherwise tint it.
		self.image:setFillColor( tint.red or 1,tint.green or 1,tint.blue or 1 )
	end
end

--//% 	Get the bitmap image representing this character as a display object
--//	@return [displayObject]		bitmap object

function BitmapCharacter:getImage()
	return self.image 
end 

--//%	Get the bounding box for the unmodified character.
--//	return [boundingBox] 		table containing bounding box x1,y1,x2,y2,width and height members.

function BitmapCharacter:getBoundingBox()
	return self.boundingBox
end

--//%	Get the character associated with this bitmap
--//	@return [number]	Unicode value of character, or nil if it is not a unicode character.

function BitmapCharacter:getCharacter()
	return self.character
end 

--- ************************************************************************************************************************************************************************
--//%										Modifier Store singleton - keeps an internal list of all standard modifiers
--- ************************************************************************************************************************************************************************

local ModifierStore = Base:new()

--//%	Initialise the store

function ModifierStore:initialise()
	self.storeItems = {} 																	-- hash of store items
end

--//%	Register a named modifier
--//	@name 		[string]			modifier name
--//	@modifier 	[function/table]	modifier instance or function

function ModifierStore:register(name,modifier)
	name = name:lower()
	assert(self.storeItems[name] == nil,"Duplicate modifier name "..name)
	self.storeItems[name] = modifier
end

--//%	Retrieve a named modifier
--//	@name 		[string]			modifier name
--//	@return 	[function/Table]	modifier instance or function requested

function ModifierStore:get(name)
	name = name:lower()
	assert(self.storeItems[name] ~= nil,"Modifier unknown "..name)
	return self.storeItems[name]
end

ModifierStore:initialise()																	-- make prototype an instance.
ModifierStore.new = nil

--- ************************************************************************************************************************************************************************
--//	This is a collection of Bitmap Characters that may be available for re-use, when changing the text on a Bitmap String. For some reason I called it a Bucket class
--//	This is tightly coupled to the BitmapString class which uses it.
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
--//	@character 		  [number/string] 		character code wanted from the bucket.
--//	@return 		  [BitmapCharacter]		useable bitmap character from bucket or nil if not found.

function BitmapCharacterBucket:getInstance(character)
	for index,bucketItem in pairs(self.collection) do 										-- work through the bucket
		if bucketItem:getCharacter() == character then  									-- found a match ?
			local instance = bucketItem 													-- save the instance.
			self.collection[index] = nil 													-- remove it from the list
			-- print("Recycle" .. character)
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
--							This extracts characters, one at a time, from a string, converting 13/10 to 13 and extracting {} commands
--- ************************************************************************************************************************************************************************

local CharacterSource = Base:new()

--//%	Initialise a character source
--//	@str 	[string] 				string to use.
--//	@start 	[string]				start character string
--//	@end 	[string] 				end character string

function CharacterSource:initialise(str,startc,endc)
	self.source = str 																		-- save the source.
	self.index = 1 																			-- next character from here.
	self.startCode = startc or "{"			 												-- get start and end code
	self.endCode = endc or "}"
end

--//% 	Get the next character from the source as a unicode number, if it is a {command} returns that as a string.
--//	@return 	[string/number] 			unicode of character, returns 13 for both CR and LF, nil if there is nothing left. 

function CharacterSource:get() 																
	if self:nextMatches(self.startCode) then  											-- is it a start tint (e.g normally {)
		local cmd = ""
		while not self:nextMatches(self.endCode) do  									-- keep going till } (or whatever) found.
			code = self:getRaw() 														-- get next.
			assert(code ~= nil,"Missing closing terminator in command")
			if code ~= self.endCode then cmd = cmd .. string.char(code) end 			-- build a string up
		end
		code = cmd:lower() 																-- return a lower case string.
		return code
	end 

	local code = self:getRaw() 															-- get the code character, unprocessed.
	if code == 10 then code = 13 end 													-- convert return to newline so 0x0D and 0x0A are synonymous.
	return code 
end

--//%	Check to see if there there any more characters to get from the source.
--//	@return [boolean] true if there are.

function CharacterSource:isMore() 
	return self.index <= #self.source
end

--//% 	Allows us to read a single character, if available. Can be overridden for UTF-8 support. And is.
--//	@return 	[number]			unicode of next character or nil.

function CharacterSource:getRaw()
	if not self:isMore() then return nil end 												-- nothing left.
	local unicode = self.source:sub(self.index,self.index):byte(1) 							-- get character, make into a number
	self.index = self.index + 1 															-- advance to next.
	return unicode 
end 

--//% 	Check to see if the next character matches the given string or not (ASCII) - if it does, then skip it. This is fairly tightly
--//	coupled to getRaw() because it does not use it at present. However it is mandatory that the match string by Unicode not UTF-8.
--//	if this is a serious problem I'll improve this, but this should be sufficient.
--//	@return 	[boolean]			true if a match is found.

function CharacterSource:nextMatches(match)
	if not self:isMore() then return false end 												-- nothing to match against.
	if self.source:sub(self.index,self.index+#match-1) ~= match then return false end
	self.index = self.index + #match 
	return true 
end 

--- ************************************************************************************************************************************************************************
--//%								UTF-8 Encoder. UTF-8 is only encoded to the two byte level. Overrides getRaw() to extract UFT-8 chars
--- ************************************************************************************************************************************************************************

local UTF8Source = CharacterSource:new()

--//%	Get raw character, uses superclass's routine.
--//	@return [number]	unicode character

function UTF8Source:getRaw()
	local ch = CharacterSource.getRaw(self) 												-- get the next character from the source.
	if ch < 0x80 then return ch end 														-- single character UTF-8
	local topBits = 32 																		-- modulus of byte 1.
	local topPart = 6
	local countChars = 1
	while math.floor(ch/topBits) ~= topPart do 												-- keep going till it is 110 xxxxx
		topBits = topBits / 2 																-- shift everything left.
		topPart = (topPart + 1) * 2 														-- next top bits value
		countChars = countChars + 1 														-- one more character
		assert(countChars < 6,"Unsupport UTF-8 format (7 byte)")
	end
	ch = ch % topBits 																		-- the first bit (e.g. xxxxx)
	while countChars > 0 do  																-- pull in all the extended characters 10xx xxxx
		countChars = countChars - 1 														-- decrement counter
		local c2 = CharacterSource.getRaw(self)  											-- get next extension
		assert(math.floor(c2/64) == 2,"Malformed UTF-8 Character") 							-- check to see if 10xx xxxx
		ch = ch * 64 + c2 % 64 																-- shift character code into correct position
	end 
	return ch
end

--- ************************************************************************************************************************************************************************
--																		Bitmap String class.
--
--	Basically a collection of bitmaps with positioning information that can be modified.
--- ************************************************************************************************************************************************************************

local BitmapString = Base:new() 															-- exists purely for the documentation.

BitmapString.isDebug = false 																-- provides visual debug support for the string.
BitmapString.animationFrequency = 15 														-- animation update frequency, Hz. (static)
BitmapString.sourceClass = CharacterSource 													-- source for characters
BitmapString.imageMapping = "icons/*.png" 													-- maps icons to a location.
BitmapString.Justify = { LEFT = 0, CENTER = 1, CENTRE = 1, RIGHT = 2} 						-- Justification comments.

BitmapString.startTintDef = "{" 															-- start and end markers for font tinting.
BitmapString.endTintDef = "}"
BitmapString.DEFAULT_SIZE = -1 																-- use the built in font size.

--//	enable bounding box for characters (red) and string (green)
--//	@flag [boolean] true/false
function BitmapString:showBoundingBox(flag)
	BitmapString.isDebug = flag
	BitmapCharacter.isDebug = flag
end

--// 	We have a replacement constructor, which decorates a Corona Group with the BitmapString's methods. Note that you cannot therefore subclass
--//	BitmapString as normal, because it is a mixin. 

function BitmapString:new(...)
	local newObject = display.newGroup() 													-- create new group
	newObject.__oldRemoveSelf = newObject.removeSelf 										-- create an __oldRemoveSelf method which is the removeSelf()
	for name,object in pairs(BitmapString) do  												-- go through bitmap string looking for methods etc.
		if type(object) == "function" and name ~= "new" then 								-- if it's a function, other than new.
			newObject[name] = object  														-- decorate the new Object
		end
	end
	newObject.Justify = BitmapString.Justify 												-- expose constants
	newObject.DEFAULT_SIZE = BitmapString.DEFAULT_SIZE
	newObject:initialise(...) 																-- now call the constructor.
	return newObject
end

--//	Constructor initialisation. Sets the font name and size.
--//	@fontName [string]		Name of font, corresponds to .fnt file.
--//	@fontSize [number]		Height of font in pixels, default is current size if ommitted, DEFAULT_SIZE is actual physical font size on PNG.

function BitmapString:initialise(fontName,fontSize) 
	self.fontName = fontName 																-- save the font name and the font size.
	assert(self.fontName ~= nil,"No default font name for Bitmap String")					-- check a font was provided.
	self.fontSize = fontSize or 64															-- save the font size which defaults to 64
	self.characterList = {} 																-- list of characters.
	self.currText = nil 																	-- text string currently has no value
	self.isHorizontal = true																-- is horizontal text.
	self.direction = 0 																		-- direction is 90 degrees.
	self.justification = BitmapString.Justify.CENTER										-- and multi-line is centred.
	self.verticalSpacingScalar = 1 															-- vertical spacing scalar
	self.horizontalSpacingPixels = 0 														-- horizontal gap extra.
	self.internalXAnchor,self.internalYAnchor = 0.5,0.5 									-- internal anchor (initial) values.
	self.tinting = nil 																		-- current standard tinting, if any.
	self.modifier = nil 																	-- no modifier.
	self.isAnimated = false 																-- not animated
	self.animationRate = 1 																	-- animation rate is 1
	self.animationFrequency = 15 															-- animation updates per second.
	self.animationNext = 0 																	-- time of next animation event.
	self.creationTime = system.getTimer() 													-- remember the start time.
	if BitmapString.isDebug then 
		self.debuggingRectangle = display.newRect(0,0,1,1)									-- moving it will update its location correctly.
		self.debuggingRectangle:setStrokeColor(0,1,0) 									    -- make it green, one width 
		self.debuggingRectangle.strokeWidth = 1
		self.debuggingRectangle:setFillColor( 0,0,0,0 )
		self.debuggingRectangle.anchorX,self.debuggingRectangle.anchorY = 0,0 				-- anchor at top left, position it with the bounding box.
		self:insert(self.debuggingRectangle)
	end
end 

--//	Destructor. Stops animation, clears text, blanks table and finally removes itself (as it is a viewgroup mixin)

function BitmapString:destroy()
	if self.characterList == nil then return end											-- already been done.
	self:stop() 																			-- stop any animations.
	self:setText("") 																		-- removes the bitmaps and tidies up.
	if BitmapString.isDebug then self.debuggingRectangle:removeSelf() end 					-- remove the debugging rectangle if it is in use.
	assert(self.numChildren == 0,"View group not cleaned up correctly")
	self.boundingBox = nil self.justification = nil self.characterList = nil 				-- clean up
	self.debuggingRectangle = nil self.currText = nil self.fontName = nil
	self.lineCount = nil self.wordCount = nil self.fontSize = nil self.isHorizontal = nil
	self.lineLength = nil self.horizontalSpacingPixels = nil self.verticalSpacingScalar = nil
	self.internalXAnchor = nil self.internalYAnchor = nil self.tinting = nil 
	self.modifier = nil self.lineLengthChars = nil self.isAnimated = nil 
	self.creationTime = nil self.animationRate = nil self.direction = nil
	self.animationNext = nil self.animationFrequency = nil
	-- for k,v in pairs(self) do if type(v) ~= "function" then print("(BitmapSt)",k,v) end end -- dump any remaining refs.
	self:__oldRemoveSelf() 																	-- finally, call the old removeSelf() method for the display group
end

--// 	RemoveSelf method, synonym for destroy. Cleans up. Additionally, supports a 'check' on the count of bitmap instances, if this is done
--//	this checks that all strings have been formally deleted, and thus there should be no resource loss.
--//	@checkCount [boolean] 	Instance count check

function BitmapString:removeSelf(checkCount)
	self:destroy()
	if checkCount then
		assert(BitmapCharacter.instanceCount == 0,"Code error, not all Strings are being destroyed")
	end
end

BitmapString.remove = BitmapString.removeSelf 												-- synonym remove for removeSelf

--//	Show is a way of getting round the problems of using members rather than methods when their setting has side-effects.
--//	The method copies the anchorX, anchorY and text values in, then sets and reformats the text appropriately.
--//	@return [BitmapString] 	self for chaining.

function BitmapString:show()
	self.internalXAnchor,self.internalYAnchor = self.anchorX or 0.5,self.anchorY or 0.5 	-- get anchor X, anchor Y
	local text = self.currText 																-- get current text
	self.currText = text .. "!" 															-- this means the change check will fail :)
	self:setText(text)																		-- set the text back so it reformats.
	return self
end

--//	Set the text of the string to the new text. If it changes, it recreates the entire string,using the previous text items where possible.
--//	lines, words, characters are counted, then it is formatted around (0,0) and multi line text is justified. If text member is defined
--//	it uses that as the default, failing that it uses ""
--//	@newText [string]		Replacement text
--//	@return  [BitmapString]	Chain

function BitmapString:setText(newText)
	newText = newText or self.text															-- default is self.text member
	newText = newText or "" 																-- and if that's not defined, then nil.
	if newText == self.currText then return self end 										-- if unchanged, do absolutely nothing.
	local bucket = BitmapCharacterBucket:new(self.characterList) 							-- create a bucket out of the old character list.
	self.characterList = {} 																-- clear the character list.
	self.currText = newText 																-- update the text saved.
	local source = BitmapString.sourceClass:new(newText,BitmapString.startTintDef, 			-- create a character source for it.
																		BitmapString.endTintDef)
	local xCharacter = 1 local yCharacter = 1 												-- these are the indexes of the character.
	self.lineCount = 1 																		-- number of lines.
	local wordNumber = 0 																	-- current word number
	local inWord = false 																	-- word tracking state.
	self.lineLengthChars = {} 																-- line length in characters of each line.
	local characterCount = 1 																-- current character number
	local currentTint = nil 																-- current character specific tint.

	if self.fontSize < 0 then 
		self.fontSize = BitmapFontContainer:getFontInstance(self.fontName):getScaledDefaultSize()
	end

	while source:isMore() do 																-- is there more to get ?
		local code = source:get() 															-- yes, get the next character.
		local isImageCharacter = (code.." "):sub(1,1) == '$'
		if not self.isHorizontal and code == 13 then code = 32 end 							-- if vertical, then use space rather than CR.

		if type(code) == "number" then 														-- if it is a command, currently only a tint.
			local isWord = code > 32 														-- check for word split, e.g. not space.
			if isWord ~= inWord then 														-- moved in or out of word
				inWord = isWord 															-- update state
				if inWord then wordNumber = wordNumber + 1 end 								-- moved into word, bump the word number
			end
		end

		if type(code) == "string" and not isImageCharacter then 							-- is it a string, but not an image character
			currentTint = self:evaluateTint(code)											-- evaluate as section specific tint

		elseif code ~= 13 then 																-- it's a normal character

			if isImageCharacter then 														-- if image character then expand it.
				code = "$"..BitmapString:getImageLocation(code:sub(2))
			end 

			self.lineLengthChars[yCharacter] = xCharacter 									-- update the line length entry.
			self.lineCount = math.max(self.lineCount,yCharacter) 							-- update number of lines.
			local newRect = { charNumber = xCharacter, lineNumber = yCharacter }			-- start with the character number.
			newRect.wordNumber = wordNumber 												-- save the word number
			newRect.totalCharacterNumber = characterCount 									-- save the character count (overall)
			characterCount = characterCount+1
			newRect.tinting = currentTint 													-- save the current tint in that character

			newRect.bitmapChar = bucket:getInstance(code) 									-- is there one in the bucket we can use.
			if newRect.bitmapChar == nil then 												-- no so create a new one
				newRect.bitmapChar = BitmapCharacter:new(self.fontName,code) 				-- of the correct font and character.
				self:insert(newRect.bitmapChar:getImage()) 									-- insert the bitmap image into the view group.
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
		else 	
			xCharacter = 1 																	-- carriage return.
			yCharacter = yCharacter + 1
		end
	end
	for i = 1,#self.characterList do 														-- tell everyone the word count and line count
		self.characterList[i].wordCount = wordNumber
		self.characterList[i].lineCount = self.lineCount 
		self.characterList[i].totalCharacterCount = characterCount - 1 						-- count of characters in total.
	end
	bucket:destroy() 																		-- empty what is left in the bucket
	self:reformatText() 																	-- reformat the text justified and recalculate the bounding box.
	return self
end

--//%	Reformat and rejustify the text, calculate the non-modified bounding box. This has several phases (1) it reformats the text, left justified based at (0,0)
--//	(2) it justifies the text centrally or right if required, (3) it moves the origin from (0,0) if the anchor is set to anything other than (0,0) and finally
--//	(4) it reapplies the modifiers.

function BitmapString:reformatText() 
	self.boundingBox = { x1 = 0,x2 = 0,y1 = 0, y2 = 0 }										-- initial bounding box.
	self.lineLength = {} 																	-- line lengths table.
	for line = 1,self.lineCount do  														-- format each line in turn
		self.lineLength[line] = self:reformatLine(line,0) 									-- reformat each line, and get its length
	end
	self.boundingBox.width = self.boundingBox.x2 - self.boundingBox.x1 						-- set width and height.
	self.boundingBox.height = self.boundingBox.y2 - self.boundingBox.y1
	if self.justification ~= BitmapString.Justify.LEFT then 								-- if not left justified
		self:justifyText(self.justification == BitmapString.Justify.RIGHT)					-- right or centre justify it
	end
	self:anchorMove() 																		-- move the text to allow for the anchors.
	self:applyModifiers() 																	-- apply all the modifiers as appropriate.
end

--//% 	Handle the string repositioning for anchoring. Uses the bounding box to work out the height and width, which is converted into an offset
--//	all the bitmap characters and the debug rectangle (if used) are then moved. We cannot use anchorChildren because of the animation.

function BitmapString:anchorMove()
	if self.internalXAnchor ~= 0 or self.internalYAnchor ~= 0 then 							-- not anchored at 0,0 (e.g. top left)
		local xOffset = -(self.internalXAnchor * self.boundingBox.width) 					-- calculate x,y offsets
		local yOffset = -(self.internalYAnchor * self.boundingBox.height)
		for index,char in ipairs(self.characterList) do 									-- move all bitmaps by that.
			char.bitmapChar:moveBy(xOffset,yOffset)
		end
		self.boundingBox.x1 = self.boundingBox.x1 + xOffset 								-- adjust the bounding box for the anchoring.
		self.boundingBox.x2 = self.boundingBox.x2 + xOffset
		self.boundingBox.y1 = self.boundingBox.y1 + yOffset
		self.boundingBox.y2 = self.boundingBox.y2 + yOffset
	end
	if BitmapString.isDebug then 															-- if debugging, update the debugging rectangle.
		local r = self.debuggingRectangle
		r.x,r.y = self.boundingBox.x1,self.boundingBox.y1
		r.width,r.height = self.boundingBox.width,self.boundingBox.height
		r:toFront()
	end
end

--//% 	Apply modifiers to all the characters. Works through all the characters, for each it creates an default modifier with the characters
--//	personal tint, which it then sends to the modifier with the information structure to be modified. This modifier is then applied to the
--//	bitmap character.

function BitmapString:applyModifiers()
	local currentTint = self.tinting or { red = 1, green = 1, blue = 1 } 					-- get current overall tinting or the stock one
	local elapsed = 0  																		-- elapsed time zero if not animated
	if self.isAnimated ~= nil then 															-- if animated, then calculat elapsed time.
		elapsed = system.getTimer() - elapsed
	end


	for _,char in ipairs(self.characterList) do  											-- work through the character list

		local bitmapChar = char.bitmapChar 													-- point to the bitmap character

		local lineSize = self.lineLengthChars[char.lineNumber] or 0 						-- number of characters in this line.
		local adjustment = 0 																-- allow for left and right half character in positioning.
		adjustment = self.boundingBox.width / lineSize / 2
		-- adjustment = 0

		local modifier = { xScale = 1, yScale = 1, xOffset = 0, yOffset = 0, rotation = 0, 	-- the pre-modifier modifier.
							alpha = 1,tint = { red = currentTint.red, green = currentTint.green, blue = currentTint.blue } }

		if char.tinting then  																-- does the character have its own personal tinting.
			modifier.tint.red = char.tinting.red  											-- if so, copy it into the modifier.
			modifier.tint.blue = char.tinting.blue 
			modifier.tint.green = char.tinting.green 
		end

		if self.modifier ~= nil then 

			local infoTable = { elapsed = elapsed, 											-- elapsed time in milliseconds.
								index = char.charNumber, 									-- index of character number in current line
								length = lineSize,											-- length of current line
								totalIndex = char.totalCharacterNumber, 					-- overall character number
								totalCount = char.totalCharacterCount, 						-- overall character count
								lineIndex = char.lineNumber, 								-- current line number
								lineCount = self.lineCount, 								-- number of lines.
								wordIndex = char.wordNumber, 								-- word number
								wordCount = char.wordCount 									-- count of lines.
			}

			infoTable.charIndex = infoTable.index infoTable.charCount = infoTable.length 	-- modify for consistency , old ones still work of course.

			local charBox = bitmapChar:getBoundingBox() 									-- get the bounding box
			local x = (charBox.x1 + charBox.x2) / 2 										-- position of character midpoint  
			local cPos = (x - (self.boundingBox.x1 + adjustment)) / 						-- convert to percentage of position.
									(self.boundingBox.width-adjustment*2) * 100 
			cPos = math.max(math.min(cPos,100),0)											-- force into range
			cPos = math.round(cPos + elapsed / 100 * self.animationRate) % 100 				-- adjust for animation

			-- print(math.round(cPos),infoTable.index,infoTable.length,infoTable.wordIndex,infoTable.wordCount,infoTable.lineIndex,infoTable.lineCount)

			if type(self.modifier) == "table" then 											-- if it is a table, e.g. a class, call its modify method
				self.modifier:modify(modifier,cPos,infoTable)
			else 																			-- otherwise, call it as a function.
				self.modifier(modifier,cPos,infoTable)
			end
			if math.abs(modifier.xScale) < 0.001 then modifier.xScale = 0.001 end 			-- very low value scaling does not work, zero causes an error
			if math.abs(modifier.yScale) < 0.001 then modifier.yScale = 0.001 end
		end


		bitmapChar:setTintColor(modifier.tint) 												-- apply the tint part of the modifier.
		if self.modifier ~= nil then 
			bitmapChar:modify(modifier) 													-- and modify the other bits.
		end
	end
end

--//%	Convert a textual colour definition to a tint array
--//	@descr 	[string]	description - can be text, n,n,n or ""
--//	@return [table]		tint table containing red,green,blue members or nil.

function BitmapString:evaluateTint(descr)
	if descr == "" then return nil end 														-- empty goes back to the standard tint.
	descr = descr:lower() 																	-- decapitalise
	if BitmapString.standardColours[descr] ~= nil then return  								-- named colour returns that colour.
		BitmapString.standardColours[descr] 
	end
	local r,g,b = descr:match("^([0-9%.]+)%,([0-9%.]+)%,([0-9%.]+)$")						-- rip out r,g,b bits
	assert(b ~= nil,"Bad tint colour " .. descr) 											-- check it is valid
	return { red = r, green = g, blue = b }
end 

BitmapString.standardColours = { 															-- known tinting colours.
	black = 	{ red = 0, green = 0, blue = 0 },
	red = 		{ red = 1, green = 0, blue = 0 },
	green = 	{ red = 0, green = 1, blue = 0 },
	yellow = 	{ red = 1, green = 1, blue = 0 },
	blue= 		{ red = 0, green = 0, blue = 1 },
	magenta = 	{ red = 1, green = 0, blue = 1 },
	cyan = 		{ red = 0, green = 1, blue = 1 },
	white = 	{ red = 1, green = 1, blue = 1 },
	grey = 		{ red = 0.5, green = 0.5, blue = 0.5 },
	orange = 	{ red = 1, green = 140/255, blue = 0 },
	brown = 	{ red = 139/255, green = 69/255, blue = 19/255 }
}
--//	Set the string encoding to use. Supports unicode and utf-8. Works by overriding the SourceClass member which is used to create a
--//	SourceClass when the string is being dismantled.
--//	@encoding [string] 			unicode, utf-8 or utf8 - nil is unicode

function BitmapString:setEncoding(encoding)
	encoding = (encoding or "unicode"):lower() 												-- default is unicode, make l/c
	if encoding == "" or encoding == "unicode" then 
		BitmapString.sourceClass = CharacterSource 
	elseif encoding == "utf8" or encoding == "utf-8" then 									-- utf-8 and utf8 use that source 
		BitmapString.sourceClass = UTF8Source
	else 																					-- otherwise we don't know.
		error("Unsupported encoding "..encoding)
	end
end

--//%	Justify the text. Only centre and right, it is left justified by default.
--//%	@isRightJustify [boolean]	true if to be right justified rather than centred (default if not called is left)

function BitmapString:justifyText(isRightJustify)
	for line = 1,self.lineCount do  														-- work through each line
		local offset = (self.boundingBox.width-self.lineLength[line]) 						-- calculate the difference between this line and the longest one.
		if not isRightJustify then offset = offset / 2 end 									-- if centre, halve it.
		self:reformatLine(line,offset) 														-- and reformat it.
	end
end

--//%	Reformat a single line, update the bounding box, return the right most display pixel used. This positions a line according to the direction.
--//	(for direction 180 it works backwards)
--// 	@lineNumber	[number]	line to reformat
--// 	@xPos 		[number] 	indent from left to reformat with
--//	@return 	[number]	rightmost pixel used.

function BitmapString:reformatLine(lineNumber,xPos)
	local index = 1 																		-- index in character list.
	local xEnd = xPos

	if self.direction == 180 then 															-- if backwards, then advance xpos to end position
		for _,charItem in ipairs(self.characterList) do 
			if charItem.lineNumber == lineNumber then 
				xPos = xPos + self.horizontalSpacingPixels + charItem.bitmapChar:getBoundingBox().width 
			end 
		end
		xPos = xPos - self.horizontalSpacingPixels 											-- adjust for first
		xEnd = xPos 																		-- remember the end
	end

	while index <= #self.characterList do 													-- work through all the characters.
		local charItem = self.characterList[index] 											-- short cut to the item
		if charItem.lineNumber == lineNumber then 											-- is it in the line we are rendering.
			local ln = lineNumber 															-- line number to go to.
			if self.direction == 270 then ln = charItem.lineCount - ln + 1 end 				-- vertically flip for 270 degree orientation
			if self.direction == 180 then  													-- work backwards for 180 degree orientation.
				xPos = xPos - charItem.bitmapChar.boundingBox.width 
			end
			local charBox = charItem.bitmapChar:getBoundingBox() 							-- get character bounding box
			charItem.bitmapChar:moveTo(xPos,												-- move and size correctly.
										(ln - 1) * charBox.height * self.verticalSpacingScalar,self.fontSize) 
			charBox = charItem.bitmapChar:getBoundingBox() 									-- get character bounding box
			xPos = math.max(charBox.x2) 													-- get the next position to the right.
			self.boundingBox.x2 = math.max(self.boundingBox.x2,xPos) 						-- update the bounding box.
			self.boundingBox.y2 = math.max(self.boundingBox.y2,charBox.y2)
			xPos = xPos + self.horizontalSpacingPixels 										-- spacing goes after bounding box.
			if self.direction == 180 then
				xPos = charBox.x1 - self.horizontalSpacingPixels 
			end
		end
		index = index + 1 																	-- go to next entry
	end
	return math.max(xPos,xEnd)
end

--//	Return the view group if you want to animate it using transition.to. The object now is the view group
--//	but this is left in for consistency. You can just remove getView() methods.
--//	@return [self]

function BitmapString:getView() return self end 								

--//	Turns animation on, with an optional speed scalar. This causes the 'cPos' in modifiers to change with time
--//	allowing the various animation effects. Note that if you turn animation on it creates a reference which you have to remove
--//	if you want the automatic garbage collection for Storyboard and Composer.
--//	@speedScalar [number]	Speed Scalar, defaults to 1. 3 is three times as fast.
--//	@return [BitmapString]	allows chaining.

function BitmapString:animate(speedScalar)
	if not self.isAnimated then 															-- Add runtime enter frame if not already animating	
		Runtime:addEventListener("enterFrame",self)
	end
	self.isAnimated = true 																	-- turn it on
	self.animationRate = speedScalar or 1 													-- set the speed
	return self
end

--//	Turn animation off. 
--//	@return [BitmapString]	allows chaining.

function BitmapString:stop()
	if self.isAnimated then 																-- remove event listener if animating 
		Runtime:removeEventListener("enterFrame", self)
	end
	self.isAnimated = false 																-- turn it off
	return self
end

--//%	Enter Frame event handler. Ignores fps and uses its own animation rate which is 15Hz by default.

function BitmapString:enterFrame(event)
	assert(self.isAnimated,"Event listener on but not animated ?")							-- it should be animating !
	local time = system.getTimer()															-- get system time 
	if time > self.animationNext then 														-- is it time to animate ?
		self.animationNext = time + 1000 / BitmapString.animationFrequency					-- next time we animate is.
		self:applyModifiers() 																-- reapply the modifiers.
	end
end

--//	Set the animation rate - how many updates are a done a second. If this is > fps it will be fps.
--//	@frequency [number]		updates per second of the animation rate, defaults to 15 updates per second.

function BitmapString:setAnimationRate(frequency)
	BitmapString.animationFrequency = frequency or 15 										-- set the animation frequency, default 15
end

--//	Map the image name to a file name. You can override this to get more complex images, or just use the setImageLocation method.
--//	@baseImage 	[string] 		Base Image name of an icon, shorn of the $ (e.g. {$fred} => "fred")
--//	@return 	[string]		Path name of image to use (by default icons/fred.png)

function BitmapString:getImageLocation(baseImage)
	return BitmapString.imageMapping:gsub("%*",baseImage)
end

--//	Set the default location for images to be used in fonts (e.g. {$icon}).
--//	@location 	[string] 		Path name with an asterisk to be used where the name should be substituted, defaults to icon/*.png

function BitmapString:setImageLocation(location)
	BitmapString.imageMapping = location or "icons/*.png"
end

--//	Set multi-line justification.
--//	@justification [number]	BitmapString.Justify.LEFT/CENTER/RIGHT
--//	@return [BitmapString]	allows chaining.

function BitmapString:setJustification(justification)
	justification = justification or BitmapString.Justify.CENTER 							-- default is centre.
	if justification ~= self.justification then 											-- has it changed ?
		self.justification = justification 													-- update
		self:reformatText() 																-- reformat
	end
	return self
end

--//	Move the view group - i.e. the font. Included for consistency, you can just assign to x,y
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
--//	@fontSize [number]			Height of font in pixels, default is current size if ommitted, DEFAULT_SIZE is actual physical font size on PNG.
--//	@return [BitmapString]	allows chaining.

function BitmapString:setFont(font,fontSize)
	local originalText = self.currText 														-- preserve the original text
	self:setText("") 																		-- set the text to empty, which clears up the displayObjects etc.
	self.fontName = font or self.fontName													-- update font and font size
	self.fontSize = fontSize or self.fontSize
	self:setText(originalText) 																-- and put the text back.
	return self
end

--//	Set the anchor position - same as Corona except it is done with a method not by assigning member variables. If you omit the parameters
--//	then it will use anchorX, anchorY as defaults.

--//	@anchorX 	[number]			X anchor position 0->1
--//	@anchorY 	[number]			Y anchor position 0->1
--//	@return [BitmapString]	allows chaining.

function BitmapString:setAnchor(anchorX,anchorY)
	anchorX = anchorX or self.anchorX anchorY = anchorY or self.anchorY 					-- use the anchorX, anchorY values if they are there.
	if anchorX ~= self.internalXAnchor or anchorY ~= self.internalYAnchor then 				-- different from the internal one.
		self.anchorX,self.anchorY = anchorX,anchorY 										-- update the visible ones.
		self.internalXAnchor = anchorX self.internalYAnchor = anchorY 						-- update
		self:reformatText() 																-- and reformat.
	end
	return self
end

--//	Set the direction - we only support 4 main compass points, and the font is always upright. 
--//	@direction [number] string direction (degrees) 0,90,180,270
--//	@return [BitmapString]	allows chaining.

function BitmapString:setDirection(direction)
	direction = (direction + 3600) % 360 													-- shift into range 0-360
	assert(direction % 90 == 0,"Direction not supported")									-- now we only support 90 degree text.
	self.isHorizontal = (direction == 0 or direction == 180) 								-- set the horizontal flag
	self.direction = direction 																-- set the direction.
	self:setFont() 																			-- recreate the font to update the alignment.
	return self
end

--//	Allows you to adjust the spacing between letters by adding a given number of pixels.
--//	@spacing [number]	Pixels to insert between letters (or remove, can be negative) 
--//	@return [BitmapString]	allows chaining.

function BitmapString:setSpacing(spacing)
	self.horizontalSpacingPixels = spacing or 0 											-- update the distance
	self:reformatText() 																	-- reformat the text
	return self
end

--//	Allows you to adjust the spacing between letters vertically. This is a scalar, so 0.5 halves the distance.
--//	@spacing [number]	Pixels to insert between letters (or remove, can be negative)
--//	@return [BitmapString]	allows chaining.

function BitmapString:setVerticalSpacing(spacing)
	self.verticalSpacingScalar = spacing or 1 												-- update the spacing
	self:reformatText() 																	-- reformat the text
	return self
end

--//	Set the Font Size
--//	@size [number]			Height of font in pixels, default is current size if ommitted, DEFAULT_SIZE is actual physical font size on PNG.
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
		funcOrTable = ModifierStore:get(funcOrTable)
	end
	self.modifier = funcOrTable 															-- set the modifier
	self:reformatText() 																	-- reformat the text.
	return self
end

--//	Apply an overall tint to the string. This can be overridden or modified using the tint table of the modifier
--//	which itself has three fields - red, green and blue. If nothing provided, clears the default tint.
--//	@r 	[number] 		Red component 0-1
--//	@g 	[number] 		Green component 0-1
--//	@b 	[number] 		Blue component 0-1
--//	@return [BitmapString] self

function BitmapString:setTintColor(r,g,b)
	if r == nil and g == nil and b == nil then 												-- no parameters  																	
		self.tinting = nil 																	-- clear tint
	else
		self.tinting = { red = r or 1 , green = g or 1, blue = b or 1 } 					-- otherwise create a tint.
	end
	self:reformatText()
	return self
end

--//	Set the bounding strings for tint definitions (defaults to { and }). These can be multiple character strings
--//	but must be standard ASCII characters.
--//	@cStart [string]		start string
--//	@cEnd 	[string]		end string.

function BitmapString:setTintBrackets(cStart,cEnd) 
	BitmapString.startTintDef = cStart or "{"
	BitmapString.endTintDef = cEnd or "}"
	assert(BitmapString.startTintDef ~= "") 												-- these will cause absolute chaos.
	assert(BitmapString.endTintDef ~= "")
	assert(BitmapString.startTintDef ~= BitmapString.endTintDef)
end

--//	SetScale is no longer supported. The effect of disproportionately scaled fonts can be achieved simply by scaling
--// 	the view group. For larger fonts, increase the font size.

function BitmapString:setScale(xScale,yScale)
	error("setScale() is no longer supported - use the scale of the object to produce different text size ratios, or adjust the font size")
end

--//	Clear is no longer supported, because of the need to keep references.

function BitmapString:clear()
	error("clear() is no longer supported - make sure animation is stopped when relying on Corona to clean up.")
end

--- ************************************************************************************************************************************************************************
--
--		This adds a display.newBitmapText method which is fairly close to that provided by Corona for newText, as close as I can get. 
--
--- ************************************************************************************************************************************************************************

function display.newBitmapText(...)
	local options = arg[1] 																		-- equivalent to 'options' in documentation
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
	if options.width ~= nil or options.height ~= nil then print("newBitmapText does not support multiline text") end

	local bitmapString = display.hiddenBitmapStringPrototype:new(options.font,options.fontSize)	-- create a bitmap string object
	bitmapString:setText(options.text) 															-- set the text
	if options.x ~= nil then bitmapString:moveTo(options.x,options.y or 0) end 					-- if a position is provided, move it there.
	if options.parent ~= nil then options.parent:insert(bitmapString:getView()) end 			-- insert into parent

	local justify = BitmapString.Justify.LEFT 													-- convert the align option into an appropriate parameter.
	if options.align == "center" then justify = BitmapString.Justify.CENTER end 
	if options.align == "right" then justify = BitmapString.Justify.RIGHT end 
	bitmapString:setJustification(justify)
	return bitmapString
end

display.hiddenBitmapStringPrototype = BitmapString 												-- the hidden prototype ooh err....

--- ************************************************************************************************************************************************************************
--																	Curve class with one static method.
--- ************************************************************************************************************************************************************************

local Curve = Base:new() 

--//	Helper function which calculates curves according to the definition - basically can take a segment of a trigonometrical curve and apply it to 
--//	whatever you want, it can be repeated over a range, so you could say apply the sin curve from 0-180 5 times and get 5 'humps'
--
--//	@curveDefinition 	[Modifier Descriptor]	Table containing startAngle,endAngle,curveCount,formula
--//	@position 			[number]				Position in curve 0 to 100
--//	@return 			[number]				Value of curve (normally between 0 and 1)

function Curve:curve(curveDefinition,position)
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

--- ************************************************************************************************************************************************************************
--
--//		Modifiers can be functions, classes or text references to system modifiers. The modifier takes five parameters <br><ul>
--//
--//			<li>modifier 		structure to modify - has xOffset, yOffset, xScale, yScale,alpha  and rotation members (0,0,1,1,1,0) which it can
--// 								tweak. Called for each character of the string. You can see all of them in Wobble, or just rotation in Jagged.</li>
--//			<li>cPos 			the character position, from 0-100 - how far along the string this is. This does not correlate to string character
--// 								position, as this is changed to animate the display. It is a percentage of the text width. </li>
--// 			<li>info 			table containing information for the modifier : elapsed - elapsed time in ms, index - position in this line, 
--// 								length - length of this linem lineCount, lineIndex - line number of this character, lineCount - total number of lines
--//								</li></ul>
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
	modifier.yOffset = - Curve:curve(self.curveDesc,cPos) * 50 * self.scale 			
end

--//	Extend simple Curve scale Modifier so it is inverted.

local SimpleInverseCurveModifier = SimpleCurveModifier:new()

--// %	Make the modifications needed to change the vertical position
--//	@modifier [Modifier Table]	Structure to modify to change effects
--//	@cPos [number]  Position in effect
--//	@info [table] Information about the character/string/line

function SimpleInverseCurveModifier:modify(modifier,cPos,info)
	modifier.yOffset = Curve:curve(self.curveDesc,cPos) * 50 * self.scale 			
end

--//	Modifier which changes the vertical scale on a curve

local SimpleCurveScaleModifier = SimpleCurveModifier:new()						 			-- curvepos scales the text vertically rather than the position.

--// %	Make the modifications needed to change the vertical scale
--//	@modifier [Modifier Table]	Structure to modify to change effects
--//	@cPos [number]  Position in effect
--//	@info [table] Information about the character/string/line

function SimpleCurveScaleModifier:modify(modifier,cPos,info)
	modifier.yScale = Curve:curve(self.curveDesc,cPos)*self.scale+1 					-- so we just override the bit that applies it.
end

--//	Scale but shaped the other way.

local SimpleInverseCurveScaleModifier = SimpleCurveScaleModifier:new()

--// %	Make the modifications needed to change the vertical scale
--//	@modifier [Modifier Table]	Structure to modify to change effects
--//	@cPos [number]  Position in effect
--//	@info [table] Information about the character/string/line

function SimpleInverseCurveScaleModifier:modify(modifier,cPos,info)
	modifier.yScale = 1 - Curve:curve(self.curveDesc,cPos)*self.scale*2/3				-- so we just override the bit that applies it.
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

ModifierStore:register("wobble",WobbleModifier:new())										-- tell the system about them.
ModifierStore:register("curve",SimpleCurveModifier:new())
ModifierStore:register("icurve",SimpleInverseCurveModifier:new())
ModifierStore:register("scale",SimpleCurveScaleModifier:new())
ModifierStore:register("iscale",SimpleInverseCurveScaleModifier:new())
ModifierStore:register("jagged",JaggedModifier:new())
ModifierStore:register("zoomout",ZoomOutModifier:new())
ModifierStore:register("zoomin",ZoomInModifier:new())

local Modifiers = { WobbleModifier = WobbleModifier,										-- create table so we can provide the Modifiers.
					SimpleCurveModifier = SimpleCurveModifier,
					SimpleInverseCurveModifier = SimpleCurveModifier,
					SimpleCurveScaleModifier = SimpleCurveScaleModifier,
					SimpleInverseCurveScaleModifier = SimpleInverseCurveScaleModifier,
					JaggedModifier = JaggedModifier,
					ZoomOutModifier = ZoomOutModifier,
					ZoomInModifier = ZoomInModifier }

return { BitmapString = BitmapString, Modifiers = Modifiers, FontManager = BitmapString, Curve = Curve, BitmapFont = BitmapFont }

-- the above isn't a typo. It's so that old FontManager calls () still work :)

-- option to create any displayObject.

-- Known issues
-- ============
-- You can't subclass it. Create an instance and decorate it.
-- To animate you have to have a links from the Runtime. If you let the system remove it rather than stopping it yourself it will leave a trailing reference.

--[[

	Date 		Changes Made
	---- 		------------
	26/05/14 	Corrected code in display.newBitmapString so it works properly.
	27/05/14 	Text alignment bug reported by Richard 9. Tested with static Arial export.
	01/06/14 	Full UTF-8 Support (up to 6 bytes)
	01/06/14 	Auto-selection of differing scales of png to allow for different device resolutions
	01/06/14 	Reads padding from font file.
	02/06/14 	Implemented DEFAULT_SIZE
	05/07/14 	Ingemar Bergmark fixed the way it handles multi resolution pngs to work with the Corona system.
				Fixed padding bug with image characters
				Stopped crashing when no imageSuffix in config.
--]]