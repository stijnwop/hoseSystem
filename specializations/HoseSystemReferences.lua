--
-- Created by IntelliJ IDEA.
-- User: stijn
-- Date: 15-4-2017
-- Time: 16:22
-- To change this template use File | Settings | File Templates.
--

HoseSystemReferences = {}
local HoseSystemReferences_mt = Class(HoseSystemReferences)

function HoseSystemReferences:new(object, mt)
    local references = {
        object = object
    }

    setmetatable(references, mt == nil and HoseSystemReferences_mt or mt)

    references.object.vehicleToMountHoseSystem = 0
    references.object.referenceIdToMountHoseSystem = 0
    references.object.referenceIsExtendable = false
    references.object.doNetworkObjectsIteration = false

    if object.isServer then
        references.vehicleToMountHoseSystemSend = nil
        references.referenceIdToMountHoseSystemSend = nil
        references.referenceIsExtendableSend = nil
    end

    return references
end

function HoseSystemReferences:delete()
end

function HoseSystemReferences:readStream(streamId, connection)

end

function HoseSystemReferences:writeStream(streamId, connection)
end

function HoseSystemReferences:update(dt)
    -- iterate over grabPoints to sync the vehicles with all clients
    if self.object.doNetworkObjectsIteration then
        self:iterateNetworkObjects()
    end

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

function HoseSystemReferences:draw()
end

function HoseSystemReferences:loadFillableObjectAndReference(vehicle, referenceId, isExtendable, noEventSend)
    self.object.vehicleToMountHoseSystem = vehicle
    self.object.referenceIdToMountHoseSystem = referenceId
    self.object.referenceIsExtendable = isExtendable

    if self.object.isServer then
        if (self.object.vehicleToMountHoseSystem ~= self.vehicleToMountHoseSystemSend) or (self.object.referenceIdToMountHoseSystem ~= self.referenceIdToMountHoseSystemSend) or (self.object.referenceIsExtendable ~= self.referenceIsExtendableSend) then
            if noEventSend == nil or not noEventSend then
                g_server:broadcastEvent(HoseSystemLoadFillableObjectAndReferenceEvent:new(self.object, self.object.vehicleToMountHoseSystem, self.object.referenceIdToMountHoseSystem, self.object.referenceIsExtendable))
            end

            --            print('vehicleToMountHoseSystem ' .. tostring(self.vehicleToMountHoseSystem))
            --            print('referenceIdToMountHoseSystem ' .. tostring(self.object.referenceIdToMountHoseSystem))
            --            print('referenceIsExtendable ' .. tostring(self.referenceIsExtendable))

            self.vehicleToMountHoseSystemSend = self.object.vehicleToMountHoseSystem
            self.referenceIdToMountHoseSystemSend = self.object.referenceIdToMountHoseSystem
            self.referenceIsExtendableSend = self.object.referenceIsExtendable
        end
    end
end

function HoseSystemReferences:iterateNetworkObjects()
    if self.object.grabPoints ~= nil then
        for index, grabPoint in pairs(self.object.grabPoints) do
            -- Todo: lookup better solution
            if grabPoint.connectorVehicleId ~= nil then
                local vehicle = networkGetObject(grabPoint.connectorVehicleId)

                if vehicle ~= nil then
                    grabPoint.connectorVehicle = vehicle
                    grabPoint.connectorVehicleId = nil

--                    self:syncIsUsed(index, HoseSystem:getIsConnected(grabPoint.attachState), grabPoint.hasExtenableJointIndex, true)
                end
            end
        end
    end

    self.object.queueNetworkObjects = false
end


