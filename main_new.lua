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

bms = fm.BitmapString:new("demofont",60)														
bms:setText("Hello world\nAgain.\nLine 3")
bms:moveTo(160,140)
bms.xScale = 1
bms.yScale = 1
--bms.rotation = 10
bms:setFont("font2")
bms:setVerticalSpacing(1.2)
bms:setSpacing(-4)
bms:setModifier("icurve")
-- bms:setText("Hi")
-- bms:setAnchor(0,0)

-- bms.anchorX,bms.anchorY = 0.5,0.5 bms.text = "Yo !" bms:show()

display.newLine(0,240,320,240):setStrokeColor( 1,1,0 )
display.newLine(160,0,160,480):setStrokeColor( 1,1,0 )

bms2 = display.newBitmapText("Hello World !",0,350,"retrofont",55)
bms2:setAnchor(0,0.5)-- :setTintColor(0,1,1)
-- bms2:setModifier("wobble")

-- bms2:setModifier(function(modifier,cPos,infoTable)
-- 	if infoTable.charIndex % 3 == 0 then modifier.tint.red = 0 end
-- end)

-- bms:removeSelf()
-- bms2:removeSelf()

--transition.to(bms,{ x = 140, y = 140, time = 1000,xScale = 0.7, yScale = 0.7,rotation = 360*3 })
--transition.to(bms2,{ xScale = 1.75, time = 1000 })