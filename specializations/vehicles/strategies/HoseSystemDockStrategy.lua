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
HoseSystemDockStrategy.DEFORMATION_ROTATION_OFFSET = 0.001
HoseSystemDockStrategy.DEFORMATION_TRANSLATION_MULTIPLIER = 0.01
HoseSystemDockStrategy.DOCK_INRANGE_DISTANCE = 0.25
HoseSystemDockStrategy.DOCK_INRANGE_Y_OFFSET = 0.5
HoseSystemDockStrategy.DOCK_DEFORM_Y_MAX = 0.1 -- maximun amount that the fillArm is allowed to push on the funnel

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

    dockStrategy.dockingArmObject = nil

    if object.isClient then
        dockStrategy.lastMovedReferenceId = nil
    end

    return dockStrategy
end

---
--
function HoseSystemDockStrategy:delete()
    for _, reference in pairs(self.object.dockingSystemReferences) do
        removeTrigger(reference.node)
    end
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
        entry.deformationNodeOrgTrans = { getTranslation(entry.deformationNode) }
        entry.deformationNodeOrgRot = { getRotation(entry.deformationNode) }
        entry.deformationNodeLastTrans = entry.deformationNodeOrgTrans
        entry.deformationNodeLastRot = entry.deformationNodeOrgRot
        entry.deformatioYOffset = Utils.getNoNil(getXMLFloat(xmlFile, key .. '#deformatioYOffset'), HoseSystemDockStrategy.DOCK_INRANGE_Y_OFFSET)
        entry.deformatioYMaxPush = Utils.getNoNil(getXMLFloat(xmlFile, key .. '#deformatioYMaxPush'), HoseSystemDockStrategy.DOCK_DEFORM_Y_MAX)
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

    if self.object.isClient then
        self:deformDockFunnel(inrange, referenceId, dt)
    end

    if not self.object.isServer then
        return
    end

    if inrange then
        self.dockingArmObject:addFillObject(self.object, self.dockingArmObject.pumpMotorFillArmMode)
    elseif self.dockingArmObject ~= nil then
        self.dockingArmObject:removeFillObject(self.object, self.dockingArmObject.pumpMotorFillArmMode)
    end
end

