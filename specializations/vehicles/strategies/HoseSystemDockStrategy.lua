--
-- HoseSystemDockStrategy
--
-- Authors: Wopster
-- Description: Strategy for loading dockings
--
-- Copyright (c) Wopster, 2017

HoseSystemDockStrategy = {}

HoseSystemDockStrategy.TYPE = 'dock'
HoseSystemDockStrategy.DEFORMATION_ROTATION_LIMIT = math.rad(35) -- we have 35° limit on the deformation
HoseSystemDockStrategy.DEFORMATION_ROTATION_OFFSET = 0.001
HoseSystemDockStrategy.DEFORMATION_TRANSLATION_MULTIPLIER = 0.01
HoseSystemDockStrategy.DEFORMATION_RESET_TIME = 2500 -- ms
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

    if not HoseSystemUtil.getHasListElement(g_currentMission.dockingSystemReferences, object) then
        table.insert(g_currentMission.dockingSystemReferences, object)
    end

    dockStrategy.dockingArmObjects = {}
    dockStrategy.dockingArmObjectsDelayedDelete = {}

    if object.isClient then
        dockStrategy.lastMovedReferenceIds = {}
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
-- @param streamId
-- @param connection
--
function HoseSystemDockStrategy:readStream(streamId, connection)
    if connection:getIsServer() then
        for id = 1, streamReadUInt8(streamId) do
            -- load the object later on first frame
            self.object:setIsDockUsed(id, streamReadBool(streamId), nil, true)

            if streamReadBool(streamId) then
                if self.dockObjectsToload == nil then
                    self.dockObjectsToload = {}
                end

                table.insert(self.dockObjectsToload, { id = id, objectId = readNetworkNodeObjectId(streamId) })
            end
        end
    end
end

