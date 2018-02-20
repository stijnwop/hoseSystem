--
-- HoseSystem
--
-- Authors: Wopster
-- Description: Main specilization for the HoseSystem
--
-- Copyright (c) Wopster, 2017

HoseSystem = {
    debugRendering = true,
    logLevel = 3,
    baseDirectory = g_currentModDirectory
}

local srcDirectory = HoseSystem.baseDirectory .. 'specializations'
local eventDirectory = HoseSystem.baseDirectory .. 'specializations/events'

local files = {
    -- Events
    ('%s/%s'):format(eventDirectory, 'HoseSystemGrabEvent'),
    ('%s/%s'):format(eventDirectory, 'HoseSystemDropEvent'),
    ('%s/%s'):format(eventDirectory, 'HoseSystemAttachEvent'),
    ('%s/%s'):format(eventDirectory, 'HoseSystemDetachEvent'),
    ('%s/%s'):format(eventDirectory, 'HoseSystemIsUsedEvent'),
    ('%s/%s'):format(eventDirectory, 'HoseSystemSetOwnerEvent'),
    ('%s/%s'):format(eventDirectory, 'HoseSystemToggleLockEvent'),
    ('%s/%s'):format(eventDirectory, 'HoseSystemLoadFillableObjectAndReferenceEvent'),
    --    ('%s/%s'):format(eventDirectory, 'HoseSystemChainCountEvent'),
    -- Classes
    ('%s/%s'):format(srcDirectory, 'HoseSystemPlayerInteractive'),
    ('%s/%s'):format(srcDirectory, 'HoseSystemPlayerInteractiveHandling'),
    ('%s/%s'):format(srcDirectory, 'HoseSystemPlayerInteractiveRestrictions'),
    ('%s/%s'):format(srcDirectory, 'HoseSystemFillTriggerInteractive'),
    ('%s/%s'):format(srcDirectory, 'HoseSystemReferences'),
}

for _, directory in pairs(files) do
    source(directory .. '.lua')
end

-- The grabPoint states
HoseSystem.STATE_ATTACHED = 0
HoseSystem.STATE_DETACHED = 1
HoseSystem.STATE_CONNECTED = 2
HoseSystem.STATE_PARKED = 3

HoseSystem.MOVED_DISTANCE_THRESHOLD = 0.001

HoseSystem.CCT_COLLISION_MASK = 32 -- 0x00000020 avoid CTT bit mask
HoseSystem.HOSESYSTEM_COLLISION_MASK = 8194

---
-- @param specializations
--
function HoseSystem.prerequisitesPresent(specializations)
    return true
end

---
-- @param savegame
--
function HoseSystem:preLoad(savegame)
    self.loadHoseJoints = HoseSystem.loadHoseJoints
    self.loadGrabPoints = HoseSystem.loadGrabPoints
    self.updateSpline = HoseSystem.updateSpline
    self.toggleLock = HoseSystem.toggleLock
    self.setEmptyEffect = HoseSystem.setEmptyEffect
    self.toggleEmptyingEffect = HoseSystem.toggleEmptyingEffect

    self.loadObjectChangeValuesFromXML = Utils.overwrittenFunction(self.loadObjectChangeValuesFromXML, HoseSystem.loadObjectChangeValuesFromXML)
    self.setObjectChangeValues = Utils.overwrittenFunction(self.setObjectChangeValues, HoseSystem.setObjectChangeValues)
end

