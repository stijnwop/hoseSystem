--
-- HoseSystemHoseCouplingStrategy
--
-- Authors: Wopster
-- Description: Strategy for loading hose couplings
--
-- Copyright (c) Wopster, 2017

HoseSystemHoseCouplingStrategy = {}

HoseSystemHoseCouplingStrategy.TYPE = 'hoseCoupling'
HoseSystemHoseCouplingStrategy.EMPTY_LITER_PER_SECOND = 25

local HoseSystemHoseCouplingStrategy_mt = Class(HoseSystemHoseCouplingStrategy)

---
-- @param object
-- @param mt
--
function HoseSystemHoseCouplingStrategy:new(object, mt)
    local hoseCouplingStrategy = {
        object = object
    }

    setmetatable(hoseCouplingStrategy, mt == nil and HoseSystemHoseCouplingStrategy_mt or mt)

    if g_currentMission.hoseSystemReferences == nil then
        g_currentMission.hoseSystemReferences = {}
    end

    if not HoseSystemUtil.getHasListElement(g_currentMission.hoseSystemReferences, object) then
        table.insert(g_currentMission.hoseSystemReferences, object)
    end

    object.hasHoseSystem = true

    if object.hasHoseSystemPumpMotor then
        object.pumpMotorFillMode = HoseSystemPumpMotor.getInitialFillMode(HoseSystemConnectorFactory.TYPE_HOSE_COUPLING)
    end

    object.fillLevelChangedDirtyFlag = object:getNextDirtyFlag()
    self.fillLevelChanged = false

    object.attachedHoseSystemReferences = {}

    return hoseCouplingStrategy
end

---
--
function HoseSystemHoseCouplingStrategy:preDelete()
    if self.object.isServer and self.object.attachedHoseSystemReferences ~= nil and g_currentMission.hoseSystemHoses ~= nil then
        for referenceId, entry in pairs(self.object.attachedHoseSystemReferences) do
            local reference = self.object.hoseSystemReferences[referenceId]

            if reference.isUsed and reference.hoseSystem ~= nil then
                reference.hoseSystem.poly.interactiveHandling:detach(reference.grabPointId, self.object, referenceId, false)
            end
        end
    end
end

---
--
function HoseSystemHoseCouplingStrategy:delete()
end

---
-- @param streamId
-- @param timestamp
-- @param connection
--
function HoseSystemHoseCouplingStrategy:readUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        if streamReadBool(streamId) then
            for referenceId, entry in pairs(self.object.attachedHoseSystemReferences) do
                entry.showEffect = streamReadBool(streamId)

                if streamReadBool(streamId) then
                    entry.lastGrabPointId = streamReadUIntN(streamId, HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS) + 1
                    entry.lastHoseSystem = readNetworkNodeObject(streamId)
                end

                if HoseSystem.debugRendering then
                    HoseSystemUtil:log(HoseSystemUtil.DEBUG, 'Coupling readUpdateStream active references [referenceId] = ' .. tostring(referenceId) .. " [showEffect] = " .. tostring(entry.showEffect))
                end

                self:updateQueuedReferencesGraphics(referenceId)
            end
        end
    end
end

---
-- @param streamId
-- @param connection
-- @param dirtyMask
--
function HoseSystemHoseCouplingStrategy:writeUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        if streamWriteBool(streamId, bitAND(dirtyMask, self.object.fillLevelChangedDirtyFlag) ~= 0) then
            for _, entry in pairs(self.object.attachedHoseSystemReferences) do
                streamWriteBool(streamId, entry.showEffect)

                local writeAdditional = entry.lastGrabPointId ~= nil and entry.lastHoseSystem ~= nil

                streamWriteBool(streamId, writeAdditional)

                if writeAdditional then
                    streamWriteUIntN(streamId, entry.lastGrabPointId - 1, HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS)
                    writeNetworkNodeObject(streamId, entry.lastHoseSystem)
                end

                entry.sendShowEffect = entry.showEffect
            end
        end
    end
end

