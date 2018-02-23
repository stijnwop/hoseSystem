--
-- HoseSystemConnector
--
-- Authors: Wopster
-- Description: The HoseSystem connector script for vehicles
--
-- Copyright (c) Wopster, 2017

HoseSystemConnector = {
    baseDirectory = g_currentModDirectory
}

HoseSystemConnector.PLAYER_DISTANCE = 1.3
HoseSystemConnector.DEFAULT_INRANGE_DISTANCE = 1.3

source(HoseSystemConnector.baseDirectory .. 'specializations/vehicles/HoseSystemConnectorFactory.lua')

---
-- @param specializations
--
function HoseSystemConnector.prerequisitesPresent(specializations)
    return true
end

---
-- @param savegame
--
function HoseSystemConnector:preLoad(savegame)
    self.toggleLock = HoseSystemConnector.toggleLock
    self.toggleManureFlow = HoseSystemConnector.toggleManureFlow
    self.setIsUsed = HoseSystemConnector.setIsUsed
    self.setIsDockUsed = HoseSystemConnector.setIsDockUsed
    self.getIsPlayerInReferenceRange = HoseSystemConnector.getIsPlayerInReferenceRange
    self.onConnectorAttach = HoseSystemConnector.onConnectorAttach
    self.onConnectorDetach = HoseSystemConnector.onConnectorDetach

    -- overwrittenFunctions
    self.getIsOverloadingAllowed = Utils.overwrittenFunction(self.getIsOverloadingAllowed, HoseSystemConnector.getIsOverloadingAllowed)
end

---
-- @param savegame
--
function HoseSystemConnector:load(savegame)
    self.connectStrategies = {}
    self.hoseSystemReferences = {}
    self.dockingSystemReferences = {}
    self.transferSystemReferences = {}

    HoseSystemConnector.loadHoseReferences(self, self.xmlFile, 'vehicle.hoseSystemReferences.')

    if self.unloadTrigger ~= nil then
        self.unloadTrigger:delete()
        self.unloadTrigger = nil
    end
end

---
-- @param savegame
--
function HoseSystemConnector:postLoad(savegame)
    if savegame ~= nil and not savegame.resetVehicles then
        for id, reference in ipairs(self.hoseSystemReferences) do
            local key = string.format('%s.reference(%d)', savegame.key, id - 1)

            self:toggleLock(id, Utils.getNoNil(getXMLBool(savegame.xmlFile, key .. '#isLocked'), false), false, true)
            self:toggleManureFlow(id, Utils.getNoNil(getXMLBool(savegame.xmlFile, key .. '#flowOpened'), false), false, true)
        end
    end
end

---
-- @param self
-- @param xmlFile
-- @param base
--
function HoseSystemConnector.loadHoseReferences(self, xmlFile, base)
    local i = 0

    while true do
        local key = string.format(base .. 'hoseSystemReference(%d)', i)

        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local typeString = Utils.getNoNil(getXMLString(xmlFile, key .. '#type'), HoseSystemConnectorFactory.TYPE_HOSE_COUPLING)

        if typeString ~= nil then
            local factory = HoseSystemConnectorFactory.getInstance()
            local type = factory.getInitialType(typeString)

            if type == nil then
                HoseSystemUtil:log(HoseSystemUtil.ERROR, ('Invalid connector type %s!'):format(typeString))
                -- fallback on hose coupling
                typeString = HoseSystemConnectorFactory.TYPE_HOSE_COUPLING
                type = factory.getInitialType(typeString)
            end

            local node = HoseSystemXMLUtil.getOrCreateNode(self.components, xmlFile, key)

            if node ~= nil then
                local strategy = factory:getConnectorStrategy(type, self)

                -- defaults
                local entry = {
                    id = i + 1,
                    type = type,
                    node = node,
                    isUsed = false,
                    inRangeDistance = Utils.getNoNil(getXMLFloat(xmlFile, key .. '#inRangeDistance'), HoseSystemConnector.DEFAULT_INRANGE_DISTANCE),
                }

                HoseSystemUtil.callStrategyFunction({ strategy }, 'load' .. HoseSystemUtil:firstToUpper(typeString), { xmlFile, key, entry })

                self.connectStrategies = HoseSystemUtil.insertStrategy(strategy, self.connectStrategies)
            else
                HoseSystemUtil:log(HoseSystemUtil.ERROR, "Invalid reference node: " .. i)
            end
        end

        i = i + 1
    end
end

---
--
function HoseSystemConnector:preDelete()
    for _, class in pairs(self.connectStrategies) do
        if class.preDelete ~= nil then
            class:preDelete()
        end
    end
