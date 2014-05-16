--- ************************************************************************************************************************************************************************
---
---				Name : 		main.lua
---				Purpose :	Simple demo of the bitmap strings.
---				Created:	30 April 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

display.setStatusBar(display.HiddenStatusBar)

fm = require("system.fontmanager")																-- get an instance of the font manager.
fm.FontManager:setEncoding("utf8") 																-- set expected encoding to UTF-8 (default is Unicode character set.)

local bgr = display.newRect( 0,0,320,480) 														-- blue background
bgr:setFillColor(0,0,1)
bgr.anchorX,bgr.anchorY = 0,0

local msg = "An{brown}other {1,0,1}line\rwit{}h\ra curve" .. string.char(0xC3,0xBE,0x2A) 		-- this is A~ 3/4 in Unicode, and a circle with a vertical line in UTF-8.
																								-- the curly brackets set tinting colours.

local str = fm.BitmapString:new("demofont") 													-- create a string OOP method.
str:moveTo(160,240):setScale(2,2):setFontSize(50) 												-- centre it, double the scale, size 48.
str:setText(msg)																				-- set the text
--str:setDirection(180) 																		-- write it backwards (why did I do this ?)
str:setAnchor(0.5,0) 																			-- anchor top centre,
str:setModifier("iscale")																		-- shape with a curve
str:setVerticalSpacing(0.5):animate(4)															-- animate it - if you comment this out it will curve but not animate
 																								-- the number is a speed scalar.

str:setTintColor(1,1,0) 																		-- apply a tint to it.

str2 = display.newBitmapText("Bye !",0,0,"font2",45) 											-- or we can do it Corona style !  - YAY !!!!
																								-- *BUT* it does not have compatible methods. So you have to use moveTo()
str2:setAnchor(0,0):setScale(-1,1):setDirection(270)											-- and setAnchor() for example, rather than accessing members directly.

local str3 = fm.BitmapString:new("font2",28):													-- a third string, created using the constructor, showing chaining.
								moveTo(160,400):setText("Wobbly text"):setScale(2,2) 			


-- str3:setModifier(fm.Modifiers.WobbleModifier:new(2))											-- a more violent wobble with a new wobble modifier instance
-- str3:setModifier(SimpleCurveModifier:new(0,180,4,2)) 										-- simple curves and scales with a different part of the trigonometrical curve
-- str3:setModifier(SimpleCurveScaleModifier:new(0,180,4,2))
str3:setModifier("wobble") 																		-- or just wobble.
str3:animate() 																					-- make this one animate.

--
--	A sample function type modifier, okay , so I chose 360 because it saves me scaling the rotation :)
--
function pulser(modifier, cPos, info)
	local w = math.floor(info.elapsed/360) % info.length + 1 									-- every 360ms change character, creates a number 1 .. length
	if info.index == w then  																	-- are we scaling this character
		local newScale = 1 + (info.elapsed % 360) / 360 										-- calculate the scale zoom - make it 2- rather than 1+, it goes backwards
		modifier.xScale,modifier.yScale = newScale,newScale 									-- scale it up
		-- modifier.rotation = info.elapsed % 360 												-- this looks ridiculous, but it's interesting
		modifier.tint.red = 0 																	-- so, we set the tinting for that one as well.
	end
end

--
--	Identical but pulses lines, so uses lineIndex and lineCount instead 
--
function linePulser(modifier, cPos, info)
	local w = math.floor(info.elapsed/360) % info.lineCount + 1 
	if info.lineIndex == w then  														
		local newScale = 1 + (info.elapsed % 360) / 360 		
		modifier.xScale,modifier.yScale = newScale,newScale 	
		-- modifier.rotation = info.elapsed % 360 	
		modifier.tint.red = 0
	end
end

--
--	Identical but pulses words, so uses wordIndex and wordCount instead
--
--	tests wordCount because this could be zero, causing divide by zero.
--
function wordPulser(modifier, cPos, info)
	if info.wordCount == 0 then return end 
	local w = math.floor(info.elapsed/360) % info.wordCount + 1 
	if info.wordIndex == w then  														
		local newScale = 1 + (info.elapsed % 360) / 360 		
		modifier.xScale,modifier.yScale = newScale,newScale 	
		-- modifier.rotation = info.elapsed % 360 	
		modifier.tint.red = 0
	end
end

-- str:setModifier(linePulser) 																	-- pick something to run, comment both out, it's a curve/scale
str:setModifier(wordPulser)

local str4 = display.newBitmapText("pulse",160,240,"retrofont",80) 								-- create a new string using Corona method.
str4:setModifier(pulser):animate() 																-- make it use the above modifier, and animate it.

-- str4:setDirection(180) 																		-- backwards
-- str4:setText("Hello\nWorld !") 																-- you can change the text, strings aren't immutable.

local demoTarget = {} 																			-- something to send an event to.
function demoTarget.tap(event) print("tap",event) end

str4:addEventListener( "tap", demoTarget )														-- print 'tap' if you tap it.
-- str4:removeEventListener("tap")

--str4:remove() 																					-- remove kills it. str4 will be an empty object.
--str4:remove()

-- for _,n in pairs(str4) do print("str4",_,n) end

local t = 800 																					-- run over 8 seconds.

-- str:getView().isVisible = false str2:getView().isVisible = false str3:getView().isVisible = false str4:getView().isVisible = false

--
--	Animate using the usual Corona methods.
--
--	Remove the comment, the screen clears at the end, this is a 'tidy everything up' routine.
--
transition.to(str:getView(),{ time = t,rotation = 0, y = 0, xScale = 1, yScale = 1, rotation = 360*2,
	onComplete = function()  
		-- fm.FontManager:clearText() 
	end })

transition.to(str2:getView(), { time = t,x = 300, y = 400, alpha = 0.4,xScale = 0.4,yScale = 0.4 })

transition.to(str3:getView(), { time = t,rotation = 360 })

-- transition.to(str4:getView(), { time = t, xScale = 2,yScale = 2})


--[[
local composer = require( "composer" )
composer.loadScene("demoscene")
print(_G.scene,_G.scene.view,_G.sceneText,getmetatable(_G.sceneText:getView()),_G.sceneText:getView().numChildren,_G.sceneText:getView().isVisible,_G.owner.isVisible,_G.owner.numChildren)
--composer.gotoScene("demoscene")
composer.removeScene("demoscene")
print(_G.scene,_G.scene.view,_G.sceneText,getmetatable(_G.sceneText:getView()),_G.sceneText:getView().numChildren,_G.sceneText:getView().isVisible,_G.owner.isVisible,_G.owner.numChildren)
--]]