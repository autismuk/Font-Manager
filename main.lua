--- ************************************************************************************************************************************************************************
---
---				Name : 		main.lua
---				Purpose :	Simple demo of the bitmap strings.
---				Created:	30 April 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

-- this is just a stub leading to four other example files. To run it, just comment out all except the ones you want to run.

-- main_original and main_new are two fairly simple demonstrations of it in action
-- main_roll is a 'rolling out text' demo which was a suggestion of Richard9's and also used as a text. It's a demo of using it for RPG type text boxes
-- main_test is an exhaustive test, creating and destroying umpteen strings and tweaking them to see if everything cleans up correctly.

require("main_original")
--require("main_new")
--require("main_roll")
--require("main_test")

-- probably the best way to learn it is to look at main_original and main_new and experiment and see what happens. Change calls, add some new fonts.
-- (GlyphDesigner is excellent but bmglyph works okay too) 

-- It's much easier than it looks, you can almost treat it like display.newText() calls. The 'complex' bit is the modifiers, and you may well not need these.

-- Paul Robson 26/5/2014
