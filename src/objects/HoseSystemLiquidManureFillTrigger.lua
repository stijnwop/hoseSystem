--
-- HoseSystemLiquidManureFillTrigger
--
-- Authors: Wopster
-- Description: Overwritten liquidManureTrigger to function with the HoseSystem
-- Note: Uses parts from the LiquidManureFillTriggerExtension (FS15) from Xentro.
--
-- Copyright (c) Wopster and Xentro, 2017

HoseSystemLiquidManureFillTrigger = {}

HoseSystemLiquidManureFillTrigger.PLAYER_DISTANCE = 1.3
HoseSystemLiquidManureFillTrigger.PLANE_IDLE = 15
HoseSystemLiquidManureFillTrigger.LEVEL_CHANGE_TRESHOLD_TIME = 100 -- ms
HoseSystemLiquidManureFillTrigger.RESET_CHANGE_TRESHOLD_TIME = 500 -- ms

---
-- @param superFunc
-- @param mt
--
function HoseSystemLiquidManureFillTrigger:new(superFunc, mt)
    local trigger = superFunc(self, mt)

    trigger.supportsHoseSystem = false
    trigger.offsetY = 0
    trigger.lastFillLevelChangeTime = 0
    trigger.inRageReferenceIndex = nil

    return trigger
end

