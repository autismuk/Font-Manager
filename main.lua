-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------

display.setStatusBar(display.HiddenStatusBar)

fm = require("system.fontmanager")

--- ************************************************************************************************************************************************************************

-- display.newLine(0,240,320,240):setStrokeColor( 0,1,0 )
-- display.newLine(160,0,160,480):setStrokeColor( 0,1,0 )

local str = fm.BitmapString:new("retrofont")

str:moveTo(160,240):setAnchor(0.5,0.5):setScale(2,2):setDirection(0):setSpacing(0):setFontSize(48)
str:setText("Another demo curve")
str:setModifier("curve"):animate(4)

local str2 = fm.BitmapString:new("font2",45):setDirection(270):setText("Bye!"):setAnchor(0,0):setScale(-1,1)

local str3 = fm.BitmapString:new("demofont",30):moveTo(160,400):setText("Another one"):setScale(2,2)

-- str3:setModifier(fm.Modifiers.WobbleModifier:new(2))
-- str3:setModifier(SimpleCurveModifier:new(0,180,4,2))
-- str3:setModifier(SimpleCurveScaleModifier:new(0,180,4,2))

str3:setModifier("wobble")
str3:animate()

function pulser(modifier, cPos, elapsed, index, length)
	local w = math.floor(elapsed/360) % length + 1
	if index == w then 
		modifier.xScale,modifier.yScale = 2,2
		-- modifier.rotation = elapsed % 360
	end
end

local str4 = fm.BitmapString:new("retrofont",80):setText("pulse"):moveTo(160,240):setModifier(pulser):animate()
local t = 8000

transition.to(str:getView(),{ time = t,rotation = 0, y = 100, xScale = 0.4,yScale = 0.7,onComplete = function() --[[ FontManager:clearText()--]] end })
transition.to(str2:getView(), { time = t,x = 300, y = 400, alpha = 0.4,xScale = 0.4,yScale = 0.4 })
transition.to(str3:getView(), { time = t,rotation = 360 })
transition.to(str4:getView(), { time = t, xScale = 2,yScale = 2})