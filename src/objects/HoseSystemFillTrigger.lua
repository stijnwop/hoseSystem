--
-- HoseSystemFillTrigger
--
-- Authors: Wopster
-- Description: Base class for the HoseSystemFillTrigger
--
-- Copyright (c) Wopster, 2018

HoseSystemFillTrigger = {}

HoseSystemFillTrigger.TRIGGER_CALLBACK = "triggerCallback"

HoseSystemFillTrigger.TYPE_EXPENSES = 1
HoseSystemFillTrigger.TYPE_CAPACITY = 2

HoseSystemFillTrigger.stringToTypes = {
    ["expenses"] = HoseSystemFillTrigger.TYPE_EXPENSES,
    ["capacity"] = HoseSystemFillTrigger.TYPE_CAPACITY
}

local HoseSystemFillTrigger_mt = Class(HoseSystemFillTrigger, Object)

function HoseSystemFillTrigger:preLoadHoseSystem()
end

---
-- @param mt
-- @param nodeId
--
function HoseSystemFillTrigger:new(isServer, isClient, mt, nodeId, strategyStr, hasNetworkParent)
    local strategyType = HoseSystemFillTrigger.stringToTypes[strategyStr:lower()]

    if strategyType == nil then
        HoseSystemUtil:log(HoseSystemUtil.ERROR, "No strategy type specified!")
        return
    end

    local mt = mt == nil and HoseSystemFillTrigger_mt or mt

    local trigger = {}

    if not hasNetworkParent then
        print("Register network object")
        trigger = Object:new(isServer, isClient, mt)
        trigger:register()

        trigger.fillDirtyFlag = trigger:getNextDirtyFlag()
        trigger.hoseSystemDirtyFlag = trigger:getNextDirtyFlag()
    else
        setmetatable(trigger, mt)
    end

    trigger.triggerId = nil
    trigger.nodeId = nodeId

    local strategy
    if strategyType == HoseSystemFillTrigger.TYPE_EXPENSES then
        strategy = HoseSystemExpensesStrategy:new(trigger)
    elseif strategyType == HoseSystemFillTrigger.TYPE_CAPACITY then
        strategy = HoseSystemCapacityStrategy:new(trigger)
    end

    trigger.strategy = strategy
    trigger.vehiclesInRange = {}
    trigger.playerInRange = false

    return trigger
end

---
-- @param nodeId
-- @param fillType
-- @param fillLevelObject
--
function HoseSystemFillTrigger:load(nodeId, fillLevelObject, fillType)
    if fillLevelObject ~= nil then
        fillLevelObject.hoseSystemParent = self

        self.isClient = fillLevelObject.isClient
        self.isServer = fillLevelObject.isServer
        self.hoseSystemDirtyFlag = fillLevelObject:getNextDirtyFlag()
    end

    self.fillLevelObject = fillLevelObject

    local xmlFilename = getUserAttribute(nodeId, 'xmlFilename')

    if xmlFilename == nil then
        if HoseSystem.debugRendering then
            HoseSystemUtil:log(HoseSystemUtil.WARNING, ("HoseSystemFillTrigger is trying to load the trigger '%s', but it's not prepared for it! Loading default triggers.."):format(getName(nodeId)))
        end

        return false
    end

    if not HoseSystemObjectsUtil.getIsNodeValid(nodeId) then
        --        return false
    end

    if self.nodeId == nil then
        self.nodeId = nodeId
    end

    self.triggerId = Utils.indexToObject(nodeId, getUserAttribute(nodeId, "triggerIndex"))
    if self.triggerId == nil then
        self.triggerId = nodeId
    end

    if not HoseSystemObjectsUtil.getIsValidTrigger(self.triggerId) then
        --        return false
    end

    addTrigger(self.triggerId, HoseSystemFillTrigger.TRIGGER_CALLBACK, self)

    self.fillType = Utils.getNoNil(fillType, self.fillType)

    if self.fillType == nil then
        self.fillType = HoseSystemFillTrigger.getFillTypeFromUserAttribute(nodeId)
    end

    -- Load the strategy
    self.strategy:load()

    local baseDirectory = g_currentMission.loadingMapBaseDirectory

    if baseDirectory == "" then
        baseDirectory = Utils.getNoNil(self.baseDirectory, baseDirectory)
    end

    self.xmlFilename = Utils.getFilename(xmlFilename, baseDirectory)
    local xmlFile = loadXMLFile('hoseSystemFillTrigger_' .. tostring(nodeId), self.xmlFilename)

    -- setup dummy component
    self.components = {}

    table.insert(self.components, { node = nodeId })

    self.referenceNodes = {}
    self.hoseSystemReferences = {}
    self.attachedHoseSystemReferences = {}

    if xmlFile ~= 0 then
        local xmlKey = HoseSystemFillTrigger.getTriggerXmlKey(nodeId, xmlFile)

        if xmlKey ~= nil then
            HoseSystemFillTrigger.loadHoseSystemPit(self, nodeId, xmlFile, xmlKey)
            HoseSystemFillTrigger.loadHoseSystemReferences(self, nodeId, xmlFile, string.format('%s.hoseSystemReferences.', xmlKey), self.hoseSystemReferences)
        end
    else
        HoseSystemUtil:log(HoseSystemUtil.ERROR, "Could not find XML file at path: " .. self.xmlFilename)
    end

    delete(xmlFile)

    local hasReferences = next(self.hoseSystemReferences) ~= nil
    self.supportsHoseSystem = self.detectionNode ~= nil or hasReferences

    if hasReferences then
        table.insert(g_hoseSystem.hoseSystemReferences, self)
    end

    self.isEnabled = true

    return true
