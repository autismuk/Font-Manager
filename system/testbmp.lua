--
--			This is a testing bed to cheque the Bitmap font methods are working correctly,
--
--			e.g. there is no usage of anything but the BitmapFont methods
--

fm = require("system.fontmanager")

local fontSize = 20
local scale = 2.4
local zscale = 3
local letters = {}
local font = fm.BitmapFont:new("demofont")

local rframe = display.newRect(64,320,20,20)
rframe.strokeWidth = 1 rframe:setFillColor( 0,0,0,0 )
rframe.anchorX,rframe.anchorY = 0,0
local text = "Hello, worldy !"
for i = 1,#text do
	local c = text:sub(i,i):byte(1)
	letters[i] = font:getCharacter(c)
end

local frame = 0

function repaint()
	local x = 64
	for i = 1,#text do
		local xs = 1
		if i == 2 or i == 8 then xs = zscale end
		if i == 8 then xs = 1 / xs end
		yy = math.sin(i/2) * 10
		rot = frame * i
		if i == 9 then rot = - rot end
		x = x + font:moveScaleCharacter(letters[i],fontSize,x,320,scale,scale,xs,xs,0,yy,rot)
	end
	return x -64
end


Runtime:addEventListener( "enterFrame", function(e) 
	frame = frame + 1
	local p = math.floor(frame) % 40
	if p > 20 then p = 40-p end
	zscale = 0.1 + p/5
	w = repaint()
	rframe.width = w
	rframe.height = font:getCharacterHeight(32,fontSize,scale)
end)