---
-- @param superFunc
-- @param nodeId
-- @param fillLevelObject
-- @param fillType
--
function HoseSystemLiquidManureFillTrigger:load(superFunc, nodeId, fillLevelObject, fillType)
    if superFunc(self, nodeId, fillLevelObject, fillType) then
        local xmlFilename = getUserAttribute(nodeId, 'xmlFilename')

        if xmlFilename == nil then
            if HoseSystem.debugRendering then
                HoseSystemUtil:log(HoseSystemUtil.WARNING, 'HoseSystemFillTrigger is trying to load the xml file, but the file could not be found! Loading default triggers..')
            end

            return true
        end

        self.getCapacity = HoseSystemLiquidManureFillTrigger.getCapacity
        self.getFreeCapacity = HoseSystemLiquidManureFillTrigger.getFreeCapacity
        self.allowFillType = HoseSystemLiquidManureFillTrigger.allowFillType
        self.getCurrentFillTypes = HoseSystemLiquidManureFillTrigger.getCurrentFillTypes
        self.resetFillLevelIfNeeded = HoseSystemLiquidManureFillTrigger.resetFillLevelIfNeeded
        self.getFillLevel = HoseSystemLiquidManureFillTrigger.getFillLevel
        self.updateShaderPlane = HoseSystemLiquidManureFillTrigger.updateShaderPlane -- shader stuff
        self.updateShaderPlaneGraphics = HoseSystemLiquidManureFillTrigger.updateShaderPlaneGraphics -- shader stuff

        self.getNearestReference = HoseSystemLiquidManureFillTrigger.getNearestReference
        self.setIsUsed = HoseSystemLiquidManureFillTrigger.setIsUsed
        self.toggleLock = HoseSystemLiquidManureFillTrigger.toggleLock
        self.toggleManureFlow = HoseSystemLiquidManureFillTrigger.toggleManureFlow
        self.onConnectorAttach = HoseSystemLiquidManureFillTrigger.onConnectorAttach
        self.onConnectorDetach = HoseSystemLiquidManureFillTrigger.onConnectorDetach

        -- detection for hose
        self.checkPlaneY = HoseSystemLiquidManureFillTrigger.checkPlaneY
        self.checkNode = HoseSystemLiquidManureFillTrigger.checkNode

        self.delete = Utils.overwrittenFunction(self.delete, HoseSystemLiquidManureFillTrigger.delete)
        self.update = Utils.overwrittenFunction(self.update, HoseSystemLiquidManureFillTrigger.update)
        self.setFillLevel = Utils.overwrittenFunction(self.setFillLevel, HoseSystemLiquidManureFillTrigger.setFillLevel)
        self.getIsActivatable = Utils.overwrittenFunction(self.getIsActivatable, HoseSystemLiquidManureFillTrigger.getIsActivatable)

        self.components = {}
        self.referenceNodes = {}
        self.hoseSystemReferences = {}
        self.attachedHoseSystemReferences = {}

        local baseDirectory = g_currentMission.loadingMapBaseDirectory

        if baseDirectory == "" then
            baseDirectory = Utils.getNoNil(self.baseDirectory, baseDirectory)
        end

        self.xmlFilename = Utils.getFilename(xmlFilename, baseDirectory)
        local xmlFile = loadXMLFile('hoseSystemFillTrigger', self.xmlFilename)

        if xmlFile ~= 0 then
            local objectIdentifier = getUserAttribute(nodeId, 'identifier')

            if objectIdentifier ~= nil then
                local i = 0
                local key

                while true do
                    local objectXMLKey = string.format('map.hoseSystemFillTriggers.hoseSystemFillTrigger(%d)', i)

                    if not hasXMLProperty(xmlFile, objectXMLKey) then
                        break
                    end

                    local objectXMLIdentifier = getXMLString(xmlFile, objectXMLKey .. '#identifier')

                    if objectXMLIdentifier:lower() == objectIdentifier:lower() then
                        key = objectXMLKey
                        break
                    end

                    i = i + 1
                end

                if key ~= nil then
                    local pitKey = string.format('%s.pit', key)

                    if hasXMLProperty(xmlFile, pitKey) then
                        local detectionNode = Utils.indexToObject(nodeId, getXMLString(xmlFile, pitKey .. '#bottomNode'))

                        if detectionNode ~= nil then
                            self.detectionNode = detectionNode
                            g_currentMission:addNodeObject(self.detectionNode, self)
                        end

                        local coverNode = Utils.indexToObject(nodeId, getXMLString(xmlFile, pitKey .. '#coverNode'))

                        if coverNode ~= nil then
                            self.coverNode = coverNode
                        end

                        local offsetY = getXMLFloat(xmlFile, pitKey .. '#offsetY')

                        if offsetY ~= nil then
                            self.offsetY = offsetY
                        end

                        self.moveMinY = getXMLFloat(xmlFile, pitKey .. '#planeMinY')
                        self.moveMaxY = getXMLFloat(xmlFile, pitKey .. '#planeMaxY')
                        self.movingId = Utils.indexToObject(nodeId, getXMLString(xmlFile, pitKey .. '#planeNode'))

                        self.animatedObjectSaveId = getXMLString(xmlFile, pitKey .. '#animatedObjectSaveId')
                    end

                    HoseSystemLiquidManureFillTrigger.loadHoseSystemReferences(self, nodeId, xmlFile, string.format('%s.hoseSystemReferences.', key), self.hoseSystemReferences)
                else
                    HoseSystemUtil:log(HoseSystemUtil.ERROR, 'HoseSystemFillTrigger - identifier could not be found the in the xml!')
                end
            else
                HoseSystemUtil:log(HoseSystemUtil.ERROR, 'HoseSystemFillTrigger - please define an identifier in your user attributes.')
            end
        else
            HoseSystemUtil:log(HoseSystemUtil.ERROR, "HoseSystemFillTrigger - error loading xml file! Please check your filepath.")
        end

        delete(xmlFile)

        local referencesCount = #self.hoseSystemReferences

        if referencesCount > 0 then
            if g_currentMission.hoseSystemReferences == nil then
                g_currentMission.hoseSystemReferences = {}
            end

            table.insert(g_currentMission.hoseSystemReferences, self)
        end

        -- well this should hold the supported fillModes
        -- self.fillModes = {}
        self.supportsHoseSystem = self.detectionNode ~= nil or referencesCount > 0
        self.shaderOnIdle = true
        self.referenceType = HoseSystemConnectorFactory.getInitialType(HoseSystemConnectorFactory.TYPE_HOSE_COUPLING)

        g_currentMission:addNodeObject(self.nodeId, self)

        if self.fillLevelObject ~= nil then
            self.fillLevelObject.hoseSystemParent = self
        end

        return true
    end

    return false
end