---
-- @param savegame
--
function HoseSystem:load(savegame)
    self.jointSpline = {}
    self.grabPoints = {}
    self.nodesToGrabPoints = {}

    self:loadHoseJoints(self.xmlFile, 'vehicle.hoseSystem.jointSpline')
    self:loadGrabPoints(self.xmlFile, 'vehicle.hoseSystem.grabPoints')

    local startTrans = { getWorldTranslation(self.components[1].node) }
    local endTrans = { getWorldTranslation(self.components[self.jointSpline.endComponentId].node) }

    self.data = {
        length = Utils.vector3Length(endTrans[1] - startTrans[1], endTrans[2] - startTrans[2], endTrans[3] - startTrans[3]),
        lastInRangePosition = { 0, 0, 0 },
        rangeRestrictionMessageShown = false,
        centerNode = Utils.indexToObject(self.components, getXMLString(self.xmlFile, 'vehicle.hoseSystem#centerNode'))
    }

    -- For now just set 4kg for every meter.
    self.data.generatedMass = (0.04 * self.data.length) * 100

    self.supportedFillTypes = {}

    local fillTypeCategories = getXMLString(self.xmlFile, 'vehicle.hoseSystem#supportedFillTypeCategories')

    if fillTypeCategories ~= nil then
        local fillTypes = FillUtil.getFillTypeByCategoryName(fillTypeCategories, "Warning: '" .. self.configFileName .. "' has invalid fillTypeCategory '%s'.")

        if fillTypes ~= nil then
            for _, fillType in pairs(fillTypes) do
                self.supportedFillTypes[fillType] = true
            end
        end
    end

    if self.isClient then
        local effects = EffectManager:loadEffect(self.xmlFile, 'vehicle.hoseSystem.effect', self.components, self)

        if effects ~= nil then
            local effect = {
                effects = effects,
                activeIndex = nil,
                isActive = false
            }

            self.hoseEffects = effect
        end
    end

    self.componentRunUpdates = 0
    self.componentNumRunUpdates = 10

    self.polymorphismClasses = {}

    -- in case we need to access it later we setup callbacks here
    self.poly = {
        interactiveHandling = HoseSystemPlayerInteractiveHandling:new(self),
        references = HoseSystemReferences:new(self)
    }

    table.insert(self.polymorphismClasses, self.poly.interactiveHandling)
    table.insert(self.polymorphismClasses, HoseSystemFillTriggerInteractive:new(self))
    table.insert(self.polymorphismClasses, self.poly.references)
    table.insert(self.polymorphismClasses, HoseSystemPlayerInteractiveRestrictions:new(self))
end

---
-- @param xmlFile
-- @param baseString
--
function HoseSystem:loadHoseJoints(xmlFile, baseString)
    local entry = {}
    local rootJointNode = Utils.indexToObject(self.components, getXMLString(xmlFile, ('%s#rootJointNode'):format(baseString)))
    local jointCount = getXMLInt(xmlFile, ('%s#numJoints'):format(baseString))

    entry.hoseJoints = {}

    if rootJointNode ~= nil and jointCount ~= nil then
        for i = 1, jointCount do
            local count = #entry.hoseJoints
            local jointNode = count > 0 and getChildAt(entry.hoseJoints[count].node, 0) or rootJointNode

            if jointNode ~= nil then
                table.insert(entry.hoseJoints, {
                    node = jointNode,
                    parent = getParent(jointNode)
                })
            end
        end
    end

    entry.curveControllerTrans = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, ('%s#curveControllerTrans'):format(baseString)), 3), { 0, 0, 7.5 }) -- set curve "controller" trans relative to grabPoints
    entry.numJoints = #entry.hoseJoints
    entry.endComponentId = #self.components
    entry.lastPosition = { { 0, 0, 0 }, { 0, 0, 0 } }
    entry.firstRunUpdates = 0
    entry.firstNumRunUpdates = Utils.getNoNil(getXMLInt(xmlFile, ('%s#firstNumRunUpdates'):format(baseString)), 7)
    entry.length = getXMLFloat(xmlFile, 'vehicle.size#length')

    if entry.numJoints > 0 then -- we should confirm that 1 or 2 attacherJoints are in place too.
        -- store "hose" in an global table for faster distance check later on
        if g_currentMission.hoseSystemHoses == nil then
            g_currentMission.hoseSystemHoses = {}
        end

        table.insert(g_currentMission.hoseSystemHoses, self)
    end

    self.jointSpline = entry
end

