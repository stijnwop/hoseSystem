--
-- Created by IntelliJ IDEA.
-- User: stijn
-- Date: 13-4-2017
-- Time: 18:37
-- To change this template use File | Settings | File Templates.
--

HoseSystemActivatable = {}
local HoseSystemActivatable_mt = Class(TensionBeltsActivatable)

function HoseSystemActivatable:new(object)
    local self = {
        object = object
    }

    setmetatable(self, HoseSystemActivatable_mt)

    return self
end

function HoseSystemActivatable:getIsActivatable()
--    return self.object.isPlayerInTensionBeltRange
end

function HoseSystemActivatable:onActivateObject()
    if self.object.currentBelt ~= nil then
        if self.object.currentBelt.mesh ~= nil then
            self.object:setTensionBeltsActive(false, self.object.currentBelt.id, false)
        else
            self.object:setTensionBeltsActive(true, self.object.currentBelt.id, false)
        end
    end

    self:updateActivateText()

    g_currentMission:addActivatableObject(self)
end

function HoseSystemActivatable:drawActivate()
end

function HoseSystemActivatable:updateActivateText()
end