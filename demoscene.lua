--- ************************************************************************************************************************************************************************
---
---            Name :      demoscene.lua
---            Purpose :   Simple scene so we can test garbage collection in the library.
---            Created:    15 May 2014
---            Author:     Paul Robson (paul@robsons.org.uk)
---            License:    MIT
---
--- ************************************************************************************************************************************************************************

local composer = require( "composer" )
local scene = composer.newScene()

function scene:create( event )

   local sceneGroup = self.view
   print("Create scene")

   local newText = display.newBitmapText("Scene Text",160,100,"retrofont",64):setModifier("curve"):animate(5)
   sceneGroup:insert(newText:getView())
   _G.scene = self
   _G.sceneText = newText
   _G.owner = sceneGroup
end

-- "scene:show()"
function scene:show( event )

   local sceneGroup = self.view
   local phase = event.phase
   print("Show scene",phase)
end

-- "scene:hide()"
function scene:hide( event )

   local sceneGroup = self.view
   local phase = event.phase
   print("Hide scene,phase")
end

-- "scene:destroy()"
function scene:destroy( event )
   print("Destroy scene")
   local sceneGroup = self.view
end

---------------------------------------------------------------------------------

-- Listener setup
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

---------------------------------------------------------------------------------

return scene