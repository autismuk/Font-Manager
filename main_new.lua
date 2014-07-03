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

fm.BitmapString:setTintBrackets("@[","@]") 														-- change the tint brackets

bms = fm.BitmapString:new("newTest",240/3):setText("Hello")										-- create a string "Hello"
bms:setText("Hello world\nAgain @[brown@]Padding.\n@[cyan@]Line 3") 							-- set the text
bms:setText("QM")
--bms:setText("Agiy")
bms:moveTo(0,0) 																				-- postion it
bms:setAnchor(0,0)
bms:setJustification(bms.Justify.LEFT) 															-- left justify
bms:show()
--bms.rotation = 10 																			-- rotate
--bms:setFont("font2") 																			-- change font
--bms:setVerticalSpacing(1.2) 																	-- change vertical spacing.
--bms:setSpacing(-4) 																				-- change horizontal spacing
--bms:setModifier("curve"):animate(4) 															-- curve shape and then animate

-- bms.anchorX,bms.anchorY = 0.5,0.5 bms.text = "Yo !" bms:show() 								-- can change things this way

display.newLine(0,240,320,240):setStrokeColor( 1,1,0 )
display.newLine(160,0,160,480):setStrokeColor( 1,1,0 )

--bms:setImageLocation("fred/*.png") 															-- this sets where $images are found.
--bms:setImageLocation() 																		-- back to default

local options = { text = "Hgllo Worly @[$crab@]\nLine 2!",x = 0,y = 350,fontSize = 44,			-- use display.newBitmapText with an options table
										font = "retrofont", align = "right"} 					-- (see display.newText())
--bms2 = display.newBitmapText(options)
--bms2:setAnchor(0,0) 																			-- set the anchor point
-- bms2:setTintColor(1,1,0) 																	-- tint it yellow
--bms2:setSpacing(0):setModifier("wobble"):animate() 												-- clear horizontal spacing, wobble and animate

--bms:addEventListener( "tap", function(e) print("tapped") end) 								-- check add event listener works


-- bms:removeSelf() 																			-- make them go away
-- bms2:removeSelf(true)

-- fm.FontManager:setAnimationFrequency(3) 														-- animation rate (e.g. 3 animations / second)

-- bms2:setModifier(function(modifier,cPos,infoTable) 											-- simple modifier making every 3rd character semi transparent
--	if infoTable.charIndex % 3 == 0 then modifier.alpha = 0.4 end
-- end)

--[[
bms:setModifier(function(modifier,cPos,infoTable) 												-- an early roll out, see main_roll for a much better one.
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

--transition.to(bms,{ x = 160, y = 0, xScale = 1,yScale = 1, time = 1000/1,rotation = 360*3 }) 	-- you can transition them like any other object
--transition.to(bms2,{ yScale = 1.55, time = 1000 })

-- *BUT*
-- if you use it in Composer, and animate, you must stop the animation (bms:stop()) or remove the bitmap (bms:removeSelf()) because if you don't and CoronaClass
-- garbage collects the scene, it won't work properly.