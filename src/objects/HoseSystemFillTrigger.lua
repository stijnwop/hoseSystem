--
-- HoseSystemFillTrigger
--
-- Authors: Wopster
-- Description: Base class for the HoseSystemFillTrigger
--
-- Copyright (c) Wopster, 2018

HoseSystemFillTrigger = {}

HoseSystemFillTrigger.TRIGGER_CALLBACK = "triggerCallback"

local HoseSystemFillTrigger_mt = Class(HoseSystemFillTrigger, Object)

function HoseSystemFillTrigger:preLoadHoseSystem()
end

---
-- @param mt
-- @param nodeId
--
function HoseSystemFillTrigger:new(isServer, isClient, mt, nodeId, strategyType)
    local mt = mt == nil and HoseSystemFillTrigger_mt or mt

    local trigger = Object:new(isServer, isClient, mt)

    trigger:register()
    trigger.triggerId = nil
    trigger.nodeId = nodeId

    local strategy = HoseSystemExpensesStrategy:new(trigger)

    trigger.strategy = strategy

    return trigger
end

---
-- @param nodeId
-- @param fillType
--
function HoseSystemFillTrigger:load(nodeId, fillType)
    local xmlFilename = getUserAttribute(nodeId, 'xmlFilename')

    if xmlFilename == nil then
        if HoseSystem.debugRendering then
            HoseSystemUtil:log(HoseSystemUtil.WARNING, 'HoseSystemFillTrigger is trying to load the xml file, but the file could not be found! Loading default triggers..')
        end

        return false
    end

    if not HoseSystemObjectsUtil.getIsNodeValid(nodeId) then
        return false
    end

    if self.nodeId == nil then
        self.nodeId = nodeId
    end

    self.triggerId = Utils.indexToObject(nodeId, getUserAttribute(nodeId, "triggerIndex"))

    if self.triggerId == nil then
        self.triggerId = nodeId
    end

    if not HoseSystemObjectsUtil.getIsValidTrigger(self.triggerId) then
        return false
    end

    addTrigger(self.triggerId, HoseSystemFillTrigger.TRIGGER_CALLBACK, self.strategy)

    self.fillType = fillType ~= nil and fillType or HoseSystemFillTrigger.getFillTypeFromUserAttribute(nodeId)

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

    g_currentMission:addNodeObject(self.nodeId, self)

    -- Todo: Fix and delete this later
    self.hoseSystemParent = self
    self.fillLevelObject = self

    if hasReferences then
        table.insert(g_hoseSystem.hoseSystemReferences, self)
    end

    self.isEnabled = true
    self.planeDirtyFlag = self:getNextDirtyFlag()

    return true
end

function HoseSystemFillTrigger:readStream(streamId)
end

function HoseSystemFillTrigger:writeStream(streamId)
end

function HoseSystemFillTrigger:readUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        local isDirty = streamReadBool(streamId)
        -- update shader
    end
end

function HoseSystemFillTrigger:writeUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        if streamWriteBool(streamId, bitAND(dirtyMask, self.planeDirtyFlag) ~= 0) then
        end
    end
end

function HoseSystemFillTrigger:delete()
    removeTrigger(self.triggerId)

    if self.detectionNode ~= nil then
        g_currentMission:removeNodeObject(self.detectionNode)
    end

    if self.referenceNodes ~= nil then
        for _, referenceNode in pairs(self.referenceNodes) do
            g_currentMission:removeNodeObject(referenceNode)
        end
    end

    HoseSystemUtil:removeElementFromList(g_hoseSystem.hoseSystemReferences, self)
end

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

    if self.isServer then
        self:setIsUsed(referenceId, true, hoseSystem)
    end
end

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

function HoseSystemFillTrigger:allowFillType(fillType)
    return fillType == FillUtil.FILLTYPE_UNKNOWN or fillType == self.fillType
end

function HoseSystemFillTrigger:getFillLevel(fillType)
    return self.strategy:getFillLevel(fillType)
end

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

function HoseSystemFillTrigger:setFillLevel(fillLevel, delta, noEventSend)
    return self.strategy:setFillLevel(fillLevel, delta, noEventSend)
end

function HoseSystemFillTrigger:getIsActivatable(fillable)
    if not self.strategy:getIsActivatable(fillable) then
        return false
    end

    if not fillable:allowFillType(self.fillType, false) then
        return false
    end

    return true
end

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

        local offsetY = getXMLFloat(xmlFile, pitKey .. '#offsetY')

        if offsetY ~= nil then
            self.offsetY = offsetY
        end

        self.moveMinY = getXMLFloat(xmlFile, pitKey .. '#planeMinY')
        self.moveMaxY = getXMLFloat(xmlFile, pitKey .. '#planeMaxY')
        self.movingId = Utils.indexToObject(nodeId, getXMLString(xmlFile, pitKey .. '#planeNode'))

        self.animatedObjectSaveId = getXMLString(xmlFile, pitKey .. '#animatedObjectSaveId')
    end
end

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
                liquidManureHose = nil,
                grabPoints = nil,
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