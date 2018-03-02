--
-- HoseSystemReferences
--
-- Authors: Wopster
-- Description: Class that handles the reference interaction
--
-- Copyright (c) Wopster, 2017

HoseSystemReferences = {}

HoseSystemReferences.SEQUENCE = 0.6 * 0.6
HoseSystemReferences.VEHICLE_DISTANCE = 1.3

HoseSystemReferences.BLINKING_WARNING_TIME = 50 -- ms

HoseSystemReferences.EXTEND_Y_ROT_OFFSET = 2.3
HoseSystemReferences.EXTEND_Y_ROT_OFFSET_INVERSE = 0.6
HoseSystemReferences.RADIANS_LIMIT = math.rad(80)

local HoseSystemReferences_mt = Class(HoseSystemReferences)

---
-- @param object
-- @param mt
--
function HoseSystemReferences:new(object, mt)
    local references = {
        object = object
    }

    setmetatable(references, mt == nil and HoseSystemReferences_mt or mt)

    references.object.vehicleToMountHoseSystem = 0
    references.object.referenceIdToMountHoseSystem = 0
    references.object.referenceIsExtendable = false

    if object.isServer then
        references.vehicleToMountHoseSystemSend = nil
        references.referenceIdToMountHoseSystemSend = nil
        references.referenceIsExtendableSend = nil
    end

    return references
end

---
--
function HoseSystemReferences:delete()
end

---
-- @param streamId
-- @param connection
--
function HoseSystemReferences:readStream(streamId, connection)
    local vehicleToMountHoseSystem = readNetworkNodeObjectId(streamId)
    local referenceIdToMountHoseSystem = streamReadInt8(streamId)
    local referenceIsExtendable = streamReadBool(streamId)

    self:loadFillableObjectAndReference(vehicleToMountHoseSystem, referenceIdToMountHoseSystem, referenceIsExtendable, true)
end

---
-- @param streamId
-- @param connection
--
function HoseSystemReferences:writeStream(streamId, connection)
    writeNetworkNodeObjectId(streamId, self.object.vehicleToMountHoseSystem)
    streamWriteInt8(streamId, self.object.referenceIdToMountHoseSystem)
    streamWriteBool(streamId, self.object.referenceIsExtendable)
end

---
-- @param dt
--
function HoseSystemReferences:update(dt)
    -- iterate over grabPoints to sync the vehicles with all clients
    self:iterateNetworkObjects()

    if not self.object.isServer then
        return
    end

    if self.object.grabPoints ~= nil then
        for _, grabPoint in pairs(self.object.grabPoints) do
            if grabPoint.isOwned and HoseSystem:getIsAttached(grabPoint.state) then
                self:searchReferences(grabPoint)
            end
        end
    end
end

---
--
function HoseSystemReferences:draw()
end

---
-- @param vehicle
-- @param referenceId
-- @param isExtendable
-- @param noEventSend
--
function HoseSystemReferences:loadFillableObjectAndReference(vehicle, referenceId, isExtendable, noEventSend)
    self.object.vehicleToMountHoseSystem = vehicle
    self.object.referenceIdToMountHoseSystem = referenceId
    self.object.referenceIsExtendable = isExtendable

    if self.object.isServer then
        if (self.object.vehicleToMountHoseSystem ~= self.vehicleToMountHoseSystemSend) or (self.object.referenceIdToMountHoseSystem ~= self.referenceIdToMountHoseSystemSend) or (self.object.referenceIsExtendable ~= self.referenceIsExtendableSend) then
            if noEventSend == nil or not noEventSend then
                g_server:broadcastEvent(HoseSystemLoadFillableObjectAndReferenceEvent:new(self.object, self.object.vehicleToMountHoseSystem, self.object.referenceIdToMountHoseSystem, self.object.referenceIsExtendable))
            end

            self.vehicleToMountHoseSystemSend = self.object.vehicleToMountHoseSystem
            self.referenceIdToMountHoseSystemSend = self.object.referenceIdToMountHoseSystem
            self.referenceIsExtendableSend = self.object.referenceIsExtendable
        end
    end
end

---
--
function HoseSystemReferences:iterateNetworkObjects()
    if self.object.grabPointsToload ~= nil then
        for _, n in pairs(self.object.grabPointsToload) do
            self.object.grabPoints[n.id].connectorVehicle = networkGetObject(n.connectorVehicleId)
        end

        self.object.grabPointsToload = nil
    end
end

---
-- @param grabPoint
--
function HoseSystemReferences:searchReferences(grabPoint)
    local x, y, z = getWorldTranslation(grabPoint.node)
    local sequence = HoseSystemReferences.SEQUENCE
    local reset = true

    if g_currentMission.hoseSystemReferences ~= nil and #g_currentMission.hoseSystemReferences > 0 then
        for _, hoseSystemReference in pairs(g_currentMission.hoseSystemReferences) do
            -- Hose references
            if hoseSystemReference ~= nil then
                for i, reference in pairs(hoseSystemReference.hoseSystemReferences) do
                    if not reference.isUsed then
                        if HoseSystemReferences:getCanConnect(x, y, z, sequence, grabPoint, reference) then
                            local object = reference.isObject and hoseSystemReference.fillLevelObject or hoseSystemReference
                            self:loadFillableObjectAndReference(networkGetObjectId(object), i, false)
                            reset = false
                            break
                        end
                    end
                end
            end
        end
    end

    if grabPoint.connectable then
        if g_currentMission.hoseSystemHoses ~= nil and #g_currentMission.hoseSystemHoses > 0 then
            for _, hoseSystemHose in pairs(g_currentMission.hoseSystemHoses) do
                if hoseSystemHose ~= self and hoseSystemHose.grabPoints ~= nil then
                    for i, reference in pairs(hoseSystemHose.grabPoints) do
                        if grabPoint.connectable or reference.connectable then
                            if HoseSystem:getIsDetached(reference.state) then
                                local rx, ry, rz = getWorldTranslation(reference.node)
                                local dist = Utils.vector2LengthSq(x - rx, z - rz)

                                if dist < sequence then
                                    local vehicleDistance = math.abs(y - ry)

                                    if vehicleDistance < HoseSystemReferences.VEHICLE_DISTANCE then
                                        if HoseSystemReferences:getCanExtend(reference.id > 1, reference.node, grabPoint.node) then
                                            self:loadFillableObjectAndReference(networkGetObjectId(hoseSystemHose), i, reference.connectable or grabPoint.connectable)
                                            sequence = dist
                                            reset = false
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if reset then -- only reset when not in range of something
        self:loadFillableObjectAndReference(0, 0, false)
    end
