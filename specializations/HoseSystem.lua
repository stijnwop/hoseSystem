--
-- Created by IntelliJ IDEA.
-- User: Stijn Wopereis
-- Date: 13-4-2017
-- Time: 18:36
-- To change this template use File | Settings | File Templates.
--

HoseSystem = {
    debugRendering = true,
    modDir = g_currentModDirectory
}

local srcDirectory = HoseSystem.modDir .. 'specializations'
local eventDirectory = HoseSystem.modDir .. 'specializations/events'

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

HoseSystem.STATE_ATTACHED = 0
HoseSystem.STATE_DETACHED = 1
HoseSystem.STATE_CONNECTED = 2
HoseSystem.STATE_PARKED = 3

HoseSystem.cctCollisionMask = 32 -- 110010 avoid CTT bit mask
HoseSystem.hoseCollisionMask = 8194

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

    --    print(HoseSystem:print_r(self.grabPoints))

    local startTrans = { getWorldTranslation(self.components[1].node) }
    local endTrans = { getWorldTranslation(self.components[self.jointSpline.endComponentId].node) }

    self.data = {
        length = Utils.vector3Length(endTrans[1] - startTrans[1], endTrans[2] - startTrans[2], endTrans[3] - startTrans[3]),
        lastInRangePosition = { 0, 0, 0 },
        rangeRestrictionMessageShown = false,
        centerNode = Utils.indexToObject(self.components, getXMLString(self.xmlFile, 'vehicle.hoseSystem#centerNode'))
    }

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
                isActive = false
            }

            self.hoseEffects = effect
        end
    end

    self.componentRunUpdates = 0
    self.componentNumRunUpdates = 5

    self.polymorphismClasses = {}

    -- in case we need to access it later we setup callbacks here
    self.poly = {
        interactiveHandling = HoseSystemPlayerInteractiveHandling:new(self),
        interactiveFillTrigger = HoseSystemFillTriggerInteractive:new(self),
        references = HoseSystemReferences:new(self)
    }

    table.insert(self.polymorphismClasses, self.poly.interactiveHandling)
    table.insert(self.polymorphismClasses, self.poly.interactiveFillTrigger)
    table.insert(self.polymorphismClasses, self.poly.references)
    table.insert(self.polymorphismClasses, HoseSystemPlayerInteractiveRestrictions:new(self))
end

function HoseSystem:loadHoseJoints(xmlFile, baseString)
    local entry = {}
    local rootJointNode = Utils.indexToObject(self.components, getXMLString(xmlFile, ('%s#rootJointNode'):format(baseString)))
    local jointCount = getXMLInt(xmlFile, ('%s#numJoints'):format(baseString))

    entry.hoseJoints = {}

    if rootJointNode ~= nil and jointCount ~= nil then
        for i = 1, jointCount do
            local count = table.getn(entry.hoseJoints)
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

function HoseSystem:loadGrabPoints(xmlFile, baseString)
    local i = 0

    while true do
        local key = ('%s.grabPoint(%d)'):format(baseString, i)

        if not hasXMLProperty(xmlFile, key) then
            break
        end

        if #self.grabPoints == 2 ^ HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS then
            print(('HoseSystem warning - Max number of grabpoints is %s!'):format(2 ^ HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS))
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
                centerJointIndex = 0,
                hasJointIndex = false, -- We don't sync the actual JointIndex it's server sided
                hasExtenableJointIndex = false, -- We don't sync the actual JointIndex it's server sided
                componentIndex = Utils.getNoNil(getXMLInt(xmlFile, key .. '#componentIndex'), 0) + 1,
                componentJointIndex = Utils.getNoNil(getXMLInt(xmlFile, key .. '#componentJointIndex'), 1),
                componentChildNode = Utils.indexToObject(self.components, getXMLString(xmlFile, key .. '#componentChildNode')),
                connectable = Utils.getNoNil(getXMLBool(xmlFile, key .. '#connectable'), false),
                connectableAnimation = nil,
                isLocked = false,
                state = HoseSystem.STATE_DETACHED,
                connectorRef = nil,
                connectorRefId = 0,
                connectorVehicle = nil,
                connectorVehicleId = nil,
                currentOwner = nil,
                isOwned = false
            }

            table.insert(self.grabPoints, entry)
            self.nodesToGrabPoints[entry.node] = entry
        else
            print('HoseSystem error - Invalid grabPoint node, please check your XML!')
            break
        end

        i = i + 1 -- i++
    end
