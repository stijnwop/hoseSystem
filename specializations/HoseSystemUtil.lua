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
-- @param number
-- @param idp
--
function HoseSystemUtil:mathRound(number, idp)
    local multiplier = 10 ^ (idp or 0)
    return math.floor(number * multiplier + 0.5) / multiplier
end

---
-- @param j1
-- @param j2
--
function HoseSystemUtil:calculateCosAngle(j1, j2)
    local x1, y1, z1 = localDirectionToWorld(j1, 1, 0, 0)
    local x2, y2, z2 = localDirectionToWorld(j2, 1, 0, 0)

    return x1 * x2 + y1 * y2 + z1 * z2
end

---
-- @param cond
-- @param trueValue
-- @param falseValue
--
function HoseSystemUtil:ternary(cond, trueValue, falseValue)
    return cond and trueValue or falseValue
end

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

function HoseSystemUtil:getDependentGrabPoint(grabPoints, id, allowPlayer, allowDetached)
    for _, grabPoint in pairs(grabPoints) do
        if grabPoint.id ~= id then
            if HoseSystem:getIsConnected(grabPoint.state) or allowPlayer and HoseSystem:getIsAttached(grabPoint.state) or allowDetached and HoseSystem:getIsDetached(grabPoint.state) then
                return grabPoint
            end
        end
    end

    return nil
end

function HoseSystemUtil:removeElementFromList(t, element)
    if t ~= nil and #t > 0 then
        for i, e in ipairs(t) do
            if e == element then
                table.remove(t, i)
                break
            end
        end
    end
end

function HoseSystemUtil:getFirstElement(table)
    return table[1]
end

function HoseSystemUtil:getFirstElement(table)
    return table[#table]
end

function HoseSystemUtil:print_r(t, name, indent)
    local tableList = {}

    local table_r = function(t, name, indent, full)
        local id = not full and name or type(name) ~= "number" and tostring(name) or '[' .. name .. ']'
        local tag = indent .. id .. ' : '
        local out = {}

        if type(t) == "table" then
            if tableList[t] ~= nil then
                table.insert(out, tag .. '{} -- ' .. tableList[t] .. ' (self reference)')
            else
                tableList[t] = full and (full .. '.' .. id) or id

                if next(t) then -- If table not empty.. fill it further
                    table.insert(out, tag .. '{')

                    for key, value in pairs(t) do
                        table.insert(out, table_r(value, key, indent .. '|  ', tableList[t]))
                    end

                    table.insert(out, indent .. '}')
                else
                    table.insert(out, tag .. '{}')
                end
            end
        else
            local val = type(t) ~= "number" and type(t) ~= "boolean" and '"' .. tostring(t) .. '"' or tostring(t)
            table.insert(out, tag .. val)
        end

        return table.concat(out, '\n')
    end

    return table_r(t, name or 'Value', indent or '')
end

addConsoleCommand("gsToggleHoseSystemDebugRendering", "Toggles the debug rendering of the HoseSystem", "consoleCommandToggleHoseSystemDebugRendering", HoseSystemUtil)