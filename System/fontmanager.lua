--- ************************************************************************************************************************************************************************
---
---				Name : 		scenemgr.lua
---				Purpose :	Manage Scene transitions and state
---				Created:	30 April 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

-- Standard OOP (with Constructor parameters added.)
_G.Base =  _G.Base or { new = function(s,...) local o = { } setmetatable(o,s) s.__index = s s:initialise(...) return o end, initialise = function() end }
