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

    return hoseCouplingStrategy
end

---
--
function HoseSystemHoseCouplingStrategy:preDelete()
    if self.object.hoseSystemReferences ~= nil and g_currentMission.hoseSystemHoses ~= nil then
        for referenceId, reference in pairs(self.object.hoseSystemReferences) do
            if reference.isUsed then
                if reference.hoseSystem ~= nil and reference.hoseSystem.grabPoints ~= nil then
                    for grabPointIndex, grabPoint in pairs(reference.hoseSystem.grabPoints) do
                        if HoseSystem:getIsConnected(grabPoint.state) and grabPoint.connectorRefId == referenceId then
                            reference.hoseSystem.poly.interactiveHandling:detach(grabPointIndex, self.object, referenceId, false)
                        end
                    end
                end
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
            self.fillLevelChanged = streamReadBool(streamId)
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
            streamWriteBool(streamId, self.fillLevelChanged)
        end
    end
end

---
-- @param streamId
-- @param connection
--
function HoseSystemHoseCouplingStrategy:readStream(streamId, connection)
    if connection:getIsServer() then
        for id = 1, streamReadUInt8(streamId) do
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
        end

        if streamReadBool(streamId) then
            self.object.currentReferenceIndex = streamReadInt8(streamId)
        end

        if streamReadBool(streamId) then
            self.object.currentGrabPointIndex = streamReadInt8(streamId)
        end
    end
end

