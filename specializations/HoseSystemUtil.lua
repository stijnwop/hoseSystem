--
-- Created by IntelliJ IDEA.
-- User: Stijn Wopereis
-- Date: 13-4-2017
-- Time: 18:36
-- To change this template use File | Settings | File Templates.
--

HoseSystemUtil = {
    consoleCommandToggleHoseSystemDebugRendering = function(unusedSelf)
        HoseSystem.debugRendering = not HoseSystem.debugRendering

        return "HoseSystemDebugRendering = " .. tostring(HoseSystem.debugRendering)
    end
}

HoseSystemUtil.eventHelper = {
    STATE_CLIENT = 1,
    STATE_SERVER = 2,
    GRABPOINTS_NUM_SEND_BITS = 2, -- Max 2^2
    REFERENCES_NUM_SEND_BITS = 4  -- Max 2^4
}

---
-- @param vehicle
--
function HoseSystemUtil:addToPhysicsRecursively(vehicle)
    if vehicle ~= nil then
        vehicle:addToPhysics()

        HoseSystemUtil:addToPhysicsRecursively(vehicle.attacherVehicle)
    end
end

---
-- @param vehicle
--
function HoseSystemUtil:removeFromPhysicsRecursively(vehicle)
    if vehicle ~= nil then
        vehicle:removeFromPhysics()

        HoseSystemUtil:removeFromPhysicsRecursively(vehicle.attacherVehicle)
    end
end

---
-- @param reference
--
function HoseSystemUtil:addHoseSystemToPhysics(grabPoint, reference)
    local hoseSystem = HoseSystemUtil:getHoseSystemFromReference(reference)

    if hoseSystem ~= nil then
        local vehicle = HoseSystemReferences:getReferenceVehicle(grabPoint.connectorVehicle)
        hoseSystem.poly.interactiveHandling:addToPhysicsParts(grabPoint, {}, vehicle, reference, true)
    end
end

---
-- @param reference
--
function HoseSystemUtil:removeHoseSystemFromPhysics(reference)
    local hoseSystem = HoseSystemUtil:getHoseSystemFromReference(reference)

    if hoseSystem ~= nil then
        hoseSystem:removeFromPhysics()
    end
end

---
-- @param object
-- @param referenceId
--
function HoseSystemUtil:getReferencesWithSingleConnection(object, referenceId)
    local references = {}

    for id, reference in pairs(object.hoseSystemReferences) do
        local continue = true

        if referenceId ~= nil and referenceId == id then
            continue = false
        end

        if continue then
            if reference.isUsed and not reference.parkable then
                if reference.hoseSystem ~= nil and reference.hoseSystem.grabPoints ~= nil then
                    local grabPoints = HoseSystem:getConnectedReferenceGrabPoints(reference.hoseSystem, id)

                    if #grabPoints == 1 then
                        table.insert(references, { grabPoint = grabPoints[1], reference = reference })
                    end
                end
            end
        end
    end

    return references
end

---
-- @param reference
--
function HoseSystemUtil:getHoseSystemFromReference(reference)
    if reference.hoseSystem ~= nil then
        return reference.hoseSystem
    end

    return nil
end

function HoseSystemUtil:getDependentGrabPoint(grabPoints, id, allowPlayer)
    for _, grabPoint in pairs(grabPoints) do
        if grabPoint.id ~= id then
            if HoseSystem:getIsConnected(grabPoint.state) or allowPlayer and HoseSystem:getIsAttached(grabPoint.state) then
                return grabPoint
            end
        end
    end

    return nil
end

addConsoleCommand("gsToggleHoseSystemDebugRendering", "Toggles the debug rendering of the HoseSystem", "consoleCommandToggleHoseSystemDebugRendering", HoseSystemUtil)