---
-- @param self
-- @param nodeId
-- @param xmlFile
-- @param base
-- @param references
--
function HoseSystemLiquidManureFillTrigger.loadHoseSystemReferences(self, nodeId, xmlFile, base, references)
    local i = 0

    while true do
        local key = string.format(base .. 'hoseSystemReference(%d)', i)

        if not hasXMLProperty(xmlFile, key) then
            break
        end

        if #references == 2 ^ HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS then
            HoseSystemUtil:log(HoseSystemUtil.ERROR, ('Max number of references is %s!'):format(2 ^ HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS))
            break
        end

        local node = Utils.indexToObject(nodeId, getXMLString(xmlFile, key .. '#node'))

        if node ~= nil then
            local id = i + 1

            self.referenceNodes[id] = node

            g_currentMission:addNodeObject(self.referenceNodes[id], self)

            -- build dummy component node
            self.components[id] = {
                node = nodeId
            }

            local entry = {
                id = id,
                node = self.referenceNodes[id],
                isUsed = false,
                flowOpened = false,
                isLocked = false,
                liquidManureHose = nil,
                grabPoints = nil,
                isObject = true,
                componentIndex = id, -- where to joint to?
                parkable = false,
                inRangeDistance = Utils.getNoNil(getXMLFloat(xmlFile, key .. 'inRangeDistance'), 1.3),
                lockAnimatedObjectSaveId = Utils.getNoNil(getXMLString(xmlFile, key .. '#lockAnimatedObjectSaveId'), nil),
                manureFlowAnimatedObjectSaveId = Utils.getNoNil(getXMLString(xmlFile, key .. '#manureFlowAnimatedObjectSaveId'), nil)
            }

            table.insert(references, entry)
        end

        i = i + 1
    end
end

---
-- @param superFunc
--
function HoseSystemLiquidManureFillTrigger:delete(superFunc)
    if superFunc ~= nil then
        superFunc(self)
    end

    if self.detectionNode ~= nil then
        g_currentMission:removeNodeObject(self.detectionNode)
    end

    if self.referenceNodes ~= nil then
        for _, referenceNode in pairs(self.referenceNodes) do
            g_currentMission:removeNodeObject(referenceNode)
        end
    end

    HoseSystemUtil:removeElementFromList(g_currentMission.hoseSystemReferences, self)
end

---
-- @param superFunc
-- @param dt
--
function HoseSystemLiquidManureFillTrigger:update(superFunc, dt)
    if superFunc ~= nil then
        superFunc(self, dt)
    end

    if self.fillLevelObject.isClient then
        if not self.playerInRange then
            if g_currentMission.animatedObjects ~= nil then -- Note: this is only possible with the extension
                local object = g_currentMission.animatedObjects[self.animatedObjectSaveId]

                if object ~= nil then
                    self.isEnabled = object.animation.time == 1
                end
            end
        end

        if self.playerInRange then
            if g_currentMission.animatedObjects ~= nil then
                self.inRageReferenceIndex = self:getNearestReference({ getWorldTranslation(g_currentMission.player.rootNode) })

                if self.inRageReferenceIndex ~= nil then
                    local reference = self.hoseSystemReferences[self.inRageReferenceIndex]

                    if reference ~= nil then
                        if reference.lockAnimatedObjectSaveId ~= nil then
                            local animatedObject = g_currentMission.animatedObjects[reference.lockAnimatedObjectSaveId]

                            if animatedObject ~= nil then
                                -- Todo: do the animation
                            end
                        else
                            if not reference.isLocked then
                                self:toggleLock(self.inRageReferenceIndex, true, true)
                            end
                        end

                        if reference.isLocked then
                            if reference.manureFlowAnimatedObjectSaveId ~= nil then
                                local animatedObject = g_currentMission.animatedObjects[reference.lockAnimatedObjectSaveId]

                                if animatedObject ~= nil then
                                    -- Todo: do the animation
                                end
                            else
                                if not reference.flowOpened then
                                    self:toggleManureFlow(self.inRageReferenceIndex, true, true)
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Set plane to idle when there's no recent changes to the fill level
        if not self.shaderOnIdle and self.lastFillLevelChangeTime + HoseSystemLiquidManureFillTrigger.LEVEL_CHANGE_TRESHOLD_TIME < g_currentMission.time then
            self:updateShaderPlane(false)
        end
    end
