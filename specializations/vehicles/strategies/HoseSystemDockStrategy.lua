--
-- HoseSystemDockStrategy
--
-- Authors: Wopster
-- Description: Strategy for loading dockings
--
-- Copyright (c) Wopster, 2017


HoseSystemDockStrategy = {}

HoseSystemDockStrategy.TYPE = 'dock'
HoseSystemDockStrategy.DEFORMATION_ROTATION_LIMIT = math.rad(40) -- we have 40° limit on the deformation
HoseSystemDockStrategy.DOCK_INRANGE_DISTANCE = 0.5

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

    dockStrategy.dockingArm = nil

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
function HoseSystemDockStrategy:loadDock(xmlFile, key, entry)
    entry.deformationNode = Utils.indexToObject(self.object.components, getXMLString(xmlFile, key .. '#deformatioNode'))

    if entry.deformationNode ~= nil then
        entry.deformationNodeOrgTrans = { getRotation(entry.deformationNode) }
        entry.deformationNodeOrgRot = { getRotation(entry.deformationNode) }
    end

    addTrigger(entry.node, 'triggerCallback', self)

    table.insert(self.object.dockingSystemReferences, entry)

    return entry
end

---
-- @param dt
--
function HoseSystemDockStrategy:update(dt)
    local inrange, referenceId = self:getDockArmInrange()

    if inrange then
    end
end

function HoseSystemDockStrategy:getDockArmInrange()
    if self.dockingArm ~= nil then
        local armTrans = { getWorldTranslation(self.dockingArm.node) }
        local distanceSequence = HoseSystemDockStrategy.DOCK_INRANGE_DISTANCE

        for referenceId, reference in pairs(self.object.dockingSystemReferences) do
            if reference.deformationNode ~= nil then
                local trans = { getWorldTranslation(reference.deformationNode) }
                local distance = Utils.vector3Length(trans[1] - armTrans[1], trans[2] - armTrans[2], trans[3] - armTrans[3])

                distanceSequence = Utils.getNoNil(reference.inRangeDistance, distanceSequence)

                if distance < distanceSequence then
                    distanceSequence = distance

                    return true, referenceId
                end
            end
        end
    end

    return false, nil
end

---
-- @param dt
--
function HoseSystemDockStrategy:triggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    if onEnter or onLeave then
        if otherActorId ~= 0 then
            local object = g_currentMission.nodeToVehicle[otherActorId]

            if object ~= nil and object ~= self.object then
                if object.hasHoseSystemFillArm and HoseSystemUtil.getHasStrategy(HoseSystemDockArmStrategy, object.fillArmStrategies) then
                    if onEnter then
                        self.dockingArm = object.fillArm
                        object:addFillObject(self.object, object.pumpMotorFillArmMode)
                    elseif onLeave then
                        self.dockingArm = object.fillArm
                        object:removeFillObject(self.object, object.pumpMotorFillArmMode)
                    end
                end
            end
        end
    end
end