--
-- AnimatedObjectExtension
--
-- Authors: Wopster
-- Description: Extends the animated object load function to get the animated object by saveId
--
-- Copyright (c) Wopster, 2017

AnimatedObjectExtension = {}

---
-- @param superFunc
-- @param nodeId
--
function AnimatedObjectExtension:load(superFunc, nodeId)
	if superFunc(self, nodeId) then
		if g_currentMission.animatedObjects == nil then
			g_currentMission.animatedObjects = {}
		end
		
		g_currentMission.animatedObjects[self.saveId] = self
		
		return true
	end

	return false
end

AnimatedObject.load = Utils.overwrittenFunction(AnimatedObject.load, AnimatedObjectExtension.load)