---
-- @param streamId
-- @param connection
--
function HoseSystemHoseCouplingStrategy:readStream(streamId, connection)
    if connection:getIsServer() then
        for id = 1, streamReadInt8(streamId) do
            local reference = self.object.hoseSystemReferences[id]

            -- load the hoseSystem object later on first frame
            self.object:setIsUsed(id, streamReadBool(streamId), nil, true)

            if streamReadBool(streamId) then
                if self.hoseSystemsToload == nil then
                    self.hoseSystemsToload = {}
                end

                table.insert(self.hoseSystemsToload, { id = id, hoseSystemId = readNetworkNodeObjectId(streamId) })
            end

            self.object:toggleLock(id, streamReadBool(streamId), false, true)
            self.object:toggleManureFlow(id, streamReadBool(streamId), false, true)

            if reference.isUsed and self.object.attachedHoseSystemReferences[reference.id] == nil then
                self.object.attachedHoseSystemReferences[reference.id] = {
                    showEffect = false
                }
            end
        end

        self:priorityQueueReferences()
    end
end

---
-- @param streamId
-- @param connection
--
function HoseSystemHoseCouplingStrategy:writeStream(streamId, connection)
    if not connection:getIsServer() then
        streamWriteInt8(streamId, #self.object.hoseSystemReferences)

        for id = 1, #self.object.hoseSystemReferences do
            local reference = self.object.hoseSystemReferences[id]

            streamWriteBool(streamId, reference.isUsed)
            streamWriteBool(streamId, reference.hoseSystem ~= nil)

            if reference.hoseSystem ~= nil then
                writeNetworkNodeObjectId(streamId, networkGetObjectId(reference.hoseSystem))
            end

            streamWriteBool(streamId, reference.isLocked)
            streamWriteBool(streamId, reference.flowOpened)
        end
    end
end

---
-- @param xmlFile
-- @param key
-- @param entry
--
function HoseSystemHoseCouplingStrategy:loadHoseCoupling(xmlFile, key, entry)
    if #self.object.hoseSystemReferences == 2 ^ HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS then
        HoseSystemUtil:log(HoseSystemUtil.ERROR, ('Max number of references is %s!'):format(2 ^ HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS))
        return
    end

    entry.flowOpened = false
    entry.isLocked = false
    entry.hoseSystem = nil
    entry.grabPointId = nil
    entry.grabPoints = nil
    entry.isObject = false
    entry.componentIndex = Utils.getNoNil(getXMLFloat(xmlFile, key .. 'componentIndex'), 0) + 1

    if entry.componentIndex > 1 and entry.componentIndex > #self.object.components then
        HoseSystemUtil:log(HoseSystemUtil.ERROR, ('The given componentIndex (%s) is higher then the component count!'):format(entry.componentIndex))
    end

    entry.parkable = Utils.getNoNil(getXMLBool(xmlFile, key .. '#parkable'), false)
    entry.lockAnimationName = Utils.getNoNil(getXMLString(xmlFile, key .. '#lockAnimationName'), nil)
    entry.manureFlowAnimationName = Utils.getNoNil(getXMLString(xmlFile, key .. '#manureFlowAnimationName'), nil)

    if entry.parkable then
        entry.parkAnimationName = Utils.getNoNil(getXMLString(xmlFile, key .. '#parkAnimationName'), nil)
        entry.parkLength = Utils.getNoNil(getXMLFloat(xmlFile, key .. '#parkLength'), 5) -- Default length of 5m
        entry.offsetThreshold = Utils.getNoNil(getXMLFloat(xmlFile, key .. '#offsetThreshold'), 0)
        local offsetDirection = Utils.getNoNil(getXMLString(xmlFile, key .. '#offsetDirection'), 'right')
        entry.offsetDirection = string.lower(offsetDirection) ~= 'right' and HoseSystemUtil.DIRECTION_LEFT or HoseSystemUtil.DIRECTION_RIGHT
        entry.startTransOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#startTransOffset'), 3), { 0, 0, 0 })
        local startRotOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#startRotOffset'), 3), { 0, 0, 0 })
        entry.startRotOffset = { Utils.degToRad(startRotOffset[1]), Utils.degToRad(startRotOffset[2]), Utils.degToRad(startRotOffset[3]) }
        entry.endTransOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#endTransOffset'), 3), { 0, 0, 0 })
        local endRotOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#endRotOffset'), 3), { 0, 0, 0 })
        entry.endRotOffset = { Utils.degToRad(endRotOffset[1]), Utils.degToRad(endRotOffset[2]), Utils.degToRad(endRotOffset[3]) }

        local maxNode = createTransformGroup(('hoseSystemReference_park_maxNode_%d'):format(entry.id))
        local trans = { localToWorld(entry.node, 0, 0, entry.offsetDirection ~= 1 and -entry.parkLength or entry.parkLength) }

        link(entry.node, maxNode)
        setWorldTranslation(maxNode, unpack(trans))

        entry.maxParkLengthNode = maxNode
    end

    entry.fillUnitIndex = Utils.getNoNil(getXMLInt(xmlFile, key .. '#fillUnitIndex'), 1)

    table.insert(self.object.hoseSystemReferences, entry)

    return entry
end

---
-- @param dt
--
function HoseSystemHoseCouplingStrategy:update(dt)
    if self.hoseSystemsToload ~= nil then
        for _, n in pairs(self.hoseSystemsToload) do
            self.object.hoseSystemReferences[n.id].hoseSystem = networkGetObject(n.hoseSystemId)
        end

        self.hoseSystemsToload = nil
    end

    -- run this client sided only
    if not self.object.isClient then
        return
    end

    if HoseSystemPlayerInteractive:getIsPlayerValid(false) then
        local inRange, referenceId = self.object:getIsPlayerInReferenceRange()

        if inRange then
            local reference = self.object.hoseSystemReferences[referenceId]

            if reference ~= nil then
                if not reference.flowOpened then
                    if reference.lockAnimationName ~= nil and self.object.animations[reference.lockAnimationName] ~= nil and #self.object.animations[reference.lockAnimationName].parts > 0 then
                        local _, firstPartAnimation = next(self.object.animations[reference.lockAnimationName].parts, nil)

                        if firstPartAnimation.node ~= nil and g_i18n:hasText('action_toggleLockStateLock') and g_i18n:hasText('action_toggleLockStateUnlock') then
                            local state = self.object:getAnimationTime(reference.lockAnimationName) == 0

                            HoseSystemUtil:renderHelpTextOnNode(firstPartAnimation.node, string.format(state and g_i18n:getText('action_toggleLockStateLock') or g_i18n:getText('action_toggleLockStateUnlock'), reference.hoseSystem.typeDesc), string.format(g_i18n:getText('input_mouseInteract'), g_i18n:getText('input_mouseInteractMouseLeft')))

                            if InputBinding.hasEvent(InputBinding.toggleLock) then
                                self.object:toggleLock(referenceId, state, false)
                            end
                        end
                    end
                end

                if reference.isLocked then
                    if reference.manureFlowAnimationName ~= nil and self.object.animations[reference.manureFlowAnimationName] ~= nil and #self.object.animations[reference.manureFlowAnimationName].parts > 0 then
                        local _, firstPartAnimation = next(self.object.animations[reference.manureFlowAnimationName].parts, nil)

                        if firstPartAnimation.node ~= nil and g_i18n:hasText('action_toggleManureFlow') and g_i18n:hasText('action_toggleManureFlowStateOpen') and g_i18n:hasText('action_toggleManureFlowStateClose') then
                            local state = self.object:getAnimationTime(reference.manureFlowAnimationName) == 0

                            HoseSystemUtil:renderHelpTextOnNode(firstPartAnimation.node, string.format(g_i18n:getText('action_toggleManureFlow'), state and g_i18n:getText('action_toggleManureFlowStateOpen') or g_i18n:getText('action_toggleManureFlowStateClose')), string.format(g_i18n:getText('input_mouseInteract'), g_i18n:getText('input_mouseInteractMouseRight')))

                            if InputBinding.hasEvent(InputBinding.toggleManureFlow) then
                                self.object:toggleManureFlow(referenceId, state, false)
                            end
                        end
                    end
                end
            end
        end
    end
end

---
-- @param dt
--
function HoseSystemHoseCouplingStrategy:updateTick(dt)
    self:findFillObject(dt)

    -- Todo: Moved feature to version 1.1 determine pump efficiency based on hose chain lenght
    --                if reference ~= nil then
    --                    local count = self.pumpFillEfficiency.maxTimeStatic / 10 * reference.hoseSystem.currentChainCount
    --                    self.pumpFillEfficiency.maxTime = reference.hoseSystem.currentChainCount > 0 and  self.pumpFillEfficiency.maxTimeStatic + count or self.pumpFillEfficiency.maxTimeStatic
    --                    print("CurrentChainCount= " .. reference.hoseSystem.currentChainCount .. "maxTime= " .. self.pumpFillEfficiency.maxTime .. 'What we do to it= ' .. count)
    --                end

    if not self.object.isServer then
        return
    end

    if self.object.hasHoseSystemPumpMotor then
        for referenceId, entry in pairs(self.object.attachedHoseSystemReferences) do
            if entry.isActive then
                local fillDirection = self.object:getFillDirection()
                local isAbleToPump = entry.isActive

                -- if fill direction is IN we have some exceptions
                if fillDirection == HoseSystemPumpMotor.IN then
                    if self.object.fillObjectHasPlane and self.object.fillObject.checkPlaneY ~= nil then
                        if not HoseSystem:getIsConnected(entry.lastGrabPoint.state) then
                            if entry.lastHoseSystem.lastRaycastDistance ~= 0 then
                                local x, y, z = getWorldTranslation(entry.lastGrabPoint.raycastNode)
                                local isUnderFillplane, _ = entry.lastHoseSystem.lastRaycastObject:checkPlaneY(y - entry.lastGrabPoint.planeOffset, { x, y, z })

                                isAbleToPump = isUnderFillplane
                            end
                        end
                    end
                end

                self.object:handlePump(self.object.pumpMotorFillMode, dt, isAbleToPump)
            end
        end

        -- Todo: move this to the object and don't let this control it
        if self.object.fillObjectFound then
            if self.object.fillObject ~= nil and self.object.fillObject.checkPlaneY ~= nil then -- we are raycasting a fillplane
                if self.object.fillObject.updateShaderPlane ~= nil then
                    self.object.fillObject:updateShaderPlane(self.object.pumpIsStarted, self.object.fillDirection, self.object.pumpFillEfficiency.litersPerSecond)
                end
            end
        end
    end
end

---
-- @param grabPoint
-- @param hoseSystem
--
function HoseSystemHoseCouplingStrategy:getLastGrabpointRecursively(grabPoint, hoseSystem)
    if grabPoint ~= nil then
        if grabPoint.connectorVehicle ~= nil and grabPoint.connectorVehicle.grabPoints ~= nil then
            for i, connectorGrabPoint in pairs(grabPoint.connectorVehicle.grabPoints) do
                if connectorGrabPoint ~= nil then
                    local reference = HoseSystemReferences:getReference(grabPoint.connectorVehicle, grabPoint.connectorRefId, grabPoint)

                    if connectorGrabPoint ~= reference then
                        self:getLastGrabpointRecursively(connectorGrabPoint, reference.hoseSystem)
                    end
                end
            end
        end

        return grabPoint, hoseSystem
    end

    return nil, nil
end

---
-- @param dt
--
function HoseSystemHoseCouplingStrategy:findFillObject(dt)
    self:priorityQueueReferences()

    if next(self.object.attachedHoseSystemReferences) == nil then
        return
    end

    if not self.object.isServer then
        return
    end

    for referenceId, entry in pairs(self.object.attachedHoseSystemReferences) do
        local reference = self.object.hoseSystemReferences[referenceId]

        if reference ~= nil then
            if entry.lastGrabPoint ~= nil then
                local fillObject
                local isRayCasted = false
                entry.showEffect = false

                if HoseSystem:getIsConnected(entry.lastGrabPoint.state) and not entry.lastGrabPoint.connectable then
                    if self.object.hasHoseSystemPumpMotor then
                        local lastVehicle = HoseSystemReferences:getReferenceVehicle(entry.lastGrabPoint.connectorVehicle)
                        local lastReference = lastVehicle.hoseSystemReferences[entry.lastGrabPoint.connectorRefId]

                        if lastReference ~= nil and lastVehicle ~= nil and lastVehicle.grabPoints == nil then -- checks if it's not a hose!
                            if lastReference.isUsed and lastReference.flowOpened and lastReference.isLocked then
                                if lastReference.isObject or SpecializationUtil.hasSpecialization(Fillable, lastVehicle.specializations) then
                                    entry.isActive = true
                                    fillObject = lastVehicle
                                end
                            end
                        end
                    end
                elseif HoseSystem:getIsDetached(entry.lastGrabPoint.state) then -- don't lookup when the player picks up the hose from the pit
                    local hoseSystem = reference.hoseSystem

                    -- check what the lastGrabPoint has on it's raycast
                    if hoseSystem ~= nil and reference.flowOpened then
                        if hoseSystem.lastRaycastDistance ~= 0 and hoseSystem.lastRaycastObject ~= nil then
                            if self.object.hasHoseSystemPumpMotor then
                                entry.isActive = true

                                if self.object.pumpIsStarted and self.object.fillDirection == HoseSystemPumpMotor.OUT then
                                    entry.showEffect = true
                                end

                                isRayCasted = true
                                fillObject = hoseSystem.lastRaycastObject
                            end
                        elseif reference.manureFlowAnimationName ~= nil then
                            local fillType = self.object:getUnitLastValidFillType(reference.fillUnitIndex)
                            local fillLevel = self.object:getFillLevel(fillType)

                            if fillLevel > 0 then
                                local deltaFillLevel = math.min(HoseSystemHoseCouplingStrategy.EMPTY_LITER_PER_SECOND * dt / 1000, fillLevel)

                                entry.showEffect = true

                                self.object:setFillLevel(fillLevel - deltaFillLevel, fillType)
                            end
                        end
                    end
                end

                if entry.isActive then
                    if not self.object.fillObjectFound then
                        self.object:addFillObject(fillObject, self.object.pumpMotorFillMode, isRayCasted)
                    end
                else
                    if self.object.fillObjectFound then
                        self.object:removeFillObject(fillObject, self.object.pumpMotorFillMode)
                    end
                end
            end
        end

        if entry.sendShowEffect ~= entry.showEffect then
            if not g_currentMission.missionDynamicInfo.isMultiplayer then
                entry.sendShowEffect = entry.showEffect
            end

            self.object:raiseDirtyFlags(self.object.fillLevelChangedDirtyFlag)
            self:updateQueuedReferencesGraphics(referenceId)
        end
    end
end

---
--
function HoseSystemHoseCouplingStrategy:priorityQueueReferences()
    for id, entry in pairs(self.object.attachedHoseSystemReferences) do
        local reference = self.object.hoseSystemReferences[id]

        if reference ~= nil and reference.isUsed and reference.isLocked then
            if reference.hoseSystem ~= nil and reference.grabPointId ~= nil then
                local otherGrabPointId = HoseSystem.getOtherGrabPointId(reference.hoseSystem, reference.grabPointId)
                local lastGrabPoint, lastHoseSystem = self:getLastGrabpointRecursively(reference.hoseSystem.grabPoints[otherGrabPointId], reference.hoseSystem)

                entry.grabPointId = reference.grabPointId
                entry.lastGrabPoint = lastGrabPoint
                entry.lastGrabPointId = lastGrabPoint.id
                entry.lastHoseSystem = lastHoseSystem

                if self.object.isServer then
                    entry.isActive = false
                end
            end
        end
    end
end

---
-- @param hoseSystem
-- @param referenceId
--
function HoseSystemHoseCouplingStrategy.getGrabPointIdFromReference(hoseSystem, referenceId)
    if hoseSystem ~= nil and hoseSystem.grabPoints ~= nil then
        for id, grabPoint in pairs(hoseSystem.grabPoints) do
            if HoseSystem:getIsConnected(grabPoint.state) and grabPoint.connectorRefId == referenceId then -- and grabPoint.connectorVehicle == object then
                return id
            end
        end
    end

    return nil
end

---
-- @param referenceId
--
function HoseSystemHoseCouplingStrategy:updateQueuedReferencesGraphics(referenceId)
    if not self.object.isClient then
        return
    end

    if next(self.object.attachedHoseSystemReferences) == nil then
        return
    end

    local allow = true

    if not self.object.fillObjectFound and self.object.pumpIsStarted then
        allow = false
    end

    local netInfo = self.object.attachedHoseSystemReferences[referenceId]
    local reference = self.object.hoseSystemReferences[referenceId]

    if reference ~= nil then
        if netInfo.lastGrabPointId ~= nil and netInfo.lastHoseSystem ~= nil then
            local unitIndex = reference.fillUnitIndex
            local showEffect = allow and netInfo.showEffect

            if self.object.pumpIsStarted then
                if self.object.fillDirection ~= HoseSystemPumpMotor.OUT then
                    showEffect = false
                else
                    unitIndex = self.object.fillUnitIndex
                end
            end

            local fillType = self.object:getUnitLastValidFillType(unitIndex)
            netInfo.lastHoseSystem:toggleEmptyingEffect(showEffect, netInfo.lastGrabPointId, fillType)
        end
    end
end