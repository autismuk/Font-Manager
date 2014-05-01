--- ************************************************************************************************************************************************************************
---
---				Name : 		scenemgr.lua
---				Purpose :	Manage Scene transitions and state
---				Created:	30 April 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

local function convertFontFile(fromFile,toFile,fontFile)
	print("Converting "..fromFile.." to " .. toFile .. " using ".. fontFile) 					-- prompt
	local hIn = io.open(fromFile,"r") 															-- open source and destination files.
	local hOut = io.open(toFile,"w")
	hOut:write("-- generated from "..fromFile.."\nreturn {\n")
	local match = "^char%s+id=(%d+)%s+x=(%d+)%s+y=(%d+)%s+width=(%d+)%s+height=(%d+)%s+xoffset=([%d%-]+)%s+yoffset=([%d%-]+)%s+xadvance=(%d+)"
	for line in hIn:lines() do
		local charCode,x,y,width,height,xoffset,yoffset,xadvance = line:lower():match(match)
		if charCode ~= nil and ((width ~= "0" and height ~= "0") or charCode == "32") then
			local itemDef = ("{x=%s,y=%s,width=%s,height=%s}"):format(x,y,width,height)
			local charDef = ("{code=%s,frame=%s,xOffset=%s,yOffset=%s,width=%s},"):format(charCode,itemDef,xoffset,yoffset,xadvance)
			hOut:write(charDef .. "\n")
		end
	end
	hOut:write(('"%s"\n}\n'):format(fontFile))
	hIn:close()
	hOut:close()
end


for _,parameter in ipairs(arg) do 																-- scan through all command line arguments
	if parameter:match("%.fnt$") ~= nil and parameter:match("%@2x") == nil then 				-- look for .fnt files without @2x in them
		convertFontFile(parameter,parameter:sub(1,-5)..".lua",parameter:sub(1,-5)..".png") 		-- if found, convert the .fnt to a .lua file
	end
end
