--
-- HoseSystemDockStrategy
--
-- Authors: Wopster
-- Description: Strategy for loading dockings
--
-- Copyright (c) Wopster, 2017


HoseSystemDockStrategy = {}

HoseSystemDockStrategy.TYPE = 'dock'
HoseSystemDockStrategy.DEFORMATION_ROTATION_LIMIT = math.deg(40) -- we have 40° limit on the deformation

local HoseSystemDockStrategy_mt = Class(HoseSystemDockStrategy)

---
-- @param object
-- @param mt
--
function HoseSystemDockStrategy:new(object, mt)
    local dockStrategy = {
        object = object
    }

    setmetatable(dockStrategy, mt == nil and HoseSystemDockStrategy_mt or mt)

    if g_currentMission.dockingSystemReferences == nil then
        g_currentMission.dockingSystemReferences = {}
    end

    table.insert(g_currentMission.dockingSystemReferences, object)

    return dockStrategy
end

---
--
function HoseSystemDockStrategy:delete()
end

---
-- @param type
-- @param xmlFile
-- @param key
-- @param entry
--
function HoseSystemDockStrategy:loadDock(type, xmlFile, key, entry)
    if type ~= HoseSystemConnector.getInitialType(HoseSystemDockStrategy.TYPE) then
        return entry
    end

    entry.deformationNode = Utils.indexToObject(self.object.components, getXMLString(xmlFile, key .. '#deformatioNode'))

    if entry.deformationNode ~= nil then
        entry.deformationNodeOrgTrans = { getRotation(entry.deformationNode) }
        entry.deformationNodeOrgRot = { getRotation(entry.deformationNode) }
    end

    addTrigger(entry.node, 'triggerCallback', self)

    return entry
end

---
-- @param dt
--
function HoseSystemDockStrategy:update(dt)
end

---
-- @param dt
--
function HoseSystemDockStrategy:triggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    if not self.object.isServer then
        return
    end

    if onEnter or onLeave then
        if otherActorId ~= 0 then
            local object = g_currentMission.nodeToVehicle[otherActorId]

            if object ~= nil and object ~= self.object then
                if object.hasHoseSystemFillArm and HoseSystemUtil.getHasStrategy(HoseSystemDockArmStrategy, object.fillArmStrategies) then
                    if onEnter then
                        object:setFillObject(self.object, false)
                    elseif onLeave then
                        object:setFillObject(nil, true)
                    end
                end
            end
        end
    end
end