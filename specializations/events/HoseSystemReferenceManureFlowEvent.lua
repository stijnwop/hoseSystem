--
-- Manure flow event
--
-- Authors: Wopster
-- Description: Event when the manure flow state changes from the connector
--
-- Copyright (c) Wopster, 2017

HoseSystemReferenceManureFlowEvent = {}
HoseSystemReferenceManureFlowEvent_mt = Class(HoseSystemReferenceManureFlowEvent, Event)

InitEventClass(HoseSystemReferenceManureFlowEvent, 'HoseSystemReferenceManureFlowEvent')

function HoseSystemReferenceManureFlowEvent:emptyNew()
    local event = Event:new(HoseSystemReferenceManureFlowEvent_mt)
    return event
end

function HoseSystemReferenceManureFlowEvent:new(object, referenceId, state, force)
    local event = HoseSystemReferenceManureFlowEvent:emptyNew()

    event.object = object
    event.referenceId = referenceId
    event.state = state
    event.force = force

    return event
end

function HoseSystemReferenceManureFlowEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.object))
    streamWriteUIntN(streamId, self.referenceId - 1, HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS)
    streamWriteBool(streamId, self.state)
    streamWriteBool(streamId, self.force)
end

function HoseSystemReferenceManureFlowEvent:readStream(streamId, connection)
    self.object = networkGetObject(streamReadInt32(streamId))
    self.referenceId = streamReadUIntN(streamId, HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS) + 1
    self.state = streamReadBool(streamId)
    self.force = streamReadBool(streamId)
    self:run(connection)
end

function HoseSystemReferenceManureFlowEvent:run(connection)
    self.object:toggleManureFlow(self.referenceId, self.state, self.force, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end
end

function HoseSystemReferenceManureFlowEvent.sendEvent(object, referenceId, state, force, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemReferenceManureFlowEvent:new(object, referenceId, state, force), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(HoseSystemReferenceManureFlowEvent:new(object, referenceId, state, force))
        end
    end
end