end

---
-- @param playerTrans
--
function HoseSystemLiquidManureFillTrigger:getNearestReference(playerTrans)
    if self.hoseSystemReferences == nil or next(self.attachedHoseSystemReferences) == nil then
        return nil
    end

    local x, y, z = unpack(playerTrans)
    local nearestDisSequence = HoseSystemLiquidManureFillTrigger.PLAYER_DISTANCE

    for referenceId, _ in pairs(self.attachedHoseSystemReferences) do
        local reference = self.hoseSystemReferences[referenceId]

        if reference ~= nil and reference.isUsed and reference.hoseSystem ~= nil then
            for grabPointIndex, grabPoint in pairs(reference.hoseSystem.grabPoints) do
                if HoseSystem:getIsConnected(grabPoint.state) and grabPoint.connectorRefId == referenceIndex then
                    local gx, gy, gz = getWorldTranslation(reference.node)
                    local dist = Utils.vector3Length(x - gx, y - gy, z - gz)

                    nearestDisSequence = Utils.getNoNil(reference.inRangeDistance, nearestDisSequence)

                    if dist < nearestDisSequence then
                        nearestDisSequence = dist

                        return referenceIndex
                    end
                end
            end
        end
    end

    return nil
end

---
-- @param superFunc
-- @param fillable
--
function HoseSystemLiquidManureFillTrigger:getIsActivatable(superFunc, fillable)
    if superFunc(self, fillable) then
        if self.supportsHoseSystem then
            if fillable.hasHoseSystem ~= nil and fillable.hasHoseSystem then
                return false
            end
        end

        return true
    end

    return false
end

---
-- @param fillType
-- @param allowEmptying
--
function HoseSystemLiquidManureFillTrigger:allowFillType(fillType, allowEmptying)
    return fillType == FillUtil.FILLTYPE_UNKNOWN or fillType == self.fillType
end

---
--
function HoseSystemLiquidManureFillTrigger:getCurrentFillTypes()
    return { self.fillType }
end

---
-- @param fillType
--
function HoseSystemLiquidManureFillTrigger:resetFillLevelIfNeeded(fillType)
    if self.lastFillLevelChangeTime + HoseSystemLiquidManureFillTrigger.RESET_CHANGE_TRESHOLD_TIME > g_currentMission.time then
        return false
    end

    self:setFillLevel(0)

    return true
end

---
-- @param superFunc
-- @param fillLevel
-- @param noEventSend
--
function HoseSystemLiquidManureFillTrigger:setFillLevel(superFunc, fillLevel, noEventSend)
    fillLevel = Utils.clamp(fillLevel, 0, self.capacity)

    if self.fillLevel ~= fillLevel then
        self.fillLevel = fillLevel

        if noEventSend == nil or not noEventSend then
            self.fillLevelObject:liquidManureFillLevelChanged(fillLevel, self.fillType, self)
        end

        if self.fillLevelObject.isClient then
            if self.movingId ~= nil then
                local x, y, z = getTranslation(self.movingId)
                local y = self.moveMinY + (self.moveMaxY - self.moveMinY) * self.fillLevel / self.capacity
                setTranslation(self.movingId, x, y, z)
            end
        end
    end

    self.lastFillLevelChangeTime = g_currentMission.time
end

---
-- @param fillType
--
function HoseSystemLiquidManureFillTrigger:getFillLevel(fillType)
    if fillType == nil then
        return self.fillLevel
    end

    return fillType == self.fillType and self.fillLevel or 0
end

---
-- @param fillType
--
function HoseSystemLiquidManureFillTrigger:getCapacity(fillType)
    if fillType == nil then
        return self.capacity
    end

    return fillType == self.fillType and self.capacity or 0
end

---
-- @param fillType
--
function HoseSystemLiquidManureFillTrigger:getFreeCapacity(fillType)
    return self:getCapacity(fillType) - self:getFillLevel(fillType)
end

