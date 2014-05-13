Font-Manager
============

Bitmap Font Manager for Corona / Lua - provides font management, bitmap string management, animation and special effects.

Allows the use of GlyphDesigner fonts - can be done either using an OOP style - e.g. BitmapString:new(), or using a display.newBitmapText() method which is 
fairly close to display.newText (these strings are multiline)

The main differences are that

(i) assigning x,y,xScale,anchorY etc. won't work. The methods have similar functionality though, anchors, scales, positioning should work the same.

(ii) the value returned vis display.newBitmapText() ISN'T A DISPLAY OBJECT - it's a lua table. You can access its 'display object' using a getView()
method.

So for example, you can write code like:

	local str4 = display.newBitmapText("Hello World !",160,240,"retrofont",40) 

	transition.to(str4:getView(), { time = 1000, xScale = 2,yScale = 2})

notice the str4:getView() ^^

You can also create strings like this.

	local str4 = fm.BitmapString:new("retrofont",40):moveTo(160,240)

... same thing. the display.newBitmapText() is actually a shorthand to this to help people who aren't OOP minded. Which is fine :)

The strings have their own internal scales and direction and position, they also have modifiers so you can tweak the shape and size and rotation of individual
characters, either statically, or they can be animated automatically.

So to curve this string can be as simple as :

	str4:setModifier("curve")

and to animate this curve is actually easier :

	str4:animate()

There are stock animations (run main.lua in the Corona simulator !) and you can also make your own up, and customise the standard ones. The pulse effect 
(see main.lua) is done by this code.

	function pulser(modifier, cPos, info)
		local w = math.floor(info.elapsed/360) % info.length + 1 									-- every 360ms change character, creates a number 1 .. length
		if index == w then  																		-- are we scaling this character
			local newScale = 1 + (info.elapsed % 360) / 360 										-- calculate the scale zoom
			modifier.xScale,modifier.yScale = newScale,newScale 									-- scale it up
		end
	end

and to use this instead, just

	str4:setModifier(pulser)

Using groups with these is not a good idea unless you are careful, as they are managed seperately and tracked individually. 

But you can get rid of them individually, effectively.

	str4:setText("")

will vanish it, though it is still there, and to kill them all :

	fm.FontManager:clearText()

will kill all the objects.

You can chain things if you want and not bother with references

	display.newBitmapText("Hello World !",160,240,"retrofont",40):setModifier("curve"):animate()

will create it, set its modifier and run it until you clear the screen.

You can add an event listener to the view, but there is a method particular to this object

	str4:addEventListener("tap",target)

which will call target.<event> and when you call the clearText() method it will automatically remove it for you.

You can set the font encoding with

	fm.FontManager:setEncoding("utf8")

currently unicode, utf-8 and utf8 are supported. UTF-8 format is only supported as a 2 byte length. If anyone wants this extended please let me know.
	
Note: fm, assumes you've done something like fm = require("fontmanager")

Paul Robson.