end

---
--
function HoseSystemConnector:delete()
    for _, class in pairs(self.connectStrategies) do
        if class.delete ~= nil then
            class:delete()
        end
    end

    HoseSystemUtil:removeElementFromList(g_currentMission.hoseSystemReferences, self)
    HoseSystemUtil:removeElementFromList(g_currentMission.dockingSystemReferences, self)
end

---
-- @param streamId
-- @param timestamp
-- @param connection
--
function HoseSystemConnector:readUpdateStream(streamId, timestamp, connection)
    for _, class in pairs(self.connectStrategies) do
        if class.readUpdateStream ~= nil then
            class:readUpdateStream(streamId, timestamp, connection)
        end
    end
end

---
-- @param streamId
-- @param connection
-- @param dirtyMask
--
function HoseSystemConnector:writeUpdateStream(streamId, connection, dirtyMask)
    for _, class in pairs(self.connectStrategies) do
        if class.writeUpdateStream ~= nil then
            class:writeUpdateStream(streamId, connection, dirtyMask)
        end
    end
end

---
-- @param streamId
-- @param connection
--
function HoseSystemConnector:readStream(streamId, connection)
    if connection:getIsServer() then
        --
    end

    for _, class in pairs(self.connectStrategies) do
        if class.readStream ~= nil then
            class:readStream(streamId, connection)
        end
    end
end

---
-- @param streamId
-- @param connection
--
function HoseSystemConnector:writeStream(streamId, connection)
    if not connection:getIsServer() then
        --
    end

    for _, class in pairs(self.connectStrategies) do
        if class.writeStream ~= nil then
            class:writeStream(streamId, connection)
        end
    end
end

---
-- @param nodeIdent
--
function HoseSystemConnector:getSaveAttributesAndNodes(nodeIdent)
    local nodes = ""

    if self.hoseSystemReferences ~= nil then
        for id, reference in pairs(self.hoseSystemReferences) do
            if id > 1 then
                nodes = nodes .. "\n"
            end

            nodes = nodes .. nodeIdent .. ('<reference id="%s" isLocked="%s" flowOpened="%s" />'):format(id, tostring(reference.isLocked), tostring(reference.flowOpened))
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
function HoseSystemConnector:mouseEvent(posX, posY, isDown, isUp, button)
end

---
-- @param unicode
-- @param sym
-- @param modifier
-- @param isDown
--
function HoseSystemConnector:keyEvent(unicode, sym, modifier, isDown)
end

---
-- @param dt
--
function HoseSystemConnector:update(dt)
    for _, class in pairs(self.connectStrategies) do
        if class.update ~= nil then
            class:update(dt)
        end
    end
end

---
-- @param dt
--
function HoseSystemConnector:updateTick(dt)
    for _, class in pairs(self.connectStrategies) do
        if class.updateTick ~= nil then
            class:updateTick(dt)
        end
    end
end

---
--
function HoseSystemConnector:draw()
end

---
--
function HoseSystemConnector:getIsPlayerInReferenceRange()
    local playerTrans = { getWorldTranslation(g_currentMission.player.rootNode) }
    local playerDistanceSequence = HoseSystemConnector.PLAYER_DISTANCE

    if self.hoseSystemReferences ~= nil then
        for referenceId, _ in pairs(self.attachedHoseSystemReferences) do
            local reference = self.hoseSystemReferences[referenceId]

            if reference ~= nil and reference.isUsed and not reference.parkable and reference.hoseSystem ~= nil then
                local trans = { getWorldTranslation(reference.node) }
                local distance = Utils.vector3Length(trans[1] - playerTrans[1], trans[2] - playerTrans[2], trans[3] - playerTrans[3])

                playerDistanceSequence = Utils.getNoNil(reference.inRangeDistance, playerDistanceSequence)

                if distance < playerDistanceSequence then
                    playerDistanceSequence = distance

                    return true, referenceId
                end
            end
        end
    end

    return false, nil
end

---
-- @param index
-- @param max
--
function HoseSystemConnector:getFillableVehicle(index, max)
    return index > 1 and 1 or max
end

---
-- @param index
-- @param state
-- @param force
-- @param noEventSend
--
function HoseSystemConnector:toggleLock(index, state, force, noEventSend)
    local reference = self.hoseSystemReferences[index]

    if reference ~= nil and not reference.parkable and reference.isLocked ~= state or force then
        HoseSystemReferenceLockEvent.sendEvent(self, index, state, force, noEventSend)

        if reference.lockAnimationName ~= nil then
            local dir = state and 1 or -1
            local shouldPlay = force or not self:getIsAnimationPlaying(reference.lockAnimationName)

            if shouldPlay then
                self:playAnimation(reference.lockAnimationName, dir, nil, true)
                reference.isLocked = state
            end
        else
            reference.isLocked = state
        end
    end