end

---
-- @param inverse
-- @param node1
-- @param node2
--
function HoseSystemReferences:getCanExtend(inverse, node1, node2)
    local rot = math.abs(Utils.getYRotationBetweenNodes(node1, node2))

    if inverse then
        return HoseSystemUtil:mathRound(rot, 1) <= HoseSystemReferences.EXTEND_Y_ROT_OFFSET_INVERSE
    end

    return HoseSystemUtil:mathRound(rot, 1) >= HoseSystemReferences.EXTEND_Y_ROT_OFFSET
end

---
-- @param x
-- @param y
-- @param z
-- @param sequence
-- @param grabPoint
-- @param reference
--
function HoseSystemReferences:getCanConnect(x, y, z, sequence, grabPoint, reference)
    local rx, ry, rz = getWorldTranslation(reference.node)
    local dist = Utils.vector2LengthSq(x - rx, z - rz)

    if dist < sequence then
        if math.abs(y - ry) < reference.inRangeDistance then
            local cosAngle = HoseSystemUtil:calculateCosAngle(reference.node, grabPoint.node)

            if not reference.parkable then
                if not grabPoint.connectable then
                    if cosAngle > -HoseSystemReferences.RADIANS_LIMIT and cosAngle < HoseSystemReferences.RADIANS_LIMIT then -- > -10° < 10° -- > cosAngle > -0.17365 and cosAngle < 0.17365 then -- > -80° < 80°
                        return true
                    end
                end
            else
                return true
            end
        end
    end

    -- Check if we are in range of the generated park node
    if reference.parkable then
        local rmx, rmy, rmz = getWorldTranslation(reference.maxParkLengthNode)
        local distance = Utils.vector2LengthSq(x - rmx, z - rmz)

        if distance < sequence then
            if math.abs(y - rmy) < reference.inRangeDistance then
                return true
            end
        end
    end

    return false
end

---
-- @param object
--
function HoseSystemReferences:getHasReferenceInRange(object)
    return object.vehicleToMountHoseSystem ~= 0 and object.referenceIdToMountHoseSystem ~= 0
end

---
-- @param object
-- @param index
-- @param grabPoint
--
function HoseSystemReferences:getReference(object, index, grabPoint)
    -- When we are dealing with map objects change the object to the parent that holds the rigid body node
    if object ~= nil then
        if object.hoseSystemParent ~= nil then
            object = object.hoseSystemParent
        end

        if grabPoint.connectable and object.hoseSystemReferences ~= nil and object.hoseSystemReferences[index].parkable then
            return object.hoseSystemReferences[index]
        end

        if not grabPoint.connectable and object.hoseSystemReferences ~= nil then
            return object.hoseSystemReferences[index]
        end

        if grabPoint.connectable and object.grabPoints ~= nil or object.grabPoints ~= nil then
            return object.grabPoints[index]
        end
    end

    return nil
end

---
-- @param object
--
function HoseSystemReferences:getReferenceVehicle(object)
    if object ~= nil and object.hoseSystemParent ~= nil then
        return object.hoseSystemParent
    end

    return object
end

---
-- @param object
-- @param index
--
function HoseSystemReferences:getAllowsDetach(object, index)
    local grabPoint = object.grabPoints[index]

    if grabPoint ~= nil then
        if grabPoint.connectorRefId ~= nil then
            local vehicle = grabPoint.connectorVehicle
            local reference = HoseSystemReferences:getReference(vehicle, grabPoint.connectorRefId, grabPoint)

            if reference ~= nil then
                if not reference.parkable and vehicle.pumpIsStarted then
                    g_currentMission:showBlinkingWarning(g_i18n:getText('pumpMotor_warningTurnOffFirst'), HoseSystemReferences.BLINKING_WARNING_TIME) -- Warn about the pump being on because this is not visual so people tend to act dumb!

                    return false
                end

                local flowOpened = reference.flowOpened
                local isLocked = reference.isLocked

                -- When dealing with an object that has no visual handlings allow detach.
                if reference.isObject then
                    if reference.lockAnimatedObjectSaveId == nil then
                        isLocked = false
                    end

                    if reference.manureFlowAnimatedObjectSaveId == nil then
                        flowOpened = false
                    end
                else
                    if reference.lockAnimationName == nil then
                        isLocked = false
                    end

                    if reference.manureFlowAnimationName == nil then
                        flowOpened = false
                    end
                end

                if flowOpened or isLocked or reference.connectable then
                    return false
                end

                return true
            end
        end
    end

    return false
end