end

function HoseSystemFillTrigger:readStream(streamId)
    if connection:getIsServer() then
        if self.fillLevelObject == nil then
            self:setFillLevel(streamReadUInt16(streamId) / 65535.0 * self.capacity, true)
        end
    end
end

function HoseSystemFillTrigger:writeStream(streamId)
    if not connection:getIsServer() then
        if self.fillLevelObject == nil then
            local trivialFillLevel = math.floor(self.fillLevel * 65535.0 / self.capacity)
            streamWriteUInt16(streamId, trivialFillLevel)
        end
    end
end

function HoseSystemFillTrigger:readUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        if self.fillLevelObject == nil then
            local fillLevelDirty = streamReadBool(streamId)

            if fillLevelDirty then
                self:setFillLevel(streamReadUInt16(streamId) / 65535.0 * self.capacity, true)
            end
        end
    end
end

function HoseSystemFillTrigger:writeUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        if self.fillLevelObject == nil then
            if streamWriteBool(streamId, bitAND(dirtyMask, self.fillDirtyFlag) ~= 0) then
                -- write shader plane and write fillLevel (compressed?)
                local trivialFillLevel = math.floor(self.fillLevel * 65535.0 / self.capacity)
                streamWriteUInt16(streamId, trivialFillLevel)
            end
        end
    end
end

---
--
function HoseSystemFillTrigger:delete()
    self.strategy:delete()

    removeTrigger(self.triggerId)

    if self.detectionNode ~= nil then
        g_currentMission:removeNodeObject(self.detectionNode)
    end

    if self.referenceNodes ~= nil then
        for _, referenceNode in pairs(self.referenceNodes) do
            g_currentMission:removeNodeObject(referenceNode)
        end
    end

    if self.fillLevelObject ~= nil then
        self.fillLevelObject.hoseSystemParent = nil
        self.fillLevelObject = nil
    end

    HoseSystemUtil:removeElementFromList(g_hoseSystem.hoseSystemReferences, self)
end

---
-- @param dt
--
function HoseSystemFillTrigger:update(dt)
    if self.isClient then
        if not self.playerInRange then
            if g_currentMission.animatedObjects ~= nil then -- Note: this is only possible with the extension
                local object = g_currentMission.animatedObjects[self.animatedObjectSaveId]

                if object ~= nil then
                    self.isEnabled = object.animation.time == 1
                end
            end
        end
    end

    if self.strategy.update ~= nil then
        self.strategy:update(dt)
    end
end

---
-- @param dt
--
function HoseSystemFillTrigger:updateTick(dt)
    if self.isServer then
        -- handle dirty flag
    end

    if self.strategy.updateTick ~= nil then
        self.strategy:updateTick(dt)
    end
end

---
-- @param referenceId
-- @param hoseSystem
--
function HoseSystemFillTrigger:onConnectorAttach(referenceId, hoseSystem)
    -- register attached hoses this way
    local reference = self.hoseSystemReferences[referenceId]

    if reference ~= nil and self.attachedHoseSystemReferences[referenceId] == nil then
        self.attachedHoseSystemReferences[referenceId] = {
            showEffect = false
        }

        HoseSystemUtil:log(HoseSystemUtil.DEBUG, "register attached hose by object")
        HoseSystemUtil:log(HoseSystemUtil.DEBUG, self.attachedHoseSystemReferences)
    end

    -- Todo: test if really needed to sync with our own events
    if self.isServer then
        self:setIsUsed(referenceId, true, hoseSystem)
    end
