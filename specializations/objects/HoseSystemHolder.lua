---
--

HoseSystemHolder = {}

local HoseSystemHolder_mt = Class(HoseSystemHolder, Object)
---
-- @param nodeId
--
function HoseSystemHolder:onCreate(nodeId)
    local object = HoseSystemHolder:new(g_server ~= nil, g_client ~= nil, nodeId)

    if object ~= nil then
        g_currentMission:addOnCreateLoadedObject(object)
        object:register()
    end
end

---
-- @param isServer
-- @param isClient
-- @param nodeId
--
function HoseSystemHolder:new(isServer, isClient, nodeId)
    if not HoseSystemObjectsUtil.getIsNodeValid(nodeId) then
        return nil
    end

    local holder = Object:new(isServer, isClient, HoseSystemHolder_mt)

    self.nodeId = nodeId

    local node = Utils.indexToObject(nodeId, getUserAttribute(nodeId, "node"))

    if node ~= nil then
        holder.components = {}
        holder.referenceNodes = {}
        holder.hoseSystemReferences = {}
        holder.attachedHoseSystemReferences = {}

        table.insert(holder.components, { node = nodeId })
        table.insert(holder.referenceNodes, node)
        table.insert(holder.hoseSystemReferences, {
            id = 1,
            node = node,
            isUsed = false,
            flowOpened = false,
            isLocked = false,
            liquidManureHose = nil,
            isObject = true,
            componentIndex = 1, -- we joint to the nodeId
            parkable = false,
            inRangeDistance = 1.5
        })

        g_currentMission:addNodeObject(node, self)

        holder.supportsHoseSystem = true

        if g_currentMission.hoseSystemReferences == nil then
            g_currentMission.hoseSystemReferences = {}
        end

        table.insert(g_currentMission.hoseSystemReferences, holder)

        holder.referenceType = HoseSystemConnectorFactory.getInitialType(HoseSystemConnectorFactory.TYPE_HOSE_COUPLING)
    else
        -- Todo: log
        return nil
    end

    return holder
end

---
--
function HoseSystemHolder:delete()
    if self.referenceNodes ~= nil then
        for _, referenceNode in pairs(self.referenceNodes) do
            g_currentMission:removeNodeObject(referenceNode)
        end
    end

    HoseSystemUtil:removeElementFromList(g_currentMission.hoseSystemReferences, self)
end

---
-- @param referenceId
-- @param hoseSystem
--
function HoseSystemHolder:onConnectorAttach(referenceId, hoseSystem)
    -- register attached hoses this way
    local reference = self.hoseSystemReferences[referenceId]

    if reference ~= nil and self.attachedHoseSystemReferences[referenceId] == nil then
        self.attachedHoseSystemReferences[referenceId] = {
            showEffect = false
        }
    end

    --    if self.isServer then
    self:setIsUsed(referenceId, true, hoseSystem, true)
    --    end
end

---
-- @param referenceId
--
function HoseSystemHolder:onConnectorDetach(referenceId)
    local reference = self.hoseSystemReferences[referenceId]

    --    if self.isServer then
    self:setIsUsed(referenceId, false, nil, true)
    --    end

    if reference ~= nil and self.attachedHoseSystemReferences[referenceId] then
        self.attachedHoseSystemReferences[referenceId] = nil
    end
end

---
-- @param index
-- @param state
-- @param hoseSystem
-- @param noEventSend
--
function HoseSystemHolder:setIsUsed(index, state, hoseSystem, noEventSend)
    local reference = self.hoseSystemReferences[index]

    if reference ~= nil and reference.isUsed ~= state then
        HoseSystemReferenceIsUsedEvent.sendEvent(self.referenceType, self, index, state, hoseSystem, noEventSend)

        reference.isUsed = state
        reference.hoseSystem = hoseSystem
    end
end