---
-- @param streamId
-- @param connection
--
function HoseSystemDockStrategy:writeStream(streamId, connection)
    if not connection:getIsServer() then
        streamWriteUInt8(streamId, #self.object.dockingSystemReferences)

        for id = 1, #self.object.dockingSystemReferences do
            local reference = self.object.dockingSystemReferences[id]

            streamWriteBool(streamId, reference.isUsed)
            streamWriteBool(streamId, reference.dockingArmObject ~= nil)

            if reference.dockingArmObject ~= nil then
                writeNetworkNodeObjectId(streamId, networkGetObjectId(reference.dockingArmObject))
            end
        end
    end
end

---
-- @param xmlFile
-- @param key
-- @param entry
--
function HoseSystemDockStrategy:loadDock(xmlFile, key, entry)
    entry.parkable = Utils.getNoNil(getXMLBool(xmlFile, key .. '#parkable'), false)
    entry.deformationNode = Utils.indexToObject(self.object.components, getXMLString(xmlFile, key .. '#deformatioNode'))
    entry.dockingArmObject = nil

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
    if self.dockObjectsToload ~= nil then
        for _, n in pairs(self.dockObjectsToload) do
            self.object.dockingSystemReferences[n.id].dockingArmObject = networkGetObject(n.objectId)
        end

        self.dockObjectsToload = nil
    end

    if next(self.dockingArmObjects) == nil then
        return
    end

    for _, dockingArmObject in pairs(self.dockingArmObjects) do
        local inrange, referenceId = self:getDockArmInrange(dockingArmObject)

        if self.object.isClient then
            self:deformDockFunnel(dt, inrange, dockingArmObject, referenceId)
        end

        if self.object.isServer and dockingArmObject ~= nil and dockingArmObject ~= self.object and ((referenceId ~= nil and not self.object.dockingSystemReferences[referenceId].parkable) or not inrange) then
            if inrange and not dockingArmObject.fillObjectFound then
                dockingArmObject:addFillObject(self.object, dockingArmObject.pumpMotorDockArmFillMode, false)
                self.object:setIsDockUsed(referenceId, inrange, dockingArmObject)
            elseif not inrange and dockingArmObject.fillObjectFound then
                dockingArmObject:removeFillObject(self.object, dockingArmObject.pumpMotorDockArmFillMode)
            end
        end

        if not inrange and self.dockingArmObjectsDelayedDelete[dockingArmObject] ~= nil and self.dockingArmObjectsDelayedDelete[dockingArmObject] < g_currentMission.time then
            self.dockingArmObjectsDelayedDelete[dockingArmObject] = nil
            HoseSystemUtil:removeElementFromList(self.dockingArmObjects, dockingArmObject)

            if self.object.isClient then -- force last position
                self:deformDockFunnel(dt + 100, false, dockingArmObject)
            end
        end
    end
end

---
-- @param dt
-- @param isActive
-- @param dockingArmObject
-- @param referenceId
--
function HoseSystemDockStrategy:deformDockFunnel(dt, isActive, dockingArmObject, referenceId)
    if isActive then
        local reference = self.object.dockingSystemReferences[referenceId]
        local dockingTrans = { getWorldTranslation(dockingArmObject.fillArm.node) }
        local x, y, z = worldToLocal(reference.deformationNode, unpack(dockingTrans))
        local rx, _, rz = getRotation(reference.deformationNode)
        local pushImpact = reference.deformatioYOffset / 2 -- start halfway the offset with pushing
        local speedFactor = (y - pushImpact) * HoseSystemDockStrategy.DEFORMATION_TRANSLATION_MULTIPLIER * dt

        reference.deformationNodeLastTrans[2] = Utils.clamp(reference.deformationNodeLastTrans[2] + speedFactor, reference.deformationNodeOrgTrans[2] - reference.deformatioYMaxPush, reference.deformationNodeOrgTrans[2])
        reference.deformationNodeLastTrans = { reference.deformationNodeOrgTrans[1], reference.deformationNodeLastTrans[2], reference.deformationNodeOrgTrans[3] }

        setTranslation(reference.deformationNode, unpack(reference.deformationNodeLastTrans))

        rx = Utils.clamp(rx + z * 0.5 - HoseSystemDockStrategy.DEFORMATION_ROTATION_OFFSET, -HoseSystemDockStrategy.DEFORMATION_ROTATION_LIMIT, HoseSystemDockStrategy.DEFORMATION_ROTATION_LIMIT)
        rz = Utils.clamp(rz - x * 0.5 - HoseSystemDockStrategy.DEFORMATION_ROTATION_OFFSET, -HoseSystemDockStrategy.DEFORMATION_ROTATION_LIMIT, HoseSystemDockStrategy.DEFORMATION_ROTATION_LIMIT)
        reference.deformationNodeLastRot = { rx, reference.deformationNodeOrgRot[2], rz }

        setRotation(reference.deformationNode, unpack(reference.deformationNodeLastRot))

        if not self.lastMovedReferenceIds[referenceId] then
            self.lastMovedReferenceIds[referenceId] = true
        end
    else
        for referenceId, wasMoved in pairs(self.lastMovedReferenceIds) do
            if wasMoved then
                local reference = self.object.dockingSystemReferences[referenceId]

                if reference ~= nil then
                    if reference.deformationNodeLastTrans[2] ~= reference.deformationNodeOrgTrans[2] then
                        setTranslation(reference.deformationNode, unpack(reference.deformationNodeOrgTrans))
                    end

                    if reference.deformationNodeLastRot[1] ~= reference.deformationNodeOrgRot[1] or reference.deformationNodeLastRot[3] ~= reference.deformationNodeOrgRot[3] then
                        if math.abs(reference.deformationNodeLastRot[1]) < HoseSystemDockStrategy.DEFORMATION_ROTATION_OFFSET and math.abs(reference.deformationNodeLastRot[3]) < HoseSystemDockStrategy.DEFORMATION_ROTATION_OFFSET then
                            reference.deformationNodeLastRot[1] = reference.deformationNodeOrgRot[1]
                            reference.deformationNodeLastRot[3] = reference.deformationNodeOrgRot[3]

                            if self.lastMovedReferenceIds[referenceId] then
                                self.lastMovedReferenceIds[referenceId] = false
                            end
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

                        setRotation(reference.deformationNode, unpack(reference.deformationNodeLastRot))
                    end
                end
            end
        end
    end
end

---
-- @param dockingArmObject
--
function HoseSystemDockStrategy:getDockArmInrange(dockingArmObject)
    if dockingArmObject ~= nil and entityExists(dockingArmObject.fillArm.node) then
        local armTrans = { getWorldTranslation(dockingArmObject.fillArm.node) }
        local distanceSequence = HoseSystemDockStrategy.DOCK_INRANGE_DISTANCE

        for referenceId, reference in pairs(self.object.dockingSystemReferences) do
            if (not reference.isUsed or reference.dockingArmObject ~= nil and reference.dockingArmObject == dockingArmObject) and reference.deformationNode ~= nil then
                local trans = { getWorldTranslation(reference.deformationNode) }
                local distance = Utils.vector2Length(armTrans[1] - trans[1], armTrans[3] - trans[3])

                distanceSequence = Utils.getNoNil(reference.inRangeDistance, distanceSequence)

                if distance < distanceSequence and armTrans[2] < trans[2] + reference.deformatioYOffset and armTrans[2] > trans[2] - (reference.deformatioYOffset / 2) then
                    distanceSequence = distance

                    return true, referenceId
                else
                    if reference.isUsed and self.object.isServer then
                        self.object:setIsDockUsed(referenceId, false)
                    end
                end
            end
        end
    else
        if self.object.isServer then
            for referenceId, reference in pairs(self.object.dockingSystemReferences) do
                if reference.isUsed and reference.dockingArmObject == dockingArmObject then
                    dockingArmObject:removeFillObject(self.object, dockingArmObject.pumpMotorDockArmFillMode)
                    self.object:setIsDockUsed(referenceId, false)
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
    if (onEnter or onLeave) then
        if otherActorId ~= 0 then
            local object = g_currentMission.nodeToVehicle[otherActorId]

            if object ~= nil then
                if object.hasHoseSystemFillArm and HoseSystemUtil.getHasStrategy(HoseSystemDockArmStrategy, object.fillArmStrategies) then
                    if onEnter then
                        if self.dockingArmObjectsDelayedDelete[object] ~= nil then
                            self.dockingArmObjectsDelayedDelete[object] = nil
                        else
                            table.insert(self.dockingArmObjects, object)
                        end
                    else
                        self.dockingArmObjectsDelayedDelete[object] = g_currentMission.time + HoseSystemDockStrategy.DEFORMATION_RESET_TIME
                    end
                end
            end
        end
    end
end