---
-- @param xmlFile
-- @param baseString
--
function HoseSystem:loadGrabPoints(xmlFile, baseString)
    local i = 0

    while true do
        local key = ('%s.grabPoint(%d)'):format(baseString, i)

        if not hasXMLProperty(xmlFile, key) then
            break
        end

        if #self.grabPoints == 2 ^ HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS then
            HoseSystemUtil:log(HoseSystemUtil.ERROR, ('Max number of grabpoints is %s!'):format(2 ^ HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS))
            break
        end

        local node = Utils.indexToObject(self.components, getXMLString(xmlFile, key .. '#node'))

        local rx, ry, rz = Utils.getVectorFromString(getXMLString(xmlFile, key .. '#playerJointRotLimit'))
        local tx, ty, tz = Utils.getVectorFromString(getXMLString(xmlFile, key .. '#playerJointTransLimit'))

        if node ~= nil then
            local entry = {
                id = i + 1, -- Table index
                node = node,
                raycastNode = Utils.indexToObject(self.components, getXMLString(xmlFile, key .. '#raycastNode')),
                nodeOrgTrans = { getRotation(node) },
                nodeOrgRot = { getRotation(node) },
                playerJointRotLimit = { Utils.getNoNil(rx, 0), Utils.getNoNil(ry, 0), Utils.getNoNil(rz, 0) },
                playerJointTransLimit = { Utils.getNoNil(tx, 0), Utils.getNoNil(ty, 0), Utils.getNoNil(tz, 0) },
                jointIndex = 0,
                hasJointIndex = false, -- We don't sync the actual JointIndex it's server sided
                hasExtenableJointIndex = false, -- We don't sync the actual JointIndex it's server sided
                componentIndex = Utils.getNoNil(getXMLInt(xmlFile, key .. '#componentIndex'), 0) + 1,
                componentJointIndex = Utils.getNoNil(getXMLInt(xmlFile, key .. '#componentJointIndex'), 1),
                componentChildNode = Utils.indexToObject(self.components, getXMLString(xmlFile, key .. '#componentChildNode')),
                connectable = Utils.getNoNil(getXMLBool(xmlFile, key .. '#connectable'), false),
                connectableAnimation = nil,
                isLocked = false,
                state = HoseSystem.STATE_DETACHED,
                connectorRefId = 0,
                connectorVehicle = nil,
                currentOwner = nil,
                isOwned = false
            }

            table.insert(self.grabPoints, entry)
            self.nodesToGrabPoints[entry.node] = entry
        else
            HoseSystemUtil:log(HoseSystemUtil.ERROR, 'Invalid grabPoint node, please check your XML!')
            break
        end

        i = i + 1 -- i++
    end
end

---
-- @param savegame
--
function HoseSystem:postLoad(savegame)
    for index, grabPoint in pairs(self.grabPoints) do
        if grabPoint.connectable and grabPoint.connectableAnimation ~= nil then
            self:toggleLock(index, false, true)
        end
    end

    if savegame ~= nil and not savegame.resetVehicles then
        for index, grabPoint in ipairs(self.grabPoints) do
            local key = ('%s.grabPoint(%d)'):format(savegame.key, index - 1)

            if grabPoint.connectable and grabPoint.connectableAnimation ~= nil then
                local lockState = Utils.getNoNil(getXMLBool(savegame.xmlFile, key .. '#lockState'), false)
                self:toggleLock(index, lockState, true)
            end
        end
    end
end

---
--
function HoseSystem:preDelete()
    if self.grabPoints ~= nil then
        for index, grabPoint in pairs(self.grabPoints) do
            if HoseSystem:getIsAttached(grabPoint.state) then
                if grabPoint.isOwned and grabPoint.currentOwner ~= nil then
                    self.poly.interactiveHandling:drop(index, grabPoint.currentOwner, nil, true)
                end
            elseif HoseSystem:getIsConnected(grabPoint.state) then
                if grabPoint.connectorVehicle ~= nil and grabPoint.connectorRefId ~= nil then
                    local reference = HoseSystemReferences:getReference(grabPoint.connectorVehicle, grabPoint.connectorRefId, grabPoint)

                    self.poly.interactiveHandling:detach(index, grabPoint.connectorVehicle, grabPoint.connectorRefId, reference.connectable ~= nil and reference.connectable, true)
                end
            end
        end
    end