end

function HoseSystem:postLoad(savegame)
    for index, grabPoint in pairs(self.grabPoints) do
        if grabPoint.connectable and grabPoint.connectableAnimation ~= nil then
            self:toggleLock(index, false)
        end
    end

    if savegame ~= nil and not savegame.resetVehicles then
        for index, grabPoint in pairs(self.grabPoints) do
            local key = ('%s.grabPoint(%d)'):format(savegame.key, index - 1)

            if grabPoint.connectable and grabPoint.connectableAnimation ~= nil then
                local lockState = Utils.getNoNil(getXMLBool(savegame.xmlFile, key .. '#lockState'), false)
                self:toggleLock(index, lockState)
            end
        end
    end
end

function HoseSystem:preDelete()
    if self.isServer then
        if self.grabPoints ~= nil then
            for index, grabPoint in pairs(self.grabPoints) do
                if HoseSystem:getIsAttached(grabPoint.state) then
                    if grabPoint.isOwned and grabPoint.currentOwner ~= nil then
                        self.poly.interactiveHandling:drop(index, grabPoint.currentOwner, true)
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
end

function HoseSystem:delete()
    if g_currentMission.hoseSystemHoses ~= nil then
        for index = 1, #g_currentMission.hoseSystemHoses do
            if g_currentMission.hoseSystemHoses[index] == self then
                table.remove(g_currentMission.hoseSystemHoses, index)
                break
            end
        end
    end

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
    end
end