end

---
-- @param referenceId
--
function HoseSystemFillTrigger:onConnectorDetach(referenceId)
    local reference = self.hoseSystemReferences[referenceId]

    if self.isServer then
        self:setIsUsed(referenceId, false)
    end

    if reference ~= nil and self.attachedHoseSystemReferences[referenceId] then
        self.attachedHoseSystemReferences[referenceId] = nil
        HoseSystemUtil:log(HoseSystemUtil.DEBUG, "unregister attached hose by object")
        HoseSystemUtil:log(HoseSystemUtil.DEBUG, self.attachedHoseSystemReferences)
    end
end

---
-- @param nodeId
--
function HoseSystemFillTrigger:checkNode(nodeId)
    return self.isEnabled and self.detectionNode == nodeId or false
end

---
-- @param y
--
function HoseSystemFillTrigger:checkPlaneY(y)
    local _, py, _ = getWorldTranslation(self.movingId)
    py = py + self.offsetY

    return py >= y, py
end

---
-- @param fillType
--
function HoseSystemFillTrigger:resetFillLevelIfNeeded(fillType)
    --    if self.lastFillLevelChangeTime + HoseSystemLiquidManureFillTrigger.RESET_CHANGE_TRESHOLD_TIME > g_currentMission.time then
    --        return false
    --    end
    --
    --    self:setFillLevel(0)
    --
    --    return true
    return false
end

---
-- @param fillType
--
function HoseSystemFillTrigger:allowFillType(fillType)
    return fillType == FillUtil.FILLTYPE_UNKNOWN or fillType == self.fillType
end

---
-- @param fillType
--
function HoseSystemFillTrigger:getFillLevel(fillType)
    return self.strategy:getFillLevel(fillType)
end

---
--
function HoseSystemFillTrigger:getCurrentFillTypes()
    return { self.fillType }
end

---
-- @param fillType
--
function HoseSystemFillTrigger:getCapacity(fillType)
    return self.strategy:getCapacity(fillType)
end

---
-- @param fillType
--
function HoseSystemFillTrigger:getFreeCapacity(fillType)
    return self.strategy:getFreeCapacity(fillType)
end

---
-- @param fillLevel
-- @param noEventSend
-- @param delta
-- @param fillDirection
--
function HoseSystemFillTrigger:setFillLevel(fillLevel, noEventSend, delta, fillDirection)
    self.strategy:setFillLevel(fillLevel, noEventSend, delta)

    if noEventSend == nil or not noEventSend then
        if self.isServer then
            if self.fillLevelObject ~= nil then
                self.fillLevelObject:liquidManureFillLevelChanged(fillLevel, self.fillType, self)
            else
                self:raiseDirtyFlags(self.fillDirtyFlag)
            end

            if self.sendFillDirection ~= fillDirection or self.sendDelta ~= delta then
                self.sendFillDirection = fillDirection
                self.sendDelta = delta

                --                self:raiseDirtyFlags(self.hoseSystemDirtyFlag)
                self:updatePlaneGraphics(self.movingId, fillDirection, delta)
            end
        end
    end
end

---
-- @param fillable
--
function HoseSystemFillTrigger:getIsActivatable(fillable)
    -- Todo: this will be for the fill triggers from giants..
    if self.supportsHoseSystem then
        if fillable.hasHoseSystem ~= nil and fillable.hasHoseSystem then
            return false
        end
    end

    if not self.strategy:getIsActivatable(fillable) then
        return false
    end

    if not fillable:allowFillType(self.fillType, false) then
        return false
    end

    return true
end

---
-- @param triggerId
-- @param otherActorId
-- @param onEnter
-- @param onLeave
-- @param onStay
-- @param otherShapeId
--
function HoseSystemFillTrigger:triggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    if self.isEnabled and (onEnter or onLeave) then
        if g_currentMission.player ~= nil and otherActorId == g_currentMission.player.rootNode then
            self.playerInRange = onEnter
        else
            local vehicle = g_currentMission.nodeToVehicle[otherActorId]

            if vehicle ~= nil then
                self.vehiclesInRange[vehicle] = onEnter and true or nil
            end
        end
    end

    self.strategy:triggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
end

---
-- @param nodeId
--
function HoseSystemFillTrigger.getFillTypeFromUserAttribute(nodeId)
    local fillTypeStr = getUserAttribute(nodeId, "fillType")

    if fillTypeStr ~= nil then
        local desc = FillUtil.fillTypeNameToDesc[fillTypeStr]

        if desc ~= nil then
            return desc.index
        end
    end

    return FillUtil.FILLTYPE_UNKNOWN