end

---
--
function HoseSystem:delete()
    HoseSystemUtil:removeElementFromList(g_currentMission.hoseSystemHoses, self)

    if self.isClient then
        if self.hoseEffects ~= nil and self.hoseEffects.effect ~= nil then
            EffectManager:deleteEffects(self.hoseEffects.effect)
        end
    end

    if self.polymorphismClasses ~= nil and #self.polymorphismClasses > 0 then
        for _, class in pairs(self.polymorphismClasses) do
            if class.delete ~= nil then
                class:delete()
            end
        end

        self.polymorphismClasses = {}
    end
end

---
-- @param streamId
-- @param connection
--
function HoseSystem:writeStream(streamId, connection)
    -- Write server data to clients
    if not connection:getIsServer() then
        streamWriteUInt8(streamId, #self.grabPoints)

        for index = 1, #self.grabPoints do
            local grabPoint = self.grabPoints[index]

            if grabPoint ~= nil then
                streamWriteInt8(streamId, grabPoint.state)
                streamWriteBool(streamId, grabPoint.connectorVehicle ~= nil)
                if grabPoint.connectorVehicle ~= nil then
                    writeNetworkNodeObjectId(streamId, networkGetObjectId(grabPoint.connectorVehicle))
                end

                streamWriteInt8(streamId, grabPoint.connectorRefId)
                streamWriteBool(streamId, grabPoint.isOwned)
                writeNetworkNodeObject(streamId, grabPoint.currentOwner)
                streamWriteBool(streamId, grabPoint.hasJointIndex)
                streamWriteBool(streamId, grabPoint.hasExtenableJointIndex)
            end
        end

        for _, class in pairs(self.polymorphismClasses) do
            if class.writeStream ~= nil then
                class:writeStream(streamId, connection)
            end
        end
    end
end

---
-- @param streamId
-- @param connection
--
function HoseSystem:readStream(streamId, connection)
    if connection:getIsServer() then
        for index = 1, streamReadUInt8(streamId) do
            local grabPoint = self.grabPoints[index]
            if grabPoint ~= nil then
                grabPoint.state = streamReadInt8(streamId)

                if streamReadBool(streamId) then
                    if self.grabPointsToload == nil then
                        self.grabPointsToload = {}
                    end

                    table.insert(self.grabPointsToload, { id = index, connectorVehicleId = readNetworkNodeObjectId(streamId) })
                end

                grabPoint.connectorRefId = streamReadInt8(streamId)

                if HoseSystem:getIsConnected(grabPoint.state) then
                    if grabPoint.connectable then
                        self:toggleLock(true, true) -- close lock
                    end
                end

                local isOwned = streamReadBool(streamId)
                local player = readNetworkNodeObject(streamId)

                self.poly.interactiveHandling:setGrabPointOwner(index, isOwned, player, true)

                grabPoint.hasJointIndex = streamReadBool(streamId)
                grabPoint.hasExtenableJointIndex = streamReadBool(streamId)

                self.poly.interactiveHandling:setGrabPointIsUsed(index, HoseSystem:getIsConnected(grabPoint.state), grabPoint.hasExtenableJointIndex, false, true)
            end
        end

        for _, class in pairs(self.polymorphismClasses) do
            if class.readStream ~= nil then
                class:readStream(streamId, connection)
            end
        end
    end
end

---
-- @param nodeIdent
--
function HoseSystem:getSaveAttributesAndNodes(nodeIdent)
    local nodes = ""

    if self.grabPoints ~= nil then
        for index, grabPoint in pairs(self.grabPoints) do
            if index > 1 then
                nodes = nodes .. "\n"
            end

            local string = ('<grabPoint id="%s" lockState="%s"'):format(index, grabPoint.isLocked)

            if HoseSystem:getIsConnected(grabPoint.state) then
                if grabPoint.connectorVehicle ~= nil and grabPoint.connectorRefId ~= nil then
                    local vehicleId = 0
                    local reference = HoseSystemReferences:getReference(grabPoint.connectorVehicle, grabPoint.connectorRefId, grabPoint)

                    for i, vehicle in pairs(g_currentMission.hoseSystemReferences) do
                        if vehicle == grabPoint.connectorVehicle then
                            vehicleId = i
                            break
                        end
                    end

                    if not reference.connectable then -- check if we don't have an extendable hose on the reference
                        string = string .. (' connectorVehicleId="%s" referenceId="%s" extenable="%s"'):format(vehicleId, grabPoint.connectorRefId, tostring(grabPoint.connectable))
                    end

                    if reference.parkable then -- We are saving a parked hose.. we don't need to save the other references.
                        nodes = nodes .. nodeIdent .. string .. " />"
                        break
                    end
                end
            end

            nodes = nodes .. nodeIdent .. string .. " />"
        end
    end

    return nil, nodes
end

---
-- @param posX
-- @param posY
-- @param isDown
-- @param isUp
-- @param button
--
function HoseSystem:mouseEvent(posX, posY, isDown, isUp, button)
end

---
-- @param unicode
-- @param sym
-- @param modifier
-- @param isDown
--
function HoseSystem:keyEvent(unicode, sym, modifier, isDown)
end

---
-- @param dt
--
function HoseSystem:update(dt)
    if self.polymorphismClasses ~= nil and #self.polymorphismClasses > 0 then
        for _, class in pairs(self.polymorphismClasses) do
            if class.update ~= nil then
                class:update(dt)
            end
        end
    end

    if self.isClient then
        if self.jointSpline.firstRunUpdates < self.jointSpline.firstNumRunUpdates then
            self.jointSpline.firstRunUpdates = self.jointSpline.firstRunUpdates + 1
            self:updateSpline(true) -- force firstNumRunUpdates frame updates to give hose time to move.
        else
            self:updateSpline(false)
        end
    end
end

---
-- @param dt
--
function HoseSystem:updateTick(dt)
    if self.isServer and self.forceCompontentUpdate then
        if self.componentRunUpdates < self.componentNumRunUpdates then
            self.componentRunUpdates = self.componentRunUpdates + 1
            self:raiseDirtyFlags(self.vehicleDirtyFlag)
        else
            self.componentRunUpdates = 0
            self.forceCompontentUpdate = not self.forceCompontentUpdate
        end
    end

    if self.isClient then
        self:setEmptyEffect(self.hoseEffects.isActive, dt)
    end
end

---
--
function HoseSystem:draw()
end

---
-- @param force
--
function HoseSystem:updateSpline(force)
    local js = self.jointSpline

    -- controllers
    local p0 = { localToWorld(self.components[1].node, -js.curveControllerTrans[1], -js.curveControllerTrans[2], -js.curveControllerTrans[3]) } -- controller 1
    local p1 = { getWorldTranslation(self.components[1].node) } -- start
    local p2 = { getWorldTranslation(self.components[js.endComponentId].node) } -- end
    local p3 = { localToWorld(self.components[js.endComponentId].node, js.curveControllerTrans[1], js.curveControllerTrans[2], js.curveControllerTrans[3]) } -- controller 2

    local movedDistance1 = Utils.vector3Length(p1[1] - js.lastPosition[1][1], p1[2] - js.lastPosition[1][2], p1[3] - js.lastPosition[1][3])
    local movedDistance2 = Utils.vector3Length(p2[1] - js.lastPosition[2][1], p2[2] - js.lastPosition[2][2], p2[3] - js.lastPosition[2][3])

    if movedDistance1 > HoseSystem.MOVED_DISTANCE_THRESHOLD or movedDistance2 > HoseSystem.MOVED_DISTANCE_THRESHOLD or force then
        js.lastPosition[1] = p1
        js.lastPosition[2] = p2

        for i = 1, js.numJoints do
            if i <= js.numJoints then
                local t = (i - 1) / (js.numJoints - 1)
                local x = HoseSystem:catmullRomSpline(t, p0[1], p1[1], p2[1], p3[1])
                local y = HoseSystem:catmullRomSpline(t, p0[2], p1[2], p2[2], p3[2])
                local z = HoseSystem:catmullRomSpline(t, p0[3], p1[3], p2[3], p3[3])
                local trans = { worldToLocal(js.hoseJoints[i].parent, x, y, z) }

                setTranslation(js.hoseJoints[i].node, unpack(trans))

                local target = i < js.numJoints and { getWorldTranslation(js.hoseJoints[i + 1].node) } or { localToWorld(self.components[js.endComponentId].node, 0, 0, 1) } -- if true -> target is 1 "trans" in Z axis infront of component.

                if target ~= nil then
                    local base = { getWorldTranslation(js.hoseJoints[i].node) }
                    local direction = { target[1] - base[1], target[2] - base[2], target[3] - base[3] }

                    if (direction[1] ~= 0 or direction[2] ~= 0 or direction[3] ~= 0) then
                        local upVector = { localDirectionToWorld(js.hoseJoints[i].parent, 0, 1, 0) }
                        Utils.setWorldDirection(js.hoseJoints[i].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])
                    end
                end
            end
        end
    end

    if HoseSystem.debugRendering then
        -- debug curve line
        local tableNum = 150 -- more = closer between dots

        for i = 1, tableNum do
            local t = (i - 1) / tableNum
            local x = HoseSystem:catmullRomSpline(t, p0[1], p1[1], p2[1], p3[1])
            local y = HoseSystem:catmullRomSpline(t, p0[2], p1[2], p2[2], p3[2])
            local z = HoseSystem:catmullRomSpline(t, p0[3], p1[3], p2[3], p3[3])

            drawDebugPoint(x, y, z, 0, 1, 1, 1)
        end

        -- draw line to target joint, to show what angle we have.
        for i = 1, js.numJoints do
            local distance = js.length / js.numJoints
            local dot = { localToWorld(js.hoseJoints[i].node, 0, 0, distance) }
            local dot2 = { localToWorld(js.hoseJoints[i].node, 0, 0, 0) }
            drawDebugLine(dot[1], dot[2], dot[3], 1, 0, 0, dot2[1], dot2[2], dot2[3], 0, 1, 0)
            drawDebugPoint(dot[1], dot[2], dot[3], 1, 0, 0, 1)
            drawDebugPoint(dot2[1], dot2[2], dot2[3], 0, 1, 0, 1)
        end
    end