---
-- @param isActive
-- @param referenceId
--
function HoseSystemDockStrategy:deformDockFunnel(isActive, referenceId, dt)
    if isActive then
        local reference = self.object.dockingSystemReferences[referenceId]
        local dockingTrans = { getWorldTranslation(self.dockingArmObject.fillArm.node) }
        local x, y, z = worldToLocal(reference.deformationNode, unpack(dockingTrans))
        local rx, _, rz = getRotation(reference.deformationNode)
        local pushImpact = reference.deformatioYOffset / 2 -- start halfway the offset with pushing
        local speedFactor = (y - pushImpact) * HoseSystemDockStrategy.DEFORMATION_TRANSLATION_MULTIPLIER * dt

        reference.deformationNodeLastTrans[2] = Utils.clamp(reference.deformationNodeLastTrans[2] + speedFactor, reference.deformationNodeOrgTrans[2] - reference.deformatioYMaxPush, reference.deformationNodeOrgTrans[2])
        reference.deformationNodeLastTrans = { reference.deformationNodeOrgTrans[1], reference.deformationNodeLastTrans[2], reference.deformationNodeOrgTrans[3] }

        setTranslation(reference.deformationNode, unpack(reference.deformationNodeLastTrans))

        rx = Utils.clamp(rx + z * 1 - HoseSystemDockStrategy.DEFORMATION_ROTATION_OFFSET, -HoseSystemDockStrategy.DEFORMATION_ROTATION_LIMIT, HoseSystemDockStrategy.DEFORMATION_ROTATION_LIMIT)
        rz = Utils.clamp(rz - x * 1 - HoseSystemDockStrategy.DEFORMATION_ROTATION_OFFSET, -HoseSystemDockStrategy.DEFORMATION_ROTATION_LIMIT, HoseSystemDockStrategy.DEFORMATION_ROTATION_LIMIT)

        reference.deformationNodeLastRot = { rx, reference.deformationNodeOrgRot[2], rz }
        self.lastMovedReferenceId = referenceId

        setRotation(reference.deformationNode, unpack(reference.deformationNodeLastRot))
    else
        local reference = self.object.dockingSystemReferences[self.lastMovedReferenceId]

        if reference ~= nil then
            if reference.deformationNodeLastRot[1] ~= reference.deformationNodeOrgRot[1] or reference.deformationNodeLastRot[3] ~= reference.deformationNodeOrgRot[3] then
                if math.abs(reference.deformationNodeLastRot[1]) < HoseSystemDockStrategy.DEFORMATION_ROTATION_OFFSET and math.abs(reference.deformationNodeLastRot[3]) < HoseSystemDockStrategy.DEFORMATION_ROTATION_OFFSET then
                    reference.deformationNodeLastRot[1] = reference.deformationNodeOrgRot[1]
                    reference.deformationNodeLastRot[3] = reference.deformationNodeOrgRot[3]
                    self.lastMovedReferenceId = nil
                else
                    local speedFactor = (HoseSystemDockStrategy.DEFORMATION_ROTATION_OFFSET * 1000) - (dt * HoseSystemDockStrategy.DEFORMATION_ROTATION_OFFSET) * (2 * math.pi)

                    if reference.deformationNodeLastRot[1] < reference.deformationNodeOrgRot[1] then
                        reference.deformationNodeLastRot[1] = math.min(reference.deformationNodeLastRot[1] * speedFactor, reference.deformationNodeOrgRot[1])
                    else
                        reference.deformationNodeLastRot[1] = math.max(reference.deformationNodeLastRot[1] * speedFactor, reference.deformationNodeOrgRot[1])
                    end

                    if reference.deformationNodeLastRot[3] < reference.deformationNodeOrgRot[3] then
                        reference.deformationNodeLastRot[3] = math.min(reference.deformationNodeLastRot[3] * speedFactor, reference.deformationNodeOrgRot[3])
                    else
                        reference.deformationNodeLastRot[3] = math.max(reference.deformationNodeLastRot[3] * speedFactor, reference.deformationNodeOrgRot[3])
                    end
                end

                setRotation(reference.deformationNode, reference.deformationNodeLastRot[1], reference.deformationNodeLastRot[2], reference.deformationNodeLastRot[3])
            end
        end
    end
end

---
--
function HoseSystemDockStrategy:getDockArmInrange()
    if self.dockingArmObject ~= nil then
        local armTrans = { getWorldTranslation(self.dockingArmObject.fillArm.node) }
        local distanceSequence = HoseSystemDockStrategy.DOCK_INRANGE_DISTANCE

        for referenceId, reference in pairs(self.object.dockingSystemReferences) do
            if reference.deformationNode ~= nil then
                local trans = { getWorldTranslation(reference.deformationNode) }
                local distance = Utils.vector2Length(armTrans[1] - trans[1], armTrans[3] - trans[3])

                distanceSequence = Utils.getNoNil(reference.inRangeDistance, distanceSequence)

                if distance < distanceSequence and armTrans[2] < trans[2] + reference.deformatioYOffset then
                    distanceSequence = distance

                    return true, referenceId
                end
            end
        end
    end

    return false, nil
end

---
-- @param triggerId
-- @param otherActorId
-- @param onEnter
-- @param onLeave
-- @param onStay
-- @param otherShapeId
--
function HoseSystemDockStrategy:triggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    if onEnter or onLeave then
        if otherActorId ~= 0 then
            local object = g_currentMission.nodeToVehicle[otherActorId]

            if object ~= nil and object ~= self.object then
                if object.hasHoseSystemFillArm and HoseSystemUtil.getHasStrategy(HoseSystemDockArmStrategy, object.fillArmStrategies) then
                    if onEnter then
                        self.dockingArmObject = object
                    elseif onLeave then
                        self.dockingArmObject = object
                    end
                end
            end
        end
    end
end