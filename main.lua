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


local str = fm.BitmapString:new("retrofont") 													-- create a string using retrofont,32

str:moveTo(160,240):setScale(2,2):setFontSize(48) 												-- centre it, double the scale, size 48.
str:setText("Another demo curve")																-- set the text
str:setModifier("curve")																		-- shape with a curve
str:animate(4)																					-- animate it - if you comment this out it will curve but not animate

local str2 = fm.BitmapString:new("font2",45):setDirection(270):									-- a second string
								setText("Bye!"):setAnchor(0,0):setScale(-1,1)

local str3 = fm.BitmapString:new("demofont",30):												-- a third string
								moveTo(160,400):setText("Another one"):setScale(2,2)

-- str3:setModifier(fm.Modifiers.WobbleModifier:new(2))											-- modifier examples.
-- str3:setModifier(SimpleCurveModifier:new(0,180,4,2))
-- str3:setModifier(SimpleCurveScaleModifier:new(0,180,4,2))
str3:setModifier("wobble")

str3:animate() 																					-- make this one animate.

--
--	A sample function type modifier.
--
function pulser(modifier, cPos, elapsed, index, length)
	local w = math.floor(elapsed/360) % length + 1 												-- every 360ms change character, creates a number 1 .. length
	if index == w then  																		-- are we scaling this character
		modifier.xScale,modifier.yScale = 2,2 													-- yes, double the size
		-- modifier.rotation = elapsed % 360 													-- this looks ridiculous, but it's interesting
	end
end

local str4 = fm.BitmapString:new("retrofont",80):setText("pulse"):moveTo(160,240)				-- create the string 'pulse' to animate
str4:setModifier(pulser):animate() 																-- make it use the above modifier, and animate it.

local t = 8000 																					-- run over 8 seconds.

--
--	Animate using the usual Corona methods.
--
--	Remove the comments, the screen clears at the end.
--
transition.to(str:getView(),{ time = t,rotation = 0, y = 100, xScale = 0.4,yScale = 0.7,onComplete = function() --[[ FontManager:clearText()--]] end })

transition.to(str2:getView(), { time = t,x = 300, y = 400, alpha = 0.4,xScale = 0.4,yScale = 0.4 })

transition.to(str3:getView(), { time = t,rotation = 360 })

transition.to(str4:getView(), { time = t, xScale = 2,yScale = 2})