---
-- @param nodeId
--
function HoseSystemLiquidManureFillTrigger:checkNode(nodeId)
    return self.isEnabled and self.detectionNode == nodeId or false
end

---
-- @param y
--
function HoseSystemLiquidManureFillTrigger:checkPlaneY(y)
    local _, py, _ = getWorldTranslation(self.movingId)
    py = py + self.offsetY

    return py >= y, py
end

---
-- @param pumpIsStarted
-- @param pumpDirection
-- @param literPerSeconds
--
function HoseSystemLiquidManureFillTrigger:updateShaderPlane(pumpIsStarted, pumpDirection, literPerSeconds) -- what more?
    if self.fillLevelObject.isServer and self.supportsHoseSystem then -- sync to clients
        g_server:broadcastEvent(UpdatePlaneEvent:new(self.fillLevelObject, pumpIsStarted, pumpDirection, literPerSeconds))
    end

    if self.fillLevelObject.isClient and self.supportsHoseSystem then
        if getHasShaderParameter(self.movingId, 'displacementScaleSpeedFrequency') then
            if pumpIsStarted then
                self.shaderOnIdle = false

                local frequency = pumpDirection == HoseSystemPumpMotor.IN and literPerSeconds / 10 or literPerSeconds / 10 * 2
                local speed = pumpDirection == HoseSystemPumpMotor.IN and literPerSeconds / 100 * 1.5 or (literPerSeconds / 100 * 1.5) * 2

                self:updateShaderPlaneGraphics(self.movingId, HoseSystemUtil:mathRound(speed, 2), HoseSystemUtil:mathRound(frequency, 2))
            else
                if not self.shaderOnIdle then
                    self:updateShaderPlaneGraphics(self.movingId, 0.1, HoseSystemLiquidManureFillTrigger.PLANE_IDLE) -- idle is hardcoded
                    self.shaderOnIdle = true
                end
            end
        end
    end
end

---
-- @param node
-- @param speed
-- @param frequency
--
function HoseSystemLiquidManureFillTrigger:updateShaderPlaneGraphics(node, speed, frequency)
    local scale, x, y, _ = getShaderParameter(node, 'displacementScaleSpeedFrequency')

    if HoseSystemUtil:mathRound(x, 2) ~= speed and HoseSystemUtil:mathRound(y, 2) ~= frequency then
        setShaderParameter(node, 'displacementScaleSpeedFrequency', scale, speed, frequency, 1, false)
    end
end

---
-- @param index
-- @param state
-- @param force
-- @param noEventSend
--
function HoseSystemLiquidManureFillTrigger:toggleLock(index, state, force, noEventSend)
    local reference = self.hoseSystemReferences[index]

    if reference ~= nil and reference.isLocked ~= state or force then
        HoseSystemReferenceLockEvent.sendEvent(self.fillLevelObject.hoseSystemParent, index, state, force, noEventSend)


        if g_currentMission.animatedObjects ~= nil then
            local animatedObject = g_currentMission.animatedObjects[reference.lockAnimatedObjectSaveId]

            if animatedObject ~= nil then
                -- Todo: implement animation
            end
        end

        reference.isLocked = state
    end
end

---
-- @param index
-- @param state
-- @param force
-- @param noEventSend
--
function HoseSystemLiquidManureFillTrigger:toggleManureFlow(index, state, force, noEventSend)
    local reference = self.hoseSystemReferences[index]

    if reference ~= nil and reference.flowOpened ~= state or force then
        HoseSystemReferenceManureFlowEvent.sendEvent(self.fillLevelObject.hoseSystemParent, index, state, force, noEventSend)

        if g_currentMission.animatedObjects ~= nil then
            local animatedObject = g_currentMission.animatedObjects[reference.manureFlowAnimatedObjectSaveId]

            if animatedObject ~= nil then
                -- Todo: implement animation
            end
        end

        reference.flowOpened = state
    end
end