end

---
-- @param index
-- @param state
-- @param force
-- @param noEventSend
--
function HoseSystemConnector:toggleManureFlow(index, state, force, noEventSend)
    local reference = self.hoseSystemReferences[index]

    if reference ~= nil and not reference.parkable and reference.flowOpened ~= state or force then
        HoseSystemReferenceManureFlowEvent.sendEvent(self, index, state, force, noEventSend)

        if reference.manureFlowAnimationName ~= nil then
            local dir = state and 1 or -1
            local shouldPlay = force or not self:getIsAnimationPlaying(reference.manureFlowAnimationName)

            if shouldPlay then
                self:playAnimation(reference.manureFlowAnimationName, dir, nil, true)
                reference.flowOpened = state
            end
        else
            reference.flowOpened = state
        end
    end
end

---
-- @param index
-- @param state
-- @param hoseSystem
-- @param noEventSend
--
function HoseSystemConnector:setIsUsed(index, state, hoseSystem, noEventSend)
    -- Todo move to strategy
    if self.hoseSystemReferences ~= nil then
        local reference = self.hoseSystemReferences[index]

        if reference ~= nil and reference.isUsed ~= state then
            HoseSystemReferenceIsUsedEvent.sendEvent(reference.type, self, index, state, hoseSystem, noEventSend)

            reference.isUsed = state
            reference.hoseSystem = hoseSystem
            reference.grabPointId = HoseSystemHoseCouplingStrategy.getGrabPointIdFromReference(hoseSystem, self)

            if not reference.parkable then
                if reference.lockAnimationName == nil then
                    self:toggleLock(index, state, true, true)
                end

                if reference.manureFlowAnimationName == nil then
                    self:toggleManureFlow(index, state, true, true)
                end

                -- When detaching while on gameload we do need to sync the animations
                if not state then
                    if reference.isLocked then
                        self:toggleLock(index, not reference.isLocked, false, true)
                    end

                    if reference.flowOpened then
                        self:toggleManureFlow(index, not reference.flowOpened, false, true)
                    end
                end
            end

            if reference.parkable and reference.parkAnimationName ~= nil then
                local dir = state and 1 or -1

                if not self:getIsAnimationPlaying(reference.parkAnimationName) then
                    self:playAnimation(reference.parkAnimationName, dir, nil, true)
                end
            end
        end
    end
end

---
-- @param id
-- @param state
-- @param dockingArmObject
-- @param noEventSend
--
function HoseSystemConnector:setIsDockUsed(id, state, dockingArmObject, noEventSend)
    if self.dockingSystemReferences ~= nil then
        local reference = self.dockingSystemReferences[id]

        if reference ~= nil and reference.isUsed ~= state then
            HoseSystemReferenceIsUsedEvent.sendEvent(reference.type, self, id, state, dockingArmObject, noEventSend)

            reference.isUsed = state
            reference.dockingArmObject = dockingArmObject
        end
    end
end

---
--
function HoseSystemConnector:getIsOverloadingAllowed()
    return false
end

function HoseSystemConnector:onConnectorAttach(referenceId, hoseSystem)
    -- Todo: make this strategy based?
    -- register attached hoses this way
    local reference = self.hoseSystemReferences[referenceId]

    if reference ~= nil and self.attachedHoseSystemReferences[referenceId] == nil then
        self.attachedHoseSystemReferences[referenceId] = {
            showEffect = false
        }

        HoseSystemUtil:log(HoseSystemUtil.DEBUG, "Registered new hose! Total: " .. #self.attachedHoseSystemReferences)
    end

    if self.isServer then
        self:setIsUsed(referenceId, true, hoseSystem)
    end
end

function HoseSystemConnector:onConnectorDetach(referenceId)
    local reference = self.hoseSystemReferences[referenceId]

    if self.isServer then
        self:setIsUsed(referenceId, false)

        if self.hasHoseSystemPumpMotor then
            self:removeFillObject(self.fillObject, self.pumpMotorFillMode)
        end
    end

    if reference ~= nil and self.attachedHoseSystemReferences[referenceId] then
        self.attachedHoseSystemReferences[referenceId] = nil
        HoseSystemUtil:log(HoseSystemUtil.DEBUG, "Unregistered hose: " .. #self.attachedHoseSystemReferences)
    end
end