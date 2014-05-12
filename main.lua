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

local str = fm.BitmapString:new("testfont") 													-- create a string OOP method.


str:moveTo(160,240):setScale(2,2):setFontSize(48) 												-- centre it, double the scale, size 48.
str:setText("Another demo curve")																-- set the text
str:setModifier("iscale")																		-- shape with a curve
--str:animate(4)																					-- animate it - if you comment this out it will curve but not animate

str2 = display.newBitmapText("Bye !",0,0,"font2",45) 											-- or we can do it Corona style !  - YAY !!!!
																								-- *BUT* it does not have compatible methods. So you have to use moveTo()
str2:setAnchor(0,0):setScale(-1,1):setDirection(270)											-- and setAnchor() for example, rather than accessing members directly.

local str3 = fm.BitmapString:new("demofont",30):												-- a third string, created using the constructor.
								moveTo(160,400):setText("Another one"):setScale(2,2)

-- str3:setModifier(fm.Modifiers.WobbleModifier:new(2))											-- modifier examples.
-- str3:setModifier(SimpleCurveModifier:new(0,180,4,2))
-- str3:setModifier(SimpleCurveScaleModifier:new(0,180,4,2))
str3:setModifier("wobble")
str3:animate() 																					-- make this one animate.

--
--	A sample function type modifier, okay , so I chose 360 because it saves me scaling the rotation :)
--
function pulser(modifier, cPos, elapsed, index, length)
	local w = math.floor(elapsed/360) % length + 1 												-- every 360ms change character, creates a number 1 .. length
	if index == w then  																		-- are we scaling this character
		local newScale = 1 + (elapsed % 360) / 360 												-- calculate the scale zoom - make it 2- rather than 1+, it goes backwards
		modifier.xScale,modifier.yScale = newScale,newScale 									-- scale it up
		-- modifier.rotation = elapsed % 360 													-- this looks ridiculous, but it's interesting
	end
end

local str4 = display.newBitmapText("pulse",160,240,"retrofont",80) 								-- create a new string
str4:setModifier(pulser):animate() 																-- make it use the above modifier, and animate it.
-- str4:setDirection(180)

local demoTarget = {}
function demoTarget.tap(event) print("tap",event) end

str4:addEventListener( "tap", demoTarget )														-- print 'tap' if you tap it.
-- str4:removeEventListener("tap")


-- str4:remove()
-- for _,n in pairs(str4) do print(_,n) end


local t = 8000 																					-- run over 8 seconds.

--
--	Animate using the usual Corona methods.
--
--	Remove the comments, the screen clears at the end.
--
transition.to(str:getView(),{ time = t,rotation = 0, y = 100, xScale = 0.35,yScale = 0.35,
	onComplete = function()  
		-- fm.FontManager:clearText() 
	end })

transition.to(str2:getView(), { time = t,x = 300, y = 400, alpha = 0.4,xScale = 0.4,yScale = 0.4 })

transition.to(str3:getView(), { time = t,rotation = 360 })

transition.to(str4:getView(), { time = t, xScale = 2,yScale = 2})

-- TODO: Non horizontal directions not multiline.
-- TODO: Multi line characters.
-- TODO: Process out positioning
-- TODO: Odd characters.
