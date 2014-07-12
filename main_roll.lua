--- ************************************************************************************************************************************************************************
---
---				Name : 		main_roll.lua
---				Purpose :	Rolling out text with events.
---				Created:	23 May 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************


display.setStatusBar(display.HiddenStatusBar)
fm = require("system.fontmanager")

--- ************************************************************************************************************************************************************************
--//												Modifier class, produces a 'roll out' of text at a variable speed.
--- ************************************************************************************************************************************************************************

local RolloutModifier = Base:new()

function RolloutModifier:initialise() 
	self.lastElapsed = nil 																		-- time of last modifier call
	self.totalElapsed = 0 																		-- total elapsed time, speed of time is effect by speed
	self.outstandingPause = 0 																	-- number of pause milliseconds outstanding.
	self:setSpeed() 																			-- set speed to default.
end

--//	Set the Roll out speed
--//	@speed [number] 		Roll out speed, default 4 cps.

function RolloutModifier:setSpeed(speed)
	self.charsPerSecond = speed or 4
end

--//	Adds to the pause counter - this allows the timer system to delay for a specified period.
--//	@millisecs 	[number]	Time to delay.

function RolloutModifier:addPause(millisecs)
	self.outstandingPause = self.outstandingPause + millisecs 									-- add to required pause.
end

--//	Modifier responsible for rollout. All it does is change the alpha to hide or make characters visible.
--//	@modifier [table]		Modifications to be made to font.
--//	@cPos 	  [number]		Animation position
--//	@info 	  [table]		Information about current character
--//	@return   [number] 		Index of the current character (not required for stand alone but does not matter)

function RolloutModifier:modify(modifier, cPos, info)
	if self.lastElapsed ~= nil then  															-- if not the first
		local time = info.elapsed - self.lastElapsed 											-- time elapsed since last

		if self.outstandingPause >= 0 then  													-- time outstanding.
			self.outstandingPause = self.outstandingPause - time 								-- deduct elapsed time from pause time.
			time = 0 																			-- don't bother to count this, it's near enough.
		end 

		self.totalElapsed = self.totalElapsed + time * self.charsPerSecond						-- bump the total elapsed time adjusting for the speed.
						 
	end
	self.lastElapsed = info.elapsed 															-- record time of last call to modifier.

	local charNumber = math.floor(self.totalElapsed / 1000) + 1 								-- number of character currently being displayed.

	if info.totalIndex > charNumber then  														-- if the current character is past that
		modifier.alpha = 0 																		-- hide it.
	end
	if info.totalIndex == charNumber then 														-- if it is the current character
		modifier.alpha = (self.totalElapsed % 1000) / 1000 										-- it becomes progressively visible.
	end
	return charNumber 
end

--- ************************************************************************************************************************************************************************
--//		An adaptor for modifiers. The modifier returns the 'position' in its call (normally modifiers return nil) which is used in conjunction with 
--//														a table of events to fire events at regular intervals.
--- ************************************************************************************************************************************************************************

local EventAdaptor = Base:new()

--//	Create an adaptor.
--//	@modifier [Modifier]	Modifier to adapt to event use.

function EventAdaptor:initialise(modifier)
	self.coreModifier = modifier 																-- save the modifier to be adapted.
	self.eventList = {} 																		-- event list, keyed on name, { time = <fire time>,name = <string>,[action = <func>]}
	self.lastEventTime = 0 																		-- last 'time' when an event occurred.
	self.eventCount = 0 																		-- number of events
end 

--//	Add an event to the event queue
--//	@time 	[number] 		internal time when it will fire
--//	@name 	[string] 		event name
--//	@action [function] 		optional function to execute, may be nil.