end

---
-- @param t
-- @param p0
-- @param p1
-- @param p2
-- @param p3
--
function HoseSystem:catmullRomSpline(t, p0, p1, p2, p3)
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t ^ 2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t ^ 3)
end

---
-- @param state
-- @return bool
--
function HoseSystem:getIsDetached(state)
    return state == HoseSystem.STATE_DETACHED
end

---
-- @param state
-- @return bool
--
function HoseSystem:getIsAttached(state)
    return state == HoseSystem.STATE_ATTACHED
end

---
-- @param state
-- @return bool
--
function HoseSystem:getIsParked(state)
    return state == HoseSystem.STATE_PARKED
end

---
-- @param state
-- @return bool
--
function HoseSystem:getIsConnected(state)
    return state == HoseSystem.STATE_CONNECTED
end

---
-- @param object
-- @return int
--
function HoseSystem:getConnectedGrabPointsAmount(object)
    local count = 0

    for index, grabPoint in pairs(object.grabPoints) do
        if HoseSystem:getIsConnected(grabPoint.state) then
            count = count + 1
        end
    end

    return count
end

---
-- @param object
-- @return table
--
function HoseSystem:getConnectedGrabPoints(object)
    local grabPoints = {}

    for index, grabPoint in pairs(object.grabPoints) do
        if HoseSystem:getIsConnected(grabPoint.state) then
            table.insert(grabPoints, grabPoint)
        end
    end

    return grabPoints
