--
-- HoseSystemHoseCouplingStrategy
--
-- Authors: Wopster
-- Description: Strategy for loading hose couplings
--
-- Copyright (c) Wopster, 2017

HoseSystemHoseCouplingStrategy = {}

HoseSystemHoseCouplingStrategy.TYPE = 'hoseCoupling'

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

    object.hasHoseSystem = true

    if object.hasHoseSystemPumpMotor then
        object.pumpMotorFillMode = HoseSystemPumpMotor.getInitialFillMode(HoseSystemConnectorFactory.TYPE_HOSE_COUPLING)
    end

    return hoseCouplingStrategy
end

---
--
function HoseSystemHoseCouplingStrategy:delete()
end

---
-- @param streamId
-- @param connection
--
function HoseSystemHoseCouplingStrategy:readStream(streamId, connection)
    if connection:getIsServer() then
        for id = 1, streamReadUInt8(streamId) do
            local reference = self.hoseSystemReferences[id]

            -- load the hoseSystem object later on first frame
            self:setIsUsed(id, streamReadBool(streamId), nil, true)

            if streamReadBool(streamId) then
                if self.hoseSystemsToload == nil then
                    self.hoseSystemsToload = {}
                end

                table.insert(self.hoseSystemsToload, { id = id, hoseSystemId = readNetworkNodeObjectId(streamId) })
            end

            self:toggleLock(id, streamReadBool(streamId), false, true)
            self:toggleManureFlow(id, streamReadBool(streamId), false, true)
        end

        self.fillObjectFound = streamReadBool(streamId)
        self.fillFromFillVolume = streamReadBool(streamId)

        if streamReadBool(streamId) then
            self.currentReferenceIndex = streamReadInt8(streamId)
        end

        if streamReadBool(streamId) then
            self.currentGrabPointIndex = streamReadInt8(streamId)
        end
    end
end

---
-- @param streamId
-- @param connection
--
function HoseSystemHoseCouplingStrategy:writeStream(streamId, connection)
    if not connection:getIsServer() then
        streamWriteUInt8(streamId, #self.hoseSystemReferences)

        for id = 1, #self.hoseSystemReferences do
            local reference = self.hoseSystemReferences[id]

            streamWriteBool(streamId, reference.isUsed)
            streamWriteBool(streamId, reference.hoseSystem ~= nil)

            if reference.hoseSystem ~= nil then
                writeNetworkNodeObjectId(streamId, networkGetObjectId(reference.hoseSystem))
            end

            streamWriteBool(streamId, reference.isLocked)
            streamWriteBool(streamId, reference.flowOpened)
        end

        streamWriteBool(streamId, self.fillObjectFound)
        streamWriteBool(streamId, self.fillFromFillVolume)

        streamWriteBool(streamId, self.currentReferenceIndex ~= nil)
        if self.currentReferenceIndex ~= nil then
            streamWriteInt8(streamId, self.currentReferenceIndex)
        end

        streamWriteBool(streamId, self.currentGrabPointIndex ~= nil)
        if self.currentGrabPointIndex ~= nil then
            streamWriteInt8(streamId, self.currentGrabPointIndex)
        end
    end
end

---
-- @param type
-- @param xmlFile
-- @param key
-- @param entry
--
function HoseSystemHoseCouplingStrategy:loadHoseCoupling(type, xmlFile, key, entry)
    if type ~= HoseSystemConnector.getInitialType(HoseSystemHoseCouplingStrategy.TYPE) then
        return entry
    end

    entry.isUsed = false
    entry.flowOpened = false
    entry.isLocked = false
    entry.hoseSystem = nil
    entry.grabPoints = nil
    entry.isObject = false
    entry.componentIndex = Utils.getNoNil(getXMLFloat(xmlFile, key .. 'componentIndex'), 0) + 1
    entry.parkable = Utils.getNoNil(getXMLBool(xmlFile, key .. '#parkable'), false)
    entry.lockAnimationName = Utils.getNoNil(getXMLString(xmlFile, key .. '#lockAnimationName'), nil)
    entry.manureFlowAnimationName = Utils.getNoNil(getXMLString(xmlFile, key .. '#manureFlowAnimationName'), nil)

    if entry.parkable then
        entry.parkAnimationName = Utils.getNoNil(getXMLString(xmlFile, key .. '#parkAnimationName'), nil)
        entry.parkLength = Utils.getNoNil(getXMLFloat(xmlFile, key .. '#parkLength'), 5) -- Default length of 5m
        local offsetDirection = Utils.getNoNil(getXMLString(xmlFile, key .. '#offsetDirection'), 'right')
        entry.offsetDirection = string.lower(offsetDirection) ~= 'right' and HoseSystemUtil.DIRECTION_LEFT or HoseSystemUtil.DIRECTION_RIGHT
        entry.startTransOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#startTransOffset'), 3), { 0, 0, 0 })
        entry.startRotOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#startRotOffset'), 3), { 0, 0, 0 })
        entry.endTransOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#endTransOffset'), 3), { 0, 0, 0 })
        entry.endRotOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#endRotOffset'), 3), { 0, 0, 0 })

        local maxNode = createTransformGroup(('hoseSystemReference_park_maxNode_%d'):format(entry.id))
        local trans = { localToWorld(entry.node, 0, 0, entry.offsetDirection ~= 1 and -entry.parkLength or entry.parkLength) }

        link(entry.node, maxNode)
        setWorldTranslation(maxNode, unpack(trans))

        entry.maxParkLengthNode = maxNode
    end

    return entry
end


function HoseSystemHoseCouplingStrategy:update(dt)
    if self.hoseSystemsToload ~= nil then
        for _, n in pairs(self.hoseSystemsToload) do
            self.hoseSystemReferences[n.id].hoseSystem = networkGetObject(n.hoseSystemId)
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

                            HoseSystemUtil:renderHelpTextOnNode(firstPartAnimation.node, string.format(state and g_i18n:getText('action_toggleLockStateLock') or g_i18n:getText('action_toggleLockStateUnlock'), reference.hoseSystem.typeDesc), string.format(g_i18n:getText('input_mouseInteract'), string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_LEFT))))

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

                            HoseSystemUtil:renderHelpTextOnNode(firstPartAnimation.node, string.format(g_i18n:getText('action_toggleManureFlow'), state and g_i18n:getText('action_toggleManureFlowStateOpen') or g_i18n:getText('action_toggleManureFlowStateClose')), string.format(g_i18n:getText('input_mouseInteract'), string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_RIGHT))))

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