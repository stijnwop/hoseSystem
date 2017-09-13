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
    REFERENCES_NUM_SEND_BITS = 4 -- Max 2^4
}

---
-- @param node
-- @param actionText
-- @param inputBinding
--
function HoseSystemUtil:renderHelpTextOnNode(node, actionText, inputBinding)
    if node ~= nil then
        local worldX, worldY, worldZ = localToWorld(node, 0, 0.1, 0)
        local x, y, z = project(worldX, worldY, worldZ)

        if x < 0.95 and y < 0.95 and z < 1 and x > 0.05 and y > 0.05 and z > 0 then
            setTextAlignment(RenderText.ALIGN_CENTER)
            setTextColor(1, 1, 1, 1)
            renderText(x, y + 0.01, 0.017, inputBinding)
            renderText(x, y - 0.02, 0.017, actionText)
            setTextAlignment(RenderText.ALIGN_LEFT)
        end
    end
end

---
-- @param vehicle
--
function HoseSystemUtil:addToPhysicsRecursively(vehicle)
    if vehicle ~= nil then
        vehicle:addToPhysics()
        -- Set firstTimeRun to prevent the wheel shape not found warning!
        vehicle.firstTimeRun = false

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
function HoseSystemUtil:createHoseSystemJoint(reference)
    local hoseSystem = HoseSystemUtil:getHoseSystemFromReference(reference)

    if hoseSystem ~= nil then
        -- Get the connected grabPoint on the hose
        local connected = HoseSystem:getConnectedGrabPoints(hoseSystem)

        if #connected > 0 then
            -- We atleast got 1 grabpoint connected
            local grabPoint = HoseSystemUtil:getFirstElement(connected)
            local vehicle = HoseSystemReferences:getReferenceVehicle(grabPoint.connectorVehicle)
            local reference = HoseSystemReferences:getReference(grabPoint.connectorVehicle, grabPoint.connectorRefId, grabPoint)

            hoseSystem.poly.interactiveHandling:createCustomComponentJoint(grabPoint, vehicle, reference)
        end
    end
end

---
-- @param reference
--
function HoseSystemUtil:removeHoseSystemJoint(reference)
    local hoseSystem = HoseSystemUtil:getHoseSystemFromReference(reference)

    if hoseSystem ~= nil then
        hoseSystem.poly.interactiveHandling:deleteCustomComponentJoint()
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
                    local grabPoints = HoseSystem:getDetachedReferenceGrabPoints(reference.hoseSystem, id)

                    if #grabPoints > 0 then
                        table.insert(references, { grabPoint = HoseSystemUtil:getFirstElement(grabPoints), reference = reference, vehicle = object })
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

function HoseSystemUtil:getFirstElement(table)
    return table[1]
end

function HoseSystemUtil:getFirstElement(table)
    return table[#table]
end

addConsoleCommand("gsToggleHoseSystemDebugRendering", "Toggles the debug rendering of the HoseSystem", "consoleCommandToggleHoseSystemDebugRendering", HoseSystemUtil)