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

bms = fm.BitmapString:new("demofont",100)														
bms:setText("Hello world\nAgain.\nLine 3")
bms:moveTo(160,240)
bms.xScale = 0.5
bms.yScale = 0.5
bms.rotation = 10
bms:setFont("font2")
bms:setVerticalSpacing(1.2)
bms:setSpacing(-14)
-- bms:setText("Hi")
display.newLine(0,240,320,240):setStrokeColor( 1,1,0 )
display.newLine(160,0,160,480):setStrokeColor( 1,1,0 )

bms2 = display.newBitmapText("Hello",0,350,"retrofont",82)
y = 0
display.newLine(0,y,320,y)

-- bms:removeSelf()
-- bms2:removeSelf()

transition.to(bms,{ x = 0, y = 0, time = 1000,xScale = 1, yScale = 1,rotation = 360*3 })
-- transition.to(bms2,{ xScale = 1.75, time = 1000 })