end

---
-- @param self
-- @param nodeId
-- @param xmlFile
-- @param baseKey
--
function HoseSystemFillTrigger.loadHoseSystemPit(self, nodeId, xmlFile, baseKey)
    local pitKey = ("%s.pit"):format(baseKey)

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

        self.offsetY = Utils.getNoNil(getXMLFloat(xmlFile, pitKey .. '#offsetY'), 0)
        self.moveMinY = getXMLFloat(xmlFile, pitKey .. '#planeMinY')
        self.moveMaxY = getXMLFloat(xmlFile, pitKey .. '#planeMaxY')
        self.movingId = Utils.indexToObject(nodeId, getXMLString(xmlFile, pitKey .. '#planeNode'))
        self.animatedObjectSaveId = getXMLString(xmlFile, pitKey .. '#animatedObjectSaveId')
    end
end

---
-- @param self
-- @param nodeId
-- @param xmlFile
-- @param baseKey
-- @param references
--
function HoseSystemFillTrigger.loadHoseSystemReferences(self, nodeId, xmlFile, baseKey, references)
    local i = 0

    while true do
        local key = string.format(baseKey .. 'hoseSystemReference(%d)', i)

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

            local entry = {
                id = id,
                node = self.referenceNodes[id],
                isUsed = false,
                flowOpened = false,
                isLocked = false,
                hoseSystem = nil,
                isObject = true,
                componentIndex = 1, -- we joint to the nodeId
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
-- @param nodeId
-- @param xmlFile
--
function HoseSystemFillTrigger.getTriggerXmlKey(nodeId, xmlFile)
    local objectIdentifier = getUserAttribute(nodeId, 'identifier')

    if objectIdentifier ~= nil then
        local i = 0

        while true do
            local key = ('map.hoseSystemFillTriggers.hoseSystemFillTrigger(%d)'):format(i)

            if not hasXMLProperty(xmlFile, key) then
                break
            end

            local objectXMLIdentifier = getXMLString(xmlFile, key .. '#identifier')

            if objectXMLIdentifier:lower() == objectIdentifier:lower() then
                return key
            end

            i = i + 1
        end
    end

    return nil
end

---
-- @param index
-- @param state
-- @param force
-- @param noEventSend
--
function HoseSystemFillTrigger:toggleLock(index, state, force, noEventSend)
    local reference = self.hoseSystemReferences[index]

    if reference ~= nil and reference.isLocked ~= state or force then
        HoseSystemReferenceLockEvent.sendEvent(self, index, state, force, noEventSend)

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
function HoseSystemFillTrigger:toggleManureFlow(index, state, force, noEventSend)
    local reference = self.hoseSystemReferences[index]

    if reference ~= nil and reference.flowOpened ~= state or force then
        HoseSystemReferenceManureFlowEvent.sendEvent(self, index, state, force, noEventSend)

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
function HoseSystemFillTrigger:setIsUsed(index, state, hoseSystem, noEventSend)
    local reference = self.hoseSystemReferences[index]

    if reference ~= nil and reference.isUsed ~= state then
        HoseSystemReferenceIsUsedEvent.sendEvent(self.referenceType, self, index, state, hoseSystem, noEventSend)

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

function HoseSystemFillTrigger:updatePlaneGraphics(node, fillDirection, delta)
    if self.isClient and self.supportsHoseSystem then
        if node ~= nil and getHasShaderParameter(node, 'displacementScaleSpeedFrequency') then
            delta = Utils.clamp(delta / 1.5, 0, 5)

            local scale = HoseSystemUtil:mathRound(math.min(delta / 128, 0.05), 3)
            local frequency = math.max(5, delta * 2 ^ 2)
            -- Todo: do this properly and only set this at first state and idle state
            local speed = fillDirection == HoseSystemPumpMotor.IN and delta * 1.5 or (delta * 1.5) * 2

            local x, y, z, w = getShaderParameter(node, 'displacementScaleSpeedFrequency')

            if math.abs(z - frequency) > 0.1 or math.abs(x - scale) > 0.01 then
                -- Todo: delete
--                print("delta: " .. delta)
--                print("scale: " .. scale)
--                print("freq: " .. frequency)
--                print("speed: " .. speed)

                setShaderParameter(node, 'displacementScaleSpeedFrequency', scale, 5, frequency, w, false)
            end
        end
    end
end