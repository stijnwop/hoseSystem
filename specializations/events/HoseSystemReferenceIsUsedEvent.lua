--
-- Set is used event
--
-- Authors: Wopster
-- Description: Event when the reference is being used by a use to trigger actions
--
-- Copyright (c) Wopster, 2017

HoseSystemReferenceIsUsedEvent = {}
HoseSystemReferenceIsUsedEvent_mt = Class(HoseSystemReferenceIsUsedEvent, Event)

InitEventClass(HoseSystemReferenceIsUsedEvent, 'HoseSystemReferenceIsUsedEvent')

function HoseSystemReferenceIsUsedEvent:emptyNew()
    local event = Event:new(HoseSystemReferenceIsUsedEvent_mt)
    return event
end

function HoseSystemReferenceIsUsedEvent:new(object, referenceId, state, hoseSystem)
    local event = HoseSystemReferenceIsUsedEvent:emptyNew()

    event.object = object
    event.referenceId = referenceId
    event.state = state
    event.hoseSystem = hoseSystem

    return event
end

function HoseSystemReferenceIsUsedEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteUIntN(streamId, self.referenceId - 1, HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS)
    streamWriteBool(streamId, self.state)
    streamWriteBool(streamId, self.hoseSystem ~= nil)

    if self.hoseSystem ~= nil then
        writeNetworkNodeObject(streamId, self.hoseSystem)
    end
end

function HoseSystemReferenceIsUsedEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.referenceId = streamReadUIntN(streamId, HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS) + 1
    self.state = streamReadBool(streamId)

    if streamReadBool(streamId) then
        self.hoseSystem = readNetworkNodeObject(streamId)
    end

    self:run(connection)
end

function HoseSystemReferenceIsUsedEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    self.object:setIsUsed(self.referenceId, self.state, self.hoseSystem, true)
end

function HoseSystemReferenceIsUsedEvent.sendEvent(object, referenceId, state, hoseSystem, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemReferenceIsUsedEvent:new(object, referenceId, state, hoseSystem), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(HoseSystemReferenceIsUsedEvent:new(object, referenceId, state, hoseSystem))
        end
    end
end