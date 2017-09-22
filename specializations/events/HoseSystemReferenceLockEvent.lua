--
-- Lock event
--
-- Authors: Wopster
-- Description: Event when the lock state changes from the connector
--
-- Copyright (c) Wopster, 2017

HoseSystemReferenceLockEvent = {}
HoseSystemReferenceLockEvent_mt = Class(HoseSystemReferenceLockEvent, Event)

InitEventClass(HoseSystemReferenceLockEvent, 'HoseSystemReferenceLockEvent')

function HoseSystemReferenceLockEvent:emptyNew()
    local event = Event:new(HoseSystemReferenceLockEvent_mt)
    return event
end

function HoseSystemReferenceLockEvent:new(object, referenceId, state, force)
    local event = HoseSystemReferenceLockEvent:emptyNew()

    event.object = object
    event.referenceId = referenceId
    event.state = state
    event.force = force

    return event
end

function HoseSystemReferenceLockEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteUIntN(streamId, self.referenceId - 1, HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS)
    streamWriteBool(streamId, self.state)
    streamWriteBool(streamId, self.force)
end

function HoseSystemReferenceLockEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.referenceId = streamReadUIntN(streamId, HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS) + 1
    self.state = streamReadBool(streamId)
    self.force = streamReadBool(streamId)
    self:run(connection)
end

function HoseSystemReferenceLockEvent:run(connection)
    self.object:toggleLock(self.referenceId, self.state, self.force, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end
end

function HoseSystemReferenceLockEvent.sendEvent(object, referenceId, state, force, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemReferenceLockEvent:new(object, referenceId, state, force), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(HoseSystemReferenceLockEvent:new(object, referenceId, state, force))
        end
    end
end