---
-- @param index
-- @param state
-- @param noEventSend
--
function HoseSystemLiquidManureFillTrigger:setIsUsed(index, state, hoseSystem, noEventSend)
    local reference = self.hoseSystemReferences[index]

    if reference ~= nil and reference.isUsed ~= state then
        HoseSystemReferenceIsUsedEvent.sendEvent(self.referenceType, self.fillLevelObject.hoseSystemParent, index, state, hoseSystem, noEventSend)

        reference.isUsed = state
        reference.hoseSystem = hoseSystem

        if reference.lockAnimatedObjectSaveId == nil then
            self:toggleLock(index, state, true)
        end

        if reference.manureFlowAnimatedObjectSaveId == nil then
            self:toggleManureFlow(index, state, true)
        end
    end
end

function HoseSystemLiquidManureFillTrigger:onConnectorAttach(referenceId, hoseSystem)
    -- register attached hoses this way
    local reference = self.hoseSystemReferences[referenceId]

    if reference ~= nil and self.attachedHoseSystemReferences[referenceId] == nil then
        self.attachedHoseSystemReferences[referenceId] = {
            showEffect = false
        }

        HoseSystemUtil:log(HoseSystemUtil.DEBUG, "register attached hose by object")
        HoseSystemUtil:log(HoseSystemUtil.DEBUG, self.attachedHoseSystemReferences)
    end

    if self.fillLevelObject.isServer then
        self:setIsUsed(referenceId, true, hoseSystem)
    end
end

function HoseSystemLiquidManureFillTrigger:onConnectorDetach(referenceId)
    local reference = self.hoseSystemReferences[referenceId]

    if self.fillLevelObject.isServer then
        self:setIsUsed(referenceId, false)
    end

    if reference ~= nil and self.attachedHoseSystemReferences[referenceId] then
        self.attachedHoseSystemReferences[referenceId] = nil
        HoseSystemUtil:log(HoseSystemUtil.DEBUG, "unregister attached hose by object")
        HoseSystemUtil:log(HoseSystemUtil.DEBUG, self.attachedHoseSystemReferences)
    end
end

-- LiquidManureFillTrigger
LiquidManureFillTrigger.new = Utils.overwrittenFunction(LiquidManureFillTrigger.new, HoseSystemLiquidManureFillTrigger.new)
LiquidManureFillTrigger.load = Utils.overwrittenFunction(LiquidManureFillTrigger.load, HoseSystemLiquidManureFillTrigger.load)

-- TipTrigger
-- TipTrigger.load = Utils.overwrittenFunction(TipTrigger.load, HoseSystemLiquidManureFillTrigger.load) -- overwrite to be albe to pump water?

UpdatePlaneEvent = {}
UpdatePlaneEvent_mt = Class(UpdatePlaneEvent, Event)

InitEventClass(UpdatePlaneEvent, 'UpdatePlaneEvent')

function UpdatePlaneEvent:emptyNew()
    local event = Event:new(UpdatePlaneEvent_mt)
    return event
end

function UpdatePlaneEvent:new(object, pumpIsStarted, pumpDirection, literPerSeconds)
    local event = UpdatePlaneEvent:emptyNew()

    event.object = object
    event.pumpIsStarted = pumpIsStarted
    event.pumpDirection = pumpDirection
    event.literPerSeconds = literPerSeconds

    return event
end

function UpdatePlaneEvent:writeStream(streamId, connection)
    --    if not connection:getIsServer() then
    writeNetworkNodeObject(streamId, self.object)
    streamWriteBool(streamId, self.pumpIsStarted)

    if self.pumpIsStarted then
        streamWriteInt8(streamId, self.pumpDirection)
        streamWriteInt32(streamId, self.literPerSeconds)
    end
    --    end
end

function UpdatePlaneEvent:readStream(streamId, connection)
    --    if not connection:getIsServer() then
    self.object = readNetworkNodeObject(streamId)
    self.pumpIsStarted = streamReadBool(streamId)

    if self.pumpIsStarted then
        self.pumpDirection = streamReadInt8(streamId)
        self.literPerSeconds = streamReadInt32(streamId)
    end
    --    end
    self:run(connection)
end

function UpdatePlaneEvent:run(connection)
    --    if not connection:getIsServer() then
    self.object.hoseSystemParent:updateShaderPlane(self.pumpIsStarted, self.pumpDirection, self.literPerSeconds)
    --    end
end