end

---
-- @param object
-- @param referenceId
-- @return table
--
function HoseSystem:getDetachedReferenceGrabPoints(object, referenceId)
    local grabPoints = {}

    for index, grabPoint in pairs(object.grabPoints) do
        if HoseSystem:getIsDetached(grabPoint.state) then --and grabPoint.connectorRefId ~= referenceId then
            table.insert(grabPoints, grabPoint)
        end
    end

    return grabPoints
end

---
-- @param index
-- @param shouldLock
-- @param noEventSend
--
function HoseSystem:toggleLock(index, shouldLock, noEventSend)
    if self.grabPoints ~= nil then
        local grabPoint = self.grabPoints[index]

        if grabPoint ~= nil and grabPoint.connectableAnimation ~= nil then
            grabPoint.isLocked = not grabPoint.isLocked
            self:playAnimation(grabPoint.connectableAnimation, shouldLock and -1 or 1, nil, true)
        end

        HoseSystemToggleLockEvent.sendEvent(self, index, shouldLock, noEventSend)
    end
end

---
-- @param activate
-- @param yDirectionSpeed
-- @param index
-- @param fillType
--
function HoseSystem:toggleEmptyingEffect(activate, yDirectionSpeed, index, fillType)
    if self.hoseEffects ~= nil and self.hoseEffects.isActive ~= activate then
        self.hoseEffects.isActive = activate

        if activate then
            EffectManager:setFillType(self.hoseEffects.effects, fillType)
            self.hoseEffects.activeIndex = index

            if self.hoseEffects.effects ~= nil then
                local grabPoint = self.grabPoints[index]

                if grabPoint ~= nil then
                    local trans = { getWorldTranslation(self.components[grabPoint.componentIndex].node) }

                    for _, effect in pairs(self.hoseEffects.effects) do
                        local x, _, z = getRotation(effect.node)
                        local y = grabPoint.id == 1 and math.rad(0) or math.rad(180)

                        setWorldTranslation(effect.node, unpack(trans))
                        setRotation(effect.node, x, y, z)
                    end
                end
            end
        end
    end