function EventAdaptor:addEvent(time, name ,action)
	local newEvent = { time = time, name = name, action = action }								-- construct an event object.
	self.eventList[#self.eventList+1] = newEvent 												-- add to the list
	self.eventCount = self.eventCount + 1 														-- increment event counts.
	return self
end


--//	Modifier for event adaptor. The modifications are handled by the adapted modifier, then events are checked for if the position has changed.
--//	@modifier [table]		Modifications to be made to font.
--//	@cPos 	  [number]		Animation position
--//	@info 	  [table]		Information about current character

function EventAdaptor:modify(modifier, cPos, info)
	local position = self.coreModifier:modify(modifier, cPos, info) 							-- call the adapted modifier
	if position > self.lastEventTime then  														-- are we past the previous event time.
		for key,event in pairs(self.eventList) do 												-- scan through the known events
			if event.time > self.lastEventTime and event.time <= position then 					-- is it after the previous and before/same as current ?
				local data = { modifier = modifier, info = info, owner = self, time = position, -- create an information table - modifier, info, time and reference to self.
																		modifierInstance = self.coreModifier, bitmapStringInstance }
				self:fireEvent(event.name,event,data) 											-- then fire that event.
				self.eventList[key] = nil 														-- forget about the event, freeing up any references.
				self.eventCount = self.eventCount - 1 											-- adjust count
				if self.eventCount == 0 then self:clearupEvent() end 							-- if completed then clean up.
			end
		end
		self.lastEventTime = position  															-- update the last fire time.
	end
end

--//	Fire given event
--//	@eventName 	[string]			name of event
--//	@eventInfo 	[table]				event table entry (time, name, action)
--//	@data 		[table] 			data about the modifier, the character, self and elapsed time 

function EventAdaptor:fireEvent(eventName,eventInfo,data)
	if eventInfo.action ~= nil then 															-- if an event action is provided.
		eventInfo.action(eventName,eventInfo,data) 												-- then fire it
	else 
		self:eventHandler(eventName,eventInfo,data) 											-- else let the handler handle it.
	end
end

--//	Handle a named event, e.g. one without a action method.
--//	@eventName 	[string]			name of event
--//	@eventInfo 	[table]				event table entry (time, name, action)
--//	@data 		[table] 			data about the modifier, the character, self and elapsed time 

function EventAdaptor:eventHandler(eventName,eventInfo,data)
	-- TODO: Really you should override this
	print("[Debug]",eventName,"fired at",eventInfo.time)
end

--//	Clear up any event references we can get rid of.

function EventAdaptor:clearupEvent()
end

--- ************************************************************************************************************************************************************************
--								A subclass of the EventAdaptor which always uses the Rollout Modifier or a subclass, and is specific to the task
--- ************************************************************************************************************************************************************************

local RolloutEventAdaptor = EventAdaptor:new()

--//	Constructor. 
--//	@fontManagerInstance 	[FontManager]			Font manager instance as returned from require.
--//	@modifierInstance  		[RollOutModifier] 		Rollout Modifier or subclass.

function RolloutEventAdaptor:initialise(fontManagerInstance,modifierInstance)
	self.fontManagerInstance = fontManagerInstance 												-- we need this so we can access the parsing methods in FM.
	self.rollOutModifier = modifierInstance 													-- and save the modifier we are using.
	self.commandList = { }
	EventAdaptor.initialise(self,self.rollOutModifier) 											-- call the superclass constructor
end

--//	Add an event type - e.g. by name
--//	@name 	[string] 		Name of event to add

function RolloutEventAdaptor:addEventType(name)
	assert(self.commandList[name] == nil,"Duplicate event type") 								-- no duplicates
	self.commandList[name] = 1 																	-- add to table
	return self 
end

--//	Set the text of a bitmap string using this modifier. Looks for commands which are converted into events occurring at a character position, then
--//	removes those commands, sets the text in the bitmap string and associates it with the modifier.
--//	@bitmapString [BitmapString] 		Bitmap string to use
--//	@text  		  [string] 				Text to set it to.

function RolloutEventAdaptor:setText(bitmapString,text)
	local bitmapProto = self.fontManagerInstance.BitmapString 									-- the BitmapString prototype

	local source = bitmapProto.sourceClass:new(text) 											-- create a new parser of the string dependent on the current text setting
	local charPos = 1 																			-- effective position in string.
	while source:isMore() do  																	-- work through the string.
		local nextItem = source:get() 															-- get next item.
		if type(nextItem) == "string" and self.commandList[nextItem] ~= nil then 				-- if it is a string and a known command.
			self:addEvent(charPos,nextItem) 													-- create an event at the current time, e.g. character position.
		end 
		if type(nextItem) == "number" and nextItem ~= 13 then  									-- if numeric e.g. character and not return (return doesn't count)
			charPos = charPos + 1 																-- bump the character position.
		end
	end

	for command,_ in pairs(self.commandList) do 												-- work through all the known commands and remove them.
		local regEx = "%"..bitmapProto.startTintDef..command.."%"..bitmapProto.endTintDef 		-- replacement regext, get delimiters from Bitmap String class
		while text:match(regEx) do text = text:gsub(regEx,"") end  								-- remove all instances from the text string.
	end
	bitmapString:setText(text) 																	-- set the string to the text with the commands removed.
	bitmapString:setModifier(self) 																-- and set up the modifier.
	self.bitmapStringInstance = bitmapString 													-- remember the bitmap string instance.
	bitmapString:animate()
end

--//	Handle a named event, e.g. one without a action method.
--//	@eventName 	[string]			name of event
--//	@eventInfo 	[table]				event table entry (time, name, action)
--//	@eventData 	[table] 			data about the modifier, the character, self and elapsed time 

function RolloutEventAdaptor:eventHandler(eventName,eventInfo,eventData)
	local method = self[eventName .. "Event"] 													-- the method to execute
	assert(method ~= nil,"event "..eventName .. "Event() handler not implemented") 				-- check it physically exists.
	eventData.bitmapStringInstance = self.bitmapStringInstance 									-- tell it about the bitmap display object
	method(self,eventName,eventInfo,eventData) 													-- call the handler
end 

--//	Cleaning up after the last event, we lose the reference to the bitmap String.

function RolloutEventAdaptor:clearupEvent()
	EventAdaptor.clearupEvent(self)	 															-- superclass
	self.bitmapStringInstance = nil  															-- stops us keeping a reference
end

--- ************************************************************************************************************************************************************************
--																		Sample Roll out subclass
--- ************************************************************************************************************************************************************************

local SampleRollOut = RolloutEventAdaptor:new()

function SampleRollOut:initialise(fontManagerInstance,modifierInstance)
	RolloutEventAdaptor.initialise(self,fontManagerInstance,modifierInstance) 					-- constructor for superclass
	self:addEventType("slow"):addEventType("fast") 												-- add known commands
	self:addEventType("shake"):addEventType("pause4")					
end

function SampleRollOut:slowEvent(name,info,data) 
	print("Slow event at",info.time) 
	data.modifierInstance:setSpeed(1) 															-- we are using the modifier instance, and setting the speed
end

function SampleRollOut:fastEvent(name,info,data) 
	print("Fast event at",info.time) 
	data.modifierInstance:setSpeed(10)
end

function SampleRollOut:shakeEvent(name,info,data) 
	print("Shake event at",info.time,data.bitmapStringInstance) 								-- haven't bothered to implement this but it comes out on the console.
end

function SampleRollOut:pause4Event(name,info,data) 												-- add a pause to the text - 'pause4' pauses for 4 seconds
	print("Pause4 event at",info.time)															-- these have to be registered tin the constructor.
	data.modifierInstance:addPause(4000) 	
end

--- ************************************************************************************************************************************************************************
-- 																				Main program
--- ************************************************************************************************************************************************************************

			
-- add command implementation.
																								-- some working text.
local text = "Lor{pause4}em{shake} ipsum\n{fast}dolor{$crab}sitamet{slow},\nconsectetur{fast}\nadipiscing\nelit. Duis nec\nlobortis massa.\nFusce dictum\naliquam fermen"

local textObject = display.newBitmapText("",160,240,"font2",44) 								-- create a text object, left justify it.
textObject:setJustification(textObject.Justify.LEFT):setVerticalSpacing(0.9)

local eventMod = SampleRollOut:new(fm,RolloutModifier:new()) 	 								-- create the sample roll out modifier instance.
eventMod:setText(textObject,text) 																-- set the text of the text object.

