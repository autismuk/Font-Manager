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

bms = fm.BitmapString:new("demofont",60):setText("Hello")														
bms:setText("Hello world\nAgain Padding.\nLine 3")
bms:moveTo(160,140)
bms.xScale = 0.5
bms.yScale = 0.5
--bms.rotation = 10
bms:setFont("font2")
bms:setVerticalSpacing(1.2)
bms:setSpacing(-4)
bms:setModifier("curve"):animate(4)
--bms:setJustification(bms.Justify.RIGHT)

-- bms.anchorX,bms.anchorY = 0.5,0.5 bms.text = "Yo !" bms:show()

display.newLine(0,240,320,240):setStrokeColor( 1,1,0 )
display.newLine(160,0,160,480):setStrokeColor( 1,1,0 )

bms:setImageLocation("fred/*.png")
--bms:setImageLocation()

bms2 = display.newBitmapText("Hello World {$crab}!",0,350,"retrofont",42)
bms2:setAnchor(0,0.5)
-- bms2:setTintColor(1,1,0)
--bms2:setModifier("wobble"):animate()
--bms2:setDirection(0):setAnchor(0,0):moveTo(160,240):setText("Ln1-a\nLn2")
bms2:setJustification(bms2.Justify.CENTRE)
bms2:setSpacing(0):setModifier("wobble"):animate()


--bms:addEventListener( "tap", function(e) print("tapped") end)

-- for i = 1,1000 do 
--	local newString = "" for j = 1,math.random(5,15) do newString = newString .. string.char(math.random(32,95)) end
--	if i % 2 == 0 then bms:setText(newString) else  bms2:setText(newString) end
-- end

-- bms:removeSelf()
-- bms2:removeSelf(true)

-- fm.FontManager:setAnimationFrequency(3)

-- bms2:setModifier(function(modifier,cPos,infoTable)
--	if infoTable.charIndex % 3 == 0 then modifier.alpha = 0.4 end
-- end)

--[[
bms:setModifier(function(modifier,cPos,infoTable)
	local pos = math.floor(infoTable.elapsed / 2)
	modifier.alpha = 0
	if infoTable.totalIndex < math.floor(pos/100) then
		modifier.alpha = 1
	elseif infoTable.totalIndex == math.floor(pos/100) then
		modifier.alpha = pos % 100 / 100
	end
end)
--]]
-- bms:removeSelf()
-- bms2:removeSelf(true)

transition.to(bms,{ x = 160, y = 120, xScale = 1,yScale = 1, time = 1000,rotation = 360*3 })
transition.to(bms2,{ yScale = 1.55, time = 1000 })