function HoseSystem:writeStream(streamId, connection)
    streamWriteInt8(streamId, #self.grabPoints)

    for index = 1, #self.grabPoints do
        local grabPoint = self.grabPoints[index]

        if grabPoint ~= nil then
            streamWriteInt8(streamId, grabPoint.state)
            writeNetworkNodeObjectId(streamId, networkGetObjectId(grabPoint.connectorVehicle))
            streamWriteInt32(streamId, grabPoint.connectorRefId)
            streamWriteBool(streamId, grabPoint.isOwned)
            writeNetworkNodeObject(streamId, grabPoint.currentOwner)
            streamWriteBool(streamId, grabPoint.hasJointIndex)
            streamWriteBool(streamId, grabPoint.hasExtenableJointIndex)
        end
    end

    writeNetworkNodeObjectId(streamId, self.vehicleToMountHoseSystem)
    streamWriteInt32(streamId, self.referenceIdToMountHoseSystem)
    streamWriteBool(streamId, self.referenceIsExtendable)

    --    if self.polymorphismClasses ~= nil and #self.polymorphismClasses > 0 then
    --        for _, class in pairs(self.polymorphismClasses) do
    --            if class.writeStream ~= nil then
    --                class:writeStream(streamId, connection)
    --            end
    --        end
    --    end
end

function HoseSystem:readStream(streamId, connection)
    local numGrabPoints = streamReadInt8(streamId)

    for index = 1, numGrabPoints do
        local grabPoint = self.grabPoints[index]

        if grabPoint ~= nil then
            grabPoint.state = streamReadInt8(streamId)
            grabPoint.connectorVehicleId = readNetworkNodeObjectId(streamId)
            grabPoint.connectorRefId = streamReadInt32(streamId)

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

    local vehicleToMountHoseSystem = readNetworkNodeObjectId(streamId)
    local referenceIdToMountHoseSystem = streamReadInt32(streamId)
    local referenceIsExtendable = streamReadBool(streamId)

    self.poly.references:loadFillableObjectAndReference(vehicleToMountHoseSystem, referenceIdToMountHoseSystem, referenceIsExtendable, true)
    self.doNetworkObjectsIteration = true

    --    if self.polymorphismClasses ~= nil and #self.polymorphismClasses > 0 then
    --        for _, class in pairs(self.polymorphismClasses) do
    --            if class.readStream ~= nil then
    --                class:readStream(streamId, connection)
    --            end
    --        end
    --    end
end

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
                        break
                    end
                end
            end

            nodes = nodes .. nodeIdent .. string .. " />"
        end
    end

    return nil, nodes
end

function HoseSystem:mouseEvent(posX, posY, isDown, isUp, button)
end

function HoseSystem:keyEvent(unicode, sym, modifier, isDown)
end

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

    if movedDistance1 > 0.001 or movedDistance2 > 0.001 or force then
        -- print("force " .. tostring(force) .. " distance " .. movedDistance1 .. " - " .. movedDistance2)

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
-- @param number
-- @param idp
--
function HoseSystem:mathRound(number, idp)
    local multiplier = 10 ^ (idp or 0)
    return math.floor(number * multiplier + 0.5) / multiplier
end

---
-- @param j1
-- @param j2
--
function HoseSystem:calculateCosAngle(j1, j2)
    local x1, y1, z1 = localDirectionToWorld(j1, 1, 0, 0)
    local x2, y2, z2 = localDirectionToWorld(j2, 1, 0, 0)

    return x1 * x2 + y1 * y2 + z1 * z2
end

---
-- @param cond
-- @param trueValue
-- @param falseValue
--
function HoseSystem:ternary(cond, trueValue, falseValue)
    if cond then return trueValue else return falseValue end
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
-- @return table
--
function HoseSystem:getConnectedReferenceGrabPoints(object, referenceId)
    local grabPoints = {}

    for index, grabPoint in pairs(object.grabPoints) do
        if HoseSystem:getIsConnected(grabPoint.state) and grabPoint.connectorRefId == referenceId then
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
--
function HoseSystem:toggleEmptyingEffect(activate, yDirectionSpeed, index, fillType)
    if self.hoseEffects ~= nil and self.hoseEffects.isActive ~= activate then
        self.hoseEffects.isActive = activate

        if activate then
            EffectManager:setFillType(self.hoseEffects.effects, fillType)

            if self.hoseEffects.effects ~= nil then
                local grabPoint = self.grabPoints[index]
                local trans = { getWorldTranslation(grabPoint.node) }

                for _, effect in pairs(self.hoseEffects.effects) do
                    local rot = { getRotation(effect.node) }
                    rot[2] = grabPoint.id == 1 and math.rad(0) or math.rad(180)

                    setWorldTranslation(effect.node, unpack(trans))
                    setRotation(effect.node, unpack(rot))
                end
            end
        end
    end
end

function HoseSystem:setEmptyEffect(activate, dt)
    if self.hoseEffects ~= nil and self.hoseEffects.effects ~= nil then
        if activate then
            EffectManager:startEffects(self.hoseEffects.effects)

            -- Set the direction of the effect always in toward the dection node
            if self.hoseEffects.effects ~= nil then
                if self.lastRaycastDistance ~= 0 then
                    local target = { getWorldTranslation(self.lastRaycastObject.detectionNode) }
                    local targetRot = 0

                    for _, effect in pairs(self.hoseEffects.effects) do
                        if effect.curRotation == nil then
                            effect.orgRotation = { getRotation(effect.node) }
                            effect.curRotation = { getRotation(effect.node) }
                        end

                        for i = 1, 3 do
                            if i == 1 then -- x axis
                                local x, y, z = getWorldTranslation(effect.node)
                                local _, y, z = worldDirectionToLocal(getParent(effect.node), target[1] - x, target[2] - y, target[3] - z)
                                targetRot = -math.atan2(y, z) -- x axis

                                targetRot = Utils.normalizeRotationForShortestPath(targetRot, effect.curRotation[i])
                            end

                            if math.abs(effect.curRotation[i] - targetRot) > 0.000001 then
                                if effect.curRotation[i] < targetRot then
                                    effect.curRotation[i] = math.min(effect.curRotation[i] + dt, targetRot)
                                else
                                    effect.curRotation[i] = math.max(effect.curRotation[i] - dt, targetRot)
                                end

                                if effect.curRotation[i] > 2 * math.pi then
                                    effect.curRotation[i] = effect.curRotation[i] - 2 * math.pi
                                elseif effect.curRotation[i] < -2 * math.pi then
                                    effect.curRotation[i] = effect.curRotation[i] + 2 * math.pi
                                end
                            end
                        end

                        setRotation(effect.node, effect.curRotation[1], effect.orgRotation[2], effect.orgRotation[3])
                    end
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

function HoseSystem:print_r(t, name, indent)
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