end

---
-- @param activate
-- @param dt
--
function HoseSystem:setEmptyEffect(activate, dt)
    if self.hoseEffects ~= nil and self.hoseEffects.effects ~= nil then
        if activate then
            EffectManager:startEffects(self.hoseEffects.effects)

            -- Set the direction of the effect always in toward the dection node
            if self.hoseEffects.effects ~= nil then
                local grabPoint = self.grabPoints[self.hoseEffects.activeIndex]
                local trans = { getWorldTranslation(self.components[grabPoint.componentIndex].node) }
                local rot = { getRotation(grabPoint.node) }

                rot[2] = grabPoint.id == 1 and math.rad(0) or math.rad(180)

                for _, effect in pairs(self.hoseEffects.effects) do
                    setWorldTranslation(effect.node, unpack(trans))
                    setRotation(effect.node, unpack(rot))
                end
            end
        else
            EffectManager:stopEffects(self.hoseEffects.effects)
        end
    end
end

---
-- @param superFunc
-- @param xmlFile
-- @param key
-- @param node
-- @param object
--
function HoseSystem:loadObjectChangeValuesFromXML(superFunc, xmlFile, key, node, object)
    if self.nodesToGrabPoints ~= nil and self.nodesToGrabPoints[node] ~= nil then
        local grabPoint = self.nodesToGrabPoints[node]

        grabPoint.connectableActive = Utils.getNoNil(getXMLBool(xmlFile, key .. '#connectableActive'), false)
        grabPoint.connectableInactive = Utils.getNoNil(getXMLBool(xmlFile, key .. '#connectableInactive'), false)
        grabPoint.connectableAnimation = Utils.getNoNil(getXMLString(xmlFile, key .. '#connectableAnimation'), nil)
    end
end

---
-- @param superFunc
-- @param object
-- @param isActive
--
function HoseSystem:setObjectChangeValues(superFunc, object, isActive)
    if self.nodesToGrabPoints ~= nil and self.nodesToGrabPoints[object.node] ~= nil then
        local grabPoint = self.nodesToGrabPoints[object.node]

        if isActive then
            grabPoint.connectable = grabPoint.connectableActive
        else
            grabPoint.connectable = grabPoint.connectableInactive
        end
    end
end