---
-- @param grabPoint
--
function HoseSystemReferences:searchReferences(grabPoint)
    -- do this per side? This will do for now.
    self:loadFillableObjectAndReference(0, 0, false)

    local x, y, z = getWorldTranslation(grabPoint.node)
    local sequence = 0.6 * 0.6

    if not grabPoint.connectable then
        if g_currentMission.hoseSystemReferences ~= nil and #g_currentMission.hoseSystemReferences > 0 then
            for _, hoseSystemReference in pairs(g_currentMission.hoseSystemReferences) do
                -- Hose references
                if hoseSystemReference ~= nil then
                    for i, reference in pairs(hoseSystemReference.hoseSystemReferences) do
                        if not reference.isUsed then
                            if HoseSystemReferences:getCanConnect(x, y, z, sequence, grabPoint, reference) then
                                -- self.inRangeVehicle = reference.isObject and g_currentMission:getNodeObject(liquidManureHoseReference.nodeId) or liquidManureHoseReference -- getNodeObject does work in MP?
                                -- self.inRangeReference = reference.id
                                -- self.inRangeIsExtendable = false

                                -- self:loadFillableObjectAndReference(reference.isObject and g_currentMission:getNodeObject(liquidManureHoseReference.nodeId) or liquidManureHoseReference, reference.id, false)
                                -- local object = reference.isObject and g_currentMission:getNodeObject(liquidManureHoseReference.nodeId) or liquidManureHoseReference
                                local object = reference.isObject and hoseSystemReference.fillLevelObject or hoseSystemReference
                                self:loadFillableObjectAndReference(networkGetObjectId(object), i, false)
                                break
                            end
                        end
                    end
                end
            end
        end
    else
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

                                    if vehicleDistance < 1.3 then
                                        if HoseSystemReferences:getCanExtend(reference.id > 1, reference.node, grabPoint.node) then
                                            self:loadFillableObjectAndReference(networkGetObjectId(hoseSystemHose), i, reference.connectable)
                                            sequence = dist
                                            -- self.inRangeVehicle = liquidManureHose
                                            -- self.inRangeReference = reference.id
                                            -- self.inRangeIsExtendable = true
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
end

function HoseSystemReferences:getCanExtend(inverse, node1, node2)
    local rot = math.abs(Utils.getYRotationBetweenNodes(node1, node2))

    if inverse then
        return HoseSystem:mathRound(rot, 1) <= 0.6
    end

    return HoseSystem:mathRound(rot, 1) >= 2.3
end

function HoseSystemReferences:getCanConnect(x, y, z, sequence, grabPoint, reference)
    local rx, ry, rz = getWorldTranslation(reference.node)
    local dist = Utils.vector2LengthSq(x - rx, z - rz)

    if dist < sequence then
        if math.abs(y - ry) < 1.3 then
            local cosAngle = HoseSystem:calculateCosAngle(reference.node, grabPoint.node)

            if not reference.parkable then
                if not grabPoint.connectable then
                    if cosAngle > math.rad(-80) and cosAngle < math.rad(80) then -- > -10° < 10° -- > cosAngle > -0.17365 and cosAngle < 0.17365 then -- > -80° < 80°
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
            if math.abs(y - rmy) < 1.3 then
                return true
            end
        end
    end

    return false
end

function HoseSystemReferences:getHasReferenceInRange(object)
    return object.vehicleToMountHoseSystem ~= 0 and object.referenceIdToMountHoseSystem ~= 0
end

function HoseSystemReferences:getReference(object, index, grabPoint)
    -- When we are dealing with map objects change the object to the parent that holds the rigid body node
    if object ~= nil then
        if object.hoseSystemParent ~= nil then
            object = object.hoseSystemParent
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


function HoseSystemReferences:getReferenceVehicle(object)
    if object ~= nil and object.hoseSystemParent ~= nil then
        return object.hoseSystemParent
    end

    return object
end

function HoseSystemReferences:getAllowsDetach(object, index)
    local grabPoint = object.grabPoints[index]

    if grabPoint ~= nil then
        if grabPoint.connectorRefId ~= nil then
            local vehicle = grabPoint.connectorVehicle
            local reference = HoseSystemReferences:getReference(vehicle, grabPoint.connectorRefId, grabPoint)

            if reference ~= nil then
                local flowOpened = reference.flowOpened
                local isLocked = reference.isLocked

                -- when dealing with an object that has no visual handlings allow detach.
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