---
-- @param streamId
-- @param connection
--
function HoseSystemHoseCouplingStrategy:writeStream(streamId, connection)
    if not connection:getIsServer() then
        streamWriteUInt8(streamId, #self.object.hoseSystemReferences)

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

        streamWriteBool(streamId, self.object.currentReferenceIndex ~= nil)
        if self.object.currentReferenceIndex ~= nil then
            streamWriteInt8(streamId, self.object.currentReferenceIndex)
        end

        streamWriteBool(streamId, self.object.currentGrabPointIndex ~= nil)
        if self.object.currentGrabPointIndex ~= nil then
            streamWriteInt8(streamId, self.object.currentGrabPointIndex)
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
    if self.object.isClient then
        self:updateHoseSystem(self.fillLevelChanged, true)
    end

    self:getValidFillObject(dt)

    if self.object.hasHoseSystemPumpMotor then
        if self.object.isServer then
            if self.object:getFillMode() == self.object.pumpMotorFillMode then
                local isSucking = false

                local reference = self.object.hoseSystemReferences[self.object.currentReferenceIndex]

                -- Todo: Moved feature to version 1.1 determine pump efficiency based on hose chain lenght
                --                if reference ~= nil then
                --                    local count = self.pumpFillEfficiency.maxTimeStatic / 10 * reference.hoseSystem.currentChainCount
                --                    self.pumpFillEfficiency.maxTime = reference.hoseSystem.currentChainCount > 0 and  self.pumpFillEfficiency.maxTimeStatic + count or self.pumpFillEfficiency.maxTimeStatic
                --                    print("CurrentChainCount= " .. reference.hoseSystem.currentChainCount .. "maxTime= " .. self.pumpFillEfficiency.maxTime .. 'What we do to it= ' .. count)
                --                end

                if self.object.pumpIsStarted and self.object.fillObject ~= nil then
                    local sourceObject = self.object.sourceObject

                    if self.object.fillDirection == HoseSystemPumpMotor.IN then
                        local objectFillTypes = self.object.fillObject:getCurrentFillTypes()

                        -- isn't below dubble code?
                        if self.object.fillObject:getFreeCapacity() ~= self.object.fillObject:getCapacity() then
                            for _, objectFillType in pairs(objectFillTypes) do
                                if sourceObject:allowUnitFillType(self.object.fillUnitIndex, objectFillType, false) then
                                    local objectFillLevel = self.object.fillObject:getFillLevel(objectFillType)
                                    local fillLevel = sourceObject:getUnitFillLevel(self.object.fillUnitIndex)

                                    if objectFillLevel > 0 and fillLevel < sourceObject:getUnitCapacity(self.object.fillUnitIndex) then
                                        if self.object.fillObject.checkPlaneY ~= nil then
                                            local lastGrabPoint, _ = self:getLastGrabpointRecursively(reference.hoseSystem.grabPoints[HoseSystemConnector:getFillableVehicle(self.object.currentGrabPointIndex, #reference.hoseSystem.grabPoints)])

                                            if not HoseSystem:getIsConnected(lastGrabPoint.state) then
                                                local _, y, _ = getWorldTranslation(lastGrabPoint.raycastNode)

                                                if reference.hoseSystem.lastRaycastDistance ~= 0 then
                                                    isSucking, _ = self.object.fillObject:checkPlaneY(y)
                                                end
                                            else
                                                isSucking = reference ~= nil
                                            end
                                        else
                                            isSucking = reference ~= nil
                                        end

                                        self.object:pumpIn(sourceObject, dt, objectFillLevel, objectFillType)
                                    else
                                        self.object:setPumpStarted(false, HoseSystemPumpMotor.UNIT_EMPTY)
                                    end
                                else
                                    self.object:setPumpStarted(false, HoseSystemPumpMotor.INVALID_FILLTYPE)
                                end
                            end
                        else
                            self.object:setPumpStarted(false, HoseSystemPumpMotor.OBJECT_EMPTY)
                        end
                    else
                        self.object:pumpOut(sourceObject, dt)
                    end
                end

                if self.object.isSucking ~= isSucking then
                    self.object.isSucking = isSucking
                    g_server:broadcastEvent(IsSuckingEvent:new(self.object, self.object.isSucking))
                end
            end

            if self.object.fillObjectFound then
                if self.object.fillObject ~= nil and self.object.fillObject.checkPlaneY ~= nil then -- we are raycasting a fillplane
                    if self.object.fillObject.updateShaderPlane ~= nil then
                        self.object.fillObject:updateShaderPlane(self.object.pumpIsStarted, self.object.fillDirection, self.object.pumpFillEfficiency.litersPerSecond)
                    end
                end
            end
        end

        if self.object.isClient then
            if self.object.fillObjectHasPlane then
                if self.object.fillObjectFound or self.object.fillFromFillVolume then
                    self:updateHoseSystem(true)
                end
            else
                if not self.object.fillObjectFound and self.object.pumpIsStarted then
                    self:updateHoseSystem(false)
                end
            end
        end
    end
end

---
-- @param allow
-- @param force
--
function HoseSystemHoseCouplingStrategy:updateHoseSystem(allow, force)
    if force == nil then
        force = false
    end

    if self.object.lastGrabPointIndex ~= nil and self.object.lastReferenceIndex ~= nil then
        local reference = self.object.hoseSystemReferences[self.object.lastReferenceIndex]

        if reference ~= nil and reference.hoseSystem ~= nil then
            local lastGrabPoint, lastHoseSystem = self:getLastGrabpointRecursively(reference.hoseSystem.grabPoints[HoseSystemConnector:getFillableVehicle(self.object.lastGrabPointIndex, #reference.hoseSystem.grabPoints)], reference.hoseSystem)

            if lastGrabPoint ~= nil and lastHoseSystem ~= nil then
                local unitIndex = force and reference.fillUnitIndex or self.object.fillUnitIndex
                local fillType = self.object:getUnitLastValidFillType(unitIndex)

                lastHoseSystem:toggleEmptyingEffect((allow and self.object.pumpIsStarted and self.object.fillDirection == HoseSystemPumpMotor.OUT) or (allow and force), lastGrabPoint.id > 1 and 1 or -1, lastGrabPoint.id, fillType)
            end
        end
    end
end

---
--
function HoseSystemHoseCouplingStrategy:getValidFillObject(dt)
    self.object.lastReferenceIndex = self.object.currentReferenceIndex
    self.object.lastGrabPointIndex = self.object.currentGrabPointIndex

    self.object.currentReferenceIndex, self.object.currentGrabPointIndex = self:getPriorityReference()

    if not self.object.isServer then
        return
    end

    self.fillLevelChanged = false

    if self.object.hasHoseSystemPumpMotor then
        self.object:removeFillObject(self.object.fillObject, self.object.pumpMotorFillMode)
    end

    if self.object.currentGrabPointIndex ~= nil and self.object.currentReferenceIndex ~= nil then
        local reference = self.object.hoseSystemReferences[self.object.currentReferenceIndex]

        if reference ~= nil then
            local lastGrabPoint, lastHoseSystem = self:getLastGrabpointRecursively(reference.hoseSystem.grabPoints[HoseSystemConnector:getFillableVehicle(self.object.currentGrabPointIndex, #reference.hoseSystem.grabPoints)], reference.hoseSystem)

            if lastGrabPoint ~= nil then
                -- check if the last grabPoint is connected
                if HoseSystem:getIsConnected(lastGrabPoint.state) and self.object.hasHoseSystemPumpMotor and not lastGrabPoint.connectable then
                    local lastVehicle = HoseSystemReferences:getReferenceVehicle(lastGrabPoint.connectorVehicle)
                    local lastReference = lastVehicle.hoseSystemReferences[lastGrabPoint.connectorRefId]

                    if lastReference ~= nil and lastVehicle ~= nil and lastVehicle.grabPoints == nil then -- checks if it's not a hose!
                        if lastReference.isUsed and lastReference.flowOpened and lastReference.isLocked then
                            if lastReference.isObject or SpecializationUtil.hasSpecialization(Fillable, lastVehicle.specializations) then
                                -- check fill units to allow
                                self.object:addFillObject(lastVehicle, self.object.pumpMotorFillMode, false)
                            end
                        end
                    end
                elseif HoseSystem:getIsDetached(lastGrabPoint.state) then -- don't lookup when the player picks up the hose from the pit
                    local hoseSystem = reference.hoseSystem

                    -- check what the lastGrabPoint has on it's raycast
                    if hoseSystem ~= nil then
                        if hoseSystem.lastRaycastDistance ~= 0 and hoseSystem.lastRaycastObject ~= nil then
                            if self.object.hasHoseSystemPumpMotor then
                                self.object:addFillObject(hoseSystem.lastRaycastObject, self.object.pumpMotorFillMode, true)
                            end
                        elseif reference.manureFlowAnimationName ~= nil then
                            local fillType = self.object:getUnitLastValidFillType(reference.fillUnitIndex)
                            local fillLevel = self.object:getFillLevel(fillType)

                            if fillLevel > 0 then
                                local deltaFillLevel = math.min(HoseSystemHoseCouplingStrategy.EMPTY_LITER_PER_SECOND * dt / 1000, fillLevel)

                                self.fillLevelChanged = true

                                self.object:setFillLevel(fillLevel - deltaFillLevel, fillType)
                            end
                        end
                    end
                end
            end
        end
    end

    if self.fillLevelChanged ~= self.lastFillLevelChanged then
        self.object:raiseDirtyFlags(self.object.fillLevelChangedDirtyFlag)
        self.lastFillLevelChanged = self.fillLevelChanged
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
--
function HoseSystemHoseCouplingStrategy:getPriorityReference()
    -- Todo: Moved to version 1.1
    -- but what if we have more? Can whe pump with multiple hoses? Does that lower the pumpEfficiency or increase the throughput? Priority reference? There is a cleaner way to-do this.

    if self.object.hoseSystemReferences == nil then
        return nil, nil
    end

    for referenceId, reference in pairs(self.object.hoseSystemReferences) do
        if reference.isUsed and reference.flowOpened and reference.isLocked then
            if reference.hoseSystem ~= nil and reference.hoseSystem.grabPoints ~= nil then
                for index, grabPoint in pairs(reference.hoseSystem.grabPoints) do
                    if HoseSystem:getIsConnected(grabPoint.state) and grabPoint.connectorVehicle == self.object then
                        return referenceId, index
                    end
                end
            end
        end
    end

    return nil, nil
end
